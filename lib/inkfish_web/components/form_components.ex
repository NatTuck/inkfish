defmodule InkfishWeb.FormComponents do
  use Phoenix.Component
  use Gettext, backend: InkfishWeb.Gettext
  import Phoenix.HTML.Tag

  attr :form, :any, required: true
  attr :field, :atom, required: true

  def error_tag(assigns) do
    ~H"""
    <%= for error <- Keyword.get_values(@form.errors, @field) do %>
      <span class="help-block"><%= translate_error(error) %></span>
    <% end %>
    """
  end

  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(InkfishWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(InkfishWeb.Gettext, "errors", msg, opts)
    end
  end
end
