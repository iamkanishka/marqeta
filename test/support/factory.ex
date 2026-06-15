defmodule Marqeta.Test.Factory do
  @moduledoc """
  Test factory for Marqeta API response fixtures.

  Provides `build/1`, `build/2`, and `build_list/3` for all resource types.

  ## Usage

      import Marqeta.Test.Factory

      user    = build(:user)
      card    = build(:card, %{"user_token" => user["token"]})
      page    = paginated(:user, 5)
  """

  # In Elixir, default arguments are only allowed in the first clause of
  # a multi-clause function.  We declare a single head with the default,
  # then delegate to private per-resource builders.

  @spec build(atom()) :: map()
  def build(resource_type), do: build(resource_type, %{})

  @spec build(atom(), map()) :: map()
  def build(resource_type, overrides) do
    resource_type
    |> do_build()
    |> Map.merge(overrides)
  end

  # ---------------------------------------------------------------------------
  # Private per-resource builders
  # ---------------------------------------------------------------------------

  defp do_build(:user) do
    n = :rand.uniform(99_999)

    %{
      "account_holder_group_token" => nil,
      "address1" => "123 Main St",
      "birth_date" => "1990-01-15",
      "city" => "San Francisco",
      "country" => "USA",
      "created_time" => utc_now(),
      "email" => "user#{n}@example.com",
      "first_name" => "Test",
      "last_name" => "User#{n}",
      "last_modified_time" => utc_now(),
      "metadata" => %{},
      "phone" => "555#{String.pad_leading("#{n}", 7, "0")}",
      "postal_code" => "94105",
      "state" => "CA",
      "status" => "ACTIVE",
      "token" => "user_" <> rand_hex()
    }
  end

  defp do_build(:business) do
    %{
      "business_name_dba" => "Acme",
      "business_name_legal" => "Acme Corp LLC",
      "created_time" => utc_now(),
      "last_modified_time" => utc_now(),
      "office_location" => %{
        "address1" => "100 Market St",
        "city" => "San Francisco",
        "country" => "USA",
        "state" => "CA",
        "zip" => "94105"
      },
      "status" => "ACTIVE",
      "token" => "biz_" <> rand_hex()
    }
  end

  defp do_build(:card_product) do
    %{
      "active" => true,
      "config" => %{
        "card_life_cycle" => %{"activate_upon_issue" => true},
        "fulfillment" => %{"payment_instrument" => "VIRTUAL_PAN"},
        "jit_funding" => %{
          "program_funding_source" => %{
            "enabled" => true,
            "funding_source_token" => "program_fs_01"
          }
        }
      },
      "created_time" => utc_now(),
      "last_modified_time" => utc_now(),
      "name" => "Test Card Product",
      "start_date" => "2024-01-01",
      "token" => "cp_" <> rand_hex()
    }
  end

  defp do_build(:card) do
    last_four =
      :rand.uniform(9_999) |> Integer.to_string() |> String.pad_leading(4, "0")

    %{
      "barcode" => rand_barcode(),
      "card_product_token" => "cp_" <> rand_hex(),
      "contactless_exemption_counter" => 0,
      "contactless_exemption_total_amount" => 0.00,
      "created_time" => utc_now(),
      "cvv_number" => nil,
      "expedite" => false,
      "expiration" => "12/27",
      "expiration_time" => "2027-12-31T23:59:59Z",
      "fulfillment_status" => "ISSUED",
      "instrument_type" => "VIRTUAL_PAN",
      "last_four" => last_four,
      "last_modified_time" => utc_now(),
      "metadata" => %{},
      "pan" => nil,
      "state" => "ACTIVE",
      "state_reason" => "New card issued",
      "token" => "card_" <> rand_hex(),
      "user_token" => "user_" <> rand_hex()
    }
  end

  defp do_build(:card_transition) do
    %{
      "card_token" => "card_" <> rand_hex(),
      "channel" => "API",
      "created_time" => utc_now(),
      "fulfillment_status" => "ISSUED",
      "reason" => "New card activated",
      "reason_code" => "00",
      "state" => "ACTIVE",
      "token" => "ct_" <> rand_hex(),
      "type" => "state.activated"
    }
  end

  defp do_build(:gpa_order) do
    %{
      "amount" => 100.00,
      "created_time" => utc_now(),
      "currency_code" => "USD",
      "funding_source_token" => "fs_" <> rand_hex(),
      "jit_funding" => nil,
      "last_modified_time" => utc_now(),
      "memo" => nil,
      "response" => %{
        "code" => "0000",
        "memo" => "Approved or completed successfully"
      },
      "state" => "COMPLETION",
      "tags" => nil,
      "token" => "gpa_" <> rand_hex(),
      "user_token" => "user_" <> rand_hex()
    }
  end

  defp do_build(:transaction) do
    %{
      "amount" => 42.50,
      "card_acceptor" => %{
        "city" => "San Francisco",
        "country" => "USA",
        "mcc" => "5411",
        "mid" => "mid_#{:rand.uniform(999_999)}",
        "name" => "Test Merchant",
        "state" => "CA"
      },
      "card_token" => "card_" <> rand_hex(),
      "created_time" => utc_now(),
      "currency_code" => "USD",
      "gpa" => %{
        "available_balance" => 57.50,
        "credit_balance" => 0,
        "currency_code" => "USD",
        "ledger_balance" => 57.50,
        "pending_credits" => 0
      },
      "last_modified_time" => utc_now(),
      "response" => %{
        "code" => "0000",
        "memo" => "Approved or completed successfully"
      },
      "state" => "PENDING",
      "token" => "txn_" <> rand_hex(),
      "type" => "authorization",
      "user_token" => "user_" <> rand_hex()
    }
  end

  defp do_build(:velocity_control) do
    %{
      "active" => true,
      "amount_limit" => 500.00,
      "approvals_only" => true,
      "association" => %{"user_token" => "user_" <> rand_hex()},
      "created_time" => utc_now(),
      "currency_code" => "USD",
      "include_cashback" => false,
      "include_credits" => false,
      "include_purchases" => true,
      "include_transfers" => false,
      "include_withdrawals" => true,
      "last_modified_time" => utc_now(),
      "name" => "Daily Spend Limit",
      "token" => "vc_" <> rand_hex(),
      "transaction_limit" => nil,
      "velocity_window" => "DAY"
    }
  end

  defp do_build(:kyc_result) do
    %{
      "created_time" => utc_now(),
      "last_modified_time" => utc_now(),
      "result" => %{
        "codes" => [],
        "status" => "success"
      },
      "token" => "kyc_" <> rand_hex(),
      "user_token" => "user_" <> rand_hex()
    }
  end

  defp do_build(:webhook) do
    %{
      "active" => true,
      "config" => %{
        "secret" => "MyHmacSecret123456789A",
        "signature_algorithm" => "HMAC_SHA_256",
        "url" => "https://webhook.example.com/marqeta"
      },
      "created_time" => utc_now(),
      "events" => ["*"],
      "last_modified_time" => utc_now(),
      "name" => "Test Webhook",
      "token" => "wh_" <> rand_hex()
    }
  end

  defp do_build(:credit_account) do
    %{
      "available_credit" => 4_750.00,
      "bundle_token" => "bundle_" <> rand_hex(),
      "config" => %{
        "billing_cycle_day" => 1,
        "card_level" => "TRADITIONAL",
        "e_disclosure_active" => true,
        "payment_due_interval" => 25
      },
      "created_time" => utc_now(),
      "credit_limit" => 5_000.00,
      "current_balance" => 250.00,
      "last_modified_time" => utc_now(),
      "status" => "ACTIVE",
      "token" => "ca_" <> rand_hex(),
      "user_token" => "user_" <> rand_hex()
    }
  end

  defp do_build(:jit_request) do
    %{
      "amount" => 75.00,
      "card_acceptor" => %{
        "city" => "San Francisco",
        "country" => "USA",
        "mcc" => "5411",
        "mid" => "mid_#{:rand.uniform(999_999)}",
        "name" => "Test Merchant",
        "state" => "CA"
      },
      "currency_code" => "USD",
      "jit_funding" => %{
        "acting_user_token" => "user_" <> rand_hex(),
        "amount" => 75.00,
        "method" => "pgfs.authorization",
        "tags" => nil,
        "token" => "jit_" <> rand_hex(),
        "user_token" => "user_" <> rand_hex()
      },
      "type" => "gpa.credit"
    }
  end

  defp do_build(:pin_control_token) do
    %{
      "card_token" => "card_" <> rand_hex(),
      "control_token" => "pct_" <> rand_hex(),
      "created_time" => utc_now(),
      "last_modified_time" => utc_now()
    }
  end

  defp do_build(:auth_control) do
    %{
      "active" => true,
      "association" => %{"card_product_token" => "cp_" <> rand_hex()},
      "created_time" => utc_now(),
      "last_modified_time" => utc_now(),
      "merchant_scope" => %{"mcc_group" => "gambling"},
      "name" => "Block Gambling",
      "token" => "ac_" <> rand_hex()
    }
  end

  defp do_build(:fee) do
    %{
      "active" => true,
      "amount" => 9.99,
      "created_time" => utc_now(),
      "currency_code" => "USD",
      "last_modified_time" => utc_now(),
      "name" => "Monthly Maintenance Fee",
      "token" => "fee_" <> rand_hex(),
      "type" => "MONTHLY"
    }
  end

  defp do_build(:error_response) do
    %{
      "error_code" => "400010",
      "error_message" => "One or more fields are invalid"
    }
  end

  # ---------------------------------------------------------------------------
  # Paginated list wrapper
  # ---------------------------------------------------------------------------

  @doc """
  Builds a paginated list response wrapping `count` items of `resource_type`.

  ## Options

    * `:is_more`     — whether more pages exist. Default: `false`.
    * `:start_index` — pagination offset. Default: `0`.

  ## Example

      paginated(:user, 5)
      #=> %{"count" => 5, "start_index" => 0, "is_more" => false, "data" => [...]}
  """
  @spec paginated(atom(), non_neg_integer(), keyword()) :: map()
  def paginated(resource_type, count, opts \\ []) do
    data = Enum.map(1..max(count, 1), fn _ -> build(resource_type) end)
    start_index = Keyword.get(opts, :start_index, 0)
    is_more = Keyword.get(opts, :is_more, false)

    %{
      "count" => length(data),
      "data" => data,
      "end_index" => start_index + length(data) - 1,
      "is_more" => is_more,
      "start_index" => start_index
    }
  end

  @doc "Builds a list of `count` resources of `resource_type`."
  @spec build_list(atom(), non_neg_integer(), map()) :: [map()]
  def build_list(resource_type, count, overrides \\ %{}) do
    Enum.map(1..count, fn _ -> build(resource_type, overrides) end)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp rand_hex, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  defp rand_barcode, do: :rand.uniform(9_999_999_999) |> Integer.to_string()
  defp utc_now, do: DateTime.utc_now() |> DateTime.to_iso8601()
end

defmodule Marqeta.Test.BypassHelper do
  @moduledoc """
  Helpers for setting up Bypass HTTP mock servers in tests.

  ## Usage

      defmodule MyTest do
        use ExUnit.Case, async: true
        import Marqeta.Test.Factory
        import Marqeta.Test.BypassHelper

        setup do
          bypass = Bypass.open()
          configure_marqeta(bypass)
          {:ok, bypass: bypass}
        end

        test "creates a user", %{bypass: bypass} do
          user = build(:user)
          expect_post(bypass, "/users", user)
          assert {:ok, result} = Marqeta.Users.create(%{first_name: "Jane"})
          assert result["token"] == user["token"]
        end
      end
  """

  @doc "Configures the Marqeta client to use a Bypass server for this test."
  @spec configure_marqeta(term()) :: :ok
  def configure_marqeta(bypass) do
    Application.put_env(:marqeta, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:marqeta, :application_token, "test_app_token")
    Application.put_env(:marqeta, :admin_access_token, "test_admin_token")
    Application.put_env(:marqeta, :retry_max_attempts, 0)
    Marqeta.Config.invalidate()
    :ok
  end

  @doc "Expects one GET to `path` and responds with `body` JSON-encoded."
  @spec expect_get(term(), String.t(), map() | list(), non_neg_integer()) :: :ok
  def expect_get(bypass, path, body, status \\ 200) do
    Bypass.expect_once(bypass, "GET", path, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(status, Jason.encode!(body))
    end)
  end

  @doc "Expects one POST to `path` and responds with `body`."
  @spec expect_post(term(), String.t(), map(), non_neg_integer()) :: :ok
  def expect_post(bypass, path, body, status \\ 201) do
    Bypass.expect_once(bypass, "POST", path, fn conn ->
      {:ok, _raw, conn} = Plug.Conn.read_body(conn)

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(status, Jason.encode!(body))
    end)
  end

  @doc "Expects one PUT to `path` and responds with `body`."
  @spec expect_put(term(), String.t(), map(), non_neg_integer()) :: :ok
  def expect_put(bypass, path, body, status \\ 200) do
    Bypass.expect_once(bypass, "PUT", path, fn conn ->
      {:ok, _raw, conn} = Plug.Conn.read_body(conn)

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(status, Jason.encode!(body))
    end)
  end

  @doc "Expects one DELETE to `path` and responds with `body`."
  @spec expect_delete(term(), String.t(), map(), non_neg_integer()) :: :ok
  def expect_delete(bypass, path, body \\ %{}, status \\ 200) do
    Bypass.expect_once(bypass, "DELETE", path, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(status, Jason.encode!(body))
    end)
  end

  @doc "Expects one request and responds with an error payload."
  @spec expect_error(term(), String.t(), String.t(), map(), non_neg_integer()) :: :ok
  def expect_error(bypass, method, path, error_body, status \\ 400) do
    Bypass.expect_once(bypass, method, path, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(status, Jason.encode!(error_body))
    end)
  end

  @doc "Sets up a paginated list GET expectation with `items` as data."
  @type expect_list_opts :: [
          {:status, pos_integer()}
          | {:is_more, boolean()}
          | {:start_index, non_neg_integer()}
        ]

  @spec expect_list(
          Bypass.t(),
          binary(),
          list(),
          expect_list_opts()
        ) :: term()
  def expect_list(bypass, path, items, opts \\ []) do
    status = Keyword.get(opts, :status, 200)
    is_more = Keyword.get(opts, :is_more, false)
    start_index = Keyword.get(opts, :start_index, 0)

    body = %{
      "count" => length(items),
      "data" => items,
      "end_index" => start_index + length(items) - 1,
      "is_more" => is_more,
      "start_index" => start_index
    }

    expect_get(bypass, path, body, status)
  end
end
