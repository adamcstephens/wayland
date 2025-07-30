defmodule WaylandClientTest do
  use ExUnit.Case
  doctest WaylandClient

  alias WaylandClient

  describe "WaylandClient" do
    test "module exists and has basic functions" do
      assert function_exported?(WaylandClient, :connect, 0)
      assert function_exported?(WaylandClient, :connect, 1)
      assert function_exported?(WaylandClient, :disconnect, 1)
      assert function_exported?(WaylandClient, :create_surface, 1)
      assert function_exported?(WaylandClient, :destroy_surface, 1)
      assert function_exported?(WaylandClient, :get_registry, 1)
      assert function_exported?(WaylandClient, :list_globals, 1)
      assert function_exported?(WaylandClient, :flush_events, 1)
      assert function_exported?(WaylandClient, :connected?, 1)
    end

    # Note: These tests cannot run without a Wayland display server
    # They are here to verify the API structure
    @tag :skip
    test "can connect to wayland display" do
      case WaylandClient.connect() do
        {:ok, display} ->
          assert is_reference(display)
          assert WaylandClient.connected?(display)
          assert WaylandClient.disconnect(display) == :ok

        {:error, _reason} ->
          # Expected when no Wayland display is available
          :ok
      end
    end

    @tag :skip
    test "can get registry" do
      case WaylandClient.connect() do
        {:ok, display} ->
          case WaylandClient.get_registry(display) do
            {:ok, registry} ->
              assert is_reference(registry)
              case WaylandClient.list_globals(registry) do
                {:ok, globals} ->
                  assert is_list(globals)

                {:error, _} ->
                  :ok
              end

            {:error, _} ->
              :ok
          end

          WaylandClient.disconnect(display)

        {:error, _reason} ->
          :ok
      end
    end
  end
end