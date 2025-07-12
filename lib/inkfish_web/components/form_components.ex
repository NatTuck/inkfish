defmodule InkfishWeb.FormComponents do
  use Phoenix.Component
  use Gettext, backend: InkfishWeb.Gettext

  attr :form, :any, required: true
  attr :field, :atom, required: true

  def error_tag(assigns) do
    ~H"""
    <%= for error <- Keyword.get_values(@form.errors, @field) do %>
      <span class="help-block"><%= error %></span>
    <% end %>
    """
  end
end
