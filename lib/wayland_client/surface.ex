defmodule WaylandClient.Surface do
  @moduledoc """
  Manages Wayland surfaces.

  A surface is a rectangular area that can be displayed on screen.
  This module provides functions for creating, configuring, and destroying surfaces.
  """

  alias WaylandClient.Nif

  @type display :: reference()
  @type surface :: reference()
  @type error :: {:error, String.t()}

  @doc """
  Create a new surface.

  Creates a new surface that can be used for rendering content.

  ## Parameters

  - `display` - The display connection

  ## Examples

      {:ok, surface} = WaylandClient.Surface.create(display)

  """
  @spec create(display()) :: {:ok, surface()} | error()
  def create(display) do
    Nif.create_surface(display)
  end

  @doc """
  Destroy a surface.

  Destroys the surface and releases its resources.

  ## Parameters

  - `surface` - The surface to destroy

  ## Examples

      :ok = WaylandClient.Surface.destroy(surface)

  """
  @spec destroy(surface()) :: :ok | error()
  def destroy(surface) do
    Nif.destroy_surface(surface)
  end

  @doc """
  Attach a buffer to the surface.

  Attaches a buffer containing pixel data to the surface.

  ## Parameters

  - `surface` - The surface to attach the buffer to
  - `buffer` - The buffer reference (can be nil to detach)
  - `x` - X offset for the buffer
  - `y` - Y offset for the buffer

  ## Examples

      :ok = WaylandClient.Surface.attach(surface, buffer, 0, 0)
      :ok = WaylandClient.Surface.attach(surface, nil, 0, 0)  # Detach buffer

  """
  @spec attach(surface(), reference() | nil, integer(), integer()) :: :ok | error()
  def attach(surface, buffer, x, y) when is_integer(x) and is_integer(y) do
    Nif.surface_attach(surface, buffer, x, y)
  end

  @doc """
  Mark a region of the surface as damaged.

  Tells the compositor which parts of the surface have changed
  and need to be repainted.

  ## Parameters

  - `surface` - The surface
  - `x` - X coordinate of the damaged region
  - `y` - Y coordinate of the damaged region
  - `width` - Width of the damaged region
  - `height` - Height of the damaged region

  ## Examples

      :ok = WaylandClient.Surface.damage(surface, 0, 0, 800, 600)

  """
  @spec damage(surface(), integer(), integer(), integer(), integer()) :: :ok | error()
  def damage(surface, x, y, width, height)
      when is_integer(x) and is_integer(y) and is_integer(width) and is_integer(height) do
    Nif.surface_damage(surface, x, y, width, height)
  end

  @doc """
  Commit the surface state.

  Commits all pending changes to the surface, making them visible.
  This includes buffer attachments, damage regions, and other surface state.

  ## Parameters

  - `surface` - The surface to commit

  ## Examples

      :ok = WaylandClient.Surface.commit(surface)

  """
  @spec commit(surface()) :: :ok | error()
  def commit(surface) do
    Nif.surface_commit(surface)
  end

  @doc """
  Set the input region for the surface.

  Defines which parts of the surface can receive input events.

  ## Parameters

  - `surface` - The surface
  - `region` - The region reference (can be nil for infinite region)

  ## Examples

      :ok = WaylandClient.Surface.set_input_region(surface, region)
      :ok = WaylandClient.Surface.set_input_region(surface, nil)  # Infinite region

  """
  @spec set_input_region(surface(), reference() | nil) :: :ok | error()
  def set_input_region(surface, region) do
    Nif.surface_set_input_region(surface, region)
  end

  @doc """
  Set the opaque region for the surface.

  Defines which parts of the surface are opaque, allowing the compositor
  to optimize rendering.

  ## Parameters

  - `surface` - The surface
  - `region` - The region reference (can be nil for no opaque region)

  ## Examples

      :ok = WaylandClient.Surface.set_opaque_region(surface, region)
      :ok = WaylandClient.Surface.set_opaque_region(surface, nil)  # No opaque region

  """
  @spec set_opaque_region(surface(), reference() | nil) :: :ok | error()
  def set_opaque_region(surface, region) do
    Nif.surface_set_opaque_region(surface, region)
  end
end