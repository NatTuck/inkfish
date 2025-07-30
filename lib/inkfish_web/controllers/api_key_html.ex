defmodule InkfishWeb.ApiKeyHTML do
  use InkfishWeb, :html

  embed_templates "api_key_html/*"

  @doc """
  Renders an API key form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def api_key_form(assigns)
end
