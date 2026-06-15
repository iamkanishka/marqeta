defmodule Marqeta.DiVA do
  @moduledoc """
  The DiVA (Data and Insights Visualization API) provides high-performance,
  read-only access to aggregated, denormalised reporting views over all
  Core API and Credit API data.

  Use DiVA for bulk reporting and analytics. For real-time single-record
  lookups, use the corresponding Core API modules.

  ## Common Query Parameters

  All DiVA list endpoints support:

  | Parameter     | Description |
  |---|---|
  | `start_date`  | ISO 8601 date string, e.g. `"2024-01-01"` |
  | `end_date`    | ISO 8601 date string |
  | `count`       | Records per page (max 1000) |
  | `start_index` | Pagination offset |
  | `sort_by`     | Field to sort by |
  | `sort_order`  | `"ASC"` or `"DESC"` |
  | `fields`      | Comma-separated field selection |

  ## Examples

      # One page
      {:ok, page} = Marqeta.DiVA.Authorizations.list(%{
        start_date: "2024-01-01",
        end_date:   "2024-01-31",
        count:      500
      })

      # Stream all
      Marqeta.DiVA.Settlements.stream(%{start_date: "2024-01-01"})
      |> Enum.count()

      # Data dictionary for a view
      {:ok, dict} = Marqeta.DiVA.DataDictionary.get("authorizations")
  """
end

defmodule Marqeta.DiVA.Base do
  @moduledoc false

  defmacro __using__(opts) do
    path = Keyword.fetch!(opts, :path)
    resource = Keyword.get(opts, :resource, "DiVA record")

    quote do
      alias Marqeta.{Client, Pagination}
      alias Marqeta.Stream, as: MStream

      @_path unquote(path)
      @_resource unquote(resource)

      @doc """
      Lists #{@_resource} records.

      ## Parameters
      - `params` — Query params: `start_date`, `end_date`, `count`, `start_index`,
        `sort_by`, `sort_order`, `fields`.
      - `opts`   — Per-request overrides.
      """
      @spec list(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
      def list(params \\ %{}, opts \\ []) do
        Client.get(@_path, Keyword.put(opts, :params, params))
      end

      @doc "Lists #{@_resource} records. Raises on error."
      @spec list!(map(), keyword()) :: map()
      def list!(params \\ %{}, opts \\ []) do
        case list(params, opts) do
          {:ok, result} -> result
          {:error, error} -> raise error
        end
      end

      @doc """
      Returns a lazy `Stream` over all #{@_resource} records, auto-paginating.

      ## Example

          Marqeta.DiVA.Authorizations.stream(%{start_date: "2024-01-01"})
          |> Stream.filter(& &1["response_code"] == "00")
          |> Enum.count()
      """
      @spec stream(map(), keyword()) :: Enumerable.t()
      def stream(params \\ %{}, opts \\ []) do
        MStream.stream(fn p -> list(p, opts) end, params)
      end

      @doc "Returns the data dictionary (field definitions) for this DiVA view."
      @spec data_dictionary(keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
      def data_dictionary(opts \\ []) do
        view_name = @_path |> String.split("/") |> List.last()
        Client.get("/diva/datadictionary/#{view_name}", opts)
      end

      defoverridable list: 2, list!: 2, stream: 2
    end
  end
end

# ─── Core DiVA Views ──────────────────────────────────────────────────────────

defmodule Marqeta.DiVA.Authorizations do
  @moduledoc """
  All authorization attempts (approvals and declines).

  Key fields: `transaction_token`, `card_token`, `user_token`, `amount`,
  `currency_code`, `merchant_name`, `mcc`, `network`, `response_code`,
  `stan`, `rrn`, `auth_code`, `pos_type`, `card_presence`, `pin_present`,
  `is_recurring`, `is_installment`, `country_code`, `created_time`.
  """
  use Marqeta.DiVA.Base, path: "/diva/authorizations", resource: "authorization"
end

defmodule Marqeta.DiVA.Settlements do
  @moduledoc """
  Cleared and settled transaction records.

  Key fields: `transaction_token`, `clearing_record_id`, `interchange_amount`,
  `settlement_date`, `funding_date`, `network_settlement_date`,
  `acquirer_reference_data`.
  """
  use Marqeta.DiVA.Base, path: "/diva/settlements", resource: "settlement"
end

defmodule Marqeta.DiVA.Declines do
  @moduledoc """
  All declined authorization attempts with reason codes.

  Key fields: `transaction_token`, `decline_reason`, `response_code`,
  `user_token`, `card_token`, `merchant_name`, `amount`, `network_response`.
  """
  use Marqeta.DiVA.Base, path: "/diva/declines", resource: "decline"
end

defmodule Marqeta.DiVA.Loads do
  @moduledoc """
  GPA funding events: loads, reloads, and unloads.

  Key fields: `gpa_order_token`, `user_token`, `amount`, `funding_source_token`,
  `funding_source_type`, `load_type`, `state`.
  """
  use Marqeta.DiVA.Base, path: "/diva/loads", resource: "load"
end

defmodule Marqeta.DiVA.Chargebacks do
  @moduledoc """
  Chargeback records and dispute outcomes.

  Key fields: `transaction_token`, `original_transaction_token`, `chargeback_amount`,
  `network`, `reason_code`, `state`, `win_loss`.
  """
  use Marqeta.DiVA.Base, path: "/diva/chargebacks", resource: "chargeback"
end

defmodule Marqeta.DiVA.CardCounts do
  @moduledoc """
  Card inventory counts aggregated by day and card state.

  Key fields: `report_date`, `card_product_token`, `state`, `count`.
  """
  use Marqeta.DiVA.Base, path: "/diva/cardcounts", resource: "card count"
end

defmodule Marqeta.DiVA.UserCounts do
  @moduledoc """
  User count aggregates by day and KYC state.

  Key fields: `report_date`, `state`, `kyc_state`, `count`.
  """
  use Marqeta.DiVA.Base, path: "/diva/usercounts", resource: "user count"
end

defmodule Marqeta.DiVA.ActivityBalances do
  @moduledoc """
  GPA balance snapshots aggregated by day per user.

  Key fields: `report_date`, `user_token`, `gpa_balance`, `available_balance`,
  `pending_credits`, `ledger_balance`, `impacted_amount`.
  """
  use Marqeta.DiVA.Base, path: "/diva/activitybalances", resource: "activity balance"
end

defmodule Marqeta.DiVA.ActivityBalancesFundingDay do
  @moduledoc "GPA balance snapshots aggregated by funding day."
  use Marqeta.DiVA.Base,
    path: "/diva/activitybalancesfundingday",
    resource: "activity balance (funding day)"
end

defmodule Marqeta.DiVA.ActivityBalancesNetworkDetail do
  @moduledoc "GPA balance activity broken down by network (Visa, Mastercard, etc.)."
  use Marqeta.DiVA.Base,
    path: "/diva/activitybalancesnetworkdetail",
    resource: "activity balance network detail"
end

defmodule Marqeta.DiVA.ClearingDetail do
  @moduledoc """
  Individual clearing file records with interchange information.

  Key fields: `clearing_record_id`, `transaction_token`, `interchange_rate`,
  `interchange_amount`, `network_fees`, `settlement_amount`, `funding_amount`.
  """
  use Marqeta.DiVA.Base, path: "/diva/clearingdetail", resource: "clearing detail"
end

defmodule Marqeta.DiVA.Cards do
  @moduledoc "Denormalised card inventory records with fulfillment and lifecycle data."
  use Marqeta.DiVA.Base, path: "/diva/cards", resource: "card (DiVA)"

  alias Marqeta.Client

  @doc "Returns DiVA card data for a specific card token."
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def get(card_token, opts \\ []) do
    Client.get("/diva/cards/#{card_token}", opts)
  end
end

defmodule Marqeta.DiVA.Users do
  @moduledoc "Denormalised user records with KYC and account holder data."
  use Marqeta.DiVA.Base, path: "/diva/users", resource: "user (DiVA)"

  alias Marqeta.Client

  @doc "Returns DiVA user data for a specific user token."
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def get(user_token, opts \\ []) do
    Client.get("/diva/users/#{user_token}", opts)
  end
end

defmodule Marqeta.DiVA.DirectDeposit do
  @moduledoc """
  Direct deposit (ACH inbound) transaction reporting.

  Key fields: `transaction_token`, `user_token`, `amount`, `company_name`,
  `company_id`, `individual_name`, `addenda`, `entry_class_code`.
  """
  use Marqeta.DiVA.Base, path: "/diva/directdeposit", resource: "direct deposit"
end

defmodule Marqeta.DiVA.ACHGateway do
  @moduledoc "ACH gateway reporting: returns, NOCs (notifications of change), and pre-notifications."
  use Marqeta.DiVA.Base, path: "/diva/achgateway", resource: "ACH gateway record"
end

defmodule Marqeta.DiVA.ACHOrigination do
  @moduledoc "ACH origination reporting: all ACH transfers originated by the program."
  use Marqeta.DiVA.Base, path: "/diva/achorigination", resource: "ACH origination record"
end

defmodule Marqeta.DiVA.ACHPending do
  @moduledoc "ACH pending records: transfers awaiting settlement."
  use Marqeta.DiVA.Base, path: "/diva/achpending", resource: "ACH pending record"
end

defmodule Marqeta.DiVA.ACHVerification do
  @moduledoc "ACH micro-deposit verification records."
  use Marqeta.DiVA.Base, path: "/diva/achverification", resource: "ACH verification record"
end

defmodule Marqeta.DiVA.PlatformResponse do
  @moduledoc """
  JIT Gateway performance metrics.

  Key fields: `report_date`, `avg_response_time_ms`, `p95_response_time_ms`,
  `p99_response_time_ms`, `timeout_count`, `timeout_rate`, `request_count`,
  `gateway_url`.
  """
  use Marqeta.DiVA.Base, path: "/diva/platformresponse", resource: "platform response"
end

defmodule Marqeta.DiVA.ProgramBalancesSettlement do
  @moduledoc "Program-level balance settlement data by settlement date."
  use Marqeta.DiVA.Base,
    path: "/diva/programbalancessettlement",
    resource: "program balance settlement"
end

defmodule Marqeta.DiVA.ProgramFundingBalances do
  @moduledoc "Program funding source balance history."
  use Marqeta.DiVA.Base,
    path: "/diva/programfundingbalances",
    resource: "program funding balance"
end

defmodule Marqeta.DiVA.RTDAuthorizations do
  @moduledoc """
  Real-Time Decisioning authorization data.
  Includes rule evaluation results and decision for each authorization.
  """
  use Marqeta.DiVA.Base, path: "/diva/rtdauthorizations", resource: "RTD authorization"
end

defmodule Marqeta.DiVA.RTDTransactionCountByRules do
  @moduledoc "Real-Time Decisioning transaction counts aggregated by rule."
  use Marqeta.DiVA.Base,
    path: "/diva/rtdtransactioncountbyrules",
    resource: "RTD transaction count by rule"
end

defmodule Marqeta.DiVA.CoreAPITransactionToken do
  @moduledoc "Look up DiVA records by Core API transaction token for cross-system correlation."
  use Marqeta.DiVA.Base,
    path: "/diva/coreapitransactiontoken",
    resource: "Core API transaction token mapping"
end

# ─── Credit DiVA Views ────────────────────────────────────────────────────────

defmodule Marqeta.DiVA.CreditAccounts do
  @moduledoc """
  Denormalised credit account reporting data.

  Key fields: `account_token`, `user_token`, `bundle_token`, `credit_limit`,
  `current_balance`, `available_credit`, `status`, `billing_cycle_day`,
  `payment_due_date`, `minimum_payment_due`.
  """
  use Marqeta.DiVA.Base, path: "/diva/creditaccounts", resource: "credit account (DiVA)"
end

defmodule Marqeta.DiVA.CreditCards do
  @moduledoc "Denormalised credit card data for credit platform accounts."
  use Marqeta.DiVA.Base, path: "/diva/creditcards", resource: "credit card (DiVA)"
end

defmodule Marqeta.DiVA.CreditAccountDailyBalances do
  @moduledoc """
  Daily balance snapshots for credit accounts.

  Key fields: `report_date`, `account_token`, `current_balance`, `available_credit`,
  `statement_balance`, `minimum_payment_due`, `past_due_amount`.
  """
  use Marqeta.DiVA.Base,
    path: "/diva/creditaccountdailybalances",
    resource: "credit account daily balance"
end

defmodule Marqeta.DiVA.CreditJournalEntries do
  @moduledoc "Credit account journal entries: purchases, payments, fees, interest, rewards."
  use Marqeta.DiVA.Base,
    path: "/diva/creditjournalentries",
    resource: "credit journal entry (DiVA)"
end

defmodule Marqeta.DiVA.CreditLedgerEntries do
  @moduledoc "Credit account ledger entries with balance impact amounts."
  use Marqeta.DiVA.Base, path: "/diva/creditledgerentries", resource: "credit ledger entry (DiVA)"
end

defmodule Marqeta.DiVA.CreditPayments do
  @moduledoc "Credit account payment records."
  use Marqeta.DiVA.Base, path: "/diva/creditpayments", resource: "credit payment (DiVA)"
end

defmodule Marqeta.DiVA.CreditDisputes do
  @moduledoc "Credit account dispute records with resolution status."
  use Marqeta.DiVA.Base, path: "/diva/creditdisputes", resource: "credit dispute (DiVA)"
end

defmodule Marqeta.DiVA.CreditRewards do
  @moduledoc "Credit reward accruals, redemptions, and current balances."
  use Marqeta.DiVA.Base, path: "/diva/creditrewards", resource: "credit reward (DiVA)"
end

defmodule Marqeta.DiVA.CreditStatements do
  @moduledoc "Credit account billing cycle statement data."
  use Marqeta.DiVA.Base, path: "/diva/creditstatements", resource: "credit statement (DiVA)"
end

defmodule Marqeta.DiVA.CreditAccountAdjustments do
  @moduledoc "Credit account manual adjustment records."
  use Marqeta.DiVA.Base,
    path: "/diva/creditaccountadjustments",
    resource: "credit account adjustment (DiVA)"
end

# ─── Views & Data Dictionary ──────────────────────────────────────────────────

defmodule Marqeta.DiVA.Views do
  @moduledoc """
  Lists all available DiVA view names.

  ## Example

      {:ok, page} = Marqeta.DiVA.Views.list()
      Enum.each(page["data"], &IO.puts(&1["name"]))
  """
  use Marqeta.DiVA.Base, path: "/diva/views", resource: "DiVA view"
end

defmodule Marqeta.DiVA.DataDictionary do
  @moduledoc """
  Retrieve field definitions, types, and descriptions for any DiVA view.

  ## Examples

      # All view dictionaries
      {:ok, all} = Marqeta.DiVA.DataDictionary.list()

      # Specific view
      {:ok, dict} = Marqeta.DiVA.DataDictionary.get("authorizations")
      # Returns: [%{"name" => "transaction_token", "type" => "string", ...}, ...]
  """

  alias Marqeta.Client

  @doc "Lists data dictionary entries for all DiVA views."
  @spec list(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list(params \\ %{}, opts \\ []) do
    Client.get("/diva/datadictionary", Keyword.put(opts, :params, params))
  end

  @doc "Returns the data dictionary for a specific DiVA view by name."
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def get(view_name, opts \\ []) do
    Client.get("/diva/datadictionary/#{view_name}", opts)
  end
end
