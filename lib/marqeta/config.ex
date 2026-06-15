defmodule Marqeta.Config do
  @moduledoc """
  Configuration for the Marqeta client.

  Loaded from the `:marqeta` application environment and validated with
  `NimbleOptions`. The validated struct is cached in `:persistent_term` for
  zero-overhead repeated reads.

  ## Options

    * `:base_url` — Base URL of the Marqeta API.
      Defaults to `"https://sandbox-api.marqeta.com/v3"`.
    * `:application_token` — Your Marqeta application token. **Required.**
    * `:admin_access_token` — Your admin access token. **Required.**
    * `:pool_size` — HTTP connection pool size per host. Default: `10`.
    * `:pool_count` — Number of pools per host. Default: `1`.
    * `:timeout` — Request timeout in milliseconds. Default: `30_000`.
    * `:connect_timeout` — Connection timeout in milliseconds. Default: `5_000`.
    * `:retry_max_attempts` — Max retry attempts on transient errors. Default: `3`.
    * `:retry_base_delay` — Base delay for exponential backoff (ms). Default: `500`.
    * `:retry_max_delay` — Maximum retry delay (ms). Default: `10_000`.
    * `:retry_jitter` — Add jitter to retry delays. Default: `true`.
    * `:sandbox` — `true` when using the sandbox environment. Default: `false`.
    * `:telemetry_prefix` — Prefix for telemetry events. Default: `[:marqeta]`.
    * `:log_level` — Log level for HTTP calls. Default: `:info`.
    * `:custom_headers` — Additional headers included in every request.
    * `:http_client` — HTTP client module (override for testing).

  ## Example

      config :marqeta,
        base_url: "https://sandbox-api.marqeta.com/v3",
        application_token: System.fetch_env!("MARQETA_APP_TOKEN"),
        admin_access_token: System.fetch_env!("MARQETA_ADMIN_TOKEN"),
        pool_size: 20,
        timeout: 30_000,
        retry_max_attempts: 3,
        sandbox: true
  """

  @type t :: %__MODULE__{
          admin_access_token: String.t(),
          application_token: String.t(),
          base_url: String.t(),
          connect_timeout: pos_integer(),
          custom_headers: [{String.t(), String.t()}],
          http_client: module(),
          log_level: Logger.level(),
          pool_count: pos_integer(),
          pool_size: pos_integer(),
          retry_base_delay: pos_integer(),
          retry_jitter: boolean(),
          retry_max_attempts: non_neg_integer(),
          retry_max_delay: pos_integer(),
          sandbox: boolean(),
          telemetry_prefix: [atom()]
        }

  defstruct admin_access_token: nil,
            application_token: nil,
            base_url: "https://sandbox-api.marqeta.com/v3",
            connect_timeout: 5_000,
            custom_headers: [],
            http_client: Marqeta.Client,
            log_level: :info,
            pool_count: 1,
            pool_size: 10,
            retry_base_delay: 500,
            retry_jitter: true,
            retry_max_attempts: 3,
            retry_max_delay: 10_000,
            sandbox: false,
            telemetry_prefix: [:marqeta]

  @schema NimbleOptions.new!(
            admin_access_token: [
              doc: "Your Marqeta admin access token",
              required: true,
              type: :string
            ],
            application_token: [
              doc: "Your Marqeta application token",
              required: true,
              type: :string
            ],
            base_url: [
              default: "https://sandbox-api.marqeta.com/v3",
              doc: "Base URL of the Marqeta API",
              type: :string
            ],
            connect_timeout: [
              default: 5_000,
              doc: "Connection timeout in milliseconds",
              type: :pos_integer
            ],
            custom_headers: [
              default: [],
              doc: "Additional headers included in every request",
              type: {:list, :any}
            ],
            http_client: [
              default: Marqeta.Client,
              doc: "HTTP client module",
              type: :atom
            ],
            log_level: [
              default: :info,
              doc: "Log level for HTTP calls",
              type: {:in, [:debug, :info, :warning, :error, :none]}
            ],
            pool_count: [
              default: 1,
              doc: "Number of connection pools per host",
              type: :pos_integer
            ],
            pool_size: [
              default: 10,
              doc: "HTTP connection pool size per host",
              type: :pos_integer
            ],
            retry_base_delay: [
              default: 500,
              doc: "Base delay for exponential backoff (ms)",
              type: :pos_integer
            ],
            retry_jitter: [
              default: true,
              doc: "Add jitter to retry delays",
              type: :boolean
            ],
            retry_max_attempts: [
              default: 3,
              doc: "Max retry attempts on transient errors",
              type: :non_neg_integer
            ],
            retry_max_delay: [
              default: 10_000,
              doc: "Maximum retry delay (ms)",
              type: :pos_integer
            ],
            sandbox: [
              default: false,
              doc: "Whether this is a sandbox environment",
              type: :boolean
            ],
            telemetry_prefix: [
              default: [:marqeta],
              doc: "Prefix for telemetry events",
              type: {:list, :atom}
            ]
          )

  @doc """
  Loads and validates configuration from the application environment.

  Raises `NimbleOptions.ValidationError` if the configuration is invalid.
  """
  @spec load!() :: t()
  def load! do
    raw = Application.get_all_env(:marqeta)

    case NimbleOptions.validate(raw, @schema) do
      {:ok, opts} -> struct!(__MODULE__, opts)
      {:error, error} -> raise error
    end
  end

  @doc """
  Loads configuration from the application environment.

  Returns `{:ok, t()}` or `{:error, NimbleOptions.ValidationError.t()}`.
  """
  @spec load() :: {:ok, t()} | {:error, NimbleOptions.ValidationError.t()}
  def load do
    raw = Application.get_all_env(:marqeta)

    case NimbleOptions.validate(raw, @schema) do
      {:ok, opts} -> {:ok, struct!(__MODULE__, opts)}
      {:error, _} = err -> err
    end
  end

  @doc """
  Returns the current config. Cached in `:persistent_term` after the first call.
  """
  @spec get() :: t()
  def get do
    case :persistent_term.get({__MODULE__, :config}, nil) do
      nil ->
        config = load!()
        :persistent_term.put({__MODULE__, :config}, config)
        config

      config ->
        config
    end
  end

  @doc """
  Invalidates the cached config.

  Call this after updating the application environment at runtime.
  """
  @spec invalidate() :: :ok
  def invalidate do
    :persistent_term.erase({__MODULE__, :config})
    :ok
  end

  @doc """
  Returns the NimbleOptions schema documentation string.
  """
  @spec docs() :: String.t()
  def docs, do: NimbleOptions.docs(@schema)
end
