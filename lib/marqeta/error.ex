defmodule Marqeta.Error do
  @moduledoc """
  Structured error type returned by all Marqeta API functions.

  ## Error types

  | Type                    | HTTP status | Retryable? |
  |-------------------------|-------------|------------|
  | `:validation_error`     | 400, 422    | No         |
  | `:authentication_error` | 401         | No         |
  | `:authorization_error`  | 403         | No         |
  | `:not_found`            | 404         | No         |
  | `:conflict_error`       | 409         | No         |
  | `:rate_limit_error`     | 429         | Yes        |
  | `:server_error`         | 500+        | Yes        |
  | `:network_error`        | —           | Yes        |
  | `:timeout_error`        | —           | Yes        |
  | `:decode_error`         | —           | No         |
  | `:api_error`            | other       | No         |
  | `:unknown_error`        | —           | No         |

  ## Fields

    * `:type`         — error type atom (see table above)
    * `:message`      — human-readable error message
    * `:http_status`  — HTTP status code (when applicable)
    * `:error_code`   — Marqeta error code string (e.g. `"400040"`)
    * `:request_id`   — Marqeta request correlation ID from `x-request-id` header
    * `:field_errors` — list of field-level validation errors
    * `:retryable?`   — whether this error is safe to retry
    * `:raw`          — raw response body or original exception
  """

  @type error_type ::
          :api_error
          | :authentication_error
          | :authorization_error
          | :conflict_error
          | :decode_error
          | :network_error
          | :not_found
          | :rate_limit_error
          | :server_error
          | :timeout_error
          | :unknown_error
          | :validation_error

  @type field_error :: %{code: String.t() | nil, field: String.t(), message: String.t()}

  @type headers :: [{String.t(), String.t()}] | %{String.t() => String.t() | [String.t()]}

  @type t :: %__MODULE__{
          error_code: String.t() | nil,
          field_errors: [field_error()],
          http_status: non_neg_integer() | nil,
          message: String.t(),
          raw: term(),
          request_id: String.t() | nil,
          retryable?: boolean(),
          type: error_type()
        }

  defexception [
    :error_code,
    :http_status,
    :message,
    :raw,
    :request_id,
    :type,
    field_errors: [],
    retryable?: false
  ]

  @impl true
  def message(%__MODULE__{message: msg, http_status: nil}),
    do: msg || "Unknown Marqeta error"

  def message(%__MODULE__{message: msg, http_status: status, error_code: nil}),
    do: "HTTP #{status}: #{msg}"

  def message(%__MODULE__{message: msg, http_status: status, error_code: code}),
    do: "HTTP #{status} (#{code}): #{msg}"

  # ---------------------------------------------------------------------------
  # Builders
  # ---------------------------------------------------------------------------

  @doc """
  Builds a `Marqeta.Error` from a parsed HTTP response.

  `headers` may be a keyword list of `{name, value}` tuples (as returned by
  Finch / Req) or a map of `name => value` strings.
  """
  @spec from_response(%{body: term(), headers: headers(), status: non_neg_integer()}) :: t()
  def from_response(%{body: body, headers: headers, status: status}) do
    request_id = extract_request_id(headers)
    {type, msg, error_code, fields} = parse_body(status, body)

    %__MODULE__{
      error_code: error_code,
      field_errors: fields,
      http_status: status,
      message: msg,
      raw: body,
      request_id: request_id,
      retryable?: retryable?(status),
      type: type
    }
  end

  @doc """
  Builds a `Marqeta.Error` from a network or transport exception.
  """
  @spec from_exception(term()) :: t()
  def from_exception(exception) do
    {type, msg, retryable?} = classify_exception(exception)

    %__MODULE__{
      message: msg,
      raw: exception,
      retryable?: retryable?,
      type: type
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec extract_request_id(headers()) :: String.t() | nil
  defp extract_request_id(headers) when is_list(headers) do
    case List.keyfind(headers, "x-request-id", 0) do
      {_, id} -> id
      nil -> nil
    end
  end

  defp extract_request_id(headers) when is_map(headers) do
    Map.get(headers, "x-request-id")
  end

  defp extract_request_id(_), do: nil

  @spec parse_body(non_neg_integer(), term()) ::
          {error_type(), String.t(), String.t() | nil, [field_error()]}
  defp parse_body(status, body) when is_map(body) do
    error_code = body["error_code"] || body["code"]
    msg = body["error_message"] || body["message"] || body["detail"] || default_message(status)
    fields = parse_field_errors(body)
    {type_from_status(status), msg, error_code, fields}
  end

  defp parse_body(status, body) when is_binary(body) do
    trimmed = String.trim(body)
    msg = if trimmed == "", do: default_message(status), else: trimmed
    {type_from_status(status), msg, nil, []}
  end

  defp parse_body(status, _body) do
    {type_from_status(status), default_message(status), nil, []}
  end

  @spec parse_field_errors(map()) :: [field_error()]
  defp parse_field_errors(%{"errors" => errors}) when is_list(errors) do
    Enum.map(errors, fn e ->
      %{
        code: e["code"],
        field: e["field"] || e["path"] || "",
        message: e["message"] || e["detail"] || ""
      }
    end)
  end

  defp parse_field_errors(_), do: []

  @spec type_from_status(non_neg_integer()) ::
          :api_error
          | :authentication_error
          | :authorization_error
          | :conflict_error
          | :not_found
          | :rate_limit_error
          | :server_error
          | :validation_error
  defp type_from_status(400), do: :validation_error
  defp type_from_status(401), do: :authentication_error
  defp type_from_status(403), do: :authorization_error
  defp type_from_status(404), do: :not_found
  defp type_from_status(409), do: :conflict_error
  defp type_from_status(422), do: :validation_error
  defp type_from_status(429), do: :rate_limit_error
  defp type_from_status(status) when status >= 500, do: :server_error
  defp type_from_status(_), do: :api_error

  @spec retryable?(non_neg_integer()) :: boolean()
  defp retryable?(429), do: true
  defp retryable?(status) when status >= 500, do: true
  defp retryable?(_), do: false

  @spec default_message(non_neg_integer()) :: String.t()
  defp default_message(400), do: "Bad request"
  defp default_message(401), do: "Unauthorized — check your credentials"
  defp default_message(403), do: "Forbidden — insufficient permissions"
  defp default_message(404), do: "Resource not found"

  defp default_message(409),
    do: "Conflict — resource already exists or is in an incompatible state"

  defp default_message(422), do: "Unprocessable entity"
  defp default_message(429), do: "Rate limit exceeded"
  defp default_message(500), do: "Internal server error"
  defp default_message(502), do: "Bad gateway"
  defp default_message(503), do: "Service unavailable"
  defp default_message(504), do: "Gateway timeout"
  defp default_message(status), do: "Unexpected HTTP status #{status}"

  @spec classify_exception(term()) :: {error_type(), String.t(), boolean()}
  defp classify_exception(%Req.TransportError{reason: :timeout}),
    do: {:timeout_error, "Request timed out", true}

  defp classify_exception(%Req.TransportError{reason: :connect_timeout}),
    do: {:timeout_error, "Connection timed out", true}

  defp classify_exception(%Req.TransportError{reason: reason}),
    do: {:network_error, "Transport error: #{inspect(reason)}", true}

  defp classify_exception(%Jason.DecodeError{} = e),
    do: {:decode_error, "Failed to decode response: #{Exception.message(e)}", false}

  defp classify_exception(e) when is_exception(e),
    do: {:unknown_error, "Unexpected error: #{Exception.message(e)}", false}

  defp classify_exception(reason),
    do: {:network_error, "Network error: #{inspect(reason)}", true}
end
