defmodule InkfishWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use InkfishWeb, :controller
      use InkfishWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def static_paths do
    ~w(assets fonts images favicon.ico robots.txt)
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: InkfishWeb.Layouts]

      import Plug.Conn
      use Gettext, backend: InkfishWeb.Gettext

      import InkfishWeb.ViewHelpers

      unquote(verified_routes())

      defp respond_with_error(conn, code, msg) do
        if conn.assigns[:client_mode] == :browser do
          conn
          |> put_flash(:error, msg)
          |> redirect(to: ~p"/")
          |> halt()
        else
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(code, JSON.encode!(%{error: msg}))
          |> halt()
        end
      end
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML

      # Core UI components and translation
      import InkfishWeb.CoreComponents
      import InkfishWeb.FormComponents

      use Gettext, backend: InkfishWeb.Gettext

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      import InkfishWeb.ViewHelpers

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def json do
    quote do
      import InkfishWeb.ViewHelpers
      import InkfishWeb.JsonHelpers
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: InkfishWeb.Endpoint,
        router: InkfishWeb.Router,
        statics: InkfishWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
