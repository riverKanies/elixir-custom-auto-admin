defmodule MyApp.AutoAdminView do
  use MyApp, :view

  def render_field(form, schema_module, field, selects, opts \\ []) do
    select_items = Map.get(selects, field)
    case schema_module.__schema__(:type, field) do
      :boolean -> Phoenix.HTML.Form.checkbox(form, field, opts)
      :integer -> Phoenix.HTML.Form.number_input(form, field, opts)
      :id -> Phoenix.HTML.Form.number_input(form, field, opts)
      {:embed, embedded} -> render("embed.html", [form: form, field: field, schema_module: embedded.related, selects: select_items, opts: opts])
      _ -> case select_items do
            nil -> Phoenix.HTML.Form.text_input(form, field, opts)
            %{multi: select_items} -> Phoenix.HTML.Form.multiple_select(form, field, select_items, opts)
            _ -> Phoenix.HTML.Form.select(form, field, select_items, opts)
          end
    end
  end

  def render_item(item_schema, item) do
    schema = Map.get(item_schema, :related)
    case schema do
      nil -> 
        [record, _] = item_schema.through
        "through #{record}"
      _ ->
        schema.__schema__(:fields)
        |> Enum.map(fn key ->
            case schema.__schema__(:type, key) do
              {:embed, _} -> "#{key}: [embed]"
              _ -> "#{key}: #{Map.get(item, key)}"
            end
          end)
        |> Enum.join(", ")
    end
  end

end