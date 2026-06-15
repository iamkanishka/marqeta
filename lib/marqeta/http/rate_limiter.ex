defmodule Marqeta.RateLimiter do
  @moduledoc """
  Token-bucket rate limiter for the Marqeta API.

  Maintains per-category token buckets. When a bucket is empty, callers
  block until tokens refill on the next 100 ms tick.

  ## Buckets

  | Bucket        | Default RPS | Burst |
  |---------------|-------------|-------|
  | `:default`    | 50          | 100   |
  | `:diva`       | 20          | 50    |
  | `:simulations`| 10          | 20    |

  The limiter is started automatically by Marqeta.Application and is
  called by `Marqeta.Client` before every outbound request.
  In tests the GenServer is not started so the call is a no-op.
  """

  use GenServer

  require Logger

  @refill_ms 100

  @initial_buckets %{
    default: %{max: 100, rps: 50, tokens: 100},
    diva: %{max: 50, rps: 20, tokens: 50},
    simulations: %{max: 20, rps: 10, tokens: 20}
  }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Acquires a rate-limit token for the given `path`.

  Blocks (up to 10 s) if the relevant bucket is empty.
  Returns `:ok` once a token has been acquired.
  """
  @spec check_rate_limit(String.t()) :: :ok
  def check_rate_limit(path) do
    bucket = bucket_for(path)
    GenServer.call(__MODULE__, {:acquire, bucket}, 10_000)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl GenServer
  def init(_opts) do
    schedule_refill()
    {:ok, %{buckets: @initial_buckets, waiters: %{}}}
  end

  @impl GenServer
  def handle_call({:acquire, bucket}, from, state) do
    case get_in(state, [:buckets, bucket, :tokens]) do
      tokens when is_number(tokens) and tokens >= 1 ->
        new_state = update_in(state, [:buckets, bucket, :tokens], &(&1 - 1))
        {:reply, :ok, new_state}

      _ ->
        # Park the caller; reply on the next refill tick.
        waiters = Map.update(state.waiters, bucket, [from], &[from | &1])
        {:noreply, %{state | waiters: waiters}}
    end
  end

  @impl GenServer
  def handle_info(:refill, state) do
    new_buckets =
      Map.new(state.buckets, fn {name, bucket} ->
        refill = bucket.rps * @refill_ms / 1_000
        new_tokens = min(bucket.tokens + refill, bucket.max)
        {name, %{bucket | tokens: new_tokens}}
      end)

    {new_waiters, final_buckets} =
      Enum.reduce(
        state.waiters,
        {%{}, new_buckets},
        fn {bucket, callers}, {wacc, bacc} ->
          {remaining, updated_bacc} = release_waiters(callers, bucket, bacc)
          {Map.put(wacc, bucket, remaining), updated_bacc}
        end
      )

    schedule_refill()
    {:noreply, %{state | buckets: final_buckets, waiters: new_waiters}}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec release_waiters([GenServer.from()], atom(), map()) ::
          {[GenServer.from()], map()}
  defp release_waiters([], _bucket, buckets), do: {[], buckets}

  defp release_waiters([caller | rest], bucket, buckets) do
    tokens = get_in(buckets, [bucket, :tokens])

    if tokens >= 1 do
      GenServer.reply(caller, :ok)
      updated = update_in(buckets, [bucket, :tokens], &(&1 - 1))
      release_waiters(rest, bucket, updated)
    else
      {[caller | rest], buckets}
    end
  end

  defp schedule_refill, do: Process.send_after(self(), :refill, @refill_ms)

  @spec bucket_for(String.t()) :: atom()
  defp bucket_for("/simulate" <> _), do: :simulations
  defp bucket_for("/simulations" <> _), do: :simulations
  defp bucket_for("/diva" <> _), do: :diva
  defp bucket_for(_), do: :default
end
