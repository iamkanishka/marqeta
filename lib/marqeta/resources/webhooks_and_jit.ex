defmodule Marqeta.Webhooks do
  @moduledoc """
  Create and manage webhook endpoints for real-time event notifications.

  Marqeta sends HTTPS POST requests to your endpoint when events occur.

  ## Authentication options

  - **HTTP Basic Auth**: `config.basic_auth_username` + `config.basic_auth_password`
  - **HMAC Signature**: `config.secret` + `config.signature_algorithm` (`HMAC_SHA_256` or `HMAC_SHA_1`)
  - **mTLS** (beta): mutual TLS via certificate

  ## Event wildcard syntax

  - `"*"` — all events
  - `"transaction.*"` — all transaction events
  - Wildcards work only on top-level types; `"cardtransition.fulfillment.*"` is NOT valid.

  See `Marqeta.EventTypes` for all available event strings.

  ## Example

      {:ok, webhook} = Marqeta.Webhooks.create(%{
        name: "production",
        active: true,
        events: ["*"],
        config: %{
          url: "https://api.yourapp.com/webhooks/marqeta",
          basic_auth_username: "webhook_user",
          basic_auth_password: "S3cur3P@ssw0rd!XY",
          secret: "MyHmacSecret@123456789",
          signature_algorithm: "HMAC_SHA_256",
          custom_header: %{"X-My-Token" => "abc123"}
        }
      })

      # Test connectivity
      {:ok, _} = Marqeta.Webhooks.ping(webhook["token"])

      # Resend a specific event
      {:ok, _} = Marqeta.Webhooks.resend(webhook["token"], "event_token_abc")
  """

  use Marqeta.Resource, path: "/webhooks", resource: "webhook"

  alias Marqeta.Client

  @doc "Sends a ping to test that your webhook endpoint is reachable."
  @spec ping(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def ping(webhook_token, opts \\ []) do
    Client.post("/webhooks/#{webhook_token}/ping", %{}, opts)
  end

  @doc "Resends a specific event notification to the webhook endpoint."
  @spec resend(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def resend(webhook_token, event_token, opts \\ []) do
    Client.post("/webhooks/#{webhook_token}/resend/#{event_token}", %{}, opts)
  end

  @doc """
  Verifies an incoming webhook payload against its HMAC-SHA256 signature.

  Always verify signatures in production to prevent spoofed webhook delivery.

  ## Parameters
  - `payload`   — Raw request body binary (do NOT parse JSON first)
  - `signature` — Value from `X-Marqeta-Signature` header
  - `secret`    — Your webhook secret configured in `config.secret`

  ## Returns
  `true` if the signature is valid, `false` otherwise.

  ## Phoenix example

      defmodule MyAppWeb.MarqetaWebhookController do
        use MyAppWeb, :controller

        def handle(conn, _params) do
          sig    = get_req_header(conn, "x-marqeta-signature") |> List.first("")
          body   = conn.assigns[:raw_body]
          secret = Application.fetch_env!(:my_app, :marqeta_webhook_secret)

          if Marqeta.Webhooks.valid_signature?(body, sig, secret) do
            process_event(conn.body_params)
            send_resp(conn, 200, "ok")
          else
            send_resp(conn, 401, "invalid signature")
          end
        end
      end
  """
  @spec valid_signature?(binary(), String.t(), String.t()) :: boolean()
  def valid_signature?(payload, signature, secret)
      when is_binary(payload) and is_binary(signature) and is_binary(secret) do
    expected = Base.encode16(:crypto.mac(:hmac, :sha256, secret, payload), case: :lower)
    secure_compare(expected, String.downcase(signature))
  rescue
    _ -> false
  end

  @doc """
  Verifies an HMAC-SHA1 signature (for webhooks using `HMAC_SHA_1`).
  Prefer SHA-256 for new integrations.
  """
  @spec valid_signature_sha1?(binary(), String.t(), String.t()) :: boolean()
  def valid_signature_sha1?(payload, signature, secret)
      when is_binary(payload) and is_binary(signature) and is_binary(secret) do
    expected = Base.encode16(:crypto.mac(:hmac, :sha, secret, payload), case: :lower)
    secure_compare(expected, String.downcase(signature))
  rescue
    _ -> false
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  # Constant-time binary comparison to prevent timing attacks.
  # Compares two strings of equal length in O(n) time regardless of where
  # they differ. Returns false if lengths differ (also safe — length leaks
  # are acceptable since HMAC output length is fixed and public).
  @spec secure_compare(String.t(), String.t()) :: boolean()
  defp secure_compare(a, b) when byte_size(a) == byte_size(b) do
    a_bytes = :binary.bin_to_list(a)
    b_bytes = :binary.bin_to_list(b)

    Enum.zip(a_bytes, b_bytes)
    |> Enum.reduce(0, fn {x, y}, acc -> acc || :erlang.bxor(x, y) end)
    |> Kernel.==(0)
  end

  defp secure_compare(_a, _b), do: false

  @doc """
  Parses an incoming webhook event body.

  ## Returns
  `{:ok, event_map}` or `{:error, decode_error}`.
  """
  @spec parse_event(String.t() | map()) :: {:ok, map()} | {:error, Jason.DecodeError.t()}
  def parse_event(body) when is_binary(body) do
    Jason.decode(body)
  end

  def parse_event(body) when is_map(body), do: {:ok, body}

  @doc """
  Extracts the event type from a parsed webhook event.

  ## Examples

      {:ok, event} = Marqeta.Webhooks.parse_event(body)
      Marqeta.Webhooks.event_type(event)
      # => "transaction.authorization"
  """
  @spec event_type(map()) :: String.t() | nil
  def event_type(%{"type" => type}), do: type
  def event_type(_), do: nil
end

defmodule Marqeta.GatewayJIT do
  @moduledoc """
  Utilities for handling Gateway Just-in-Time (JIT) Funding requests.

  When using Gateway JIT Funding, Marqeta sends a **synchronous** funding
  request to your gateway endpoint for every authorization. Your gateway
  must respond with an approval or denial within the configured timeout
  (typically 1.5–3 seconds).

  ## Request Flow

  ```
  Cardholder swipes card
        ↓
  Network sends authorization to Marqeta
        ↓
  Marqeta sends JIT request → YOUR GATEWAY (sync, ~1.5s timeout)
        ↓
  Your gateway responds approve/deny
        ↓
  Marqeta approves/declines the network authorization
        ↓
  Marqeta sends async webhook notification (informative)
  ```

  ## JIT Methods

  ### Actionable (require a funding response)
  - `pgfs.authorization` — standard purchase authorization
  - `pgfs.authorization.account_verification` — zero-dollar card validation
  - `pgfs.auth_plus_capture` — single-message (PIN debit / ATM)
  - `pgfs.balance_inquiry` — balance inquiry

  ### Informative (no response needed — just acknowledge)
  - `pgfs.authorization.capture` — funds captured after authorization
  - `pgfs.authorization.capture.chargeback` — chargeback processed
  - `pgfs.authorization.reversal` — authorization reversed
  - `pgfs.authorization.clearing` — settlement complete
  - `pgfs.adjustment.credit` — credit adjustment applied
  - `pgfs.adjustment.debit` — debit adjustment applied

  ## Examples

      # In your gateway controller (Plug/Phoenix):
      def handle(conn, params) do
        alias Marqeta.GatewayJIT

        response =
          if GatewayJIT.actionable?(params) do
            user_token = GatewayJIT.user_token(params)
            amount     = GatewayJIT.amount(params)
            mcc        = GatewayJIT.mcc(params)

            cond do
              blocked_mcc?(mcc)       -> GatewayJIT.decline(params, reason: "TRANSACTION_NOT_PERMITTED")
              insufficient?(user_token, amount) -> GatewayJIT.decline(params, reason: "INSUFFICIENT_FUNDS")
              true                    -> GatewayJIT.approve(params)
            end
          else
            # Informative — return a minimal acknowledgement
            GatewayJIT.ack(params)
          end

        json(conn, response)
      end
  """

  @actionable_methods ~w(
    pgfs.authorization
    pgfs.authorization.account_verification
    pgfs.auth_plus_capture
    pgfs.balance_inquiry
  )

  @decline_reasons ~w(
    INSUFFICIENT_FUNDS
    INVALID_MERCHANT
    TRANSACTION_NOT_PERMITTED
    SUSPECTED_FRAUD
    DO_NOT_HONOR
    CARD_NOT_ACTIVE
    EXCEEDS_LIMIT
  )

  # ---------------------------------------------------------------------------
  # Response builders
  # ---------------------------------------------------------------------------

  @doc """
  Builds an approval response for a JIT funding request.

  ## Options
  - `:amount`   — Override the approved amount (partial approval). Defaults to request amount.
  - `:memo`     — Optional memo string (max 99 chars).
  - `:metadata` — Optional map of metadata (max 20 keys).
  - `:tags`     — Optional tags string.
  """
  @spec approve(map(), keyword()) :: map()
  def approve(request, opts \\ []) do
    jit = request["jit_funding"]
    amount = Keyword.get(opts, :amount, jit["amount"])
    memo = Keyword.get(opts, :memo)
    meta = Keyword.get(opts, :metadata, %{})
    tags = Keyword.get(opts, :tags, jit["tags"])

    base = %{
      "jit_funding" => %{
        "token" => jit["token"],
        "method" => jit["method"],
        "user_token" => jit["user_token"],
        "acting_user_token" => jit["acting_user_token"],
        "amount" => amount,
        "tags" => tags
      }
    }

    base
    |> maybe_put_in(["jit_funding", "memo"], memo)
    |> maybe_put_in(["jit_funding", "metadata"], if(map_size(meta) > 0, do: meta, else: nil))
  end

  @doc """
  Builds a decline response for a JIT funding request.

  ## Decline Reasons
  #{Enum.map_join(@decline_reasons, "\n", &"  - `\"#{&1}\"`")}

  ## Options
  - `:reason` — Decline reason string. Defaults to `"DO_NOT_HONOR"`.
  - `:memo`   — Optional memo.
  """
  @spec decline(map(), keyword()) :: map()
  def decline(request, opts \\ []) do
    jit = request["jit_funding"]
    reason = Keyword.get(opts, :reason, "DO_NOT_HONOR")
    memo = Keyword.get(opts, :memo)

    base = %{
      "jit_funding" => %{
        "token" => jit["token"],
        "method" => jit["method"],
        "user_token" => jit["user_token"],
        "acting_user_token" => jit["acting_user_token"],
        "amount" => 0,
        "decline_reason" => reason
      }
    }

    maybe_put_in(base, ["jit_funding", "memo"], memo)
  end

  @doc """
  Builds an acknowledgement response for informative JIT notifications.
  Use this when `actionable?/1` returns `false`.
  """
  @spec ack(map()) :: map()
  def ack(request) do
    jit = request["jit_funding"]

    %{
      "jit_funding" => %{
        "token" => jit["token"],
        "method" => jit["method"]
      }
    }
  end

  # Kept as aliases for backward compat with earlier generated code
  defdelegate approve_response(request, opts \\ []), to: __MODULE__, as: :approve
  defdelegate decline_response(request, opts \\ []), to: __MODULE__, as: :decline

  # ---------------------------------------------------------------------------
  # Inspectors
  # ---------------------------------------------------------------------------

  @doc "Returns `true` if the JIT request requires a funding decision response."
  @spec actionable?(map()) :: boolean()
  def actionable?(%{"jit_funding" => %{"method" => method}}),
    do: method in @actionable_methods

  def actionable?(_), do: false

  @doc "Returns the JIT method string."
  @spec method(map()) :: String.t() | nil
  def method(%{"jit_funding" => %{"method" => m}}), do: m
  def method(_), do: nil

  @doc "Returns the requested funding amount."
  @spec amount(map()) :: number() | nil
  def amount(%{"jit_funding" => %{"amount" => a}}), do: a
  def amount(_), do: nil

  @doc "Returns the user token from a JIT request."
  @spec user_token(map()) :: String.t() | nil
  def user_token(%{"jit_funding" => %{"user_token" => t}}), do: t
  def user_token(_), do: nil

  @doc "Returns the acting user token (may differ from user_token in hierarchical accounts)."
  @spec acting_user_token(map()) :: String.t() | nil
  def acting_user_token(%{"jit_funding" => %{"acting_user_token" => t}}), do: t
  def acting_user_token(_), do: nil

  @doc "Returns the merchant name from a JIT request."
  @spec merchant_name(map()) :: String.t() | nil
  def merchant_name(%{"card_acceptor" => %{"name" => n}}), do: n
  def merchant_name(_), do: nil

  @doc "Returns the MCC code from a JIT request."
  @spec mcc(map()) :: String.t() | nil
  def mcc(%{"card_acceptor" => %{"mcc" => m}}), do: m
  def mcc(_), do: nil

  @doc "Returns the merchant country from a JIT request."
  @spec country(map()) :: String.t() | nil
  def country(%{"card_acceptor" => %{"country" => c}}), do: c
  def country(_), do: nil

  @doc "Returns the currency code from a JIT request."
  @spec currency(map()) :: String.t() | nil
  def currency(%{"currency_code" => c}), do: c
  def currency(_), do: nil

  @doc "Returns the transaction type (e.g. `\"gpa.credit\"`)."
  @spec transaction_type(map()) :: String.t() | nil
  def transaction_type(%{"type" => t}), do: t
  def transaction_type(_), do: nil

  @doc "Returns the card token from a JIT request."
  @spec card_token(map()) :: String.t() | nil
  def card_token(%{"card" => %{"token" => t}}), do: t
  def card_token(_), do: nil

  @doc "Returns `true` if this is a zero-dollar account verification."
  @spec account_verification?(map()) :: boolean()
  def account_verification?(request),
    do: method(request) == "pgfs.authorization.account_verification"

  @doc "Returns `true` if this is an ATM / single-message transaction."
  @spec auth_plus_capture?(map()) :: boolean()
  def auth_plus_capture?(request),
    do: method(request) == "pgfs.auth_plus_capture"

  @doc "List of all valid decline reasons."
  @spec decline_reasons() :: [String.t()]
  def decline_reasons, do: @decline_reasons

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp maybe_put_in(map, _keys, nil), do: map
  defp maybe_put_in(map, keys, value), do: put_in(map, keys, value)
end

defmodule Marqeta.Simulations do
  @moduledoc """
  Simulate card transactions in the sandbox environment.

  **Sandbox only** — these endpoints are not available in production.

  ## Examples

      # Simulate an authorization
      {:ok, auth} = Marqeta.Simulations.authorization(%{
        card_token: "card_01",
        amount: 42.50,
        mid: "merchant_01",
        card_acceptor: %{
          name: "Coffee Shop",
          mcc: "5812",
          city: "San Francisco",
          state: "CA",
          country: "USA"
        }
      })

      # Settle it
      {:ok, _} = Marqeta.Simulations.clearing(%{
        original_transaction_token: auth["token"],
        amount: 42.50
      })

      # Or do it in one step
      {:ok, txn} = Marqeta.Simulations.purchase(%{
        card_token: "card_01",
        amount: 100.00
      })

      # Simulate a refund
      {:ok, _} = Marqeta.Simulations.refund(%{
        card_token: "card_01",
        amount: 15.00,
        mid: "merchant_01"
      })

      # ATM withdrawal
      {:ok, _} = Marqeta.Simulations.atm_withdrawal(%{
        card_token: "card_01",
        amount: 200.00
      })

      # Simulations 2.0 (card transactions)
      {:ok, _} = Marqeta.Simulations.card_transaction(%{
        card_token: "card_01",
        amount: 50.00,
        type: "AUTHORIZATION"
      })
  """

  alias Marqeta.Client

  @doc "Simulates a card authorization."
  @spec authorization(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def authorization(params, opts \\ []) do
    Client.post("/simulate/authorization", params, opts)
  end

  @doc "Simulates clearing (capture/settlement) for an existing authorization."
  @spec clearing(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def clearing(params, opts \\ []) do
    Client.post("/simulate/clearing", params, opts)
  end

  @doc "Simulates a full purchase: authorization + clearing in one step."
  @spec purchase(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def purchase(params, opts \\ []) do
    Client.post("/simulate/financial", params, opts)
  end

  @doc "Simulates a reversal (void) of an authorization."
  @spec reversal(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def reversal(params, opts \\ []) do
    Client.post("/simulate/reversal", params, opts)
  end

  @doc "Simulates a refund (credit) on a card."
  @spec refund(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def refund(params, opts \\ []) do
    Client.post("/simulate/clearingrefund", params, opts)
  end

  @doc "Simulates an ATM withdrawal (auth_plus_capture)."
  @spec atm_withdrawal(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def atm_withdrawal(params, opts \\ []) do
    Client.post("/simulate/atm_withdrawal", params, opts)
  end

  @doc "Simulates a PIN debit transaction."
  @spec pin_debit(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def pin_debit(params, opts \\ []) do
    Client.post("/simulate/pindebit", params, opts)
  end

  @doc "Simulates a direct deposit (ACH inbound) transaction."
  @spec direct_deposit(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def direct_deposit(params, opts \\ []) do
    Client.post("/simulate/directdeposit", params, opts)
  end

  @doc "Simulates a balance inquiry."
  @spec balance_inquiry(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def balance_inquiry(params, opts \\ []) do
    Client.post("/simulate/balanceinquiry", params, opts)
  end

  @doc "Simulations 2.0 — card transaction (supports more transaction types)."
  @spec card_transaction(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def card_transaction(params, opts \\ []) do
    Client.post("/simulations/cardtransactions", params, opts)
  end

  @doc "Simulations 2.0 — direct deposit."
  @spec card_direct_deposit(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def card_direct_deposit(params, opts \\ []) do
    Client.post("/simulations/directdeposits", params, opts)
  end
end

defmodule Marqeta.Sandbox do
  @moduledoc """
  Sandbox bootstrapping helpers for development and testing.

  `bootstrap/2` creates a complete, ready-to-use sandbox setup:
  a user + card product + active virtual card + funded GPA.

  ## Examples

      {:ok, setup} = Marqeta.Sandbox.bootstrap(%{
        first_name: "Alice",
        last_name: "Smith"
      }, funding_source_token: "program_fs_01", amount: 500.00)

      # setup.user, setup.card_product, setup.card, setup.gpa_order
      {:ok, auth} = Marqeta.Simulations.authorization(%{
        card_token: setup.card["token"],
        amount: 25.00,
        mid: "merchant_01"
      })
  """

  alias Marqeta.{CardProducts, Cards, GPAOrders, Simulations, Users}

  @type bootstrap_result :: %{
          user: map(),
          card_product: map(),
          card: map(),
          gpa_order: map()
        }

  @doc """
  Bootstraps a complete sandbox setup.

  ## Required Options
  - `:funding_source_token` — your program funding source token

  ## Optional Options
  - `:amount`    — initial GPA load amount (default: `100.00`)
  - `:currency`  — currency code (default: `"USD"`)
  - `:card_product_config` — override card product config

  ## Returns
  `{:ok, %{user, card_product, card, gpa_order}}` or `{:error, %Marqeta.Error{}}`.
  """
  @spec bootstrap(map(), keyword()) :: {:ok, bootstrap_result()} | {:error, Marqeta.Error.t()}
  def bootstrap(user_params \\ %{}, opts \\ []) do
    amount = Keyword.get(opts, :amount, 100.00)
    currency = Keyword.get(opts, :currency, "USD")
    fs_token = Keyword.fetch!(opts, :funding_source_token)
    cp_config = Keyword.get(opts, :card_product_config, %{})

    user_params_built = build_user(user_params)
    cp_params_built = build_card_product(fs_token, cp_config)

    with {:ok, user} <- Users.create(user_params_built),
         {:ok, cp} <- CardProducts.create(cp_params_built),
         {:ok, card} <-
           Cards.create(%{card_product_token: cp["token"], user_token: user["token"]}),
         {:ok, order} <-
           GPAOrders.create(%{
             amount: amount,
             currency_code: currency,
             funding_source_token: fs_token,
             user_token: user["token"]
           }) do
      {:ok, %{card: card, card_product: cp, gpa_order: order, user: user}}
    end
  end

  @doc """
  Runs a full purchase simulation on a bootstrapped setup.

  ## Returns
  `{:ok, %{authorization, clearing}}` or `{:error, error}`.
  """
  @spec simulate_purchase(String.t(), number(), map()) ::
          {:ok, %{authorization: map(), clearing: map()}} | {:error, Marqeta.Error.t()}
  def simulate_purchase(card_token, amount, merchant \\ %{}) do
    merchant_defaults = %{
      "name" => "Sandbox Merchant",
      "mcc" => "5999",
      "city" => "San Francisco",
      "state" => "CA",
      "country" => "USA"
    }

    with {:ok, auth} <-
           Simulations.authorization(%{
             card_token: card_token,
             amount: amount,
             mid: "sandbox_merchant",
             card_acceptor: Map.merge(merchant_defaults, merchant)
           }),
         {:ok, clear} <-
           Simulations.clearing(%{
             original_transaction_token: auth["token"],
             amount: amount
           }) do
      {:ok, %{authorization: auth, clearing: clear}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private builders
  # ---------------------------------------------------------------------------

  defp build_user(overrides) do
    n = :rand.uniform(99_999)

    Map.merge(
      %{
        first_name: "Test",
        last_name: "User#{n}",
        email: "testuser#{n}@marqeta-sandbox.example.com",
        phone: "555#{String.pad_leading("#{n}", 7, "0")}",
        address1: "1 Test Street",
        city: "San Francisco",
        state: "CA",
        postal_code: "94105",
        country: "USA",
        birth_date: "1990-01-01",
        identifications: [%{type: "SSN", value: "123456789"}]
      },
      overrides
    )
  end

  defp build_card_product(fs_token, overrides) do
    n = :rand.uniform(99_999)

    base = %{
      name: "Sandbox Card Product #{n}",
      start_date: Date.to_string(Date.utc_today()),
      config: %{
        card_life_cycle: %{activate_upon_issue: true},
        fulfillment: %{payment_instrument: "VIRTUAL_PAN"},
        jit_funding: %{
          program_funding_source: %{
            funding_source_token: fs_token,
            enabled: true
          }
        }
      }
    }

    deep_merge(base, overrides)
  end

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _k, l, r -> deep_merge(l, r) end)
  end

  defp deep_merge(_left, right), do: right
end
