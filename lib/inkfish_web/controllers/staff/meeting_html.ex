defmodule InkfishWeb.Staff.MeetingHTML do
  use InkfishWeb, :html

  embed_templates "meeting_html/*"

  @doc """
  Renders a meeting form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :teamsets, :any, required: true

  def meeting_form(assigns)
end
