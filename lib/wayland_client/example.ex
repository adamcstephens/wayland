defmodule WaylandClient.Example do
  @moduledoc """
  Example application demonstrating WaylandClient usage.

  This module shows how to:
  - Connect to a Wayland display server
  - Discover available global objects
  - Create and manage surfaces
  - Handle basic event processing

  Run with: `WaylandClient.Example.run()`
  """

  require Logger

  def run do
    Logger.info("Starting Wayland client example...")

    case connect_to_wayland() do
      {:ok, display} ->
        Logger.info("Connected to Wayland display")
        
        # Discover globals
        discover_globals(display)
        
        # Create a surface (will fail until compositor binding is implemented)
        create_example_surface(display)
        
        # Cleanup
        WaylandClient.disconnect(display)
        Logger.info("Disconnected from Wayland display")

      {:error, reason} ->
        Logger.error("Failed to connect to Wayland display: #{reason}")
        Logger.info("Make sure:")
        Logger.info("  1. A Wayland compositor is running")
        Logger.info("  2. WAYLAND_DISPLAY environment variable is set")
        Logger.info("  3. You have permission to access the Wayland socket")
    end
  end

  defp connect_to_wayland do
    # Try default display first
    case WaylandClient.connect() do
      {:ok, display} -> 
        {:ok, display}
      
      {:error, _} ->
        # Try explicit display names
        ["wayland-0", "wayland-1"]
        |> Enum.reduce_while({:error, "no display found"}, fn display_name, acc ->
          case WaylandClient.connect(display_name) do
            {:ok, display} -> {:halt, {:ok, display}}
            {:error, _} -> {:cont, acc}
          end
        end)
    end
  end

  defp discover_globals(display) do
    Logger.info("Discovering global objects...")
    
    case WaylandClient.get_registry(display) do
      {:ok, registry} ->
        case WaylandClient.list_globals(registry) do
          {:ok, globals} ->
            Logger.info("Found #{length(globals)} global objects:")
            
            Enum.each(globals, fn global ->
              Logger.info("  - #{global.interface} v#{global.version} (id: #{global.id})")
            end)
            
            # Look for common interfaces
            check_for_interface(globals, "wl_compositor", "Compositor")
            check_for_interface(globals, "wl_shell", "Shell")
            check_for_interface(globals, "wl_seat", "Input device")
            check_for_interface(globals, "wl_output", "Display output")

          {:error, reason} ->
            Logger.error("Failed to list globals: #{reason}")
        end

      {:error, reason} ->
        Logger.error("Failed to get registry: #{reason}")
    end
  end

  defp check_for_interface(globals, interface_name, description) do
    case Enum.find(globals, fn global -> global.interface == interface_name end) do
      nil ->
        Logger.warn("#{description} (#{interface_name}) not found")
      
      global ->
        Logger.info("✓ #{description} available: #{interface_name} v#{global.version}")
    end
  end

  defp create_example_surface(display) do
    Logger.info("Attempting to create a surface...")
    
    case WaylandClient.create_surface(display) do
      {:ok, surface} ->
        Logger.info("Surface created successfully!")
        
        # In a real application, you would:
        # 1. Create a shared memory buffer
        # 2. Attach the buffer to the surface
        # 3. Mark damage regions
        # 4. Commit the surface
        
        Logger.info("Destroying surface...")
        WaylandClient.destroy_surface(surface)
        
      {:error, reason} ->
        Logger.warn("Surface creation failed: #{reason}")
        Logger.info("This is expected as compositor binding is not yet fully implemented")
    end
  end

  def demo_api do
    """
    # WaylandClient API Demo

    ## Basic Connection
    {:ok, display} = WaylandClient.connect()
    WaylandClient.connected?(display) # => true

    ## Registry and Globals
    {:ok, registry} = WaylandClient.get_registry(display)
    {:ok, globals} = WaylandClient.list_globals(registry)

    ## Surface Management
    {:ok, surface} = WaylandClient.create_surface(display)
    WaylandClient.destroy_surface(surface)

    ## Event Processing
    WaylandClient.flush_events(display)

    ## Cleanup
    WaylandClient.disconnect(display)

    ## Advanced Registry Usage
    {:ok, compositor} = WaylandClient.Registry.find_and_bind(registry, "wl_compositor")
    {:ok, shell} = WaylandClient.Registry.find_and_bind(registry, "wl_shell")
    """
  end
end