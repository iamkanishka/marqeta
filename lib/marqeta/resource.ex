defmodule Marqeta.Resource do
  @moduledoc """
  Shared macro for all Marqeta resource modules.

  Generates standard CRUD and streaming functions via `use Marqeta.Resource`.

  ## Options

    * `:path`     — API path prefix, e.g. `"/users"`. Required for CRUD generation.
    * `:resource` — Human-readable resource name used in documentation strings.
    * `:create`   — Generate `create/2` and `create!/2`. Default: `true`.
    * `:get`      — Generate `get/2` and `get!/2`. Default: `true`.
    * `:update`   — Generate `update/3` and `update!/3`. Default: `true`.
    * `:list`     — Generate `list/2`, `list!/2`, and `stream/2`. Default: `true`.

  All generated public functions are `defoverridable` so individual modules can
  replace or extend them.

  ## Example

      defmodule Marqeta.Users do
        use Marqeta.Resource, path: "/users", resource: "user"

        def search(params, opts \\\\ []) do
          Client.post("/users/lookup", params, opts)
        end
      end
  """

  @doc "Merges caller-supplied params over defaults."
  @spec build_params(map(), map()) :: map()
  def build_params(params, defaults \\ %{}), do: Map.merge(defaults, params)

  defmacro __using__(opts) do
    path = Keyword.get(opts, :path)
    resource = Keyword.get(opts, :resource, "resource")

    has_create = Keyword.get(opts, :create, path != nil)
    has_get = Keyword.get(opts, :get, path != nil)
    has_update = Keyword.get(opts, :update, path != nil)
    has_list = Keyword.get(opts, :list, path != nil)

    # Build the defoverridable list at macro-expansion time (before the quote block).
    # Only public functions are listed — `bang!/2` is `defp` so it is intentionally
    # excluded. defoverridable cannot reference private functions.
    overridable_fns =
      []
      |> then(fn acc -> if has_create, do: [{:create, 2}, {:create!, 2} | acc], else: acc end)
      |> then(fn acc -> if has_get, do: [{:get, 2}, {:get!, 2} | acc], else: acc end)
      |> then(fn acc -> if has_update, do: [{:update, 3}, {:update!, 3} | acc], else: acc end)
      |> then(fn acc ->
        if has_list, do: [{:list, 2}, {:list!, 2}, {:stream, 2} | acc], else: acc
      end)

    # Build the defoverridable AST node only when the list is non-empty.
    # We compute this OUTSIDE the quote so we can use a plain Elixir `if` that
    # returns either the AST node or `nil` (nil is a no-op inside a quote block).
    maybe_defoverridable =
      if overridable_fns != [] do
        quote do
          defoverridable unquote(overridable_fns)
        end
      end

    quote do
      alias Marqeta.{Client, Error}
      alias Marqeta.Stream, as: MStream

      @_path unquote(path)
      @_resource unquote(resource)

      # Private helper used by all generated bang-variant functions.
      # Defined before any public function so it is always available.
      @spec bang!(atom(), list()) :: map()
      defp bang!(fun, args) do
        case apply(__MODULE__, fun, args) do
          {:ok, result} -> result
          {:error, error} -> raise error
        end
      end

      unquote(
        if has_create do
          quote do
            @doc """
            Creates a new #{@_resource}.

            Returns `{:ok, map()}` on success, `{:error, %Marqeta.Error{}}` on failure.
            """
            @spec create(map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
            def create(params \\ %{}, opts \\ []) do
              Client.post(@_path, params, opts)
            end

            @doc "Creates a new #{@_resource}. Raises `Marqeta.Error` on failure."
            @spec create!(map(), keyword()) :: map()
            def create!(params \\ %{}, opts \\ []) do
              bang!(:create, [params, opts])
            end
          end
        end
      )

      unquote(
        if has_get do
          quote do
            @doc """
            Retrieves a #{@_resource} by token.

            Returns `{:ok, map()}` on success, `{:error, %Marqeta.Error{}}` on failure.
            """
            @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
            def get(token, opts \\ []) do
              Client.get("#{@_path}/#{token}", opts)
            end

            @doc "Retrieves a #{@_resource} by token. Raises `Marqeta.Error` on failure."
            @spec get!(String.t(), keyword()) :: map()
            def get!(token, opts \\ []) do
              bang!(:get, [token, opts])
            end
          end
        end
      )

      unquote(
        if has_update do
          quote do
            @doc """
            Updates an existing #{@_resource}.

            Returns `{:ok, map()}` on success, `{:error, %Marqeta.Error{}}` on failure.
            """
            @spec update(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
            def update(token, params, opts \\ []) do
              Client.put("#{@_path}/#{token}", params, opts)
            end

            @doc "Updates an existing #{@_resource}. Raises `Marqeta.Error` on failure."
            @spec update!(String.t(), map(), keyword()) :: map()
            def update!(token, params, opts \\ []) do
              bang!(:update, [token, params, opts])
            end
          end
        end
      )

      unquote(
        if has_list do
          quote do
            @doc """
            Lists #{@_resource} resources.

            Accepts standard Marqeta pagination params:
            `count`, `start_index`, `sort_by`, `sort_order`, `fields`.

            Use `stream/2` to lazily iterate all pages automatically.
            """
            @spec list(map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
            def list(params \\ %{}, opts \\ []) do
              Client.get(@_path, Keyword.put(opts, :params, params))
            end

            @doc "Lists #{@_resource} resources. Raises `Marqeta.Error` on failure."
            @spec list!(map(), keyword()) :: map()
            def list!(params \\ %{}, opts \\ []) do
              bang!(:list, [params, opts])
            end

            @doc """
            Returns a lazy `Stream` that auto-paginates #{@_resource} resources.
            """
            @spec stream(map(), keyword()) :: Enumerable.t()
            def stream(params \\ %{}, opts \\ []) do
              MStream.stream(fn p -> list(p, opts) end, params)
            end
          end
        end
      )

      # Emit defoverridable only when there are public functions to mark overridable.
      # `maybe_defoverridable` is either a quoted `defoverridable [...]` AST node
      # or `nil` — nil is safely ignored inside a quote block.
      unquote(maybe_defoverridable)
    end
  end
end
