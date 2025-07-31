# Project Overview

Create an Elixir wayland client library for building wayland applications in Elixir. Uses a Rust NIF with Rustler to interface with wayland.

## Folder structure

- `/lib` is the elixir code
- `/native/wayland_client` is the rust create for the NIF

## Development

- Install Nix
- Install direnv
- Enter the Nix flake development shell by running direnv allow
- Use elixir and rust versions from the environment
