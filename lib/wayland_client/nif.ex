defmodule WaylandClient.Nif do
  @moduledoc """
  Native Interface Functions (NIF) for Wayland client operations.

  This module provides the low-level interface to the Rust implementation
  using the Smithay wayland-client library.

  All functions in this module are implemented in Rust and should not be
  called directly. Use the higher-level modules like WaylandClient.Display,
  WaylandClient.Surface, and WaylandClient.Registry instead.
  """

  use Rustler, otp_app: :wayland_client, crate: "wayland_client_nif"

  # Display functions
  def connect(), do: :erlang.nif_error(:nif_not_loaded)
  def connect(display_name), do: connect_to_display(display_name)
  def connect_to_display(_display_name), do: :erlang.nif_error(:nif_not_loaded)
  def disconnect(_display), do: :erlang.nif_error(:nif_not_loaded)
  def is_connected(_display), do: :erlang.nif_error(:nif_not_loaded)
  def flush_events(_display), do: :erlang.nif_error(:nif_not_loaded)
  def get_fd(_display), do: :erlang.nif_error(:nif_not_loaded)
  def roundtrip(_display), do: :erlang.nif_error(:nif_not_loaded)

  # Surface functions
  def create_surface(_display), do: :erlang.nif_error(:nif_not_loaded)
  def destroy_surface(_surface), do: :erlang.nif_error(:nif_not_loaded)
  def surface_attach(_surface, _buffer, _x, _y), do: :erlang.nif_error(:nif_not_loaded)
  def surface_damage(_surface, _x, _y, _width, _height), do: :erlang.nif_error(:nif_not_loaded)
  def surface_commit(_surface), do: :erlang.nif_error(:nif_not_loaded)
  def surface_set_input_region(_surface, _region), do: :erlang.nif_error(:nif_not_loaded)
  def surface_set_opaque_region(_surface, _region), do: :erlang.nif_error(:nif_not_loaded)

  # Registry functions
  def get_registry(_display), do: :erlang.nif_error(:nif_not_loaded)
  def list_globals(_registry), do: :erlang.nif_error(:nif_not_loaded)
  def bind_global(_registry, _id, _interface, _version), do: :erlang.nif_error(:nif_not_loaded)

  # Buffer functions
  def create_shm_pool(_display, _size), do: :erlang.nif_error(:nif_not_loaded)
  def create_buffer(_pool, _offset, _width, _height, _stride, _format),
    do: :erlang.nif_error(:nif_not_loaded)

  # Region functions
  def create_region(_compositor), do: :erlang.nif_error(:nif_not_loaded)
  def region_add(_region, _x, _y, _width, _height), do: :erlang.nif_error(:nif_not_loaded)
  def region_subtract(_region, _x, _y, _width, _height), do: :erlang.nif_error(:nif_not_loaded)

  # Event functions
  def set_event_handler(_object, _handler_pid), do: :erlang.nif_error(:nif_not_loaded)
  def remove_event_handler(_object), do: :erlang.nif_error(:nif_not_loaded)

  # Utility functions
  def get_version(), do: :erlang.nif_error(:nif_not_loaded)
  def get_protocol_version(_interface), do: :erlang.nif_error(:nif_not_loaded)
end