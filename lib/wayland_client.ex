defmodule WaylandClient do
  @moduledoc """
  Elixir library for building Wayland clients using Rustler and Smithay wayland-client.

  This module provides the main API for connecting to Wayland display servers,
  creating surfaces, and managing Wayland protocol interactions.

  ## Basic Usage

      # Connect to the default Wayland display
      {:ok, display} = WaylandClient.connect()

      # Create a surface
      {:ok, surface} = WaylandClient.create_surface(display)

      # Get global objects through registry
      {:ok, registry} = WaylandClient.get_registry(display)

      # Cleanup when done
      :ok = WaylandClient.disconnect(display)

  ## Key Concepts

  - **Display**: The connection to the Wayland server
  - **Surface**: A rectangular area that can be displayed on screen
  - **Registry**: Interface for discovering global objects and capabilities
  - **Globals**: Server-provided objects like compositor, shell, etc.
  """

  alias WaylandClient.{Display, Surface, Registry}

  @type display :: reference()
  @type surface :: reference()
  @type registry :: reference()
  @type error :: {:error, String.t()}

  @doc """
  Connect to the Wayland display server.

  Attempts to connect to the Wayland display server specified by the
  WAYLAND_DISPLAY environment variable, or the default display if not set.

  ## Examples

      {:ok, display} = WaylandClient.connect()
      {:error, reason} = WaylandClient.connect()

  """
  @spec connect() :: {:ok, display()} | error()
  def connect do
    Display.connect()
  end

  @doc """
  Connect to a specific Wayland display.

  ## Parameters

  - `display_name` - The name of the display to connect to (e.g., "wayland-0")

  ## Examples

      {:ok, display} = WaylandClient.connect("wayland-1")

  """
  @spec connect(String.t()) :: {:ok, display()} | error()
  def connect(display_name) when is_binary(display_name) do
    Display.connect(display_name)
  end

  @doc """
  Disconnect from the Wayland display server.

  Cleanly closes the connection and releases all associated resources.

  ## Examples

      :ok = WaylandClient.disconnect(display)

  """
  @spec disconnect(display()) :: :ok | error()
  def disconnect(display) do
    Display.disconnect(display)
  end

  @doc """
  Create a new surface.

  Creates a new surface that can be used for rendering content.

  ## Examples

      {:ok, surface} = WaylandClient.create_surface(display)

  """
  @spec create_surface(display()) :: {:ok, surface()} | error()
  def create_surface(display) do
    Surface.create(display)
  end

  @doc """
  Destroy a surface.

  Destroys the surface and releases its resources.

  ## Examples

      :ok = WaylandClient.destroy_surface(surface)

  """
  @spec destroy_surface(surface()) :: :ok | error()
  def destroy_surface(surface) do
    Surface.destroy(surface)
  end

  @doc """
  Get the registry for discovering global objects.

  The registry allows you to discover what global objects (compositor, shell, etc.)
  are available from the Wayland server.

  ## Examples

      {:ok, registry} = WaylandClient.get_registry(display)

  """
  @spec get_registry(display()) :: {:ok, registry()} | error()
  def get_registry(display) do
    Registry.get(display)
  end

  @doc """
  List all available global objects.

  Returns a list of all global objects advertised by the server through the registry.

  ## Examples

      {:ok, globals} = WaylandClient.list_globals(registry)
      # Returns: [%{id: 1, interface: "wl_compositor", version: 4}, ...]

  """
  @spec list_globals(registry()) :: {:ok, [map()]} | error()
  def list_globals(registry) do
    Registry.list_globals(registry)
  end

  @doc """
  Process pending events from the Wayland server.

  This function should be called regularly to handle incoming events
  from the Wayland server.

  ## Examples

      :ok = WaylandClient.flush_events(display)

  """
  @spec flush_events(display()) :: :ok | error()
  def flush_events(display) do
    Display.flush_events(display)
  end

  @doc """
  Check if the display connection is still alive.

  ## Examples

      true = WaylandClient.connected?(display)

  """
  @spec connected?(display()) :: boolean()
  def connected?(display) do
    Display.connected?(display)
  end
end