defmodule Marqeta.UsersTest do
  use ExUnit.Case, async: true
  import Marqeta.Test.Factory
  import Marqeta.Test.BypassHelper

  setup do
    bypass = Bypass.open()
    configure_marqeta(bypass)
    {:ok, bypass: bypass}
  end

  describe "create/2" do
    test "returns {:ok, user} on success", %{bypass: bypass} do
      user = build(:user)
      expect_post(bypass, "/users", user)

      assert {:ok, returned} =
               Marqeta.Users.create(%{
                 first_name: "Jane",
                 last_name: "Doe",
                 email: "jane@example.com"
               })

      assert returned["token"] == user["token"]
      assert returned["status"] == "ACTIVE"
    end

    test "returns {:error, validation_error} on 400", %{bypass: bypass} do
      err =
        build(:error_response, %{
          "error_code" => "400040",
          "error_message" => "Email must be valid",
          "errors" => [
            %{
              "field" => "email",
              "message" => "Invalid format"
            }
          ]
        })

      expect_error(bypass, "POST", "/users", err, 400)

      assert {:error, error} = Marqeta.Users.create(%{email: "bad"})

      assert error.type == :validation_error
      assert error.http_status == 400
      assert error.error_code == "400040"
      assert error.message == "Email must be valid"
      assert [%{field: "email"}] = error.field_errors
    end

    test "returns {:error, authentication_error} on 401", %{bypass: bypass} do
      expect_error(bypass, "POST", "/users", %{"error_message" => "Unauthorized"}, 401)

      assert {:error, err} = Marqeta.Users.create(%{})
      assert err.type == :authentication_error
      assert err.http_status == 401
      assert err.retryable? == false
    end

    test "returns {:error, server_error} on 500 and marks retryable", %{bypass: bypass} do
      expect_error(bypass, "POST", "/users", %{"error_message" => "Internal error"}, 500)

      assert {:error, err} = Marqeta.Users.create(%{})
      assert err.type == :server_error
      assert err.retryable? == true
    end
  end

  describe "get/2" do
    test "retrieves a user by token", %{bypass: bypass} do
      user = build(:user)
      expect_get(bypass, "/users/#{user["token"]}", user)

      assert {:ok, returned} = Marqeta.Users.get(user["token"])
      assert returned["token"] == user["token"]
      assert returned["email"] == user["email"]
    end

    test "returns {:error, not_found} for unknown token", %{bypass: bypass} do
      expect_error(bypass, "GET", "/users/nonexistent", %{"error_message" => "Not found"}, 404)

      assert {:error, err} = Marqeta.Users.get("nonexistent")
      assert err.type == :not_found
      assert err.http_status == 404
    end
  end

  describe "update/3" do
    test "updates a user and returns updated resource", %{bypass: bypass} do
      user = build(:user, %{phone: "5551234567"})

      expect_put(bypass, "/users/#{user["token"]}", user)

      assert {:ok, returned} =
               Marqeta.Users.update(user["token"], %{phone: "5551234567"})

      assert returned["phone"] == "5551234567"
    end

    test "returns {:error, conflict} on 409", %{bypass: bypass} do
      user = build(:user)

      expect_error(
        bypass,
        "PUT",
        "/users/#{user["token"]}",
        %{"error_message" => "Conflict"},
        409
      )

      assert {:error, err} = Marqeta.Users.update(user["token"], %{})
      assert err.type == :conflict_error
    end
  end

  describe "list/2" do
    test "returns paginated response", %{bypass: bypass} do
      users = build_list(:user, 5)
      expect_list(bypass, "/users", users)

      assert {:ok, page} = Marqeta.Users.list(%{count: 5})
      assert page["count"] == 5
      assert length(page["data"]) == 5
    end

    test "returns empty list", %{bypass: bypass} do
      expect_list(bypass, "/users", [])

      assert {:ok, page} = Marqeta.Users.list()
      assert page["data"] == []
      assert page["count"] == 0
    end

    test "respects pagination params", %{bypass: bypass} do
      users = build_list(:user, 3)
      expect_list(bypass, "/users", users, start_index: 10, is_more: false)

      assert {:ok, page} = Marqeta.Users.list(%{count: 3, start_index: 10})
      assert page["start_index"] == 10
    end
  end

  describe "list_cards/3" do
    test "lists cards for a user", %{bypass: bypass} do
      user = build(:user)

      cards =
        build_list(:card, 3, %{
          "user_token" => user["token"]
        })

      expect_list(bypass, "/cards/user/#{user["token"]}", cards)

      assert {:ok, page} = Marqeta.Users.list_cards(user["token"])
      assert length(page["data"]) == 3
    end
  end

  describe "balances/2" do
    test "returns GPA balance for a user", %{bypass: bypass} do
      token = "user_abc123"

      balance_resp = %{
        "token" => token,
        "gpa" => %{
          "currency_code" => "USD",
          "ledger_balance" => 100.00,
          "available_balance" => 95.50,
          "credit_balance" => 0,
          "pending_credits" => 0
        }
      }

      expect_get(bypass, "/balances/#{token}", balance_resp)

      assert {:ok, bal} = Marqeta.Users.balances(token)
      assert bal["gpa"]["available_balance"] == 95.50
    end
  end

  describe "transactions/3" do
    test "lists transactions for a user", %{bypass: bypass} do
      user = build(:user)

      txns =
        build_list(:transaction, 3, %{
          "user_token" => user["token"]
        })

      expect_list(bypass, "/transactions/user/#{user["token"]}", txns)

      assert {:ok, page} = Marqeta.Users.transactions(user["token"])
      assert length(page["data"]) == 3
    end
  end

  describe "search/2" do
    test "searches for users by email", %{bypass: bypass} do
      users = build_list(:user, 1)
      expect_post(bypass, "/users/lookup", paginated(:user, 1))

      assert {:ok, page} = Marqeta.Users.search(%{email: "jane@example.com"})
      assert is_map(page)
    end
  end

  describe "bang variants" do
    test "create!/2 returns map on success", %{bypass: bypass} do
      user = build(:user)
      expect_post(bypass, "/users", user)

      result = Marqeta.Users.create!(%{first_name: "Jane"})
      assert result["token"] == user["token"]
    end

    test "create!/2 raises Marqeta.Error on failure", %{bypass: bypass} do
      expect_error(bypass, "POST", "/users", %{"error_message" => "Bad request"}, 400)

      assert_raise Marqeta.Error, fn ->
        Marqeta.Users.create!(%{})
      end
    end

    test "get!/2 raises Marqeta.Error on 404", %{bypass: bypass} do
      expect_error(bypass, "GET", "/users/missing", %{"error_message" => "Not found"}, 404)

      assert_raise Marqeta.Error, fn ->
        Marqeta.Users.get!("missing")
      end
    end
  end
end

# ─── Cards ────────────────────────────────────────────────────────────────────

defmodule Marqeta.CardsTest do
  use ExUnit.Case, async: true
  import Marqeta.Test.Factory
  import Marqeta.Test.BypassHelper

  setup do
    bypass = Bypass.open()
    configure_marqeta(bypass)
    {:ok, bypass: bypass}
  end

  describe "create/2" do
    test "creates a virtual card", %{bypass: bypass} do
      card = build(:card)
      expect_post(bypass, "/cards", card)

      assert {:ok, returned} =
               Marqeta.Cards.create(%{
                 user_token: "user_01",
                 card_product_token: "cp_01"
               })

      assert returned["state"] == "ACTIVE"
      assert returned["instrument_type"] == "VIRTUAL_PAN"
    end

    test "returns error on invalid params", %{bypass: bypass} do
      expect_error(bypass, "POST", "/cards", %{"error_message" => "user_token is required"}, 400)

      assert {:error, err} = Marqeta.Cards.create(%{})
      assert err.type == :validation_error
    end
  end

  describe "get/2" do
    test "retrieves a card by token", %{bypass: bypass} do
      card = build(:card)
      expect_get(bypass, "/cards/#{card["token"]}", card)

      assert {:ok, returned} = Marqeta.Cards.get(card["token"])
      assert returned["token"] == card["token"]
      assert returned["last_four"] == card["last_four"]
    end
  end

  describe "show_pan/2" do
    test "retrieves card with PAN and CVV", %{bypass: bypass} do
      card =
        build(:card, %{
          "pan" => "4111111111111111",
          "cvv_number" => "123"
        })

      expect_get(
        bypass,
        "/cards/#{card["token"]}?show_pan=true&show_cvv_number=true",
        card
      )

      assert {:ok, returned} = Marqeta.Cards.show_pan(card["token"])
      assert returned["pan"] == "4111111111111111"
      assert returned["cvv_number"] == "123"
    end
  end

  describe "update/3" do
    test "updates a card", %{bypass: bypass} do
      card =
        build(:card, %{
          "metadata" => %{
            "note" => "updated"
          }
        })

      expect_put(bypass, "/cards/#{card["token"]}", card)

      assert {:ok, returned} =
               Marqeta.Cards.update(card["token"], %{
                 metadata: %{note: "updated"}
               })

      assert returned["metadata"]["note"] == "updated"
    end
  end

  describe "list/2" do
    test "lists cards", %{bypass: bypass} do
      cards = build_list(:card, 4)
      expect_list(bypass, "/cards", cards)

      assert {:ok, page} = Marqeta.Cards.list()
      assert length(page["data"]) == 4
    end
  end

  describe "list_by_user/3" do
    test "lists cards for a user", %{bypass: bypass} do
      token = "user_xyz"

      cards =
        build_list(:card, 2, %{
          "user_token" => token
        })

      expect_list(bypass, "/cards/user/#{token}", cards)

      assert {:ok, page} = Marqeta.Cards.list_by_user(token)
      assert length(page["data"]) == 2
      assert Enum.all?(page["data"], &(&1["user_token"] == token))
    end
  end

  describe "list_by_last_four/3" do
    test "lists cards by last four digits", %{bypass: bypass} do
      cards = build_list(:card, 1, %{"last_four" => "1234"})
      expect_list(bypass, "/cards", cards)

      assert {:ok, page} = Marqeta.Cards.list_by_last_four("1234")
      assert hd(page["data"])["last_four"] == "1234"
    end
  end

  describe "transactions/3" do
    test "lists transactions for a card", %{bypass: bypass} do
      card_token = "card_abc"
      txns = build_list(:transaction, 3, %{"card_token" => card_token})
      expect_list(bypass, "/transactions/card/#{card_token}", txns)

      assert {:ok, page} = Marqeta.Cards.transactions(card_token)
      assert length(page["data"]) == 3
    end
  end
end

# ─── GPA Orders ───────────────────────────────────────────────────────────────

defmodule Marqeta.GPAOrdersTest do
  use ExUnit.Case, async: true
  import Marqeta.Test.Factory
  import Marqeta.Test.BypassHelper

  setup do
    bypass = Bypass.open()
    configure_marqeta(bypass)
    {:ok, bypass: bypass}
  end

  describe "create/2" do
    test "creates a GPA order", %{bypass: bypass} do
      order = build(:gpa_order, %{"amount" => 250.00})
      expect_post(bypass, "/gpaorders", order)

      assert {:ok, returned} =
               Marqeta.GPAOrders.create(%{
                 user_token: "user_01",
                 amount: 250.00,
                 currency_code: "USD",
                 funding_source_token: "fs_01"
               })

      assert returned["amount"] == 250.00
      assert returned["state"] == "COMPLETION"
    end
  end

  describe "unload/3" do
    test "unloads a GPA order", %{bypass: bypass} do
      order = build(:gpa_order)
      unload = build(:gpa_order, %{"amount" => 50.00}, %{"state" => "COMPLETION"})
      expect_post(bypass, "/gpaorders/#{order["token"]}/unloads", unload)

      assert {:ok, returned} =
               Marqeta.GPAOrders.unload(order["token"], %{
                 original_order_token: order["token"],
                 amount: 50.00,
                 currency_code: "USD",
                 funding_source_token: "fs_01"
               })

      assert returned["state"] == "COMPLETION"
    end
  end

  describe "list_by_user/3" do
    test "lists GPA orders for a user", %{bypass: bypass} do
      token = "user_abc"
      orders = build_list(:gpa_order, 2, %{"user_token" => token})
      expect_list(bypass, "/gpaorders/user/#{token}", orders)

      assert {:ok, page} = Marqeta.GPAOrders.list_by_user(token)
      assert length(page["data"]) == 2
    end
  end
end

# ─── Velocity Controls ────────────────────────────────────────────────────────

defmodule Marqeta.VelocityControlsTest do
  use ExUnit.Case, async: true
  import Marqeta.Test.Factory
  import Marqeta.Test.BypassHelper

  setup do
    bypass = Bypass.open()
    configure_marqeta(bypass)
    {:ok, bypass: bypass}
  end

  describe "create/2" do
    test "creates a velocity control", %{bypass: bypass} do
      vc = build(:velocity_control)
      expect_post(bypass, "/velocitycontrols", vc)

      assert {:ok, returned} =
               Marqeta.VelocityControls.create(%{
                 association: %{user_token: "user_01"},
                 currency_code: "USD",
                 amount_limit: 500.00,
                 velocity_window: "DAY",
                 include_purchases: true,
                 active: true
               })

      assert returned["amount_limit"] == 500.00
      assert returned["velocity_window"] == "DAY"
    end
  end

  describe "list_by_user/3" do
    test "lists velocity controls for a user", %{bypass: bypass} do
      token = "user_abc"
      vcs = build_list(:velocity_control, 2)
      expect_list(bypass, "/velocitycontrols/user/#{token}/available", vcs)

      assert {:ok, page} = Marqeta.VelocityControls.list_by_user(token)
      assert length(page["data"]) == 2
    end
  end
end

# ─── KYC Verification ─────────────────────────────────────────────────────────

defmodule Marqeta.KYCVerificationTest do
  use ExUnit.Case, async: true
  import Marqeta.Test.Factory
  import Marqeta.Test.BypassHelper

  setup do
    bypass = Bypass.open()
    configure_marqeta(bypass)
    {:ok, bypass: bypass}
  end

  describe "perform/2" do
    test "submits KYC for a user", %{bypass: bypass} do
      result = build(:kyc_result)
      expect_post(bypass, "/kyc", result)

      assert {:ok, returned} = Marqeta.KYCVerification.perform(%{user_token: "user_01"})
      assert returned["result"]["status"] == "success"
    end

    test "handles KYC failure", %{bypass: bypass} do
      result =
        build(:kyc_result, %{"result" => %{"status" => "failure", "codes" => ["DOB_MISMATCH"]}})

      expect_post(bypass, "/kyc", result)

      assert {:ok, returned} = Marqeta.KYCVerification.perform(%{user_token: "user_01"})
      assert returned["result"]["status"] == "failure"
    end
  end

  describe "list_by_user/3" do
    test "lists KYC records for a user", %{bypass: bypass} do
      token = "user_abc"
      results = build_list(:kyc_result, 1)
      expect_list(bypass, "/kyc/user/#{token}", results)

      assert {:ok, page} = Marqeta.KYCVerification.list_by_user(token)
      assert length(page["data"]) == 1
    end
  end
end

# ─── Webhooks ─────────────────────────────────────────────────────────────────

defmodule Marqeta.WebhooksTest do
  use ExUnit.Case, async: true
  import Marqeta.Test.Factory
  import Marqeta.Test.BypassHelper

  setup do
    bypass = Bypass.open()
    configure_marqeta(bypass)
    {:ok, bypass: bypass}
  end

  describe "create/2" do
    test "creates a webhook", %{bypass: bypass} do
      wh = build(:webhook)
      expect_post(bypass, "/webhooks", wh)

      assert {:ok, returned} =
               Marqeta.Webhooks.create(%{
                 name: "my-webhook",
                 active: true,
                 events: ["*"],
                 config: %{
                   url: "https://example.com/webhooks",
                   secret: "MySecret12345678901234",
                   signature_algorithm: "HMAC_SHA_256"
                 }
               })

      assert returned["active"] == true
      assert returned["events"] == ["*"]
    end
  end

  describe "ping/2" do
    test "pings a webhook endpoint", %{bypass: bypass} do
      wh = build(:webhook)
      expect_post(bypass, "/webhooks/#{wh["token"]}/ping", %{"success" => true})

      assert {:ok, _} = Marqeta.Webhooks.ping(wh["token"])
    end
  end

  describe "resend/3" do
    test "resends an event", %{bypass: bypass} do
      wh = build(:webhook)
      event = "event_abc123"
      expect_post(bypass, "/webhooks/#{wh["token"]}/resend/#{event}", %{"success" => true})

      assert {:ok, _} = Marqeta.Webhooks.resend(wh["token"], event)
    end
  end

  describe "valid_signature?/3" do
    test "returns true for correct HMAC-SHA256 signature" do
      payload = ~s({"type":"transaction.authorization"})
      secret = "my_webhook_secret_key"
      signature = Base.encode16(:crypto.mac(:hmac, :sha256, secret, payload), case: :lower)

      assert Marqeta.Webhooks.valid_signature?(payload, signature, secret)
    end

    test "returns true for uppercase signature" do
      payload = ~s({"type":"transaction"})
      secret = "secret"
      signature = Base.encode16(:crypto.mac(:hmac, :sha256, secret, payload), case: :upper)

      assert Marqeta.Webhooks.valid_signature?(payload, signature, secret)
    end

    test "returns false for wrong secret" do
      payload = "payload"
      secret = "correct_secret"

      signature =
        Base.encode16(:crypto.mac(:hmac, :sha256, "wrong_secret", payload), case: :lower)

      refute Marqeta.Webhooks.valid_signature?(payload, signature, secret)
    end

    test "returns false for tampered payload" do
      payload = "original_payload"
      secret = "secret"
      signature = Base.encode16(:crypto.mac(:hmac, :sha256, secret, payload), case: :lower)

      refute Marqeta.Webhooks.valid_signature?("tampered_payload", signature, secret)
    end

    test "returns false for empty strings" do
      refute Marqeta.Webhooks.valid_signature?("", "invalidsig", "secret")
    end
  end

  describe "parse_event/1" do
    test "parses a JSON string" do
      body = ~s({"type":"transaction.authorization","amount":42.50})
      assert {:ok, event} = Marqeta.Webhooks.parse_event(body)
      assert event["type"] == "transaction.authorization"
    end

    test "passes through a map" do
      event = %{"type" => "cardtransition.activated"}
      assert {:ok, ^event} = Marqeta.Webhooks.parse_event(event)
    end

    test "returns error for invalid JSON" do
      assert {:error, _} = Marqeta.Webhooks.parse_event("not json{{{")
    end
  end

  describe "event_type/1" do
    test "extracts event type from map" do
      event = %{"type" => "transaction.authorization"}
      assert Marqeta.Webhooks.event_type(event) == "transaction.authorization"
    end

    test "returns nil for missing type" do
      assert Marqeta.Webhooks.event_type(%{}) == nil
    end
  end
end

# ─── Gateway JIT ──────────────────────────────────────────────────────────────

defmodule Marqeta.GatewayJITTest do
  use ExUnit.Case, async: true
  import Marqeta.Test.Factory

  alias Marqeta.GatewayJIT

  describe "actionable?/1" do
    defp jit_req(method, amount \\ 50.0) do
      %{
        "jit_funding" => %{
          "acting_user_token" => "u",
          "amount" => amount,
          "method" => method,
          "tags" => nil,
          "token" => "t",
          "user_token" => "u"
        }
      }
    end

    test "returns true for pgfs.authorization" do
      assert GatewayJIT.actionable?(jit_req("pgfs.authorization"))
    end

    test "returns true for pgfs.auth_plus_capture" do
      assert GatewayJIT.actionable?(jit_req("pgfs.auth_plus_capture"))
    end

    test "returns true for pgfs.authorization.account_verification" do
      assert GatewayJIT.actionable?(jit_req("pgfs.authorization.account_verification", 0.0))
    end

    test "returns false for pgfs.authorization.capture" do
      refute GatewayJIT.actionable?(jit_req("pgfs.authorization.capture"))
    end

    test "returns false when jit_funding key is missing" do
      refute GatewayJIT.actionable?(%{"type" => "gpa.credit"})
    end
  end

  describe "approve/2" do
    test "builds correct approval response structure" do
      req = build(:jit_request)
      response = GatewayJIT.approve(req)

      assert response["jit_funding"]["token"] == req["jit_funding"]["token"]
      assert response["jit_funding"]["method"] == req["jit_funding"]["method"]
      assert response["jit_funding"]["user_token"] == req["jit_funding"]["user_token"]
      assert response["jit_funding"]["amount"] == req["jit_funding"]["amount"]
      refute Map.has_key?(response["jit_funding"], "decline_reason")
    end

    test "allows overriding amount for partial approval" do
      req = build(:jit_request)
      response = GatewayJIT.approve(req, amount: 25.00)

      assert response["jit_funding"]["amount"] == 25.00
    end

    test "includes memo when provided" do
      req = build(:jit_request)
      response = GatewayJIT.approve(req, memo: "Approved by risk engine")

      assert response["jit_funding"]["memo"] == "Approved by risk engine"
    end

    test "includes metadata when provided" do
      req = build(:jit_request)
      response = GatewayJIT.approve(req, metadata: %{"balance_after" => "450.00"})

      assert response["jit_funding"]["metadata"]["balance_after"] == "450.00"
    end

    test "does not include nil memo" do
      req = build(:jit_request)
      response = GatewayJIT.approve(req)

      refute Map.has_key?(response["jit_funding"], "memo")
    end
  end

  describe "decline/2" do
    test "builds correct decline response with zero amount" do
      req = build(:jit_request)
      response = GatewayJIT.decline(req, reason: "INSUFFICIENT_FUNDS")

      assert response["jit_funding"]["amount"] == 0
      assert response["jit_funding"]["decline_reason"] == "INSUFFICIENT_FUNDS"
    end

    test "defaults to DO_NOT_HONOR reason" do
      req = build(:jit_request)
      response = GatewayJIT.decline(req)

      assert response["jit_funding"]["decline_reason"] == "DO_NOT_HONOR"
    end

    test "sets user_token correctly" do
      req = build(:jit_request)
      response = GatewayJIT.decline(req)

      assert response["jit_funding"]["user_token"] == req["jit_funding"]["user_token"]
    end
  end

  describe "ack/1" do
    test "builds minimal acknowledgement response" do
      req = build(:jit_request)
      response = GatewayJIT.ack(req)

      assert response["jit_funding"]["token"] == req["jit_funding"]["token"]
      assert response["jit_funding"]["method"] == req["jit_funding"]["method"]
      assert map_size(response["jit_funding"]) == 2
    end
  end

  describe "field extractors" do
    setup do
      req = build(:jit_request)
      {:ok, req: req}
    end

    test "method/1 returns method string", %{req: req} do
      assert GatewayJIT.method(req) == "pgfs.authorization"
    end

    test "amount/1 returns amount", %{req: req} do
      assert GatewayJIT.amount(req) == req["jit_funding"]["amount"]
    end

    test "user_token/1 returns user token", %{req: req} do
      assert GatewayJIT.user_token(req) == req["jit_funding"]["user_token"]
    end

    test "merchant_name/1 returns merchant name", %{req: req} do
      assert GatewayJIT.merchant_name(req) == "Test Merchant"
    end

    test "mcc/1 returns MCC code", %{req: req} do
      assert GatewayJIT.mcc(req) == "5411"
    end

    test "country/1 returns country", %{req: req} do
      assert GatewayJIT.country(req) == "USA"
    end

    test "currency/1 returns currency code", %{req: req} do
      assert GatewayJIT.currency(req) == "USD"
    end

    test "extractors return nil for missing keys" do
      assert GatewayJIT.method(%{}) == nil
      assert GatewayJIT.amount(%{}) == nil
      assert GatewayJIT.user_token(%{}) == nil
      assert GatewayJIT.merchant_name(%{}) == nil
      assert GatewayJIT.mcc(%{}) == nil
    end
  end

  describe "account_verification?/1" do
    test "returns true for account verification method" do
      req = %{"jit_funding" => %{"method" => "pgfs.authorization.account_verification"}}
      assert GatewayJIT.account_verification?(req)
    end

    test "returns false for regular authorization" do
      req = %{"jit_funding" => %{"method" => "pgfs.authorization"}}
      refute GatewayJIT.account_verification?(req)
    end
  end
end

# ─── Error ────────────────────────────────────────────────────────────────────

defmodule Marqeta.ErrorTest do
  use ExUnit.Case, async: true

  alias Marqeta.Error

  describe "from_response/1" do
    test "builds validation_error from 400" do
      resp = %{
        status: 400,
        body: %{
          "error_code" => "400040",
          "error_message" => "Email is invalid",
          "errors" => [
            %{"field" => "email", "message" => "Must be a valid email"}
          ]
        },
        headers: [{"x-request-id", "req-abc-123"}]
      }

      err = Error.from_response(resp)

      assert err.type == :validation_error
      assert err.http_status == 400
      assert err.error_code == "400040"
      assert err.message == "Email is invalid"
      assert err.request_id == "req-abc-123"
      assert err.retryable? == false
      assert length(err.field_errors) == 1
      assert hd(err.field_errors).field == "email"
      assert hd(err.field_errors).message == "Must be a valid email"
    end

    test "builds authentication_error from 401" do
      err =
        Error.from_response(%{
          status: 401,
          body: %{"error_message" => "Unauthorized"},
          headers: []
        })

      assert err.type == :authentication_error
      assert err.retryable? == false
    end

    test "builds authorization_error from 403" do
      err =
        Error.from_response(%{status: 403, body: %{"error_message" => "Forbidden"}, headers: []})

      assert err.type == :authorization_error
    end

    test "builds not_found from 404" do
      err =
        Error.from_response(%{status: 404, body: %{"error_message" => "Not found"}, headers: []})

      assert err.type == :not_found
    end

    test "builds conflict_error from 409" do
      err =
        Error.from_response(%{
          status: 409,
          body: %{"error_message" => "Already exists"},
          headers: []
        })

      assert err.type == :conflict_error
    end

    test "builds rate_limit_error from 429 and marks retryable" do
      err =
        Error.from_response(%{
          status: 429,
          body: %{"error_message" => "Too many requests"},
          headers: []
        })

      assert err.type == :rate_limit_error
      assert err.retryable? == true
    end

    test "builds server_error from 500 and marks retryable" do
      err =
        Error.from_response(%{
          status: 500,
          body: %{"error_message" => "Internal error"},
          headers: []
        })

      assert err.type == :server_error
      assert err.retryable? == true
    end

    test "builds server_error from 503 and marks retryable" do
      err = Error.from_response(%{status: 503, body: "Service Unavailable", headers: []})
      assert err.type == :server_error
      assert err.retryable? == true
    end

    test "handles nil body gracefully" do
      err = Error.from_response(%{status: 500, body: nil, headers: []})
      assert err.type == :server_error
    end

    test "extracts request_id from headers" do
      err =
        Error.from_response(%{
          status: 404,
          body: %{"error_message" => "Not found"},
          headers: [{"x-request-id", "req-xyz-999"}]
        })

      assert err.request_id == "req-xyz-999"
    end

    test "returns empty field_errors when not present" do
      err = Error.from_response(%{status: 400, body: %{"error_message" => "Bad"}, headers: []})
      assert err.field_errors == []
    end
  end

  describe "from_exception/1" do
    test "classifies transport timeout as timeout_error" do
      err = Error.from_exception(%Req.TransportError{reason: :timeout})
      assert err.type == :timeout_error
      assert err.retryable? == true
    end

    test "classifies connect_timeout as timeout_error" do
      err = Error.from_exception(%Req.TransportError{reason: :connect_timeout})
      assert err.type == :timeout_error
      assert err.retryable? == true
    end

    test "classifies connection refused as network_error" do
      err = Error.from_exception(%Req.TransportError{reason: :econnrefused})
      assert err.type == :network_error
      assert err.retryable? == true
    end
  end

  describe "Exception.message/1" do
    test "formats without http_status" do
      err = %Error{type: :network_error, message: "Connection refused"}
      assert Exception.message(err) == "Connection refused"
    end

    test "formats with http_status only" do
      err = %Error{type: :server_error, message: "Internal error", http_status: 500}
      assert Exception.message(err) == "HTTP 500: Internal error"
    end

    test "formats with http_status and error_code" do
      err = %Error{
        type: :validation_error,
        message: "Bad email",
        http_status: 400,
        error_code: "400040"
      }

      assert Exception.message(err) == "HTTP 400 (400040): Bad email"
    end
  end
end

# ─── Pagination ───────────────────────────────────────────────────────────────

defmodule Marqeta.PaginationTest do
  use ExUnit.Case, async: true
  alias Marqeta.Pagination

  describe "next_page_params/2" do
    test "returns next page params when is_more is true" do
      response = %{"count" => 10, "is_more" => true}
      params = %{count: 10, start_index: 0}

      next = Pagination.next_page_params(response, params)
      assert next[:start_index] == 10
      assert next[:count] == 10
    end

    test "returns nil when count < requested and is_more false" do
      response = %{"count" => 3, "is_more" => false}
      params = %{count: 10, start_index: 0}

      assert nil == Pagination.next_page_params(response, params)
    end

    test "returns nil for empty response" do
      response = %{"count" => 0, "is_more" => false}
      params = %{count: 10, start_index: 0}

      assert nil == Pagination.next_page_params(response, params)
    end

    test "returns next when count equals requested (may be more)" do
      response = %{"count" => 10, "is_more" => false}
      params = %{count: 10, start_index: 0}

      next = Pagination.next_page_params(response, params)
      assert next[:start_index] == 10
    end

    test "accumulates start_index correctly across pages" do
      params1 = %{count: 5, start_index: 0}
      response1 = %{"count" => 5, "is_more" => true}
      params2 = Pagination.next_page_params(response1, params1)
      assert params2[:start_index] == 5

      response2 = %{"count" => 5, "is_more" => true}
      params3 = Pagination.next_page_params(response2, params2)
      assert params3[:start_index] == 10
    end
  end

  describe "extract_data/1" do
    test "extracts data list" do
      resp = %{"data" => [%{"token" => "a"}, %{"token" => "b"}]}
      assert Pagination.extract_data(resp) == [%{"token" => "a"}, %{"token" => "b"}]
    end

    test "returns empty list for missing data key" do
      assert Pagination.extract_data(%{}) == []
    end

    test "returns empty list for nil data" do
      assert Pagination.extract_data(%{"data" => nil}) == []
    end
  end

  describe "has_more?/1" do
    test "returns true when is_more is true" do
      assert Pagination.has_more?(%{"is_more" => true})
    end

    test "returns false when is_more is false" do
      refute Pagination.has_more?(%{"is_more" => false})
    end

    test "returns false when is_more key is absent" do
      refute Pagination.has_more?(%{"count" => 5})
    end
  end

  describe "normalize_params/1" do
    test "sets default count and start_index" do
      params = Pagination.normalize_params(%{})
      assert params[:count] == 5
      assert params[:start_index] == 0
    end

    test "respects provided values" do
      params = Pagination.normalize_params(%{count: 50, start_index: 100})
      assert params[:count] == 50
      assert params[:start_index] == 100
    end

    test "caps count at 1000" do
      params = Pagination.normalize_params(%{count: 99_999})
      assert params[:count] == 1000
    end
  end
end

# ─── Stream ───────────────────────────────────────────────────────────────────

defmodule Marqeta.StreamTest do
  use ExUnit.Case, async: true
  import Marqeta.Test.Factory

  alias Marqeta.Stream, as: MStream

  describe "stream/3" do
    test "emits all items from a single page" do
      items = build_list(:user, 3)
      page = %{"count" => 3, "is_more" => false, "data" => items, "start_index" => 0}

      result = Enum.to_list(MStream.stream(fn _params -> {:ok, page} end))
      assert length(result) == 3
    end

    test "auto-paginates across multiple pages" do
      page1_items = build_list(:user, 5)
      page2_items = build_list(:user, 3)

      page1 = %{"count" => 5, "is_more" => true, "data" => page1_items, "start_index" => 0}
      page2 = %{"count" => 3, "is_more" => false, "data" => page2_items, "start_index" => 5}

      call_count = :counters.new(1, [:atomics])

      result =
        Enum.to_list(
          MStream.stream(fn params ->
            :counters.add(call_count, 1, 1)
            if (params[:start_index] || 0) == 0, do: {:ok, page1}, else: {:ok, page2}
          end)
        )

      assert length(result) == 8
      assert :counters.get(call_count, 1) == 2
    end

    test "stops on empty page" do
      empty = %{"count" => 0, "is_more" => false, "data" => [], "start_index" => 0}

      result = Enum.to_list(MStream.stream(fn _params -> {:ok, empty} end))
      assert result == []
    end

    test "stops on error without raising by default" do
      result =
        Enum.to_list(
          MStream.stream(fn _params ->
            {:error, %Marqeta.Error{type: :server_error, message: "oops"}}
          end)
        )

      assert result == []
    end

    test "raises when raise_on_error: true" do
      assert_raise Marqeta.Error, fn ->
        Enum.to_list(
          MStream.stream(
            fn _params -> {:error, %Marqeta.Error{type: :server_error, message: "oops"}} end,
            %{},
            raise_on_error: true
          )
        )
      end
    end

    test "respects Stream.take for lazy evaluation" do
      call_count = :counters.new(1, [:atomics])
      items = build_list(:user, 100)
      page = %{"count" => 100, "is_more" => true, "data" => items, "start_index" => 0}

      result =
        MStream.stream(fn _params ->
          :counters.add(call_count, 1, 1)
          {:ok, page}
        end)
        |> Stream.take(5)
        |> Enum.to_list()

      assert length(result) == 5
      # Should only fetch one page (lazily evaluated)
      assert :counters.get(call_count, 1) == 1
    end
  end

  describe "all/2" do
    test "collects all items" do
      items = build_list(:user, 7)
      page = %{"count" => 7, "is_more" => false, "data" => items, "start_index" => 0}

      assert {:ok, all} = MStream.all(fn _params -> {:ok, page} end)
      assert length(all) == 7
    end

    test "collects across multiple pages" do
      p1 = %{"count" => 3, "is_more" => true, "data" => build_list(:user, 3), "start_index" => 0}
      p2 = %{"count" => 2, "is_more" => false, "data" => build_list(:user, 2), "start_index" => 3}

      assert {:ok, all} =
               MStream.all(fn params ->
                 if (params[:start_index] || 0) == 0, do: {:ok, p1}, else: {:ok, p2}
               end)

      assert length(all) == 5
    end

    test "returns error on failure" do
      error = %Marqeta.Error{type: :server_error, message: "oops"}
      assert {:error, ^error} = MStream.all(fn _params -> {:error, error} end)
    end
  end
end

# ─── Credit Accounts ──────────────────────────────────────────────────────────

defmodule Marqeta.CreditAccountsTest do
  use ExUnit.Case, async: true
  import Marqeta.Test.Factory
  import Marqeta.Test.BypassHelper

  alias Marqeta.Credit.Accounts

  setup do
    bypass = Bypass.open()
    configure_marqeta(bypass)
    {:ok, bypass: bypass}
  end

  describe "create/2" do
    test "creates a credit account", %{bypass: bypass} do
      account = build(:credit_account)
      expect_post(bypass, "/credit/accounts", account)

      assert {:ok, returned} =
               Accounts.create(%{
                 user_token: "user_01",
                 bundle_token: "bundle_01",
                 credit_limit: 5_000.00
               })

      assert returned["credit_limit"] == 5_000.00
      assert returned["status"] == "ACTIVE"
    end
  end

  describe "get/2" do
    test "retrieves a credit account", %{bypass: bypass} do
      account = build(:credit_account)
      expect_get(bypass, "/credit/accounts/#{account["token"]}", account)

      assert {:ok, returned} = Accounts.get(account["token"])
      assert returned["token"] == account["token"]
    end
  end

  describe "balance/2" do
    test "returns account balance", %{bypass: bypass} do
      token = "ca_abc"
      bal = %{"current_balance" => 250.00, "available_credit" => 4750.00}
      expect_get(bypass, "/credit/accounts/#{token}/balances", bal)

      assert {:ok, b} = Accounts.balance(token)
      assert b["current_balance"] == 250.00
    end
  end

  describe "list_by_user/3" do
    test "lists credit accounts for a user", %{bypass: bypass} do
      token = "user_abc"
      accounts = build_list(:credit_account, 2)
      expect_list(bypass, "/credit/accounts/user/#{token}", accounts)

      assert {:ok, page} = Accounts.list_by_user(token)
      assert length(page["data"]) == 2
    end
  end
end

# ─── Credit Payments ──────────────────────────────────────────────────────────

defmodule Marqeta.CreditPaymentsTest do
  use ExUnit.Case, async: true
  import Marqeta.Test.Factory
  import Marqeta.Test.BypassHelper

  alias Marqeta.Credit.Payments

  setup do
    bypass = Bypass.open()
    configure_marqeta(bypass)
    {:ok, bypass: bypass}
  end

  describe "create/3" do
    test "creates a payment on a credit account", %{bypass: bypass} do
      account_token = "ca_abc"
      payment = %{"token" => "pay_001", "amount" => 250.00, "state" => "PROCESSING"}
      expect_post(bypass, "/credit/accounts/#{account_token}/payments", payment)

      assert {:ok, returned} =
               Payments.create(account_token, %{
                 amount: 250.00,
                 payment_source_token: "source_01"
               })

      assert returned["amount"] == 250.00
    end
  end

  describe "list/3" do
    test "lists payments on a credit account", %{bypass: bypass} do
      account_token = "ca_abc"
      payments = [%{"token" => "pay_001", "amount" => 100.00}]
      expect_list(bypass, "/credit/accounts/#{account_token}/payments", payments)

      assert {:ok, page} = Payments.list(account_token)
      assert length(page["data"]) == 1
    end
  end
end

# ─── DiVA Authorizations ─────────────────────────────────────────────────────

defmodule Marqeta.DiVATest do
  use ExUnit.Case, async: true
  import Marqeta.Test.Factory
  import Marqeta.Test.BypassHelper

  alias Marqeta.DiVA.Authorizations
  alias Marqeta.DiVA.DataDictionary
  alias Marqeta.DiVA.PlatformResponse
  alias Marqeta.DiVA.Settlements
  alias Marqeta.DiVA.Views

  setup do
    bypass = Bypass.open()
    configure_marqeta(bypass)
    {:ok, bypass: bypass}
  end

  describe "Marqeta.DiVA.Authorizations.list/2" do
    test "lists authorization records", %{bypass: bypass} do
      records = build_list(:transaction, 5)
      expect_list(bypass, "/diva/authorizations", records)

      assert {:ok, page} =
               Authorizations.list(%{
                 start_date: "2024-01-01",
                 end_date: "2024-01-31"
               })

      assert length(page["data"]) == 5
    end
  end

  describe "Marqeta.DiVA.Settlements.list/2" do
    test "lists settlement records", %{bypass: bypass} do
      records = build_list(:transaction, 3)
      expect_list(bypass, "/diva/settlements", records)

      assert {:ok, page} = Settlements.list()
      assert length(page["data"]) == 3
    end
  end

  describe "Marqeta.DiVA.DataDictionary.get/2" do
    test "retrieves data dictionary for a view", %{bypass: bypass} do
      dict = %{"fields" => [%{"name" => "transaction_token", "type" => "string"}]}
      expect_get(bypass, "/diva/datadictionary/authorizations", dict)

      assert {:ok, returned} = DataDictionary.get("authorizations")
      assert length(returned["fields"]) == 1
    end
  end

  describe "Marqeta.DiVA.Views.list/2" do
    test "lists available views", %{bypass: bypass} do
      views = [%{"name" => "authorizations"}, %{"name" => "settlements"}]
      expect_list(bypass, "/diva/views", views)

      assert {:ok, page} = Views.list()
      assert length(page["data"]) == 2
    end
  end

  describe "Marqeta.DiVA.PlatformResponse.list/2" do
    test "retrieves platform response metrics", %{bypass: bypass} do
      metrics = [%{"report_date" => "2024-01-01", "avg_response_time_ms" => 120}]
      expect_list(bypass, "/diva/platformresponse", metrics)

      assert {:ok, page} = PlatformResponse.list(%{start_date: "2024-01-01"})
      assert hd(page["data"])["avg_response_time_ms"] == 120
    end
  end
end

# ─── EventTypes ───────────────────────────────────────────────────────────────

defmodule Marqeta.EventTypesTest do
  use ExUnit.Case, async: true

  describe "event type helpers" do
    test "all/0 returns wildcard" do
      assert Marqeta.EventTypes.all() == "*"
    end

    test "transaction_events/0 returns correct prefix" do
      assert "transaction.*" in Marqeta.EventTypes.transaction_events()
    end

    test "common_events/0 returns non-empty list" do
      events = Marqeta.EventTypes.common_events()
      assert is_list(events)
      assert events != []
      assert "transaction.*" in events
    end
  end
end
