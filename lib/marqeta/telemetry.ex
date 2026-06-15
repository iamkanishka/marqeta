defmodule Marqeta.Telemetry do
  @moduledoc """
  Telemetry integration for the Marqeta client.

  All HTTP requests emit telemetry events consumable by Phoenix LiveDashboard,
  PromEx, Datadog, or any `:telemetry` handler.

  ## Events

  All events use the configured `:telemetry_prefix` (default `[:marqeta]`).

  ### `[:marqeta, :request, :start]`

    * Measurements: `%{system_time: integer}`
    * Metadata: `%{attempt: integer, method: atom, path: string}`

  ### `[:marqeta, :request, :stop]`

    * Measurements: `%{duration: integer}` (native time units)
    * Metadata: `%{attempt: integer, http_status: integer | nil, method: atom, path: string, status: :ok | :error}`

  ### `[:marqeta, :request, :exception]`

    * Measurements: `%{duration: integer}`
    * Metadata: `%{kind: atom, method: atom, path: string, reason: term, stacktrace: list}`

  ### `[:marqeta, :request, :retry]`

    * Measurements: `%{system_time: integer}`
    * Metadata: `%{attempt: integer, method: atom, path: string}`

  ## Attaching a handler

      :telemetry.attach(
        "my-marqeta-logger",
        [:marqeta, :request, :stop],
        &Marqeta.Telemetry.log_handler/4,
        nil
      )

  ## Metrics

      # For Phoenix LiveDashboard or PromEx:
      Marqeta.Telemetry.metrics()
  """

  require Logger

  # ---------------------------------------------------------------------------
  # Emission helpers — called by Marqeta.Client
  # ---------------------------------------------------------------------------

  @doc false
  @spec request_start([atom()], map()) :: :ok
  def request_start(prefix, metadata) do
    :telemetry.execute(
      prefix ++ [:request, :start],
      %{system_time: System.system_time()},
      metadata
    )
  end

  @doc false
  @spec request_stop([atom()], map(), integer(), {:ok, map()} | {:error, term()}) :: :ok
  def request_stop(prefix, metadata, duration, result) do
    {status, http_status} =
      case result do
        {:ok, _} -> {:ok, nil}
        {:error, %Marqeta.Error{http_status: s}} -> {:error, s}
        {:error, _} -> {:error, nil}
      end

    :telemetry.execute(
      prefix ++ [:request, :stop],
      %{duration: duration},
      Map.merge(metadata, %{http_status: http_status, status: status})
    )
  end

  @doc false
  @spec request_retry([atom()], map()) :: :ok
  def request_retry(prefix, metadata) do
    :telemetry.execute(
      prefix ++ [:request, :retry],
      %{system_time: System.system_time()},
      metadata
    )
  end

  @doc false
  @spec request_exception([atom()], map(), integer(), atom(), term(), list()) :: :ok
  def request_exception(prefix, metadata, duration, kind, reason, stacktrace) do
    :telemetry.execute(
      prefix ++ [:request, :exception],
      %{duration: duration},
      Map.merge(metadata, %{kind: kind, reason: reason, stacktrace: stacktrace})
    )
  end

  # ---------------------------------------------------------------------------
  # Metrics definitions
  # ---------------------------------------------------------------------------

  @doc """
  Returns `Telemetry.Metrics` structs for use with Phoenix LiveDashboard or PromEx.

  ## Usage

      # In your Phoenix endpoint telemetry module:
      def metrics do
        Marqeta.Telemetry.metrics() ++ your_own_metrics()
      end
  """
  @spec metrics() :: [Telemetry.Metrics.t()]
  def metrics do
    import Telemetry.Metrics

    [
      counter("marqeta.request.stop.count",
        description: "Total Marqeta API requests completed",
        tags: [:method, :status]
      ),
      distribution("marqeta.request.stop.duration",
        description: "Marqeta API request duration in milliseconds",
        tags: [:method, :status],
        unit: {:native, :millisecond}
      ),
      counter("marqeta.request.stop.http_status_count",
        description: "Marqeta API requests by HTTP status code",
        tags: [:http_status, :method]
      ),
      counter("marqeta.request.retry.count",
        description: "Retried Marqeta API requests",
        tags: [:method]
      ),
      counter("marqeta.request.exception.count",
        description: "Unhandled exceptions during Marqeta API requests",
        tags: [:kind, :method]
      )
    ]
  end

  # ---------------------------------------------------------------------------
  # Ready-made log handler
  # ---------------------------------------------------------------------------

  @doc """
  A ready-made telemetry handler that logs request outcomes via `Logger`.

  Attach with:

      :telemetry.attach(
        "marqeta-logger",
        [:marqeta, :request, :stop],
        &Marqeta.Telemetry.log_handler/4,
        nil
      )
  """
  @spec log_handler([atom()], map(), map(), term()) :: :ok
  def log_handler([:marqeta, :request, :stop], measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    method = metadata.method |> to_string() |> String.upcase()

    case metadata.status do
      :ok ->
        Logger.debug("[Marqeta] #{method} #{metadata.path} → 2xx (#{duration_ms}ms)",
          marqeta_duration_ms: duration_ms,
          marqeta_method: method,
          marqeta_path: metadata.path
        )

      :error ->
        Logger.warning(
          "[Marqeta] #{method} #{metadata.path} → #{metadata.http_status || "ERR"} (#{duration_ms}ms)",
          marqeta_duration_ms: duration_ms,
          marqeta_http_status: metadata.http_status,
          marqeta_method: method,
          marqeta_path: metadata.path
        )
    end
  end

  # credo:disable-for-next-line Credo.Check.Readability.Specs
  def log_handler([:marqeta, :request, :retry], _measurements, metadata, _config) do
    method = metadata.method |> to_string() |> String.upcase()

    Logger.warning("[Marqeta] #{method} #{metadata.path} retry ##{metadata.attempt}",
      marqeta_attempt: metadata.attempt,
      marqeta_method: method,
      marqeta_path: metadata.path
    )
  end

  # credo:disable-for-next-line Credo.Check.Readability.Specs
  def log_handler([:marqeta, :request, :exception], _measurements, metadata, _config) do
    Logger.error(
      "[Marqeta] #{metadata.method} #{metadata.path} raised #{metadata.kind}: #{inspect(metadata.reason)}"
    )
  end

  # credo:disable-for-next-line Credo.Check.Readability.Specs
  def log_handler(_event, _measurements, _metadata, _config), do: :ok
end

defmodule Marqeta.Telemetry.Reporter do
  @moduledoc false

  use GenServer

  @handler_id "marqeta-internal-logger"

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    :telemetry.attach_many(
      @handler_id,
      [
        [:marqeta, :request, :exception],
        [:marqeta, :request, :retry],
        [:marqeta, :request, :stop]
      ],
      &Marqeta.Telemetry.log_handler/4,
      nil
    )

    {:ok, %{}}
  end

  @impl GenServer
  def terminate(_reason, _state) do
    :telemetry.detach(@handler_id)
    :ok
  end
end
