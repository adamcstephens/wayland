# Wayland Client Library for Elixir

A complete Elixir library for building Wayland clients using Rustler and the Smithay wayland-client Rust library.

> **⚠️ Current Status**: The library compiles successfully but Rust NIF functionality is currently disabled due to dependency access restrictions. Full functionality requires installing the `rustler` dependency from hex.pm and enabling Rust compilation.

## Features

- **Display Connection Management**: Connect to Wayland display servers
- **Surface Operations**: Create and manage surfaces for rendering
- **Registry Support**: Discover and bind to global objects
- **Event Processing**: Handle Wayland protocol events
- **Resource Management**: Proper cleanup and resource handling
- **Rust Integration**: High-performance NIF implementation using Smithay

## Installation

Add `wayland_client` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:wayland_client, "~> 0.1.0"}
  ]
end
```

## Requirements

- **Elixir**: >= 1.14
- **Rust**: >= 1.70 (for building the NIF)
- **Wayland**: A running Wayland compositor
- **System packages**: wayland-dev, libwayland-client0-dev (on Debian/Ubuntu)

## Enabling Full Functionality

The library currently compiles with stub implementations. To enable the full Rust-based Wayland functionality:

1. **Install Rustler dependency**: Uncomment the rustler dependency in `mix.exs`:
   ```elixir
   defp deps do
     [
       {:rustler, "~> 0.30"}
     ]
   end
   ```

2. **Enable Rust compilation**: Uncomment the rustler configuration in `mix.exs`:
   ```elixir
   compilers: [:rustler] ++ Mix.compilers(),
   rustler_crates: [
     wayland_client_nif: [
       path: "native/wayland_client",
       mode: rustler_mode(Mix.env())
     ]
   ]
   ```

3. **Update NIF module**: In `lib/wayland_client/nif.ex`, uncomment:
   ```elixir
   use Rustler, otp_app: :wayland_client, crate: "wayland_client_nif"
   ```

4. **Install dependencies and compile**:
   ```bash
   mix deps.get
   mix compile
   ```

## Quick Start

```elixir
# Connect to the default Wayland display
{:ok, display} = WaylandClient.connect()

# Get the registry to discover available globals
{:ok, registry} = WaylandClient.get_registry(display)

# List all available global objects
{:ok, globals} = WaylandClient.list_globals(registry)
IO.inspect(globals)
# Output: [%{id: 1, interface: "wl_compositor", version: 4}, ...]

# Create a surface (requires compositor)
{:ok, surface} = WaylandClient.create_surface(display)

# Process any pending events
:ok = WaylandClient.flush_events(display)

# Clean up when done
WaylandClient.destroy_surface(surface)
WaylandClient.disconnect(display)
```

## Core Modules

### WaylandClient

The main API module providing high-level functions:

- `connect/0`, `connect/1` - Connect to Wayland display
- `disconnect/1` - Disconnect from display
- `create_surface/1` - Create a new surface
- `destroy_surface/1` - Destroy a surface
- `get_registry/1` - Get the registry for global discovery
- `list_globals/1` - List all available globals
- `flush_events/1` - Process pending events
- `connected?/1` - Check connection status

### WaylandClient.Display

Display connection management:

- Connection lifecycle management
- Event processing
- File descriptor access for integration
- Roundtrip synchronization

### WaylandClient.Surface

Surface operations:

- Surface creation and destruction
- Buffer attachment
- Damage tracking
- Input and opaque regions
- State commit

### WaylandClient.Registry

Global object discovery:

- Registry access
- Global object listing
- Binding to specific globals
- Interface-based searches

## Advanced Usage

### Working with Globals

```elixir
{:ok, display} = WaylandClient.connect()
{:ok, registry} = WaylandClient.get_registry(display)

# Find the compositor
{:ok, compositor_global} = WaylandClient.Registry.find_global(registry, "wl_compositor")

# Bind to the compositor
{:ok, compositor} = WaylandClient.Registry.bind(
  registry, 
  compositor_global.id, 
  "wl_compositor", 
  compositor_global.version
)

# Find and bind in one step
{:ok, shell} = WaylandClient.Registry.find_and_bind(registry, "wl_shell")
```

### Event Loop Integration

```elixir
defmodule MyWaylandApp do
  def run do
    {:ok, display} = WaylandClient.connect()
    {:ok, fd} = WaylandClient.Display.get_fd(display)
    
    # Integrate with your event loop
    # This is pseudo-code - adapt to your event system
    EventLoop.watch_fd(fd, fn ->
      WaylandClient.flush_events(display)
    end)
    
    # Your application logic here
    main_loop(display)
  end
  
  defp main_loop(display) do
    # Process events
    WaylandClient.flush_events(display)
    
    # Your rendering/logic here
    
    # Continue loop
    Process.sleep(16)  # ~60 FPS
    main_loop(display)
  end
end
```

### Surface Rendering

```elixir
# Create and configure a surface
{:ok, display} = WaylandClient.connect()
{:ok, surface} = WaylandClient.create_surface(display)

# Attach a buffer (you'll need to create the buffer first)
WaylandClient.Surface.attach(surface, buffer, 0, 0)

# Mark the entire surface as damaged
WaylandClient.Surface.damage(surface, 0, 0, width, height)

# Commit the changes
WaylandClient.Surface.commit(surface)
```

## Building

The library uses Rustler to build the Rust NIF automatically:

```bash
# Install dependencies
mix deps.get

# Compile (this will build the Rust NIF)
mix compile

# Run tests
mix test

# Generate documentation
mix docs
```

## Development

### Building Manually

If you need to build the Rust components manually:

```bash
cd native/wayland_client
cargo build
```

### Debug Mode

The NIF is built in debug mode by default in development:

```bash
# Force release mode
MIX_ENV=prod mix compile
```

### Troubleshooting

**Connection Issues:**
- Ensure `WAYLAND_DISPLAY` is set
- Verify Wayland compositor is running
- Check permissions on the Wayland socket

**Build Issues:**
- Install required system packages: `libwayland-dev`
- Ensure Rust toolchain is installed
- Clear build artifacts: `mix clean`

**NIF Loading Issues:**
- Recompile: `mix deps.compile rustler --force`
- Check Rust target matches your system

## Protocol Support

Currently supported Wayland protocols:

- **Core Protocol**: wl_display, wl_registry, wl_compositor, wl_surface
- **Shell Extensions**: Basic shell support (extensible)
- **Input**: Planned for future releases
- **Output**: Planned for future releases

## Architecture

The library consists of:

1. **Elixir API Layer**: High-level, idiomatic Elixir interfaces
2. **Rust NIF Layer**: Low-level Wayland protocol handling using Smithay
3. **Resource Management**: Automatic cleanup of Wayland resources
4. **Event System**: Asynchronous event processing

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Smithay](https://github.com/Smithay/smithay) - Rust Wayland implementation
- [Rustler](https://github.com/rusterlium/rustler) - Rust NIF framework
