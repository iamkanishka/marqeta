# Marqeta

[![Hex.pm](https://img.shields.io/hexpm/v/marqeta.svg)](https://hex.pm/packages/marqeta)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/marqeta/)
[![CI](https://github.com/iamkanishka/marqeta/actions/workflows/ci.yml/badge.svg)](https://github.com/iamkanishka/marqeta/actions)
[![Coverage Status](https://coveralls.io/repos/github/yourorg/marqeta/badge.svg)](https://coveralls.io/github/yourorg/marqeta)

Production-grade Elixir client for the **Marqeta Core, Credit, and DiVA APIs**.

Full coverage of all 120 Marqeta API surfaces with:

- ✅ Typed errors with retryability flags
- ✅ Automatic retry with exponential backoff + jitter
- ✅ Lazy streaming for all paginated endpoints
- ✅ HTTP/2 connection pooling via Finch
- ✅ Telemetry events for all HTTP calls
- ✅ Token-bucket rate limiting
- ✅ Webhook signature verification
- ✅ Gateway JIT Funding request/response helpers
- ✅ Comprehensive test factory and Bypass helpers
- ✅ Dialyzer + Credo + ExCoveralls

---

## Installation

```elixir
def deps do
  [
    {:marqeta, "~> 1.0"}
  ]
end
```

---

## Configuration

```elixir
# config/config.exs
config :marqeta,
  base_url: "https://sandbox-api.marqeta.com/v3",
  application_token: System.fetch_env!("MARQETA_APP_TOKEN"),
  admin_access_token: System.fetch_env!("MARQETA_ADMIN_TOKEN"),
  pool_size: 10,
  timeout: 30_000,
  retry_max_attempts: 3,
  retry_base_delay: 500,
  retry_jitter: true,
  sandbox: true

# config/prod.exs
config :marqeta,
  base_url: "https://yourprogram-api.marqeta.com/v3",
  sandbox: false,
  pool_size: 25
```

---

## Quick Start

### Create a Cardholder

```elixir
{:ok, user} = Marqeta.Users.create(%{
  first_name: "Jane",
  last_name: "Doe",
  email: "jane@example.com",
  phone: "5555551234",
  address1: "123 Main St",
  city: "San Francisco",
  state: "CA",
  postal_code: "94105",
  country: "USA",
  birth_date: "1990-01-15",
  identifications: [%{type: "SSN", value: "123456789"}]
})
```

### Run KYC

```elixir
{:ok, result} = Marqeta.KYCVerification.perform(%{user_token: user["token"]})
IO.inspect(result["result"]["status"])  # => "success"
```

### Issue a Virtual Card

```elixir
{:ok, card_product} = Marqeta.CardProducts.create(%{
  name: "My Card Product",
  start_date: "2024-01-01",
  config: %{
    card_life_cycle: %{activate_upon_issue: true},
    fulfillment: %{payment_instrument: "VIRTUAL_PAN"},
    jit_funding: %{
      program_funding_source: %{
        funding_source_token: "my_program_funding_source",
        enabled: true
      }
    }
  }
})

{:ok, card} = Marqeta.Cards.create(%{
  user_token: user["token"],
  card_product_token: card_product["token"]
})
```

### Fund a User's GPA

```elixir
{:ok, order} = Marqeta.GPAOrders.create(%{
  user_token: user["token"],
  amount: 250.00,
  currency_code: "USD",
  funding_source_token: "my_funding_source"
})
```

### Set Spend Limits

```elixir
# $500/day limit for a specific user
{:ok, _} = Marqeta.VelocityControls.create(%{
  association: %{user_token: user["token"]},
  currency_code: "USD",
  amount_limit: 500.00,
  velocity_window: "DAY",
  include_purchases: true,
  include_withdrawals: true,
  active: true
})
```

### Check Balance

```elixir
{:ok, balance} = Marqeta.Users.balances(user["token"])
IO.inspect(balance["gpa"]["available_balance"])
```

---

## Pagination & Streaming

All list endpoints return paginated responses. Use the `stream` helpers for
automatic multi-page iteration:

```elixir
# Stream ALL users across all pages
Marqeta.Users.stream(%{count: 100})
|> Stream.filter(& &1["status"] == "ACTIVE")
|> Stream.map(& &1["email"])
|> Enum.to_list()

# Stream all transactions for a card, filter clearings
Marqeta.Cards.stream_transactions("card_token", %{count: 50})
|> Stream.filter(& &1["state"] == "COMPLETION")
|> Enum.count()

# Manual pagination
{:ok, page1} = Marqeta.Transactions.list(%{count: 25, start_index: 0})
{:ok, page2} = Marqeta.Transactions.list(%{count: 25, start_index: 25})
```

---

## Error Handling

All functions return `{:ok, result}` or `{:error, %Marqeta.Error{}}`.

```elixir
case Marqeta.Users.create(params) do
  {:ok, user} ->
    process_user(user)

  {:error, %Marqeta.Error{type: :validation_error, field_errors: errors}} ->
    Enum.each(errors, fn e ->
      IO.puts("#{e.field}: #{e.message}")
    end)

  {:error, %Marqeta.Error{type: :rate_limit_error, retryable?: true}} ->
    # Built-in retry handles this automatically
    :ok

  {:error, %Marqeta.Error{type: :authentication_error}} ->
    Logger.error("Check your Marqeta credentials")

  {:error, %Marqeta.Error{} = err} ->
    Logger.error("Marqeta error: #{Exception.message(err)}",
      request_id: err.request_id,
      error_code: err.error_code
    )
end
```

### Bang Variants

Every function has a `!` variant that returns the result directly or raises:

```elixir
user = Marqeta.Users.create!(%{first_name: "Jane", ...})
card = Marqeta.Cards.create!(%{user_token: user["token"], ...})
```

---

## Webhooks

### Registration

```elixir
{:ok, webhook} = Marqeta.Webhooks.create(%{
  name: "my-webhook",
  active: true,
  events: ["transaction.*", "cardtransition.*"],
  config: %{
    url: "https://api.myapp.com/webhooks/marqeta",
    secret: "MyHmacSecret@123456789",
    signature_algorithm: "HMAC_SHA_256"
  }
})

# Test it
{:ok, _} = Marqeta.Webhooks.ping(webhook["token"])
```

### Signature Verification (Phoenix example)

```elixir
defmodule MyAppWeb.MarqetaController do
  use MyAppWeb, :controller

  def handle(conn, _params) do
    signature = get_req_header(conn, "x-marqeta-signature") |> List.first("")
    raw_body  = conn.assigns[:raw_body]
    secret    = Application.fetch_env!(:my_app, :marqeta_webhook_secret)

    if Marqeta.Webhooks.valid_signature?(raw_body, signature, secret) do
      process_event(conn.body_params)
      send_resp(conn, 200, "ok")
    else
      send_resp(conn, 401, "invalid signature")
    end
  end
end
```

---

## Gateway JIT Funding

```elixir
defmodule MyAppWeb.JITController do
  use MyAppWeb, :controller

  alias Marqeta.GatewayJIT

  def handle(conn, params) do
    response =
      if GatewayJIT.actionable?(params) do
        user_token = GatewayJIT.user_token(params)
        amount     = GatewayJIT.amount(params)

        case check_user_balance(user_token, amount) do
          :ok      -> GatewayJIT.approve_response(params)
          :decline -> GatewayJIT.decline_response(params, reason: "INSUFFICIENT_FUNDS")
        end
      else
        # Informative notification - no response needed
        GatewayJIT.approve_response(params)
      end

    json(conn, response)
  end
end
```

---

## Credit Platform

```elixir
# Full credit account creation flow

# 1. Create a credit product
{:ok, product} = Marqeta.Credit.Products.create(%{
  name: "Signature Rewards Card",
  # ... policies
})

# 2. Create a bundle
{:ok, bundle} = Marqeta.Credit.Bundles.create(%{
  name: "Rewards Bundle",
  credit_product_token: product["token"]
})

# 3. Create an account
{:ok, account} = Marqeta.Credit.Accounts.create(%{
  user_token: user["token"],
  bundle_token: bundle["token"],
  credit_limit: 5_000.00,
  config: %{
    billing_cycle_day: 1,
    payment_due_interval: 25,
    e_disclosure_active: true
  }
})

# 4. Issue a card
{:ok, card} = Marqeta.Credit.Cards.create(account["token"], %{
  user_token: user["token"]
})

# 5. Make a payment
{:ok, payment} = Marqeta.Credit.Payments.create(account["token"], %{
  amount: 150.00,
  payment_source_token: "source_01"
})

# 6. List journal entries
Marqeta.Credit.JournalEntries.stream(account["token"], %{count: 100})
|> Enum.to_list()
```

---

## DiVA (Analytics & Reporting)

```elixir
# Get all settlements for January
{:ok, page} = Marqeta.DiVA.Settlements.list(%{
  start_date: "2024-01-01",
  end_date: "2024-01-31",
  count: 500
})

# Stream all authorizations for a month
Marqeta.DiVA.Authorizations.stream(%{
  start_date: "2024-01-01",
  end_date: "2024-01-31"
})
|> Stream.filter(& &1["state"] == "DECLINED")
|> Enum.count()

# Platform response time report
{:ok, perf} = Marqeta.DiVA.PlatformResponse.list(%{
  start_date: "2024-01-01",
  count: 31
})

# List all available views
{:ok, views} = Marqeta.DiVA.Views.list()

# Data dictionary for authorizations
{:ok, dict} = Marqeta.DiVA.DataDictionary.get("authorizations")
```

---

## Simulations (Sandbox)

```elixir
# Simulate a purchase
{:ok, auth} = Marqeta.Simulations.authorization(%{
  card_token: card["token"],
  amount: 42.50,
  mid: "merchant_01",
  card_acceptor: %{
    name: "Coffee Shop",
    mcc: "5812",
    city: "San Francisco"
  }
})

# Settle it
{:ok, _} = Marqeta.Simulations.clearing(%{
  original_transaction_token: auth["token"],
  amount: 42.50
})

# Quick full purchase
{:ok, txn} = Marqeta.Simulations.purchase(%{
  card_token: card["token"],
  amount: 100.00
})

# ATM withdrawal
{:ok, _} = Marqeta.Simulations.atm_withdrawal(%{
  card_token: card["token"],
  amount: 200.00
})
```

---

## Telemetry

```elixir
# Attach a custom handler
:telemetry.attach(
  "my-marqeta-metrics",
  [:marqeta, :request, :stop],
  fn _event, measurements, metadata, _config ->
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    MyMetrics.record("marqeta.request.duration", duration_ms,
      tags: ["method:#{metadata.method}", "status:#{metadata.status}"]
    )
  end,
  nil
)

# Or use the built-in metrics for Phoenix LiveDashboard / PromEx
Marqeta.Telemetry.metrics()
```

---

## Testing

```elixir
# In your test module
use Marqeta.Test.BypassHelper

setup do
  bypass = Bypass.open()
  configure_marqeta(bypass)
  {:ok, bypass: bypass}
end

test "creates a user", %{bypass: bypass} do
  user = build(:user)
  expect_post(bypass, "/users", user, 201)

  assert {:ok, result} = Marqeta.Users.create(%{first_name: "Jane"})
  assert result["token"] == user["token"]
end

test "handles validation error", %{bypass: bypass} do
  expect_error(bypass, "POST", "/users", %{
    "error_code" => "400040",
    "error_message" => "Email is invalid"
  }, 400)

  assert {:error, err} = Marqeta.Users.create(%{email: "bad"})
  assert err.type == :validation_error
end
```

---

## API Coverage

| Category        | Modules                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Core Users      | Users, UserTransitions, Businesses, BusinessTransitions, AccountHolderGroups                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Cards           | Cards, CardProducts, CardTransitions, BulkCardOrders, PINs                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| Funding         | GPAOrders, ProgramFundingSources, ProgramGatewayFundingSources, AccountHolderFundingSources, IntraAccountTransfers, ProgramTransfers, ProgramReserve, FundingViaACH, InstantFunding, AutoReload, ACHReceiving                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Spend Controls  | VelocityControls, AuthorizationControls, MCCGroups, MerchantGroups, AcceptedCountries                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| Compliance      | KYCVerification, FraudFeedback, ThreeDSecure                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Disputes        | DisputesVisa, DisputesMastercard, DisputesPulse, DisputesEvidenceCollection                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Fees            | Fees, FeeCharges, FeeRefunds                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Digital Wallets | DigitalWalletsManagement, TokenizationAsAService                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| Platform        | Webhooks, GatewayJIT, CommandomMode, SelfServiceCredentials, Simulations, Sandbox                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Credit (25)     | Accounts, Cards, Applications, Bundles, Products, Policies, Payments, PaymentSchedules, PaymentSources, JournalEntries, LedgerEntries, Statements, Disputes, Adjustments, Rewards, RewardAccounts, RewardRedemptions, RewardRules, RewardConversions, RewardGlobalConfigurations, Delinquency, Transitions, Substatuses, Refunds, BalanceRefunds                                                                                                                                                                                                                                                                                        |
| DiVA (35)       | Authorizations, Settlements, Declines, Loads, Chargebacks, CardCounts, UserCounts, ActivityBalances, ActivityBalancesFundingDay, ActivityBalancesNetworkDetail, ClearingDetail, Cards, Users, DirectDeposit, ACHGateway, ACHOrigination, ACHPending, ACHVerification, PlatformResponse, ProgramBalancesSettlement, ProgramFundingBalances, RTDAuthorizations, RTDTransactionCountByRules, CoreAPITransactionToken, CreditAccounts, CreditCards, CreditAccountDailyBalances, CreditJournalEntries, CreditLedgerEntries, CreditPayments, CreditDisputes, CreditRewards, CreditStatements, CreditAccountAdjustments, Views, DataDictionary |

**Total: 120 API surfaces across Core, Credit, and DiVA.**

---

## License

MIT License. See [LICENSE](LICENSE) for details.
