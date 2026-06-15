defmodule Marqeta.HTTP.Behaviour do
  @moduledoc "Behaviour for the Marqeta HTTP client. Implement this to provide a test double."

  @callback delete(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  @callback get(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  @callback patch(String.t(), map() | nil, keyword()) ::
              {:ok, map()} | {:error, Marqeta.Error.t()}
  @callback post(String.t(), map() | nil, keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  @callback put(String.t(), map() | nil, keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
end

defmodule Marqeta.Client do
  @moduledoc """
  Core HTTP client for the Marqeta API.

  Handles authentication (HTTP Basic Auth), retry with exponential backoff
  and jitter, telemetry emission, optional rate limiting, and error
  normalisation into `Marqeta.Error`.

  ## Per-request options

  All public functions accept an optional `opts` keyword list:

    * `:timeout`  — override the configured timeout (ms).
    * `:retry`    — max retries for this request; `false` to disable.
    * `:headers`  — additional headers `[{name, value}]`.
    * `:params`   — URL query parameters (map or keyword list).
  """

  @behaviour Marqeta.HTTP.Behaviour

  require Logger

  alias Marqeta.{Config, Error, Telemetry}

  @user_agent "marqeta-elixir/1.0.0"

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @impl Marqeta.HTTP.Behaviour
  @doc "Performs a GET request to `path`."
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(path, opts \\ []), do: request(:get, path, nil, opts)

  @impl Marqeta.HTTP.Behaviour
  @doc "Performs a POST request to `path` with `body`."
  @spec post(String.t(), map() | nil, keyword()) :: {:ok, map()} | {:error, Error.t()}
  def post(path, body \\ nil, opts \\ []), do: request(:post, path, body, opts)

  @impl Marqeta.HTTP.Behaviour
  @doc "Performs a PUT request to `path` with `body`."
  @spec put(String.t(), map() | nil, keyword()) :: {:ok, map()} | {:error, Error.t()}
  def put(path, body \\ nil, opts \\ []), do: request(:put, path, body, opts)

  @impl Marqeta.HTTP.Behaviour
  @doc "Performs a PATCH request to `path` with `body`."
  @spec patch(String.t(), map() | nil, keyword()) :: {:ok, map()} | {:error, Error.t()}
  def patch(path, body \\ nil, opts \\ []), do: request(:patch, path, body, opts)

  @impl Marqeta.HTTP.Behaviour
  @doc "Performs a DELETE request to `path`."
  @spec delete(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def delete(path, opts \\ []), do: request(:delete, path, nil, opts)

  # ---------------------------------------------------------------------------
  # Core pipeline
  # ---------------------------------------------------------------------------

  @spec request(atom(), String.t(), map() | nil, keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  defp request(method, path, body, opts) do
    config = Config.get()
    start_time = System.monotonic_time()
    metadata = %{attempt: 1, method: method, path: path}

    Telemetry.request_start(config.telemetry_prefix, metadata)

    result =
      try do
        execute_with_retry(method, path, body, opts, config, metadata, 0)
      rescue
        e ->
          duration = System.monotonic_time() - start_time

          Telemetry.request_exception(
            config.telemetry_prefix,
            metadata,
            duration,
            :error,
            e,
            __STACKTRACE__
          )

          {:error, Error.from_exception(e)}
      end

    duration = System.monotonic_time() - start_time
    Telemetry.request_stop(config.telemetry_prefix, metadata, duration, result)
    result
  end

  @spec execute_with_retry(
          atom(),
          String.t(),
          map() | nil,
          keyword(),
          Config.t(),
          %{attempt: pos_integer(), method: atom(), path: String.t()},
          non_neg_integer()
        ) :: {:ok, map()} | {:error, Error.t()}
  defp execute_with_retry(method, path, body, opts, config, metadata, attempt) do
    max_attempts =
      case Keyword.get(opts, :retry, config.retry_max_attempts) do
        false -> 0
        n when is_integer(n) -> n
        _ -> config.retry_max_attempts
      end

    case do_request(method, path, body, opts, config) do
      {:ok, _} = ok ->
        ok

      {:error, %Error{retryable?: true}} when attempt < max_attempts ->
        delay = backoff_delay(attempt, config)

        Logger.warning(
          "[Marqeta] #{String.upcase(to_string(method))} #{path} failed " <>
            "(attempt #{attempt + 1}/#{max_attempts + 1}), retrying in #{delay}ms"
        )

        Process.sleep(delay)
        updated_meta = %{metadata | attempt: attempt + 2}
        Telemetry.request_retry(config.telemetry_prefix, updated_meta)
        execute_with_retry(method, path, body, opts, config, updated_meta, attempt + 1)

      {:error, _} = err ->
        err
    end
  end

  @spec do_request(atom(), String.t(), map() | nil, keyword(), Config.t()) ::
          {:ok, map()} | {:error, Error.t()}
  defp do_request(method, path, body, opts, config) do
    if Process.whereis(Marqeta.RateLimiter) do
      Marqeta.RateLimiter.check_rate_limit(path)
    end

    url = build_url(config.base_url, path, Keyword.get(opts, :params))
    headers = build_headers(config, opts)
    timeout = Keyword.get(opts, :timeout, config.timeout)

    req_opts =
      maybe_put_body(
        [
          connect_options: [timeout: config.connect_timeout],
          finch: Marqeta.Finch,
          headers: headers,
          method: method,
          receive_timeout: timeout,
          retry: false,
          url: url
        ],
        body
      )

    case Req.request(req_opts) do
      {:ok, %{body: resp_body, status: status}} when status in 200..299 ->
        {:ok, resp_body}

      {:ok, %{body: resp_body, headers: resp_headers, status: status}} ->
        {:error, Error.from_response(%{body: resp_body, headers: resp_headers, status: status})}

      {:error, exception} ->
        {:error, Error.from_exception(exception)}
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  @spec build_url(String.t(), String.t(), map() | keyword() | nil) :: String.t()
  defp build_url(base, path, nil),
    do: String.trim_trailing(base, "/") <> path

  defp build_url(base, path, params) when params == [] or params == %{},
    do: String.trim_trailing(base, "/") <> path

  defp build_url(base, path, params),
    do: String.trim_trailing(base, "/") <> path <> "?" <> URI.encode_query(params)

  @spec build_headers(Config.t(), keyword()) :: [{String.t(), String.t()}]
  defp build_headers(config, opts) do
    auth = Base.encode64("#{config.application_token}:#{config.admin_access_token}")
    extra = Keyword.get(opts, :headers, [])

    [
      {"accept", "application/json"},
      {"authorization", "Basic #{auth}"},
      {"content-type", "application/json"},
      {"user-agent", @user_agent}
    ] ++ config.custom_headers ++ extra
  end

  @spec maybe_put_body(keyword(), map() | nil) :: keyword()
  defp maybe_put_body(req_opts, nil), do: req_opts
  defp maybe_put_body(req_opts, body), do: Keyword.put(req_opts, :json, body)

  @spec backoff_delay(non_neg_integer(), Config.t()) :: non_neg_integer()
  defp backoff_delay(attempt, config) do
    base = config.retry_base_delay
    max = config.retry_max_delay
    delay = min(trunc(base * :math.pow(2, attempt)), max)

    if config.retry_jitter do
      jitter_max = max(div(delay, 4), 1)
      delay + :rand.uniform(jitter_max) - div(jitter_max, 2)
    else
      delay
    end
  end
end
