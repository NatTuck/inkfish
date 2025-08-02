defmodule Inkfish.Repo.Info do
  def list_schemas() do
    {:ok, mods} = :application.get_key(:inkfish, :modules)

    Enum.filter(mods, fn mod ->
      {:__schema__, 1} in mod.__info__(:functions)
    end)
  end

  def schemas_without_parents() do
    list_schemas()
    |> Enum.filter(fn mod ->
      {:parent, 0} not in mod.__info__(:functions)
    end)
  end

  def slug(mod) when is_atom(mod) do
    mod.__schema__(:source)
    |> Inflex.singularize()
    |> String.to_atom()
  end

  def slug_to_mod(slug) do
    mod =
      Enum.find(list_schemas(), fn mod ->
        slug(mod) == slug
      end)

    if mod do
      {:ok, mod}
    else
      {:error, "No such schema '#{slug}'"}
    end
  end

  def path(mod) when is_atom(mod) do
    path(mod, [mod])
  end

  def path(mod, ys) when is_atom(mod) do
    if {:ok, pmod} = parent_mod(mod) do
      path(pmod, [pmod | ys])
    else
      ys
    end
  end

  def parent_field(mod) when is_atom(mod) do
    if function_exported?(mod, :parent, 0) do
      {:ok, mod.parent()}
    else
      {:error, :no_parent, mod}
    end
  end

  def parent_mod(mod) when is_atom(mod) do
    with {:ok, pfield} <- parent_field(mod) do
      if pmod = mod.__schema__(:association, pfield).related do
        {:ok, pmod}
      else
        {:error, {:missing_assoc, mod, pfield}}
      end
    else
      _err -> {:error, {:no_parent, mod}}
    end
  end

  def standard_preloads(mod) do
    if function_exported?(mod, :standard_preloads, 0) do
      mod.standard_preloads()
    else
      []
    end
  end
end
