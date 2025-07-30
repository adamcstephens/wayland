use rustler::{Atom, Env, Error, NifResult, ResourceArc, Term};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use wayland_client::{
    protocol::{wl_compositor, wl_registry, wl_surface},
    Connection, Dispatch, EventQueue, QueueHandle,
};

mod atoms {
    rustler::atoms! {
        ok,
        error,
        nil,
        not_found,
        nif_not_loaded,
    }
}

// Error types
#[derive(thiserror::Error, Debug)]
enum WaylandError {
    #[error("Connection failed: {0}")]
    ConnectionFailed(String),
    #[error("Protocol error: {0}")]
    ProtocolError(String),
    #[error("Resource not found")]
    ResourceNotFound,
    #[error("Invalid argument: {0}")]
    InvalidArgument(String),
    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),
}

impl From<WaylandError> for Error {
    fn from(err: WaylandError) -> Self {
        Error::Term(Box::new(format!("{}", err)))
    }
}

// Resource types
#[derive(Debug)]
struct DisplayResource {
    connection: Connection,
    event_queue: Arc<Mutex<EventQueue<AppData>>>,
}

// Safety: Connection is thread-safe and EventQueue is wrapped in Arc<Mutex<_>>
unsafe impl Send for DisplayResource {}
unsafe impl Sync for DisplayResource {}

#[derive(Debug)]
struct SurfaceResource {
    surface: wl_surface::WlSurface,
}

// Safety: WlSurface implements Send + Sync in wayland-client
unsafe impl Send for SurfaceResource {}
unsafe impl Sync for SurfaceResource {}

#[derive(Debug)]
struct RegistryResource {
    registry: wl_registry::WlRegistry,
    globals: Arc<Mutex<HashMap<u32, GlobalInfo>>>,
}

// Safety: WlRegistry implements Send + Sync and HashMap is wrapped in Arc<Mutex<_>>
unsafe impl Send for RegistryResource {}
unsafe impl Sync for RegistryResource {}

#[derive(Debug, Clone)]
struct GlobalInfo {
    interface: String,
    version: u32,
}

#[derive(Debug, Clone)]
struct AppData {
    globals: Arc<Mutex<HashMap<u32, GlobalInfo>>>,
}

impl Dispatch<wl_registry::WlRegistry, ()> for AppData {
    fn event(
        state: &mut Self,
        _registry: &wl_registry::WlRegistry,
        event: wl_registry::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &QueueHandle<AppData>,
    ) {
        match event {
            wl_registry::Event::Global { name, interface, version } => {
                let mut globals = state.globals.lock().unwrap();
                globals.insert(name, GlobalInfo { interface, version });
            }
            wl_registry::Event::GlobalRemove { name } => {
                let mut globals = state.globals.lock().unwrap();
                globals.remove(&name);
            }
            _ => {}
        }
    }
}

impl Dispatch<wl_compositor::WlCompositor, ()> for AppData {
    fn event(
        _state: &mut Self,
        _compositor: &wl_compositor::WlCompositor,
        _event: wl_compositor::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &QueueHandle<AppData>,
    ) {
        // Compositor events (none currently defined)
    }
}

impl Dispatch<wl_surface::WlSurface, ()> for AppData {
    fn event(
        _state: &mut Self,
        _surface: &wl_surface::WlSurface,
        event: wl_surface::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &QueueHandle<AppData>,
    ) {
        match event {
            wl_surface::Event::Enter { .. } => {
                // Surface entered an output
            }
            wl_surface::Event::Leave { .. } => {
                // Surface left an output
            }
            _ => {}
        }
    }
}

// NIF functions

#[rustler::nif]
fn connect() -> NifResult<ResourceArc<DisplayResource>> {
    connect_impl(None)
}

#[rustler::nif]
fn connect_to_display(display_name: String) -> NifResult<ResourceArc<DisplayResource>> {
    connect_impl(Some(display_name))
}

fn connect_impl(display_name: Option<String>) -> NifResult<ResourceArc<DisplayResource>> {
    let connection = match display_name {
        Some(_name) => {
            // wayland-client 0.31 doesn't support connect_to_env_with_name
            // Use the default connection and ignore the display name for now
            Connection::connect_to_env()
                .map_err(|e| WaylandError::ConnectionFailed(e.to_string()))?
        },
        None => Connection::connect_to_env()
            .map_err(|e| WaylandError::ConnectionFailed(e.to_string()))?,
    };

    let display = connection.display();
    let globals = Arc::new(Mutex::new(HashMap::new()));
    
    let mut event_queue = connection.new_event_queue();
    let qh = event_queue.handle();
    
    let _registry = display.get_registry(&qh, ());
    
    let app_data = AppData {
        globals: globals.clone(),
    };
    
    // Perform initial roundtrip to get globals
    event_queue
        .roundtrip(&mut app_data.clone())
        .map_err(|e| WaylandError::ProtocolError(e.to_string()))?;

    let resource = DisplayResource {
        connection,
        event_queue: Arc::new(Mutex::new(event_queue)),
    };

    Ok(ResourceArc::new(resource))
}

#[rustler::nif]
fn disconnect(_display: ResourceArc<DisplayResource>) -> NifResult<Atom> {
    // Connection is automatically closed when dropped
    Ok(atoms::ok())
}

#[rustler::nif]
fn is_connected(_display: ResourceArc<DisplayResource>) -> NifResult<(Atom, bool)> {
    // For simplicity, assume connection is always alive if resource exists
    // In a real implementation, you might want to check the connection status
    Ok((atoms::ok(), true))
}

#[rustler::nif]
fn flush_events(display: ResourceArc<DisplayResource>) -> NifResult<Atom> {
    let mut app_data = AppData {
        globals: Arc::new(Mutex::new(HashMap::new())),
    };
    
    display
        .event_queue
        .lock()
        .unwrap()
        .dispatch_pending(&mut app_data)
        .map_err(|e| WaylandError::ProtocolError(e.to_string()))?;

    Ok(atoms::ok())
}

#[rustler::nif]
fn get_fd(display: ResourceArc<DisplayResource>) -> NifResult<(Atom, i32)> {
    use std::os::unix::io::{AsFd, AsRawFd};
    
    let fd = display.connection.as_fd().as_raw_fd();
    Ok((atoms::ok(), fd))
}

#[rustler::nif]
fn roundtrip(display: ResourceArc<DisplayResource>) -> NifResult<Atom> {
    let mut app_data = AppData {
        globals: Arc::new(Mutex::new(HashMap::new())),
    };
    
    display
        .event_queue
        .lock()
        .unwrap()
        .roundtrip(&mut app_data)
        .map_err(|e| WaylandError::ProtocolError(e.to_string()))?;

    Ok(atoms::ok())
}

#[rustler::nif]
fn create_surface(display: ResourceArc<DisplayResource>) -> NifResult<ResourceArc<SurfaceResource>> {
    let qh = display.event_queue.lock().unwrap().handle();
    
    // We need to bind to the compositor first
    // This is a simplified version - in practice you'd get this from the registry
    let display_proxy = display.connection.display();
    let _registry = display_proxy.get_registry(&qh, ());
    
    // For now, create a placeholder surface
    // In a real implementation, you'd need to:
    // 1. Get the compositor from the registry
    // 2. Create the surface from the compositor
    
    Err(Error::Term(Box::new("Surface creation not yet implemented - need compositor".to_string())))
}

#[rustler::nif]
fn destroy_surface(_surface: ResourceArc<SurfaceResource>) -> NifResult<Atom> {
    // Surface is automatically destroyed when dropped
    Ok(atoms::ok())
}

#[rustler::nif]
fn get_registry(display: ResourceArc<DisplayResource>) -> NifResult<ResourceArc<RegistryResource>> {
    let qh = display.event_queue.lock().unwrap().handle();
    let display_proxy = display.connection.display();
    let registry = display_proxy.get_registry(&qh, ());
    let globals = Arc::new(Mutex::new(HashMap::new()));

    let resource = RegistryResource {
        registry,
        globals,
    };

    Ok(ResourceArc::new(resource))
}

#[rustler::nif]
fn list_globals(registry: ResourceArc<RegistryResource>) -> NifResult<(Atom, Vec<(u32, String, u32)>)> {
    let globals = registry.globals.lock().unwrap();
    let global_list: Vec<(u32, String, u32)> = globals
        .iter()
        .map(|(id, info)| (*id, info.interface.clone(), info.version))
        .collect();

    Ok((atoms::ok(), global_list))
}

#[rustler::nif]
fn bind_global(
    _registry: ResourceArc<RegistryResource>,
    _id: u32,
    _interface: String,
    _version: u32,
) -> NifResult<Atom> {
    // Binding to globals requires specific implementation for each interface type
    // This is a placeholder
    Err(Error::Term(Box::new("bind_global not yet implemented".to_string())))
}

#[rustler::nif]
fn get_version() -> NifResult<String> {
    Ok("0.1.0".to_string())
}

// Placeholder implementations for other functions
#[rustler::nif]
fn surface_attach(_surface: ResourceArc<SurfaceResource>, _buffer: Option<String>, _x: i32, _y: i32) -> NifResult<Atom> {
    Ok(atoms::ok())
}

#[rustler::nif]
fn surface_damage(_surface: ResourceArc<SurfaceResource>, _x: i32, _y: i32, _width: i32, _height: i32) -> NifResult<Atom> {
    Ok(atoms::ok())
}

#[rustler::nif]
fn surface_commit(_surface: ResourceArc<SurfaceResource>) -> NifResult<Atom> {
    Ok(atoms::ok())
}

#[rustler::nif]
fn surface_set_input_region(_surface: ResourceArc<SurfaceResource>, _region: Option<String>) -> NifResult<Atom> {
    Ok(atoms::ok())
}

#[rustler::nif]
fn surface_set_opaque_region(_surface: ResourceArc<SurfaceResource>, _region: Option<String>) -> NifResult<Atom> {
    Ok(atoms::ok())
}

#[rustler::nif]
fn create_shm_pool(_display: ResourceArc<DisplayResource>, _size: u64) -> NifResult<Atom> {
    Err(Error::Term(Box::new("create_shm_pool not yet implemented".to_string())))
}

#[rustler::nif]
fn create_buffer(_pool: String, _offset: u64, _width: u32, _height: u32, _stride: u32, _format: u32) -> NifResult<Atom> {
    Err(Error::Term(Box::new("create_buffer not yet implemented".to_string())))
}

#[rustler::nif]
fn create_region(_compositor: String) -> NifResult<Atom> {
    Err(Error::Term(Box::new("create_region not yet implemented".to_string())))
}

#[rustler::nif]
fn region_add(_region: String, _x: i32, _y: i32, _width: i32, _height: i32) -> NifResult<Atom> {
    Ok(atoms::ok())
}

#[rustler::nif]
fn region_subtract(_region: String, _x: i32, _y: i32, _width: i32, _height: i32) -> NifResult<Atom> {
    Ok(atoms::ok())
}

#[rustler::nif]
fn set_event_handler(_object: String, _handler_pid: String) -> NifResult<Atom> {
    Ok(atoms::ok())
}

#[rustler::nif]
fn remove_event_handler(_object: String) -> NifResult<Atom> {
    Ok(atoms::ok())
}

#[rustler::nif]
fn get_protocol_version(_interface: String) -> NifResult<(Atom, u32)> {
    // Return a default version for now
    Ok((atoms::ok(), 1))
}

rustler::init!(
    "Elixir.WaylandClient.Nif",
    load = on_load
);

fn on_load(env: Env, _info: Term) -> bool {
    rustler::resource!(DisplayResource, env);
    rustler::resource!(SurfaceResource, env);
    rustler::resource!(RegistryResource, env);
    true
}