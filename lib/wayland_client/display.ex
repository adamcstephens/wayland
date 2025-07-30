defmodule WaylandClient.Display do
  @moduledoc """
  Manages connections to Wayland display servers.

  This module handles the low-level connection management to Wayland display servers,
  including connecting, disconnecting, and event processing.
  """

  alias WaylandClient.Nif

  @type display :: reference()
  @type error :: {:error, String.t()}

  @doc """
  Connect to the default Wayland display server.

  Attempts to connect to the display specified by the WAYLAND_DISPLAY
  environment variable, or "wayland-0" if not set.
  """
  @spec connect() :: {:ok, display()} | error()
  def connect do
    Nif.connect()
  end

  @doc """
  Connect to a specific Wayland display server.

  ## Parameters

  - `display_name` - The name of the display to connect to

  ## Examples

      {:ok, display} = WaylandClient.Display.connect("wayland-1")

  """
  @spec connect(String.t()) :: {:ok, display()} | error()
  def connect(display_name) when is_binary(display_name) do
    Nif.connect(display_name)
  end

  @doc """
  Disconnect from the Wayland display server.

  Cleanly closes the connection and releases all associated resources.
  """
  @spec disconnect(display()) :: :ok | error()
  def disconnect(display) do
    Nif.disconnect(display)
  end

  @doc """
  Check if the display connection is still alive.
  """
  @spec connected?(display()) :: boolean()
  def connected?(display) do
    case Nif.is_connected(display) do
      {:ok, connected} -> connected
      {:error, _} -> false
    end
  end

  @doc """
  Process pending events from the Wayland server.

  This function processes any pending events from the server.
  It should be called regularly in your application's event loop.
  """
  @spec flush_events(display()) :: :ok | error()
  def flush_events(display) do
    Nif.flush_events(display)
  end

  @doc """
  Get the file descriptor for the display connection.

  This can be useful for integrating with event loops or select/poll mechanisms.
  """
  @spec get_fd(display()) :: {:ok, integer()} | error()
  def get_fd(display) do
    Nif.get_fd(display)
  end

  @doc """
  Roundtrip to the server.

  Sends a sync request to the server and waits for the response.
  This ensures all pending requests have been processed.
  """
  @spec roundtrip(display()) :: :ok | error()
  def roundtrip(display) do
    Nif.roundtrip(display)
  end
end