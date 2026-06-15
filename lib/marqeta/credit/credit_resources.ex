# ─────────────────────────────────────────────────────────────────────────────
# Marqeta Credit Platform — All 25 modules
# ─────────────────────────────────────────────────────────────────────────────

defmodule Marqeta.Credit.Base do
  @moduledoc false

  @spec __using__(keyword()) ::
          {:__block__, [],
           [
             {:@, [...], [...]}
             | {:alias, [...], [...]}
             | {:defp, [...], [...]}
             | {:if, [...], [...]},
             ...
           ]}
  @doc """
  Generates standard sub-resource CRUD for credit account-scoped endpoints.

  All credit sub-resources live under `/credit/accounts/{account_token}/...`
  so we can't use the standard `Marqeta.Resource` macro directly.
  """
  defmacro __using__(opts) do
    sub_path = Keyword.fetch!(opts, :sub_path)
    resource = Keyword.get(opts, :resource, "resource")
    has_create = Keyword.get(opts, :create, true)
    has_get = Keyword.get(opts, :get, true)
    has_update = Keyword.get(opts, :update, true)
    has_list = Keyword.get(opts, :list, true)
    has_delete = Keyword.get(opts, :delete, false)

    quote do
      alias Marqeta.{Client, Error}
      alias Marqeta.Stream, as: MStream

      @_sub unquote(sub_path)
      @_res unquote(resource)

      defp account_path(account_token),
        do: "/credit/accounts/#{account_token}/#{@_sub}"

      defp item_path(account_token, token),
        do: "/credit/accounts/#{account_token}/#{@_sub}/#{token}"

      if unquote(has_create) do
        @doc "Creates a #{@_res} on a credit account."
        @spec create(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
        def create(account_token, params, opts \\ []) do
          Client.post(account_path(account_token), params, opts)
        end

        @doc "Creates a #{@_res}. Raises on error."
        @spec create!(String.t(), map(), keyword()) :: map()
        def create!(account_token, params, opts \\ []) do
          case create(account_token, params, opts) do
            {:ok, r} -> r
            {:error, e} -> raise e
          end
        end
      end

      if unquote(has_get) do
        @doc "Retrieves a #{@_res} by token."
        @spec get(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
        def get(account_token, token, opts \\ []) do
          Client.get(item_path(account_token, token), opts)
        end

        @doc "Retrieves a #{@_res}. Raises on error."
        @spec get!(String.t(), String.t(), keyword()) :: map()
        def get!(account_token, token, opts \\ []) do
          case get(account_token, token, opts) do
            {:ok, r} -> r
            {:error, e} -> raise e
          end
        end
      end

      if unquote(has_update) do
        @doc "Updates a #{@_res}."
        @spec update(String.t(), String.t(), map(), keyword()) ::
                {:ok, map()} | {:error, Error.t()}
        def update(account_token, token, params, opts \\ []) do
          Client.put(item_path(account_token, token), params, opts)
        end

        @doc "Updates a #{@_res}. Raises on error."
        @spec update!(String.t(), String.t(), map(), keyword()) :: map()
        def update!(account_token, token, params, opts \\ []) do
          case update(account_token, token, params, opts) do
            {:ok, r} -> r
            {:error, e} -> raise e
          end
        end
      end

      if unquote(has_list) do
        @doc "Lists #{@_res} records on a credit account."
        @spec list(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
        def list(account_token, params \\ %{}, opts \\ []) do
          Client.get(account_path(account_token), Keyword.put(opts, :params, params))
        end

        @doc "Lists #{@_res} records. Raises on error."
        @spec list!(String.t(), map(), keyword()) :: map()
        def list!(account_token, params \\ %{}, opts \\ []) do
          case list(account_token, params, opts) do
            {:ok, r} -> r
            {:error, e} -> raise e
          end
        end

        @doc "Returns a lazy stream of all #{@_res} records for an account."
        @spec stream(String.t(), map()) :: Enumerable.t()
        def stream(account_token, params \\ %{}) do
          MStream.stream(fn p -> list(account_token, p) end, params)
        end
      end

      if unquote(has_delete) do
        @doc "Deletes a #{@_res}."
        @spec delete(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
        def delete(account_token, token, opts \\ []) do
          Client.delete(item_path(account_token, token), opts)
        end
      end
    end
  end
end

# ─── Credit Accounts ─────────────────────────────────────────────────────────

defmodule Marqeta.Credit.Accounts do
  @moduledoc """
  Create and manage credit accounts (the core object of the credit platform).

  A credit account centres around a single credit line, accessed by one or
  more cards. APR, fees, and rewards are inherited from the bundle's policies.

  ## Credit Limit
  Range: 0–1,000,000. Required at creation.

  ## Config Fields
  - `billing_cycle_day` — Day of month billing closes (1–28)
  - `payment_due_interval` — Days after billing close that payment is due
  - `e_disclosure_active` — Electronic disclosure consent
  - `card_level` — `PREMIUM`, `TRADITIONAL`, or `NA`

  ## Examples

      {:ok, account} = Marqeta.Credit.Accounts.create(%{
        user_token:   "user_01",
        bundle_token: "bundle_01",
        credit_limit: 5_000.00,
        config: %{
          billing_cycle_day:    1,
          payment_due_interval: 25,
          e_disclosure_active:  true,
          card_level:           "TRADITIONAL"
        }
      })
  """
  use Marqeta.Resource, path: "/credit/accounts", resource: "credit account"

  alias Marqeta.Client

  @doc "Returns the current balance for a credit account."
  @spec balance(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def balance(token, opts \\ []) do
    Client.get("/credit/accounts/#{token}/balances", opts)
  end

  @doc "Lists credit accounts for a user."
  @spec list_by_user(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_by_user(user_token, params \\ %{}, opts \\ []) do
    Client.get("/credit/accounts/user/#{user_token}", Keyword.put(opts, :params, params))
  end

  @doc "Lists credit accounts for a business."
  @spec list_by_business(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_by_business(token, params \\ %{}, opts \\ []) do
    Client.get("/credit/accounts/business/#{token}", Keyword.put(opts, :params, params))
  end

  @doc "Streams credit accounts for a user."
  @spec stream_by_user(String.t(), map()) :: Enumerable.t()
  def stream_by_user(user_token, params \\ %{}) do
    Marqeta.Stream.stream(fn p -> list_by_user(user_token, p) end, params)
  end
end

# ─── Credit Cards ─────────────────────────────────────────────────────────────

defmodule Marqeta.Credit.Cards do
  @moduledoc "Cards that access a credit account's credit line."
  use Marqeta.Credit.Base,
    sub_path: "cards",
    resource: "credit card",
    update: false,
    delete: false

  alias Marqeta.Client

  @doc "Shows the PAN and CVV for a credit card (PCI DSS required)."
  @spec show_pan(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def show_pan(account_token, card_token, opts \\ []) do
    Client.get(
      "/credit/accounts/#{account_token}/cards/#{card_token}?show_pan=true&show_cvv_number=true",
      opts
    )
  end
end

# ─── Credit Applications ─────────────────────────────────────────────────────

defmodule Marqeta.Credit.Applications do
  @moduledoc """
  Manage the credit card application lifecycle, including
  regulatory disclosure retrieval and status transitions.
  """
  use Marqeta.Resource, path: "/credit/applications", resource: "credit application"

  alias Marqeta.Client

  @doc "Retrieves regulatory disclosures for an application."
  @spec disclosures(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def disclosures(application_token, opts \\ []) do
    Client.get("/credit/applications/#{application_token}/disclosures", opts)
  end

  @doc "Transitions an application to a new state."
  @spec transition(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def transition(application_token, params, opts \\ []) do
    Client.post("/credit/applications/#{application_token}/transitions", params, opts)
  end

  @doc "Lists application transitions."
  @spec list_transitions(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_transitions(application_token, params \\ %{}, opts \\ []) do
    Client.get(
      "/credit/applications/#{application_token}/transitions",
      Keyword.put(opts, :params, params)
    )
  end
end

# ─── Bundles, Products, Policies ──────────────────────────────────────────────

defmodule Marqeta.Credit.Bundles do
  @moduledoc "Bundles combine credit product policies into a single configurable template."
  use Marqeta.Resource, path: "/credit/bundles", resource: "credit bundle"
end

defmodule Marqeta.Credit.Products do
  @moduledoc "Credit products define the behaviours and features of credit accounts."
  use Marqeta.Resource, path: "/credit/products", resource: "credit product"
end

defmodule Marqeta.Credit.Policies do
  @moduledoc """
  Manage policy configurations: documents, APRs, fees, and rewards.
  Policies are attached to bundles which are then attached to accounts.
  """
  use Marqeta.Resource, path: "/credit/policies", resource: "credit policy"

  alias Marqeta.Client

  @doc "Lists document policies."
  @spec list_document_policies(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_document_policies(params \\ %{}, opts \\ []) do
    Client.get("/credit/policies/documents", Keyword.put(opts, :params, params))
  end

  @doc "Retrieves a document policy."
  @spec get_document_policy(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def get_document_policy(token, opts \\ []) do
    Client.get("/credit/policies/documents/#{token}", opts)
  end

  @doc "Creates a document policy."
  @spec create_document_policy(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def create_document_policy(params, opts \\ []) do
    Client.post("/credit/policies/documents", params, opts)
  end

  @doc "Updates a document policy."
  @spec update_document_policy(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def update_document_policy(token, params, opts \\ []) do
    Client.put("/credit/policies/documents/#{token}", params, opts)
  end

  @doc "Lists APR policies."
  @spec list_apr_policies(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_apr_policies(params \\ %{}, opts \\ []) do
    Client.get("/credit/policies/aprs", Keyword.put(opts, :params, params))
  end

  @doc "Retrieves an APR policy."
  @spec get_apr_policy(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def get_apr_policy(token, opts \\ []) do
    Client.get("/credit/policies/aprs/#{token}", opts)
  end

  @doc "Creates an APR policy."
  @spec create_apr_policy(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def create_apr_policy(params, opts \\ []) do
    Client.post("/credit/policies/aprs", params, opts)
  end

  @doc "Updates an APR policy."
  @spec update_apr_policy(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def update_apr_policy(token, params, opts \\ []) do
    Client.put("/credit/policies/aprs/#{token}", params, opts)
  end

  @doc "Lists fee policies."
  @spec list_fee_policies(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_fee_policies(params \\ %{}, opts \\ []) do
    Client.get("/credit/policies/fees", Keyword.put(opts, :params, params))
  end

  @doc "Retrieves a fee policy."
  @spec get_fee_policy(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def get_fee_policy(token, opts \\ []) do
    Client.get("/credit/policies/fees/#{token}", opts)
  end

  @doc "Creates a fee policy."
  @spec create_fee_policy(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def create_fee_policy(params, opts \\ []) do
    Client.post("/credit/policies/fees", params, opts)
  end

  @doc "Updates a fee policy."
  @spec update_fee_policy(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def update_fee_policy(token, params, opts \\ []) do
    Client.put("/credit/policies/fees/#{token}", params, opts)
  end

  @doc "Lists reward policies."
  @spec list_reward_policies(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_reward_policies(params \\ %{}, opts \\ []) do
    Client.get("/credit/policies/rewards", Keyword.put(opts, :params, params))
  end

  @doc "Retrieves a reward policy."
  @spec get_reward_policy(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def get_reward_policy(token, opts \\ []) do
    Client.get("/credit/policies/rewards/#{token}", opts)
  end

  @doc "Creates a reward policy."
  @spec create_reward_policy(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def create_reward_policy(params, opts \\ []) do
    Client.post("/credit/policies/rewards", params, opts)
  end

  @doc "Updates a reward policy."
  @spec update_reward_policy(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def update_reward_policy(token, params, opts \\ []) do
    Client.put("/credit/policies/rewards/#{token}", params, opts)
  end

  @doc "Creates a credit product policy."
  @spec create_product_policy(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def create_product_policy(params, opts \\ []) do
    Client.post("/credit/policies/products", params, opts)
  end

  @doc "Retrieves a credit product policy."
  @spec get_product_policy(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def get_product_policy(token, opts \\ []) do
    Client.get("/credit/policies/products/#{token}", opts)
  end

  @doc "Updates a credit product policy."
  @spec update_product_policy(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def update_product_policy(token, params, opts \\ []) do
    Client.put("/credit/policies/products/#{token}", params, opts)
  end
end

# ─── Payments ─────────────────────────────────────────────────────────────────

defmodule Marqeta.Credit.Payments do
  @moduledoc "Create and retrieve payments to pay down credit account balances."
  use Marqeta.Credit.Base,
    sub_path: "payments",
    resource: "credit payment",
    update: false,
    delete: false
end

defmodule Marqeta.Credit.PaymentSchedules do
  @moduledoc "Schedule one-time or recurring payments on a credit account."
  use Marqeta.Credit.Base,
    sub_path: "paymentschedules",
    resource: "payment schedule",
    delete: true
end

defmodule Marqeta.Credit.PaymentSources do
  @moduledoc "Manage external payment sources for credit account payments."
  use Marqeta.Credit.Base, sub_path: "paymentsources", resource: "payment source", delete: false
end

# ─── Journal & Ledger Entries ─────────────────────────────────────────────────

defmodule Marqeta.Credit.JournalEntries do
  @moduledoc """
  Read journal entries on a credit account.
  Includes purchases, interest, fees, rewards, payments, and adjustments.
  Journal entries are read-only — created by the platform.
  """
  use Marqeta.Credit.Base,
    sub_path: "journalentries",
    resource: "journal entry",
    create: false,
    update: false,
    delete: false
end

defmodule Marqeta.Credit.LedgerEntries do
  @moduledoc "Read ledger entries on a credit account with balance impact details."
  use Marqeta.Credit.Base,
    sub_path: "ledgerentries",
    resource: "ledger entry",
    create: false,
    update: false,
    delete: false
end

# ─── Statements ───────────────────────────────────────────────────────────────

defmodule Marqeta.Credit.Statements do
  @moduledoc "Retrieve billing cycle statements for credit accounts."
  use Marqeta.Credit.Base,
    sub_path: "statements",
    resource: "credit statement",
    create: false,
    update: false,
    delete: false

  alias Marqeta.Client

  @doc "Retrieves payment info for a specific statement."
  @spec payment_info(String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def payment_info(account_token, statement_token, opts \\ []) do
    Client.get(
      "/credit/accounts/#{account_token}/statements/#{statement_token}/paymentinfo",
      opts
    )
  end

  @doc "Lists line items for a specific statement."
  @spec line_items(String.t(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def line_items(account_token, statement_token, params \\ %{}, opts \\ []) do
    Client.get(
      "/credit/accounts/#{account_token}/statements/#{statement_token}/lineitems",
      Keyword.put(opts, :params, params)
    )
  end
end

# ─── Disputes ─────────────────────────────────────────────────────────────────

defmodule Marqeta.Credit.Disputes do
  @moduledoc "Create and manage disputes on a credit account."
  use Marqeta.Credit.Base, sub_path: "disputes", resource: "credit dispute"

  alias Marqeta.Client

  @doc "Transitions a dispute to a new state."
  @spec transition(String.t(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def transition(account_token, dispute_token, params, opts \\ []) do
    Client.post(
      "/credit/accounts/#{account_token}/disputes/#{dispute_token}/transitions",
      params,
      opts
    )
  end

  @doc "Lists evidence for a dispute."
  @spec list_evidence(String.t(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_evidence(account_token, dispute_token, params \\ %{}, opts \\ []) do
    Client.get(
      "/credit/accounts/#{account_token}/disputes/#{dispute_token}/evidence",
      Keyword.put(opts, :params, params)
    )
  end

  @doc "Submits evidence for a dispute."
  @spec submit_evidence(String.t(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def submit_evidence(account_token, dispute_token, params, opts \\ []) do
    Client.post(
      "/credit/accounts/#{account_token}/disputes/#{dispute_token}/evidence",
      params,
      opts
    )
  end
end

# ─── Adjustments ──────────────────────────────────────────────────────────────

defmodule Marqeta.Credit.Adjustments do
  @moduledoc "Manually adjust the amount of a journal entry or account balance."
  use Marqeta.Credit.Base,
    sub_path: "adjustments",
    resource: "credit adjustment",
    update: false,
    delete: false
end

# ─── Rewards ──────────────────────────────────────────────────────────────────

defmodule Marqeta.Credit.Rewards do
  @moduledoc "Create one-time, non-recurring rewards on a credit account."
  use Marqeta.Credit.Base,
    sub_path: "rewards",
    resource: "credit reward",
    update: false,
    delete: false
end

defmodule Marqeta.Credit.RewardAccounts do
  @moduledoc "Manage and query reward accounts linked to credit accounts."
  use Marqeta.Resource,
    path: "/credit/rewards/accounts",
    resource: "reward account",
    create: false,
    update: false

  alias Marqeta.Client

  @doc "Lists reward accrual records for a reward account."
  @spec accruals(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def accruals(token, params \\ %{}, opts \\ []) do
    Client.get(
      "/credit/rewards/accounts/#{token}/accruals",
      Keyword.put(opts, :params, params)
    )
  end
end

defmodule Marqeta.Credit.RewardRedemptions do
  @moduledoc "Create and retrieve reward redemptions on credit accounts."

  alias Marqeta.{Client, Error}
  alias Marqeta.Stream, as: MStream

  @doc "Creates a reward redemption."
  @spec create(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(account_token, params, opts \\ []) do
    Client.post("/credit/rewards/accounts/#{account_token}/redemptions", params, opts)
  end

  @doc "Retrieves a reward redemption."
  @spec get(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(account_token, redemption_token, opts \\ []) do
    Client.get("/credit/rewards/accounts/#{account_token}/redemptions/#{redemption_token}", opts)
  end

  @doc "Lists reward redemptions for an account."
  @spec list(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(account_token, params \\ %{}, opts \\ []) do
    Client.get(
      "/credit/rewards/accounts/#{account_token}/redemptions",
      Keyword.put(opts, :params, params)
    )
  end

  @doc "Streams reward redemptions for an account."
  @spec stream(String.t(), map()) :: Enumerable.t()
  def stream(account_token, params \\ %{}) do
    MStream.stream(fn p -> list(account_token, p) end, params)
  end
end

defmodule Marqeta.Credit.RewardRules do
  @moduledoc "Manage reward earning rules (e.g. 3x on dining, 1.5x on everything else)."
  use Marqeta.Resource, path: "/credit/rewards/rules", resource: "reward rule"
end

defmodule Marqeta.Credit.RewardConversions do
  @moduledoc "Manage conversion rates applied when redeeming reward points."
  use Marqeta.Resource, path: "/credit/rewards/conversions", resource: "reward conversion"
end

defmodule Marqeta.Credit.RewardGlobalConfigurations do
  @moduledoc "Global reward program configuration (expiry, rounding, currency)."
  use Marqeta.Resource,
    path: "/credit/rewards/configurations",
    resource: "reward global configuration"
end

# ─── Delinquency ──────────────────────────────────────────────────────────────

defmodule Marqeta.Credit.Delinquency do
  @moduledoc "Retrieve and manage credit account delinquency state."

  alias Marqeta.{Client, Error}

  @doc "Returns the current delinquency state for a credit account."
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(account_token, opts \\ []) do
    Client.get("/credit/accounts/#{account_token}/delinquency", opts)
  end

  @doc "Lists delinquency state transitions for a credit account."
  @spec transitions(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def transitions(account_token, params \\ %{}, opts \\ []) do
    Client.get(
      "/credit/accounts/#{account_token}/delinquency/transitions",
      Keyword.put(opts, :params, params)
    )
  end
end

# ─── Account Transitions ──────────────────────────────────────────────────────

defmodule Marqeta.Credit.Transitions do
  @moduledoc "Transition a credit account to a new status (ACTIVE, SUSPENDED, CLOSED, etc.)."

  alias Marqeta.{Client, Error}
  alias Marqeta.Stream, as: MStream

  @doc "Creates a credit account state transition."
  @spec create(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(account_token, params, opts \\ []) do
    Client.post("/credit/accounts/#{account_token}/transitions", params, opts)
  end

  @doc "Retrieves a credit account state transition."
  @spec get(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(account_token, transition_token, opts \\ []) do
    Client.get("/credit/accounts/#{account_token}/transitions/#{transition_token}", opts)
  end

  @doc "Lists transitions for a credit account."
  @spec list(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(account_token, params \\ %{}, opts \\ []) do
    Client.get(
      "/credit/accounts/#{account_token}/transitions",
      Keyword.put(opts, :params, params)
    )
  end

  @doc "Streams transitions for a credit account."
  @spec stream(String.t(), map()) :: Enumerable.t()
  def stream(account_token, params \\ %{}) do
    MStream.stream(fn p -> list(account_token, p) end, params)
  end
end

# ─── Substatuses ──────────────────────────────────────────────────────────────

defmodule Marqeta.Credit.Substatuses do
  @moduledoc """
  Apply or remove substatuses for fine-grained state management.
  Substatuses overlay the primary account status without replacing it.
  """
  use Marqeta.Resource, path: "/credit/substatuses", resource: "credit substatus"

  alias Marqeta.Client

  @doc "Applies a substatus to a credit account."
  @spec apply_to_account(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def apply_to_account(account_token, params, opts \\ []) do
    Client.post("/credit/accounts/#{account_token}/substatuses", params, opts)
  end

  @doc "Removes a substatus from a credit account."
  @spec remove_from_account(String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def remove_from_account(account_token, substatus_token, opts \\ []) do
    Client.delete("/credit/accounts/#{account_token}/substatuses/#{substatus_token}", opts)
  end

  @doc "Lists substatuses on a credit account."
  @spec list_for_account(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_for_account(account_token, params \\ %{}, opts \\ []) do
    Client.get(
      "/credit/accounts/#{account_token}/substatuses",
      Keyword.put(opts, :params, params)
    )
  end
end

# ─── Refunds & Balance Refunds ────────────────────────────────────────────────

defmodule Marqeta.Credit.Refunds do
  @moduledoc "Issue refunds on a credit account."
  use Marqeta.Credit.Base,
    sub_path: "refunds",
    resource: "credit refund",
    update: false,
    delete: false
end

defmodule Marqeta.Credit.BalanceRefunds do
  @moduledoc "Issue balance refunds on a credit account with a negative balance."
  use Marqeta.Credit.Base,
    sub_path: "balancerefunds",
    resource: "balance refund",
    update: false,
    delete: false
end

# ─── Program Gateways ─────────────────────────────────────────────────────────

defmodule Marqeta.Credit.ProgramGateways do
  @moduledoc "Manage program gateways for credit platform integrations."
  use Marqeta.Resource, path: "/credit/programgateways", resource: "credit program gateway"
end
