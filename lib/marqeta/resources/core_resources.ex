defmodule Marqeta.CardProducts do
  @moduledoc """
  Card product templates that define card behaviour, fulfillment, JIT funding
  mode, velocity controls, contactless SCA limits, and more.

  Every card issued on your program is derived from a card product.

  ## Examples

      {:ok, cp} = Marqeta.CardProducts.create(%{
        name: "My Virtual Prepaid Card",
        start_date: "2024-01-01",
        config: %{
          card_life_cycle: %{activate_upon_issue: true},
          fulfillment: %{payment_instrument: "VIRTUAL_PAN"},
          jit_funding: %{
            program_funding_source: %{
              funding_source_token: "my_program_fs",
              enabled: true
            }
          }
        }
      })
  """
  use Marqeta.Resource, path: "/cardproducts", resource: "card product"
end

defmodule Marqeta.CardTransitions do
  @moduledoc """
  Manage card state transitions.

  ## States
  - `UNACTIVATED` → `ACTIVE` — first activation
  - `ACTIVE` → `SUSPENDED` — temporary hold
  - `SUSPENDED` → `ACTIVE` — reactivate
  - `ACTIVE` / `SUSPENDED` → `TERMINATED` — permanent close

  ## Channels
  `API`, `FRAUD`, `IVR`, `ADMIN`, `SYSTEM`, `CARDHOLDER`, `NETWORK`

  ## Reason Codes
  `00` New/replacement card, `01` Mechanical failure, `02` Suspected fraud,
  `04` Lost, `05` Stolen, `06` Loss of card privileges, `07` Card damaged,
  `08` Named: cardholder requested, `10` Excessive PIN failures, `16` Account closed,
  `23` Terminal error, `99` Administrative action.

  ## Examples

      {:ok, _} = Marqeta.CardTransitions.create(%{
        card_token: "card_01",
        state: "ACTIVE",
        reason_code: "00",
        channel: "API"
      })
  """
  use Marqeta.Resource, path: "/cardtransitions", resource: "card transition", update: false

  alias Marqeta.Client

  @doc "Lists all state transitions for a specific card."
  @spec list_by_card(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_by_card(card_token, params \\ %{}, opts \\ []) do
    Client.get("/cardtransitions/card/#{card_token}", Keyword.put(opts, :params, params))
  end

  @doc "Streams state transitions for a specific card."
  @spec stream_by_card(String.t(), map()) :: Enumerable.t()
  def stream_by_card(card_token, params \\ %{}) do
    Marqeta.Stream.stream(fn p -> list_by_card(card_token, p) end, params)
  end
end

defmodule Marqeta.Businesses do
  @moduledoc """
  Business account holders with KYC via EIN and beneficial owner structures.
  Businesses can own cards and hold GPAs.
  """
  use Marqeta.Resource, path: "/businesses", resource: "business"

  alias Marqeta.Client

  @doc "Lists child businesses of a parent business."
  @spec list_children(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_children(token, params \\ %{}, opts \\ []) do
    Client.get("/businesses/#{token}/children", Keyword.put(opts, :params, params))
  end

  @doc "Lists cards belonging to a business."
  @spec list_cards(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_cards(token, params \\ %{}, opts \\ []) do
    Client.get("/cards/business/#{token}", Keyword.put(opts, :params, params))
  end

  @doc "Returns the GPA balance for a business."
  @spec balances(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def balances(token, opts \\ []) do
    Client.get("/balances/#{token}", opts)
  end

  @doc "Lists transactions for a business."
  @spec transactions(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def transactions(token, params \\ %{}, opts \\ []) do
    Client.get("/transactions/business/#{token}", Keyword.put(opts, :params, params))
  end

  @doc "Streams transactions for a business."
  @spec stream_transactions(String.t(), map()) :: Enumerable.t()
  def stream_transactions(token, params \\ %{}) do
    Marqeta.Stream.stream(fn p -> transactions(token, p) end, params)
  end

  @doc "Lists notes on a business."
  @spec list_notes(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_notes(token, params \\ %{}, opts \\ []) do
    Client.get("/businesses/#{token}/notes", Keyword.put(opts, :params, params))
  end

  @doc "Creates a note on a business."
  @spec create_note(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def create_note(token, params, opts \\ []) do
    Client.post("/businesses/#{token}/notes", params, opts)
  end
end

defmodule Marqeta.BusinessTransitions do
  @moduledoc "Manage business state transitions (UNVERIFIED → LIMITED → ACTIVE → SUSPENDED → CLOSED)."
  use Marqeta.Resource,
    path: "/businesstransitions",
    resource: "business transition",
    update: false

  alias Marqeta.Client

  @doc "Lists all state transitions for a business."
  @spec list_by_business(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_by_business(token, params \\ %{}, opts \\ []) do
    Client.get("/businesstransitions/business/#{token}", Keyword.put(opts, :params, params))
  end
end

defmodule Marqeta.UserTransitions do
  @moduledoc "Manage user state transitions (UNVERIFIED → LIMITED → ACTIVE → SUSPENDED → CLOSED)."
  use Marqeta.Resource, path: "/usertransitions", resource: "user transition", update: false

  alias Marqeta.Client

  @doc "Lists all state transitions for a user."
  @spec list_by_user(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_by_user(token, params \\ %{}, opts \\ []) do
    Client.get("/usertransitions/user/#{token}", Keyword.put(opts, :params, params))
  end
end

defmodule Marqeta.Transactions do
  @moduledoc """
  Retrieve transaction records. Transactions are read-only — they are created
  by Marqeta when cardholders transact.

  ## Transaction Types
  `authorization`, `authorization.clearing`, `authorization.reversal`,
  `pindebit`, `pindebit.reversal`, `refund`, `refund.clearing`,
  `gpa.credit`, `gpa.credit.reversal`, `gpa.debit`, `transfer.peer`,
  `fee.charge`, `msa.credit`, `msa.debit`, `account.funding`

  ## Transaction States
  `PENDING`, `COMPLETION`, `DECLINED`, `ERROR`

  For large datasets, use `Marqeta.DiVA.Authorizations` or
  `Marqeta.DiVA.Settlements` which are optimised for bulk reads.
  """
  use Marqeta.Resource,
    path: "/transactions",
    resource: "transaction",
    create: false,
    update: false

  alias Marqeta.Client

  @doc "Lists transactions for a user."
  @spec list_by_user(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_by_user(user_token, params \\ %{}, opts \\ []) do
    Client.get("/transactions/user/#{user_token}", Keyword.put(opts, :params, params))
  end

  @doc "Lists transactions for a business."
  @spec list_by_business(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_by_business(token, params \\ %{}, opts \\ []) do
    Client.get("/transactions/business/#{token}", Keyword.put(opts, :params, params))
  end

  @doc "Lists transactions for a card."
  @spec list_by_card(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_by_card(card_token, params \\ %{}, opts \\ []) do
    Client.get("/transactions/card/#{card_token}", Keyword.put(opts, :params, params))
  end

  @doc "Lists related transactions (e.g. reversals, clearings) for a transaction."
  @spec list_related(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_related(token, params \\ %{}, opts \\ []) do
    Client.get("/transactions/#{token}/related", Keyword.put(opts, :params, params))
  end

  @doc "Streams transactions for a user."
  @spec stream_by_user(String.t(), map()) :: Enumerable.t()
  def stream_by_user(token, params \\ %{}) do
    Marqeta.Stream.stream(fn p -> list_by_user(token, p) end, params)
  end

  @doc "Streams transactions for a business."
  @spec stream_by_business(String.t(), map()) :: Enumerable.t()
  def stream_by_business(token, params \\ %{}) do
    Marqeta.Stream.stream(fn p -> list_by_business(token, p) end, params)
  end

  @doc "Streams transactions for a card."
  @spec stream_by_card(String.t(), map()) :: Enumerable.t()
  def stream_by_card(token, params \\ %{}) do
    Marqeta.Stream.stream(fn p -> list_by_card(token, p) end, params)
  end
end

defmodule Marqeta.Balances do
  @moduledoc """
  Retrieve GPA and MSA balance details for users and businesses.
  """
  use Marqeta.Resource,
    path: "/balances",
    resource: "balance",
    create: false,
    get: false,
    update: false,
    list: false

  alias Marqeta.Client

  @doc "Returns GPA balance for a user or business by token."
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def get(token, opts \\ []) do
    Client.get("/balances/#{token}", opts)
  end

  @doc "Lists MSA (Merchant-Specific Account) balances for a user."
  @spec list_msa(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_msa(token, params \\ %{}, opts \\ []) do
    Client.get("/balances/#{token}/msas", Keyword.put(opts, :params, params))
  end
end

defmodule Marqeta.GPAOrders do
  @moduledoc """
  Load and unload funds in user and business General Purpose Accounts (GPAs).

  ## Examples

      # Load $100 into a user's GPA
      {:ok, order} = Marqeta.GPAOrders.create(%{
        user_token: "user_01",
        amount: 100.00,
        currency_code: "USD",
        funding_source_token: "program_fs_01",
        memo: "Welcome bonus"
      })

      # Unload (reverse) a GPA order
      {:ok, _} = Marqeta.GPAOrders.unload(order["token"], %{
        original_order_token: order["token"],
        amount: 100.00,
        currency_code: "USD",
        funding_source_token: "program_fs_01"
      })
  """
  use Marqeta.Resource, path: "/gpaorders", resource: "GPA order", update: false

  alias Marqeta.Client

  @doc "Unloads (reverses) funds from a GPA order."
  @spec unload(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def unload(token, params, opts \\ []) do
    Client.post("/gpaorders/#{token}/unloads", params, opts)
  end

  @doc "Lists unloads (reversals) for a GPA order."
  @spec list_unloads(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_unloads(token, params \\ %{}, opts \\ []) do
    Client.get("/gpaorders/#{token}/unloads", Keyword.put(opts, :params, params))
  end

  @doc "Lists GPA orders for a user."
  @spec list_by_user(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_by_user(user_token, params \\ %{}, opts \\ []) do
    Client.get("/gpaorders/user/#{user_token}", Keyword.put(opts, :params, params))
  end

  @doc "Lists GPA orders for a business."
  @spec list_by_business(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_by_business(token, params \\ %{}, opts \\ []) do
    Client.get("/gpaorders/business/#{token}", Keyword.put(opts, :params, params))
  end
end

defmodule Marqeta.ProgramFundingSources do
  @moduledoc "Program funding sources — bank accounts used for Managed JIT Funding."
  use Marqeta.Resource, path: "/fundingsources/program", resource: "program funding source"
end

defmodule Marqeta.ProgramGatewayFundingSources do
  @moduledoc """
  Program gateway funding sources — used with Gateway JIT Funding.

  A program gateway funding source points Marqeta at your JIT gateway endpoint.
  When an authorization occurs, Marqeta calls your gateway to approve or deny
  the funding in real time.
  """
  use Marqeta.Resource,
    path: "/fundingsources/programgateway",
    resource: "program gateway funding source"
end

defmodule Marqeta.AccountHolderFundingSources do
  @moduledoc """
  ACH funding sources for individual account holders.

  Supports micro-deposit verification to confirm account ownership.

  ## Examples

      # Create an ACH funding source
      {:ok, fs} = Marqeta.AccountHolderFundingSources.create(%{
        account_number: "123456789",
        routing_number: "021000021",
        account_type: "checking",
        name_on_account: "Jane Doe",
        user_token: "user_01"
      })

      # Verify via micro-deposits
      {:ok, _} = Marqeta.AccountHolderFundingSources.verify(fs["token"], %{
        first_amount: 0.15,
        second_amount: 0.32
      })
  """
  use Marqeta.Resource,
    path: "/fundingsources/ach",
    resource: "account holder ACH funding source"

  alias Marqeta.Client

  @doc "Verifies micro-deposit amounts for an ACH funding source."
  @spec verify(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def verify(token, params, opts \\ []) do
    Client.put("/fundingsources/ach/#{token}/verificationamounts", params, opts)
  end

  @doc "Lists funding sources for a user."
  @spec list_by_user(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_by_user(user_token, params \\ %{}, opts \\ []) do
    Client.get("/fundingsources/user/#{user_token}", Keyword.put(opts, :params, params))
  end

  @doc "Lists funding sources for a business."
  @spec list_by_business(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_by_business(token, params \\ %{}, opts \\ []) do
    Client.get("/fundingsources/business/#{token}", Keyword.put(opts, :params, params))
  end

  @doc "Transitions the ACH funding source to active, cancelled, etc."
  @spec transition(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def transition(token, params, opts \\ []) do
    Client.post("/fundingsourcetransitions", Map.put(params, :token, token), opts)
  end
end

defmodule Marqeta.ProgramTransfers do
  @moduledoc """
  Move funds from a user's GPA back to the program funding source.
  Used for account closures, chargebacks, and operational transfers.
  """
  use Marqeta.Resource, path: "/programtransfers", resource: "program transfer", update: false

  alias Marqeta.Client

  @doc "Lists program transfer types configured for your program."
  @spec list_types(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_types(params \\ %{}, opts \\ []) do
    Client.get("/programtransfers/types", Keyword.put(opts, :params, params))
  end

  @doc "Creates a program transfer type."
  @spec create_type(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def create_type(params, opts \\ []) do
    Client.post("/programtransfers/types", params, opts)
  end

  @doc "Retrieves a program transfer type by token."
  @spec get_type(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def get_type(type_token, opts \\ []) do
    Client.get("/programtransfers/types/#{type_token}", opts)
  end

  @doc "Updates a program transfer type."
  @spec update_type(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def update_type(type_token, params, opts \\ []) do
    Client.put("/programtransfers/types/#{type_token}", params, opts)
  end
end

defmodule Marqeta.IntraAccountTransfers do
  @moduledoc """
  Move funds between GPAs owned by the same account holder.
  Both source and destination must belong to the same user or business.
  """
  use Marqeta.Resource,
    path: "/intraaccounttransfers",
    resource: "intra-account transfer",
    update: false,
    list: false
end

defmodule Marqeta.ProgramReserve do
  @moduledoc """
  Manage your program reserve account — the pool of funds your program
  operates from. Credit and debit the reserve, and query its balance.
  """
  use Marqeta.Resource,
    path: "/programreserve/transactions",
    resource: "program reserve transaction",
    update: false

  alias Marqeta.Client

  @doc "Returns the current program reserve balance."
  @spec balance(keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def balance(opts \\ []) do
    Client.get("/programreserve/balances", opts)
  end
end

defmodule Marqeta.FundingViaACH do
  @moduledoc """
  Initiate ACH transfers between a Marqeta funding source and an external bank.
  Supports peer transfers, program transfers, and fee transfers entirely
  within the Marqeta platform.
  """
  use Marqeta.Resource, path: "/transfers", resource: "ACH transfer", update: false
end

defmodule Marqeta.InstantFunding do
  @moduledoc """
  Fund a Marqeta-issued card from an external debit or prepaid card
  using card network push-payment rails (Visa Direct / MC Send).

  ## Examples

      {:ok, transfer} = Marqeta.InstantFunding.create(%{
        amount: 200.00,
        currency_code: "USD",
        destination_card_token: "card_01",
        source_card_token: "src_card_01"
      })
  """
  use Marqeta.Resource,
    path: "/instantfunding/transfers",
    resource: "instant funding transfer",
    update: false

  alias Marqeta.Client

  @doc "Retrieves instant funding configuration for the program."
  @spec config(keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def config(opts \\ []) do
    Client.get("/instantfunding/config", opts)
  end

  @doc "Updates instant funding configuration."
  @spec update_config(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def update_config(params, opts \\ []) do
    Client.put("/instantfunding/config", params, opts)
  end
end

defmodule Marqeta.AutoReload do
  @moduledoc """
  Automatically reload a user's GPA when the balance falls below a threshold.

  ## Examples

      {:ok, ar} = Marqeta.AutoReload.create(%{
        funding_source_token: "fs_01",
        currency_code: "USD",
        active: true,
        order_scope: %{
          gpa: %{
            reload_threshold: 10.00,
            reload_amount: 100.00
          }
        },
        association: %{user_token: "user_01"}
      })
  """
  use Marqeta.Resource, path: "/autoreloads", resource: "auto reload"

  alias Marqeta.Client

  @doc "Lists auto reload configurations for a user."
  @spec list_by_user(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_by_user(user_token, params \\ %{}, opts \\ []) do
    Client.get("/autoreloads/user/#{user_token}", Keyword.put(opts, :params, params))
  end

  @doc "Lists auto reload configurations for a business."
  @spec list_by_business(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_by_business(token, params \\ %{}, opts \\ []) do
    Client.get("/autoreloads/business/#{token}", Keyword.put(opts, :params, params))
  end

  @doc "Lists auto reload configurations for a card product."
  @spec list_by_card_product(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_by_card_product(token, params \\ %{}, opts \\ []) do
    Client.get("/autoreloads/cardproduct/#{token}", Keyword.put(opts, :params, params))
  end
end

defmodule Marqeta.ACHReceiving do
  @moduledoc """
  Enable third-party ACH credits and debits directly to account holder GPAs.
  Supports inbound ACH pull and push payments.
  """
  use Marqeta.Resource,
    path: "/achreceiving/transfers",
    resource: "ACH receiving transfer",
    update: false

  alias Marqeta.Client

  @doc "Retrieves ACH receiving configuration."
  @spec config(keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def config(opts \\ []) do
    Client.get("/achreceiving/config", opts)
  end

  @doc "Updates ACH receiving configuration."
  @spec update_config(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def update_config(params, opts \\ []) do
    Client.put("/achreceiving/config", params, opts)
  end

  @doc "Lists ACH receiving transfer types."
  @spec list_types(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_types(params \\ %{}, opts \\ []) do
    Client.get("/achreceiving/transfertypes", Keyword.put(opts, :params, params))
  end

  @doc "Creates an ACH receiving transfer type."
  @spec create_type(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def create_type(params, opts \\ []) do
    Client.post("/achreceiving/transfertypes", params, opts)
  end
end

defmodule Marqeta.VelocityControls do
  @moduledoc """
  Limit how much and how frequently users can spend.

  Controls can be scoped to a user, card product, or entire program
  (null association — requires Program Manager permission).

  A program supports up to **90** combined velocity + authorization controls.
  When multiple controls apply, the user cannot exceed **any** of them.

  ## Velocity Windows
  `DAY`, `WEEK`, `MONTH`, `LIFETIME`, `TRANSACTION`

  ## Examples

      # $500/day per user
      {:ok, _} = Marqeta.VelocityControls.create(%{
        association: %{user_token: "user_01"},
        currency_code: "USD",
        amount_limit: 500.00,
        velocity_window: "DAY",
        include_purchases: true,
        include_withdrawals: true,
        include_cashback: false,
        include_credits: false,
        active: true
      })

      # 10 transactions/week on a card product
      {:ok, _} = Marqeta.VelocityControls.create(%{
        association: %{card_product_token: "cp_01"},
        currency_code: "USD",
        amount_limit: 10_000.00,
        transaction_limit: 10,
        velocity_window: "WEEK",
        active: true
      })
  """
  use Marqeta.Resource, path: "/velocitycontrols", resource: "velocity control"

  alias Marqeta.Client

  @doc "Returns velocity controls available to a user (all applicable controls)."
  @spec list_by_user(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_by_user(user_token, params \\ %{}, opts \\ []) do
    Client.get(
      "/velocitycontrols/user/#{user_token}/available",
      Keyword.put(opts, :params, params)
    )
  end

  @doc "Returns velocity controls for a card product."
  @spec list_by_card_product(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_by_card_product(token, params \\ %{}, opts \\ []) do
    Client.get(
      "/velocitycontrols/cardproduct/#{token}",
      Keyword.put(opts, :params, params)
    )
  end
end

defmodule Marqeta.AuthorizationControls do
  @moduledoc """
  Rule-based controls that restrict which merchants cardholders can transact with.

  Supports MCC codes, merchant groups, specific merchant IDs, and
  geographic restrictions (country-level).

  ## Examples

      # Block all gambling MCCs for a card product
      {:ok, _} = Marqeta.AuthorizationControls.create(%{
        name: "No Gambling",
        association: %{card_product_token: "cp_01"},
        merchant_scope: %{mcc_group: "gambling_mccs"},
        active: true
      })
  """
  use Marqeta.Resource, path: "/authcontrols", resource: "authorization control"

  alias Marqeta.Client

  @doc "Lists exemptions configured on an authorization control."
  @spec list_exemptions(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_exemptions(token, params \\ %{}, opts \\ []) do
    Client.get("/authcontrols/#{token}/exemptions", Keyword.put(opts, :params, params))
  end

  @doc "Adds an exemption to an authorization control."
  @spec add_exemption(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def add_exemption(token, params, opts \\ []) do
    Client.post("/authcontrols/#{token}/exemptions", params, opts)
  end

  @doc "Removes an exemption from an authorization control."
  @spec remove_exemption(String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def remove_exemption(control_token, exemption_token, opts \\ []) do
    Client.delete("/authcontrols/#{control_token}/exemptions/#{exemption_token}", opts)
  end
end

defmodule Marqeta.MCCGroups do
  @moduledoc """
  Group Merchant Category Codes (MCCs) for bulk application to
  authorization controls and card product configurations.
  """
  use Marqeta.Resource, path: "/mccgroups", resource: "MCC group"
end

defmodule Marqeta.MerchantGroups do
  @moduledoc """
  Group specific merchants (by MID) for use in authorization controls.
  """
  use Marqeta.Resource, path: "/merchantgroups", resource: "merchant group"
end

defmodule Marqeta.AcceptedCountries do
  @moduledoc """
  Restrict which countries cardholders may transact in.
  Can be associated with a card product or individual cards.
  """
  use Marqeta.Resource, path: "/acceptedcountries", resource: "accepted countries"
end

defmodule Marqeta.AccountHolderGroups do
  @moduledoc """
  Apply shared settings to groups of account holders simultaneously.
  Useful for tiered products and bulk configuration.
  """
  use Marqeta.Resource, path: "/accountholdergroups", resource: "account holder group"
end

defmodule Marqeta.KYCVerification do
  @moduledoc """
  Know Your Customer (KYC) identity verification for US account holders.

  - A user may be submitted for KYC **at most twice**.
  - Account holder status must be `UNVERIFIED`, `LIMITED`, or `ACTIVE`.
  - `manual_override: true` marks an account as verified when you've
    completed KYC via a third-party provider (requires Marqeta approval).

  ## KYC Result Codes

  | Code   | Meaning |
  |--------|---------|
  | `SUCCESS` | Fully verified |
  | `FAILURE` | Unable to verify |
  | `PENDING` | Under manual review |

  ## Examples

      # Verify an individual
      {:ok, result} = Marqeta.KYCVerification.perform(%{user_token: "user_01"})

      # Verify a business
      {:ok, result} = Marqeta.KYCVerification.perform(%{business_token: "biz_01"})

      # Manual override (requires Marqeta written approval)
      {:ok, _} = Marqeta.KYCVerification.perform(%{
        user_token: "user_01",
        manual_override: true,
        notes: "Verified via Jumio",
        reference_id: "jumio_ref_001"
      })
  """
  use Marqeta.Resource,
    path: "/kyc",
    resource: "KYC verification",
    get: false,
    update: false,
    list: false

  alias Marqeta.Client

  @doc "Submits an account holder for KYC verification."
  @spec perform(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def perform(params, opts \\ []) do
    create(params, opts)
  end

  @doc "Retrieves a KYC result by token."
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def get(token, opts \\ []) do
    Client.get("/kyc/#{token}", opts)
  end

  @doc "Lists KYC verifications for a user."
  @spec list_by_user(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_by_user(user_token, params \\ %{}, opts \\ []) do
    Client.get("/kyc/user/#{user_token}", Keyword.put(opts, :params, params))
  end

  @doc "Lists KYC verifications for a business."
  @spec list_by_business(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_by_business(token, params \\ %{}, opts \\ []) do
    Client.get("/kyc/business/#{token}", Keyword.put(opts, :params, params))
  end
end

defmodule Marqeta.BulkCardOrders do
  @moduledoc """
  Order physical cards in bulk. Bulk orders share a single card product
  and fulfillment configuration.
  """
  use Marqeta.Resource, path: "/bulkissuances", resource: "bulk card order", update: false

  alias Marqeta.Client

  @doc "Lists cards generated by a bulk order."
  @spec list_cards(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_cards(token, params \\ %{}, opts \\ []) do
    Client.get("/bulkissuances/#{token}/cards", Keyword.put(opts, :params, params))
  end
end

defmodule Marqeta.PINs do
  @moduledoc """
  Set, update, and reveal PINs for payment cards.

  PIN operations use a two-step control-token flow for security.
  The control token is single-use and expires after a short window.

  ## Flow

  1. `create_control_token/1` — obtain a single-use control token
  2. `set/2` — set or update the PIN using the control token
  3. Optionally `reveal/1` — reveal the PIN (requires special program permissions)

  ## Examples

      {:ok, %{"control_token" => ct}} = Marqeta.PINs.create_control_token(%{
        card_token: "card_01"
      })

      {:ok, _} = Marqeta.PINs.set(ct, "1234")

      {:ok, %{"pin" => pin}} = Marqeta.PINs.reveal(ct)
  """
  use Marqeta.Resource, path: "/pins", resource: "PIN", create: false, list: false

  alias Marqeta.Client

  @doc "Creates a single-use PIN control token for a card."
  @spec create_control_token(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def create_control_token(params, opts \\ []) do
    Client.post("/pins/controltoken", params, opts)
  end

  @doc "Sets or updates a card PIN. Accepts a control token and 4-digit PIN string."
  @spec set(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def set(control_token, pin, opts \\ []) do
    Client.put("/pins", %{control_token: control_token, pin: pin}, opts)
  end

  @doc "Reveals a PIN using a control token. Requires special program permissions."
  @spec reveal(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def reveal(control_token, opts \\ []) do
    Client.get("/pins?control_token=#{URI.encode(control_token)}", opts)
  end
end

defmodule Marqeta.DigitalWalletsManagement do
  @moduledoc """
  Manage digital wallet token provisioning and lifecycle.
  Supports Apple Pay, Google Pay, and Samsung Pay.

  ## Token States
  `REQUESTED`, `ACTIVE`, `SUSPENDED`, `TERMINATED`

  ## Provisioning Sources
  `MOBILE_BANKING_APP`, `WEB`, `CUSTOMER_SERVICE`, `ISSUER`, `TOKEN_SERVICE_PROVIDER`
  """
  use Marqeta.Resource,
    path: "/digitalwallettokens",
    resource: "digital wallet token",
    create: false

  alias Marqeta.Client

  @doc "Transitions a digital wallet token to a new state."
  @spec transition(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def transition(params, opts \\ []) do
    Client.post("/digitalwallettokentransitions", params, opts)
  end

  @doc "Retrieves a specific digital wallet token transition."
  @spec get_transition(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def get_transition(token, opts \\ []) do
    Client.get("/digitalwallettokentransitions/#{token}", opts)
  end

  @doc "Lists digital wallet tokens for a card."
  @spec list_by_card(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_by_card(card_token, params \\ %{}, opts \\ []) do
    Client.get("/digitalwallettokens/card/#{card_token}", Keyword.put(opts, :params, params))
  end

  @doc "Lists digital wallet tokens for a user."
  @spec list_by_user(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_by_user(user_token, params \\ %{}, opts \\ []) do
    Client.get("/digitalwallettokens/user/#{user_token}", Keyword.put(opts, :params, params))
  end

  @doc "Lists all transitions for a digital wallet token."
  @spec list_transitions(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_transitions(token, params \\ %{}, opts \\ []) do
    Client.get(
      "/digitalwallettokentransitions/digitalwallettoken/#{token}",
      Keyword.put(opts, :params, params)
    )
  end

  @doc "Provides a provisioning decision for a digital wallet token request."
  @spec provision_decision(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def provision_decision(params, opts \\ []) do
    Client.post("/digitalwallettokens/provisioningdecision", params, opts)
  end
end

defmodule Marqeta.TokenizationAsAService do
  @moduledoc """
  Use Marqeta's tokenization infrastructure even when Marqeta
  is not your issuer-processor (TaaS).
  """
  use Marqeta.Resource, path: "/taas/tokens", resource: "TaaS token", update: false

  alias Marqeta.Client

  @doc "Submits a tokenization request."
  @spec tokenize(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def tokenize(params, opts \\ []) do
    Client.post("/taas/tokenize", params, opts)
  end

  @doc "Retrieves tokenization status for a token."
  @spec status(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def status(token, opts \\ []) do
    Client.get("/taas/tokens/#{token}/status", opts)
  end

  @doc "Updates a TaaS token."
  @spec update_token(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def update_token(token, params, opts \\ []) do
    Client.put("/taas/tokens/#{token}", params, opts)
  end
end

defmodule Marqeta.Fees do
  @moduledoc "Define fee templates for your program (monthly, annual, transaction, etc.)."
  use Marqeta.Resource, path: "/fees", resource: "fee"
end

defmodule Marqeta.FeeCharges do
  @moduledoc """
  Assess fees from account holder GPAs to the program fee account.
  References a fee template created via `Marqeta.Fees`.
  """
  use Marqeta.Resource, path: "/fees/charges", resource: "fee charge", update: false
end

defmodule Marqeta.FeeRefunds do
  @moduledoc "Return previously charged fees to an account holder's GPA."
  use Marqeta.Resource, path: "/fees/refunds", resource: "fee refund", update: false
end

defmodule Marqeta.FraudFeedback do
  @moduledoc """
  Submit fraud feedback on completed transactions.

  Feedback helps Marqeta's fraud models improve over time.
  Only supported on approved, non-JIT transactions.

  ## Fraud Types
  `FIRST_PARTY_FRAUD`, `THIRD_PARTY_FRAUD`, `NOT_FRAUD`
  """
  use Marqeta.Resource,
    path: "/fraudfeedback",
    resource: "fraud feedback",
    update: false,
    list: false
end

defmodule Marqeta.CardholderStatements do
  @moduledoc "Create and retrieve cardholder statements for prepaid accounts."
  use Marqeta.Resource, path: "/cardholderstatements", resource: "cardholder statement"
end

defmodule Marqeta.DepositAccounts do
  @moduledoc """
  Full lifecycle management for deposit (checking/savings) accounts.
  Distinct from GPA — deposit accounts support direct deposit and ACH.
  """
  use Marqeta.Resource, path: "/depositaccounts", resource: "deposit account"

  alias Marqeta.Client

  @doc "Lists transactions for a deposit account."
  @spec transactions(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def transactions(token, params \\ %{}, opts \\ []) do
    Client.get("/depositaccounts/#{token}/transactions", Keyword.put(opts, :params, params))
  end

  @doc "Transitions a deposit account to a new state."
  @spec transition(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def transition(token, params, opts \\ []) do
    Client.post("/depositaccounts/#{token}/transitions", params, opts)
  end

  @doc "Lists transitions for a deposit account."
  @spec list_transitions(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_transitions(token, params \\ %{}, opts \\ []) do
    Client.get("/depositaccounts/#{token}/transitions", Keyword.put(opts, :params, params))
  end
end

defmodule Marqeta.CheckReturns do
  @moduledoc "Issue physical refund cheques when closing accounts with residual balances."
  use Marqeta.Resource, path: "/checkreturns", resource: "check return", update: false
end

defmodule Marqeta.Addresses do
  @moduledoc "List and manage billing addresses for users, businesses, and funding sources."
  use Marqeta.Resource, path: "/addresses", resource: "address"
end

defmodule Marqeta.SubscriptionManagement do
  @moduledoc "Manage program subscription configurations and recurring billing setups."
  use Marqeta.Resource, path: "/subscriptions", resource: "subscription"
end

defmodule Marqeta.ThreeDSecure do
  @moduledoc """
  3D Secure (3DS) decision service.

  Evaluates each authorization against your SCA rules and decides
  whether to apply Strong Customer Authentication or grant an exemption.

  Exemption types: `LOW_VALUE`, `TRANSACTION_RISK_ANALYSIS`,
  `RECURRING`, `MERCHANT_WHITELIST`, `SECURE_CORPORATE`
  """
  use Marqeta.Resource,
    path: "/3ds/authenticationdecisions",
    resource: "3DS authentication decision",
    create: false,
    list: false,
    update: false

  alias Marqeta.Client

  @doc "Retrieves 3DS configuration for the program."
  @spec config(keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def config(opts \\ []) do
    Client.get("/3ds/config", opts)
  end

  @doc "Updates 3DS configuration."
  @spec update_config(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def update_config(params, opts \\ []) do
    Client.put("/3ds/config", params, opts)
  end

  @doc "Lists 3DS authentication decisions."
  @spec list(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list(params \\ %{}, opts \\ []) do
    Client.get("/3ds/authenticationdecisions", Keyword.put(opts, :params, params))
  end
end

defmodule Marqeta.CommandoMode do
  @moduledoc """
  Commando Mode is a fallback decision system that activates when your
  Gateway JIT endpoint is unreachable or too slow.

  Pre-configure rules (approve all / decline all / approve by MCC) so
  transactions can proceed even during gateway outages.

  ## Examples

      # View current commando mode status
      {:ok, status} = Marqeta.CommandoMode.get("commando_token")

      # List control sets
      {:ok, sets} = Marqeta.CommandoMode.list_control_sets()

      # Create a control set
      {:ok, cs} = Marqeta.CommandoMode.create_control_set(%{
        name: "Allow Groceries",
        control: %{
          transaction_type: %{
            include_purchases: true
          },
          merchant_scope: %{
            mcc_group: "grocery_mcc_group"
          }
        }
      })
  """
  use Marqeta.Resource,
    path: "/commandomode",
    resource: "commando mode",
    create: false,
    list: false

  alias Marqeta.Client

  @doc "Retrieves all commando mode entries."
  @spec list_all(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_all(params \\ %{}, opts \\ []) do
    Client.get("/commandomode", Keyword.put(opts, :params, params))
  end

  @doc "Enables commando mode for the program."
  @spec enable(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def enable(token, opts \\ []) do
    Client.post("/commandomode/#{token}/enable", %{}, opts)
  end

  @doc "Disables commando mode for the program."
  @spec disable(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def disable(token, opts \\ []) do
    Client.post("/commandomode/#{token}/disable", %{}, opts)
  end

  @doc "Lists commando mode control sets."
  @spec list_control_sets(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def list_control_sets(params \\ %{}, opts \\ []) do
    Client.get("/commandomode/controlsets", Keyword.put(opts, :params, params))
  end

  @doc "Creates a commando mode control set."
  @spec create_control_set(map(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def create_control_set(params, opts \\ []) do
    Client.post("/commandomode/controlsets", params, opts)
  end

  @doc "Retrieves a commando mode control set by token."
  @spec get_control_set(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def get_control_set(token, opts \\ []) do
    Client.get("/commandomode/controlsets/#{token}", opts)
  end

  @doc "Updates a commando mode control set."
  @spec update_control_set(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def update_control_set(token, params, opts \\ []) do
    Client.put("/commandomode/controlsets/#{token}", params, opts)
  end

  @doc "Retrieves the commando mode addendum (extended configuration)."
  @spec addendum(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def addendum(token, opts \\ []) do
    Client.get("/commandomode/#{token}/addendum", opts)
  end

  @doc "Updates the commando mode addendum."
  @spec update_addendum(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Marqeta.Error.t()}
  def update_addendum(token, params, opts \\ []) do
    Client.put("/commandomode/#{token}/addendum", params, opts)
  end
end

# Keep old name as alias for backward compat
defmodule Marqeta.CommandomMode do
  @moduledoc false
  defdelegate enable(token, opts \\ []), to: Marqeta.CommandoMode
  defdelegate disable(token, opts \\ []), to: Marqeta.CommandoMode
  defdelegate list_control_sets(params \\ %{}, opts \\ []), to: Marqeta.CommandoMode
  defdelegate create_control_set(params, opts \\ []), to: Marqeta.CommandoMode
  defdelegate get_control_set(token, opts \\ []), to: Marqeta.CommandoMode
  defdelegate update_control_set(token, params, opts \\ []), to: Marqeta.CommandoMode
  defdelegate addendum(token, opts \\ []), to: Marqeta.CommandoMode
  defdelegate update_addendum(token, params, opts \\ []), to: Marqeta.CommandoMode
end

defmodule Marqeta.SelfServiceCredentials do
  @moduledoc """
  Programmatically create, retrieve, and delete admin access tokens.

  ## Examples

      {:ok, cred} = Marqeta.SelfServiceCredentials.create(%{
        email: "admin@example.com",
        role: "ADMINISTRATOR"
      })

      {:ok, _} = Marqeta.SelfServiceCredentials.delete(cred["token"])
  """
  use Marqeta.Resource, path: "/credentials/admin", resource: "admin credential"

  alias Marqeta.Client

  @doc "Deletes an admin access token by token."
  @spec delete(String.t(), keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def delete(token, opts \\ []) do
    Client.delete("/credentials/admin/#{token}", opts)
  end
end

defmodule Marqeta.DisputesVisa do
  @moduledoc "Manage Visa network transaction disputes end-to-end."
  use Marqeta.Resource, path: "/cases/visa", resource: "Visa dispute"
end

defmodule Marqeta.DisputesMastercard do
  @moduledoc "Manage Mastercard network transaction disputes end-to-end."
  use Marqeta.Resource, path: "/cases/mastercard", resource: "Mastercard dispute"
end

defmodule Marqeta.DisputesPulse do
  @moduledoc "Manage PULSE network transaction disputes end-to-end."
  use Marqeta.Resource, path: "/cases/pulse", resource: "PULSE dispute"
end

defmodule Marqeta.DisputesEvidenceCollection do
  @moduledoc """
  Submit and manage evidence documents for transaction disputes.
  Evidence includes receipts, cardholder letters, screenshots, etc.
  """
  use Marqeta.Resource, path: "/cases/evidence", resource: "dispute evidence"
end

defmodule Marqeta.UXToolkit do
  @moduledoc "API for Marqeta's pre-built UX Toolkit card management components."
  use Marqeta.Resource, path: "/uxt", resource: "UX toolkit session"
end

defmodule Marqeta.EventTypes do
  @moduledoc """
  Reference module documenting all Marqeta webhook event type strings.

  Use these constants when subscribing to webhook events via `Marqeta.Webhooks`.

  ## Usage

      Marqeta.Webhooks.create(%{
        events: [Marqeta.EventTypes.all()],
        ...
      })

      Marqeta.Webhooks.create(%{
        events: Marqeta.EventTypes.transaction_events(),
        ...
      })
  """

  @doc "Wildcard — subscribes to all event types."
  @spec all() :: String.t()
  def all, do: "*"

  @doc "All transaction events."
  @spec transaction_events() :: [String.t()]
  def transaction_events, do: ["transaction.*"]

  @doc "All card transition events."
  @spec card_transition_events() :: [String.t()]
  def card_transition_events, do: ["cardtransition.*"]

  @doc "All user transition events."
  @spec user_transition_events() :: [String.t()]
  def user_transition_events, do: ["usertransition.*"]

  @doc "All business transition events."
  @spec business_transition_events() :: [String.t()]
  def business_transition_events, do: ["businesstransition.*"]

  @doc "All GPA order events."
  @spec gpa_order_events() :: [String.t()]
  def gpa_order_events, do: ["gpaorder.*"]

  @doc "All program transfer events."
  @spec program_transfer_events() :: [String.t()]
  def program_transfer_events, do: ["programtransfer.*"]

  @doc "All digital wallet events."
  @spec digital_wallet_events() :: [String.t()]
  def digital_wallet_events, do: ["digitalwallet.*"]

  @doc "All KYC events."
  @spec kyc_events() :: [String.t()]
  def kyc_events, do: ["kyc.*"]

  @doc "All direct deposit events."
  @spec direct_deposit_events() :: [String.t()]
  def direct_deposit_events, do: ["directdeposit.*"]

  @doc "All dispute events."
  @spec dispute_events() :: [String.t()]
  def dispute_events, do: ["cases.*"]

  @doc "All credit account events."
  @spec credit_account_events() :: [String.t()]
  def credit_account_events, do: ["credit.accounts.*"]

  @doc "List of common production-ready event subscriptions."
  @spec common_events() :: [String.t()]
  def common_events do
    [
      "transaction.*",
      "cardtransition.*",
      "usertransition.*",
      "businesstransition.*",
      "gpaorder.*",
      "programtransfer.*",
      "kyc.*"
    ]
  end
end
