defmodule Marqeta.Pagination do
  @moduledoc """
  Pagination cursor helpers for Marqeta list endpoints.

  Marqeta paginates with `count` (page size) and `start_index` (offset).
  Responses include `"is_more": true` when further pages exist.

  ## Example

      {:ok, page} = Marqeta.Users.list(%{count: 10, start_index: 0})
      if Marqeta.Pagination.has_more?(page) do
        next = Marqeta.Pagination.next_page_params(page, %{count: 10, start_index: 0})
        {:ok, page2} = Marqeta.Users.list(next)
      end
  """

  @default_count 5
  @max_count 1_000

  @type page :: %{optional(String.t()) => term()}

  @type normalized_params :: %{
          required(:count) => pos_integer(),
          required(:start_index) => non_neg_integer(),
          optional(atom()) => term()
        }

  @doc "Returns default pagination params `%{count: 5, start_index: 0}`."
  @spec default_params() :: %{count: 5, start_index: 0}
  def default_params, do: %{count: @default_count, start_index: 0}

  @doc """
  Normalises params, enforcing the maximum allowed count and a default `start_index`.

  Always returns a map containing at least `:count` and `:start_index` integer keys.
  """
  @spec normalize_params(map()) :: normalized_params()
  def normalize_params(params) when is_map(params) do
    count = params |> get_int(:count, @default_count) |> min(@max_count)
    start_index = get_int(params, :start_index, 0)
    Map.merge(params, %{count: count, start_index: start_index})
  end

  @doc """
  Returns params for the next page, or `nil` when no more pages exist.

  Determines "more pages" via:

    1. `"is_more": true` in the response (Marqeta's explicit signal).
    2. Fallback: returned `count` equals requested `count` (more may exist).
  """
  @spec next_page_params(page(), map()) :: map() | nil
  def next_page_params(response, current_params) when is_map(response) do
    returned = Map.get(response, "count", 0)
    requested = get_int(current_params, :count, @default_count)
    current_start = get_int(current_params, :start_index, 0)
    is_more = Map.get(response, "is_more", false)

    cond do
      returned == 0 ->
        nil

      is_more ->
        Map.put(current_params, :start_index, current_start + returned)

      returned >= requested ->
        Map.put(current_params, :start_index, current_start + returned)

      true ->
        nil
    end
  end

  @doc "Returns `true` when the response signals there are more pages."
  @spec has_more?(page()) :: boolean()
  def has_more?(%{"is_more" => true}), do: true
  def has_more?(_), do: false

  @doc "Extracts the `\"data\"` list from a paginated response."
  @spec extract_data(page()) :: [map()]
  def extract_data(%{"data" => data}) when is_list(data), do: data
  def extract_data(_), do: []

  @doc "Returns the record count from a paginated response."
  @spec total_count(page()) :: non_neg_integer()
  def total_count(%{"count" => n}) when is_integer(n), do: n
  def total_count(_), do: 0

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  # Reads an integer value from `map` under `key` (atom or string form),
  # returning `default` when absent or non-integer.
  @spec get_int(map(), atom(), non_neg_integer()) :: non_neg_integer()
  defp get_int(map, key, default) do
    value = Map.get(map, key) || Map.get(map, to_string(key))

    case value do
      nil -> default
      v when is_integer(v) -> v
      v when is_binary(v) -> String.to_integer(v)
      _ -> default
    end
  end
end

defmodule Marqeta.Stream do
  @moduledoc """
  Lazy streaming over paginated Marqeta list endpoints.

  Fetches the next page only when the stream consumer exhausts the current one.
  No prefetching or buffering occurs.

  ## Examples

      # Stream all users (auto-paginates)
      Marqeta.Stream.stream(&Marqeta.Users.list/1, %{count: 100})
      |> Stream.filter(& &1["status"] == "ACTIVE")
      |> Enum.to_list()

      # Take only the first 50 items
      Marqeta.Stream.stream(fn p -> Marqeta.Cards.list_by_user("tok", p) end)
      |> Enum.take(50)

      # Collect all pages into one list
      {:ok, all} = Marqeta.Stream.all(&Marqeta.Users.list/1)
  """

  alias Marqeta.Pagination

  @doc """
  Returns a lazy `Enumerable` that auto-paginates using `list_fn`.

  `list_fn` must be a 1-arity function accepting a params map and returning
  `{:ok, page}` or `{:error, error}`.

  ## Options

    * `:raise_on_error` — raise `Marqeta.Error` instead of stopping the stream
      silently on error. Default: `false`.
  """
  @spec stream(
          (map() -> {:ok, map()} | {:error, term()}),
          map(),
          keyword()
        ) :: Enumerable.t()
  def stream(list_fn, params \\ %{}, opts \\ [])
      when is_function(list_fn, 1) and is_map(params) and is_list(opts) do
    initial = Pagination.normalize_params(params)

    Stream.resource(
      fn -> {:cont, initial} end,
      &step(&1, list_fn, opts),
      fn _ -> :ok end
    )
  end

  @doc """
  Collects all pages into a single list synchronously.

  Returns `{:ok, [item]}` or `{:error, error}`.
  Prefer `stream/3` for large datasets.
  """
  @spec all((map() -> {:ok, map()} | {:error, term()}), map()) ::
          {:ok, [map()]} | {:error, term()}
  def all(list_fn, params \\ %{}) when is_function(list_fn, 1) and is_map(params) do
    collect(list_fn, Pagination.normalize_params(params), [])
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec step(
          :halt | {:cont, map()},
          (map() -> {:ok, map()} | {:error, term()}),
          keyword()
        ) :: {[map()], :halt | {:cont, map()}} | {:halt, :halt}
  defp step(:halt, _list_fn, _opts), do: {:halt, :halt}

  defp step({:cont, current_params}, list_fn, opts) do
    case list_fn.(current_params) do
      {:ok, response} ->
        data = Pagination.extract_data(response)

        if data == [] do
          {[], :halt}
        else
          case Pagination.next_page_params(response, current_params) do
            nil -> {data, :halt}
            next -> {data, {:cont, next}}
          end
        end

      {:error, error} ->
        if Keyword.get(opts, :raise_on_error, false), do: raise(error)
        {[], :halt}
    end
  end

  @spec collect(
          (map() -> {:ok, map()} | {:error, term()}),
          map(),
          [map()]
        ) :: {:ok, [map()]} | {:error, term()}
  defp collect(list_fn, params, acc) do
    case list_fn.(params) do
      {:ok, response} ->
        data = Pagination.extract_data(response)
        combined = acc ++ data

        case Pagination.next_page_params(response, params) do
          nil -> {:ok, combined}
          next -> collect(list_fn, next, combined)
        end

      {:error, _} = err ->
        err
    end
  end
end
