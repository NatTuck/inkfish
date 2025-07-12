A JSON module in this project should look something like this:

```elixir
defmodule InkfishWeb.ApiV1.SubJSON do
  use InkfishWeb, :json

  alias Inkfish.Subs.Sub
  alias Inkfish.Uploads.Upload

  @doc """
  Renders a list of subs.
  """
  def index(%{subs: subs}) do
    %{data: for(sub <- subs, do: data(sub))}
  end

  @doc """
  Renders a single sub.
  """
  def show(%{sub: sub}) do
    %{data: data(sub)}
  end

  def data(%Sub{} = sub) do
    upload = get_assoc(sub, :upload)

    %{
      id: sub.id,
      active: sub.active,
      late_penalty: sub.late_penalty,
      score: sub.score,
      hours_spent: sub.hours_spent,
      note: sub.note,
      ignore_late_penalty: sub.ignore_late_penalty,
      upload: Uploads.upload_url(upload)
    }
  end
end
```

Specifically:

- The module name should end with "JSON"
- There should be a "use InkfishWeb, :json" line.
- There should not be a use/import for InkfishWeb.Json
- There should not be a use/import for InkfishWeb.ViewHelpers
- There should be three public functions as shown: index, show, and data.
  - Data should return a map with the item fields for display.
  - Show should wrap that in a map with a data key.
  - Index should return a map with a data key containing a list of items,
    but not with an extra layer as if it called show.
- The get_assoc function should be used to get any fields that are Ecto
associations.
- There should be no render functions.
- There should be no use of render_one or render_many, those should be
  translated into calls to data on the other module.
- Fields in one object shouldn't be rendered with calls to index / show on
  other JSON modules - that'd add a nested map with a data field - instead
  those should call the data function on the appropriate module.


