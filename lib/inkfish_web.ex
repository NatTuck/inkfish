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

  def controller1 do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json]
#        layouts: [html: InkfishWeb.Layouts]

      import Plug.Conn
      import InkfishWeb.Gettext

      unquote(verified_routes())
    end
  end
  
  def controller do
    quote do
      use Phoenix.Controller, namespace: InkfishWeb

      import Plug.Conn
      import InkfishWeb.Gettext
      import InkfishWeb.ViewHelpers
      alias InkfishWeb.Router.Helpers, as: Routes

      unquote(verified_routes())
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
      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components and translation
      import InkfishWeb.CoreComponents
      import InkfishWeb.Gettext

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def view do
    # FIXME: This should be migrated to be named "html" everywhere

    quote do
      use Phoenix.View,
        root: "lib/inkfish_web/templates",
        namespace: InkfishWeb

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      # Include shared imports and aliases for views
      unquote(view_helpers())
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import InkfishWeb.Gettext
    end
  end

  defp view_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import InkfishWeb.ErrorHelpers
      import InkfishWeb.Gettext
      import InkfishWeb.ViewHelpers
      alias InkfishWeb.Router.Helpers, as: Routes

      unquote(verified_routes())
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
