defmodule WaylandClient.Registry do
  @moduledoc """
  Manages the Wayland registry for discovering global objects.

  The registry allows clients to discover what global objects (compositor, shell, etc.)
  are available from the Wayland server.
  """

  alias WaylandClient.Nif

  @type display :: reference()
  @type registry :: reference()
  @type global :: %{
          id: non_neg_integer(),
          interface: String.t(),
          version: non_neg_integer()
        }
  @type error :: {:error, String.t()}

  @doc """
  Get the registry for a display connection.

  The registry is used to discover what global objects are available
  from the Wayland server.

  ## Parameters

  - `display` - The display connection

  ## Examples

      {:ok, registry} = WaylandClient.Registry.get(display)

  """
  @spec get(display()) :: {:ok, registry()} | error()
  def get(display) do
    Nif.get_registry(display)
  end

  @doc """
  List all available global objects.

  Returns a list of all global objects advertised by the server.

  ## Parameters

  - `registry` - The registry object

  ## Examples

      {:ok, globals} = WaylandClient.Registry.list_globals(registry)
      # Returns: [%{id: 1, interface: "wl_compositor", version: 4}, ...]

  """
  @spec list_globals(registry()) :: {:ok, [global()]} | error()
  def list_globals(registry) do
    case Nif.list_globals(registry) do
      {:ok, globals} ->
        parsed_globals =
          Enum.map(globals, fn {id, interface, version} ->
            %{id: id, interface: interface, version: version}
          end)

        {:ok, parsed_globals}

      error ->
        error
    end
  end

  @doc """
  Bind to a global object.

  Binds to a specific global object, creating a proxy that can be used
  to interact with that object.

  ## Parameters

  - `registry` - The registry object
  - `id` - The global object ID
  - `interface` - The interface name
  - `version` - The interface version to bind to

  ## Examples

      {:ok, compositor} = WaylandClient.Registry.bind(registry, 1, "wl_compositor", 4)

  """
  @spec bind(registry(), non_neg_integer(), String.t(), non_neg_integer()) ::
          {:ok, reference()} | error()
  def bind(registry, id, interface, version)
      when is_integer(id) and is_binary(interface) and is_integer(version) do
    Nif.bind_global(registry, id, interface, version)
  end

  @doc """
  Find a global object by interface name.

  Searches for the first global object that matches the given interface name.

  ## Parameters

  - `registry` - The registry object
  - `interface` - The interface name to search for

  ## Examples

      {:ok, %{id: 1, interface: "wl_compositor", version: 4}} = 
        WaylandClient.Registry.find_global(registry, "wl_compositor")

  """
  @spec find_global(registry(), String.t()) :: {:ok, global()} | {:error, :not_found} | error()
  def find_global(registry, interface) when is_binary(interface) do
    case list_globals(registry) do
      {:ok, globals} ->
        case Enum.find(globals, fn global -> global.interface == interface end) do
          nil -> {:error, :not_found}
          global -> {:ok, global}
        end

      error ->
        error
    end
  end

  @doc """
  Find and bind to a global object by interface name.

  Convenience function that finds a global object by interface name
  and binds to it in a single call.

  ## Parameters

  - `registry` - The registry object
  - `interface` - The interface name to find and bind to
  - `version` - Optional version to bind to (defaults to the advertised version)

  ## Examples

      {:ok, compositor} = WaylandClient.Registry.find_and_bind(registry, "wl_compositor")
      {:ok, compositor} = WaylandClient.Registry.find_and_bind(registry, "wl_compositor", 3)

  """
  @spec find_and_bind(registry(), String.t(), non_neg_integer() | nil) ::
          {:ok, reference()} | {:error, :not_found} | error()
  def find_and_bind(registry, interface, version \\ nil) when is_binary(interface) do
    case find_global(registry, interface) do
      {:ok, global} ->
        bind_version = version || global.version
        bind(registry, global.id, interface, bind_version)

      error ->
        error
    end
  end

  @doc """
  Get all globals matching a specific interface name.

  Returns all global objects that implement the specified interface.

  ## Parameters

  - `registry` - The registry object
  - `interface` - The interface name to filter by

  ## Examples

      {:ok, outputs} = WaylandClient.Registry.get_globals_by_interface(registry, "wl_output")

  """
  @spec get_globals_by_interface(registry(), String.t()) :: {:ok, [global()]} | error()
  def get_globals_by_interface(registry, interface) when is_binary(interface) do
    case list_globals(registry) do
      {:ok, globals} ->
        matching_globals = Enum.filter(globals, fn global -> global.interface == interface end)
        {:ok, matching_globals}

      error ->
        error
    end
  end
end