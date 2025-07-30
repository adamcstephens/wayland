defmodule WaylandClient.Nif do
  @moduledoc """
  Native Interface Functions (NIF) for Wayland client operations.

  This module provides the low-level interface to the Rust implementation
  using the Smithay wayland-client library.

  All functions in this module are implemented in Rust and should not be
  called directly. Use the higher-level modules like WaylandClient.Display,
  WaylandClient.Surface, and WaylandClient.Registry instead.

  **Note**: Rust NIF is currently disabled due to dependency access restrictions.
  Enable by uncommenting the `use Rustler` line and installing rustler dependency.
  """

  # use Rustler, otp_app: :wayland_client, crate: "wayland_client_nif"

  # Stub implementations for when Rust NIF is not available
  @doc false
  defp nif_error(func), do: {:error, "NIF not available: #{func}. Install rustler dependency and enable Rust compilation."}

  # Display functions
  def connect(), do: nif_error(:connect)
  def connect(_display_name), do: nif_error(:connect)
  def connect_to_display(_display_name), do: nif_error(:connect_to_display)
  def disconnect(_display), do: nif_error(:disconnect)
  def is_connected(_display), do: nif_error(:is_connected)
  def flush_events(_display), do: nif_error(:flush_events)
  def get_fd(_display), do: nif_error(:get_fd)
  def roundtrip(_display), do: nif_error(:roundtrip)

  # Surface functions
  def create_surface(_display), do: nif_error(:create_surface)
  def destroy_surface(_surface), do: nif_error(:destroy_surface)
  def surface_attach(_surface, _buffer, _x, _y), do: nif_error(:surface_attach)
  def surface_damage(_surface, _x, _y, _width, _height), do: nif_error(:surface_damage)
  def surface_commit(_surface), do: nif_error(:surface_commit)
  def surface_set_input_region(_surface, _region), do: nif_error(:surface_set_input_region)
  def surface_set_opaque_region(_surface, _region), do: nif_error(:surface_set_opaque_region)

  # Registry functions
  def get_registry(_display), do: nif_error(:get_registry)
  def list_globals(_registry), do: nif_error(:list_globals)
  def bind_global(_registry, _id, _interface, _version), do: nif_error(:bind_global)

  # Buffer functions
  def create_shm_pool(_display, _size), do: nif_error(:create_shm_pool)
  def create_buffer(_pool, _offset, _width, _height, _stride, _format),
    do: nif_error(:create_buffer)

  # Region functions
  def create_region(_compositor), do: nif_error(:create_region)
  def region_add(_region, _x, _y, _width, _height), do: nif_error(:region_add)
  def region_subtract(_region, _x, _y, _width, _height), do: nif_error(:region_subtract)

  # Event functions
  def set_event_handler(_object, _handler_pid), do: nif_error(:set_event_handler)
  def remove_event_handler(_object), do: nif_error(:remove_event_handler)

  # Utility functions
  def get_version(), do: nif_error(:get_version)
  def get_protocol_version(_interface), do: nif_error(:get_protocol_version)
end