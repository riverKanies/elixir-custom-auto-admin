defmodule MyApp.AutoAdminController do
  use MyApp, :controller
  use MyDbDriver.{Commands, Queries}

  plug :put_layout, "autoadmin.html"
  plug :put_models
  plug :put_selects

## Begin admin update section (you only need to make changes in this section when adding a new schema to the admin)

  @models %{
    "users" => Accounts.User,
    "organizations" => Accounts.Organization,
    "organization_invitations" => Accounts.OrganizationInvitation,
    "organization_subscriptions" => Accounts.OrganizationSubscription,
    "groups" => Accounts.Group,
    "group_invitations" => Accounts.GroupInvitation,
    "group_subscriptions" => Accounts.GroupSubscription,
    "events_api_events" => ApiEvents.Events.Event,
    "events_api_event_invitations" => ApiEvents.Events.EventInvitation,
    "events_api_event_subscriptions" => ApiEvents.Events.EventSubscription,
    # ... and any other possible schema you have!
  }

  @selects %{
    organizations: %{
      address: %{
        state: UsState.to_select(:include_blank),
      },
      status: Accounts.OrganizationStatus.to_select(:include_blank),
    },
    groups: %{
      status: Accounts.GroupStatus.to_select(:include_blank),
      visibility: Accounts.GroupVisibility.to_select(:include_blank),
      affiliation_mode: Accounts.AffiliationMode.to_select(:include_blank),
    },
    users: %{
      role: Accounts.SystemRole.to_select(:include_blank),
      status: Accounts.UserStatus.to_select(:include_blank),
      notification_methods: %{multi: Accounts.NotificationMethod.to_select()},
    },
    events_api_events: %{
      bridge_provider: ApiEvents.Events.BridgeProvider.all(),
      status: ApiEvents.Events.EventStatus.all(),
    }
  }

## End admin update section

  @repos %{
    "accounts" => ApiAccounts.Repo,
    "events" => ApiEvents.Repo
  }

  def index(conn, %{"schema" => api_schema}) do
    page_num = Map.get conn.params, "page", "1"

    [api, schema] = case String.split(api_schema, "_api_") do
      [api, _schema] -> [api, api_schema]
      [schema] -> ["accounts", schema]
    end
    repo = @repos[api]
    schema_module = @models[schema]

    {:ok, page} = schema_module
    |> ExecuteQuery.paginate(repo, [page: page_num])

    opts=[
      page: page,
      schema_module: schema_module,
      schema: schema,
      page_num: page_num
    ]
    render(conn, "index.html", opts)
  end

  def edit(conn, %{"schema" => api_schema, "id" => id}) do
    [api, schema, prefix] = case String.split(api_schema, "_api_") do
      [api, _schema] -> [api, api_schema, "#{api}_api_"]
      [schema] -> ["accounts", schema, ""]
    end
    repo = @repos[api]
    schema_module = @models[schema]

    page_nums = schema_module.__schema__(:associations)
      |> Enum.reduce(%{}, fn association, acc ->
        page_num = Map.get(conn.params, "#{association}_page", "1")
        Map.put acc, association, page_num
      end)

    # model = schema_module.__schema__(:associations)
    #   |> Enum.reduce(repo.get(schema_module, id), fn a, m ->
    #     repo.preload(m, a)
    #   end)

    model = schema_module.__schema__(:associations)
      |> Enum.reduce(repo.get(schema_module, id), fn association, model ->
        schema = schema_module.__schema__(:association, association)
        case schema do
          %{related_key: key} ->
            page_num = Map.get page_nums, association
            map = Map.put %{}, key, id
            keyword = Keyword.new map
            query = from r in schema.related, where: ^keyword

            records = case ExecuteQuery.paginate(query, repo, [page: page_num]) do
              {:ok, page} -> page.entries
              _ -> []
            end
            Map.put model, association, records
          _ ->
            model
        end
      end)

      # TODO: load changeset from session?
    opts = [
      changeset: Ecto.Changeset.change(model, %{}),
      schema_module: schema_module,
      schema: schema,
      prefix: prefix,
      id: id,
      page_nums: page_nums
    ]
    render(conn, "edit.html", opts)
  end

  # create/2 works similarly and may be considered an exercise for the reader =)
  def update(conn, %{"schema" => api_schema, "id" => id, "data" => string_data}) do
    [api, schema] = case String.split(api_schema, "_api_") do
      [api, _schema] -> [api, api_schema]
      [schema] -> ["accounts", schema]
    end
    repo = @repos[api]
    schema_module = @models[schema]

    filtered_data = Enum.reduce string_data, %{}, fn {key, val}, acc ->
      case val do
        "" -> acc
        _ -> Map.put acc, key, val
      end
    end

    data = for {key, val} <- filtered_data, into: %{} do
      field = String.to_atom(key)
      if is_map(val) do
        value = for {akey, aval} <- val, into: %{} do
          afield = String.to_atom(akey)
          {afield, aval}
        end
        {field, value}
      else
        case schema_module.__schema__(:type, field) do
          :id -> {field, String.to_integer(val)}
          :utc_datetime ->
            {:ok, date_time, _offset} = DateTime.from_iso8601(val)
            {field, date_time}
          _ -> {field, val}
        end
      end
    end

    changeset = Ecto.Changeset.change(repo.get!(schema_module, id), data)

    case repo.update(changeset) do
      {:ok, _updated_model} ->
        conn
        |> put_flash(:info, "#{String.capitalize(schema)} ID #{id} updated!")
        |> redirect(to: Routes.auto_admin_path(conn, :edit, schema, id))

      {:error, changeset} ->
        conn
        |> put_flash(:failed, "#{String.capitalize(schema)} ID #{id} failed to update!")
        |> put_session(:changeset, changeset)
        |> redirect(to: Routes.auto_admin_path(conn, :edit, schema, id))
    end
  end

  defp put_models(conn, _) do
    assign(conn, :models, Map.keys(@models))
  end

  defp put_selects(conn, _) do
    assign(conn, :selects, @selects)
  end

end