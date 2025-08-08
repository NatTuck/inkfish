defmodule InkfishWeb.Staff.AttendanceHTML do
  use InkfishWeb, :html

  embed_templates "attendance_html/*"

  @doc """
  Renders a attendance form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def attendance_form(assigns)
end
