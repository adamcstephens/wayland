# Configuration for WaylandClient development

import Config

# Configure the logger
config :logger,
  level: :info,
  format: "$time $metadata[$level] $message\n"

# Configure ExUnit for testing
config :ex_unit,
  capture_log: true,
  assert_receive_timeout: 5000

# Rustler configuration for development (disabled until rustler dependency is enabled)
# config :rustler,
#   write_beam_file: true

# Application-specific configuration
config :wayland_client,
  # Default display name to try when connecting
  default_display: System.get_env("WAYLAND_DISPLAY", "wayland-0"),

  # Event processing timeout in milliseconds
  event_timeout: 1000,

  # Whether to log protocol events (development only)
  log_events: Mix.env() == :dev

config :wayland_client, WaylandClient.Nif, crate: :wayland_client
