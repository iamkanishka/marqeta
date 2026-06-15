# Getting Started

## Installation

Add `:marqeta` to your `mix.exs`:

```elixir
def deps do
  [
    {:marqeta, "~> 0.1"}
  ]
end
```

Then run:

```shell
mix deps.get
```

---

## Configuration

### Sandbox

```elixir
# config/config.exs
config :marqeta,
  base_url: "https://sandbox-api.marqeta.com/v3",
  application_token: System.fetch_env!("MARQETA_APP_TOKEN"),
  admin_access_token: System.fetch_env!("MARQETA_ADMIN_TOKEN"),
  sandbox: true
```

### Production

Production programs get a unique subdomain:

```elixir
# config/runtime.exs
config :marqeta,
  base_url: System.fetch_env!("MARQETA_BASE_URL"),  # e.g. https://myprog-api.marqeta.com/v3
  application_token: System.fetch_env!("MARQETA_APP_TOKEN"),
  admin_access_token: System.fetch_env!("MARQETA_ADMIN_TOKEN"),
  pool_size: 25,
  sandbox: false
```

---

## Your First Transaction

Below is a complete end-to-end flow in the sandbox:

```elixir
# 1. Create a cardholder
{:ok, user} = Marqeta.Users.create(%{
  first_name: "Alice",
  last_name: "Smith",
  email: "alice@example.com",
  address1: "1 Market St",
  city: "San Francisco",
  state: "CA",
  postal_code: "94105",
  country: "USA",
  birth_date: "1985-06-20",
  identifications: [%{type: "SSN", value: "987654321"}]
})

# 2. Verify identity (KYC)
{:ok, kyc} = Marqeta.KYCVerification.perform(%{user_token: user["token"]})
IO.puts("KYC status: #{kyc["result"]["status"]}")

# 3. Create a card product
{:ok, cp} = Marqeta.CardProducts.create(%{
  name: "My Prepaid Card",
  start_date: "2024-01-01",
  config: %{
    card_life_cycle: %{activate_upon_issue: true},
    fulfillment: %{payment_instrument: "VIRTUAL_PAN"},
    jit_funding: %{
      program_funding_source: %{
        funding_source_token: System.fetch_env!("MARQETA_PROGRAM_FUNDING_TOKEN"),
        enabled: true
      }
    }
  }
})

# 4. Issue a virtual card
{:ok, card} = Marqeta.Cards.create(%{
  user_token: user["token"],
  card_product_token: cp["token"]
})

# 5. Fund the user
{:ok, _order} = Marqeta.GPAOrders.create(%{
  user_token: user["token"],
  amount: 500.00,
  currency_code: "USD",
  funding_source_token: System.fetch_env!("MARQETA_PROGRAM_FUNDING_TOKEN")
})

# 6. Simulate a purchase (sandbox only)
{:ok, auth} = Marqeta.Simulations.authorization(%{
  card_token: card["token"],
  amount: 49.99,
  mid: "test_merchant_01"
})

IO.puts("Authorization: #{auth["state"]}")  # => "PENDING"

{:ok, _} = Marqeta.Simulations.clearing(%{
  original_transaction_token: auth["token"],
  amount: 49.99
})

# 7. Check balance
{:ok, balance} = Marqeta.Users.balances(user["token"])
IO.puts("Remaining: $#{balance["gpa"]["available_balance"]}")  # => "$450.01"
```

---

## Setting Up Webhooks

```elixir
# Create a webhook endpoint
{:ok, webhook} = Marqeta.Webhooks.create(%{
  name: "production",
  active: true,
  events: ["transaction.*", "cardtransition.*", "usertransition.*"],
  config: %{
    url: "https://yourapp.com/webhooks/marqeta",
    secret: System.fetch_env!("MARQETA_WEBHOOK_SECRET"),
    signature_algorithm: "HMAC_SHA_256"
  }
})

# Verify it works
{:ok, _} = Marqeta.Webhooks.ping(webhook["token"])
```

In your webhook handler (Phoenix example):

```elixir
defmodule MyAppWeb.MarqetaController do
  use MyAppWeb, :controller

  def handle(conn, _params) do
    sig    = get_req_header(conn, "x-marqeta-signature") |> List.first("")
    body   = conn.assigns[:raw_body]
    secret = Application.fetch_env!(:my_app, :marqeta_webhook_secret)

    with true <- Marqeta.Webhooks.valid_signature?(body, sig, secret),
         {:ok, event} <- Marqeta.Webhooks.parse_event(body) do
      handle_event(event["type"], event)
      send_resp(conn, 200, "ok")
    else
      _ -> send_resp(conn, 401, "unauthorized")
    end
  end

  defp handle_event("transaction." <> _state, event) do
    MyApp.TransactionWorker.enqueue(event)
  end

  defp handle_event("cardtransition." <> _state, event) do
    MyApp.CardWorker.process(event)
  end

  defp handle_event(_type, _event), do: :ok
end
```

---

## Testing Your Integration

```elixir
defmodule MyApp.MarqetaFlowTest do
  use ExUnit.Case, async: true
  use Marqeta.Test.BypassHelper

  setup do
    bypass = Bypass.open()
    configure_marqeta(bypass)
    {:ok, bypass: bypass}
  end

  test "full card issuance flow", %{bypass: bypass} do
    user = build(:user)
    cp   = build(:card_product)
    card = build(:card, "user_token" => user["token"])

    expect_post(bypass, "/users", user, 201)
    expect_post(bypass, "/cardproducts", cp, 201)
    expect_post(bypass, "/cards", card, 201)

    assert {:ok, u} = Marqeta.Users.create(%{first_name: "Test"})
    assert {:ok, p} = Marqeta.CardProducts.create(%{name: "Test Product"})
    assert {:ok, c} = Marqeta.Cards.create(%{
      user_token: u["token"],
      card_product_token: p["token"]
    })

    assert c["state"] == "ACTIVE"
    assert c["instrument_type"] == "VIRTUAL_PAN"
  end
end
```
