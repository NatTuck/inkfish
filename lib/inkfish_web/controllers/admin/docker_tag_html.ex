defmodule InkfishWeb.Admin.DockerTagHTML do
  use InkfishWeb, :html

  embed_templates "docker_tag_html/*"

  @doc """
  Renders a docker_tag form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def docker_tag_form(assigns)
end
