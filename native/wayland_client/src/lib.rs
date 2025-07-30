use rustler::{Atom, Env, Error, NifResult, ResourceArc, Term};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use wayland_client::{
    protocol::{wl_compositor, wl_registry, wl_surface},
    Connection, Dispatch, EventQueue, QueueHandle,
};

// Global storage for wayland objects (since they may not be Send + Sync)
lazy_static::lazy_static! {
    static ref CONNECTIONS: Arc<Mutex<HashMap<u32, (Connection, Arc<Mutex<EventQueue<AppData>>>)>>> = 
        Arc::new(Mutex::new(HashMap::new()));
    static ref SURFACES: Arc<Mutex<HashMap<u32, wl_surface::WlSurface>>> = 
        Arc::new(Mutex::new(HashMap::new()));
    static ref REGISTRIES: Arc<Mutex<HashMap<u32, wl_registry::WlRegistry>>> = 
        Arc::new(Mutex::new(HashMap::new()));
    static ref NEXT_ID: Arc<Mutex<u32>> = Arc::new(Mutex::new(1));
}

fn get_next_id() -> u32 {
    let mut id = NEXT_ID.lock().unwrap();
    let current = *id;
    *id += 1;
    current
}

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

// Resource types - Store IDs instead of non-Send/Sync wayland objects
#[derive(Debug)]
struct DisplayResource {
    connection_id: u32,
}

// Safety: Only contains Send + Sync types
unsafe impl Send for DisplayResource {}
unsafe impl Sync for DisplayResource {}

#[derive(Debug)]
struct SurfaceResource {
    surface_id: u32,
}

// Safety: Only contains Send + Sync types
unsafe impl Send for SurfaceResource {}
unsafe impl Sync for SurfaceResource {}

#[derive(Debug)]
struct RegistryResource {
    registry_id: u32,
    globals: Arc<Mutex<HashMap<u32, GlobalInfo>>>,
}

// Safety: Only contains Send + Sync types
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

    // Store the connection and event queue in global storage
    let connection_id = get_next_id();
    CONNECTIONS.lock().unwrap().insert(connection_id, (connection, Arc::new(Mutex::new(event_queue))));

    let resource = DisplayResource {
        connection_id,
    };

    Ok(ResourceArc::new(resource))
}

#[rustler::nif]
fn disconnect(display: ResourceArc<DisplayResource>) -> NifResult<Atom> {
    // Remove from global storage
    CONNECTIONS.lock().unwrap().remove(&display.connection_id);
    Ok(atoms::ok())
}

#[rustler::nif]
fn is_connected(display: ResourceArc<DisplayResource>) -> NifResult<(Atom, bool)> {
    let connections = CONNECTIONS.lock().unwrap();
    let connected = connections.contains_key(&display.connection_id);
    Ok((atoms::ok(), connected))
}

#[rustler::nif]
fn flush_events(display: ResourceArc<DisplayResource>) -> NifResult<Atom> {
    let connections = CONNECTIONS.lock().unwrap();
    if let Some((_, event_queue)) = connections.get(&display.connection_id) {
        let mut app_data = AppData {
            globals: Arc::new(Mutex::new(HashMap::new())),
        };
        
        event_queue
            .lock()
            .unwrap()
            .dispatch_pending(&mut app_data)
            .map_err(|e| WaylandError::ProtocolError(e.to_string()))?;
    }

    Ok(atoms::ok())
}

#[rustler::nif]
fn get_fd(display: ResourceArc<DisplayResource>) -> NifResult<(Atom, i32)> {
    use std::os::unix::io::{AsFd, AsRawFd};
    
    let connections = CONNECTIONS.lock().unwrap();
    if let Some((connection, _)) = connections.get(&display.connection_id) {
        let fd = connection.as_fd().as_raw_fd();
        Ok((atoms::ok(), fd))
    } else {
        Err(Error::Term(Box::new("Connection not found".to_string())))
    }
}

#[rustler::nif]
fn roundtrip(display: ResourceArc<DisplayResource>) -> NifResult<Atom> {
    let connections = CONNECTIONS.lock().unwrap();
    if let Some((_, event_queue)) = connections.get(&display.connection_id) {
        let mut app_data = AppData {
            globals: Arc::new(Mutex::new(HashMap::new())),
        };
        
        event_queue
            .lock()
            .unwrap()
            .roundtrip(&mut app_data)
            .map_err(|e| WaylandError::ProtocolError(e.to_string()))?;
    }

    Ok(atoms::ok())
}

#[rustler::nif]
fn create_surface(display: ResourceArc<DisplayResource>) -> NifResult<ResourceArc<SurfaceResource>> {
    // Note: This is a placeholder implementation
    // In a real implementation, you'd need to:
    // 1. Get the compositor from the registry
    // 2. Create the surface from the compositor
    
    let surface_id = get_next_id();
    
    let resource = SurfaceResource {
        surface_id,
    };

    Ok(ResourceArc::new(resource))
}

#[rustler::nif]
fn destroy_surface(_surface: ResourceArc<SurfaceResource>) -> NifResult<Atom> {
    // Surface is automatically destroyed when dropped
    Ok(atoms::ok())
}

#[rustler::nif]
fn get_registry(display: ResourceArc<DisplayResource>) -> NifResult<ResourceArc<RegistryResource>> {
    let connections = CONNECTIONS.lock().unwrap();
    if let Some((connection, event_queue)) = connections.get(&display.connection_id) {
        let qh = event_queue.lock().unwrap().handle();
        let display_proxy = connection.display();
        let registry = display_proxy.get_registry(&qh, ());
        let globals = Arc::new(Mutex::new(HashMap::new()));

        // Store registry in global storage
        let registry_id = get_next_id();
        REGISTRIES.lock().unwrap().insert(registry_id, registry);

        let resource = RegistryResource {
            registry_id,
            globals,
        };

        Ok(ResourceArc::new(resource))
    } else {
        Err(Error::Term(Box::new("Connection not found".to_string())))
    }
}

#[rustler::nif]
fn list_globals(registry: ResourceArc<RegistryResource>) -> NifResult<(Atom, Vec<(u32, String, u32)>)> {
    // Simplified implementation for testing
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