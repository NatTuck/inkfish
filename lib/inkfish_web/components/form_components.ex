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

  @doc """
  Renders a simple form.

  ## Examples

      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} label="Email"/>
        <.input field={@form[:username]} label="Username" />
        <:actions>
          <.button>Save</.button>
        </:actions>
      </.simple_form>
  """
  attr :for, :any, required: true, doc: "the datastructure for the form"

  attr :as, :any,
    default: nil,
    doc: "the server side parameter to collect all input under"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  slot :extra_block,
    required: false,
    doc: "the optional extra block that renders extra form fields"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div>
        {render_slot(@inner_block, f)}
        <div
          :for={action <- @actions}
          class="mt-2 d-flexflex align-items-center justify-content-between gap-3"
        >
          {render_slot(action, f)}
        </div>
        <div :if={@extra_block != []}>
          {render_slot(@extra_block, f)}
        </div>
      </div>
    </.form>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr :kind, :atom,
    values: [
      :primary,
      :secondary,
      :tertiary,
      :info,
      :success,
      :warning,
      :danger,
      :dark,
      :gray,
      :light
    ],
    default: :dark

  attr :type, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "btn",
        @kind == :primary && "btn-primary",
        @kind == :secondary && "btn-secondary",
        @kind == :tertiary && "btn-tertiary",
        @kind == :info && "btn-info",
        @kind == :success && "btn-success",
        @kind == :warning && "btn-warning",
        @kind == :danger && "btn-danger",
        @kind == :dark && "btn-dark btn-md",
        @kind == :gray && "btn-gray-200",
        @kind == :light && "btn-gray-50",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders an input with label and error messages.

  A `%Phoenix.HTML.Form{}` and field name may be passed to the input
  to build input names and error messages, or all the attributes and
  errors may be passed explicitly.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values:
      ~w(checkbox color date datetime-local email file hidden month number password
               range radio search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc:
      "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"

  attr :options, :list,
    doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"

  attr :multiple, :boolean,
    default: false,
    doc: "the multiple flag for select inputs"

  attr :rest, :global,
    include:
      ~w(autocomplete cols disabled form max maxlength min minlength
                                   pattern placeholder readonly required rows size step)

  slot :inner_block

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, field.errors)
    |> assign_new(:name, fn ->
      if assigns.multiple, do: field.name <> "[]", else: field.name
    end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox", value: value} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", value)
      end)

    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id || @name}>
        <input type="hidden" name={@name} value="false" />
        <input
          type="checkbox"
          id={@id || @name}
          name={@name}
          value="true"
          checked={@checked}
          class="form-check-input"
          {@rest}
        />
        {@label}
      </.label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}>{@label}</.label>
      <select
        id={@id}
        name={@name}
        class="form-select"
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "radio"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name} class="form-check">
      <input
        class="form-check-input"
        type="radio"
        name={@name}
        value={@value}
        id={@id}
        checked={@checked}
      />
      <.label class="form-check-label" for={@id}>
        {@label}
      </.label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}>{@label}</.label>
      <textarea
        id={@id || @name}
        name={@name}
        class={["form-control", @errors != [] && "is-invalid"]}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}>{@label}</.label>
      <input
        type={@type}
        name={@name}
        id={@id || @name}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "form-control",
          @errors != [] && "is-invalid"
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class={[@class || "form-label"]}>
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="invalid-feedback">
      <i class="fas fa-exclamation-circle mr-2"></i>
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :ref, :string, required: true
  attr :label, :string, required: true
  attr :upload, :map, required: true
  attr :width, :string, default: "w-full"
  slot :input_title, required: false
  slot :upload_description, required: false

  def upload_input(assigns) do
    ~H"""
    <div class="mb-3" phx-drop-target={@ref}>
      <.label for={@ref}>{@label}</.label>
      <.live_file_input upload={@upload} class="form-control" />
    </div>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :rest, :global, include: ~w(class placeholder readonly)

  def text_input(assigns) do
    ~H"""
    <input type="text" name={@field.name} id={@field.id} value={@field.value} {@rest} />
    """
  end

  def hidden_input(assigns) do
    ~H"""
    <input type="hidden" name={@field.name} id={@field.id} value={@field.value} {@rest} />
    """
  end

  def password_input(assigns) do
    ~H"""
    <input type="password" name={@field.name} id={@field.id} value={@field.value} {@rest} />
    """
  end

  def textarea(assigns) do
    ~H"""
    <textarea name={@field.name} id={@field.id} {@rest}><%= Phoenix.HTML.Form.normalize_value("textarea", @field.value) %></textarea>
    """
  end

  def checkbox(assigns) do
    ~H"""
    <span>
      <input type="hidden" name={@field.name} value="false" />
      <input type="checkbox" name={@field.name} id={@field.id} value="true" checked={@field.value} {@rest} />
    </span>
    """
  end
end
