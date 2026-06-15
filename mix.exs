defmodule Marqeta.MixProject do
  use Mix.Project

  @version "1.0.0"
  @source_url "https://github.com/iamkanishka/marqeta"
  @description "Production-grade Elixir client for the Marqeta Core, Credit, and DiVA APIs"

  def project do
    [
      app: :marqeta,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),

      # Hex
      description: @description,
      package: package(),
      source_url: @source_url,
      homepage_url: @source_url,

      # Docs
      docs: docs(),

      # Test
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.lcov": :test
      ],

      # Dialyzer
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix],
        flags: [:error_handling, :missing_return, :underspecs]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Marqeta.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # HTTP client
      {:req, "~> 0.5"},
      {:finch, "~> 0.19"},

      # JSON
      {:jason, "~> 1.4"},

      # Observability
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 1.0"},

      # Retry
      {:retry, "~> 0.18"},

      # Validation / Changesets
      {:ecto, "~> 3.12"},

      # Config
      {:nimble_options, "~> 1.1"},

      # Dev / Test
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:bypass, "~> 2.1", only: :test},
      {:mox, "~> 1.1", only: :test},
      {:stream_data, "~> 1.1", only: [:dev, :test]},
      {:ex_machina, "~> 2.7", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      ci: ["format --check-formatted", "credo --strict", "dialyzer", "test --cover"],
      "test.integration": ["test --only integration"]
    ]
  end

  defp package do
    [
      name: "marqeta",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Marqeta Docs" => "https://www.marqeta.com/docs/core-api/introduction"
      },
      maintainers: ["Your Name"],
      files: ~w(lib priv .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md", "guides/getting_started.md", "LICENSE"],
      groups_for_modules: [
        "Core Resources": [
          Marqeta.Users,
          Marqeta.Cards,
          Marqeta.CardProducts,
          Marqeta.Businesses,
          Marqeta.Transactions,
          Marqeta.Balances
        ],
        Funding: [
          Marqeta.GPAOrders,
          Marqeta.ProgramFundingSources,
          Marqeta.ProgramGatewayFundingSources,
          Marqeta.FundingViaACH,
          Marqeta.InstantFunding,
          Marqeta.IntraAccountTransfers,
          Marqeta.ProgramTransfers,
          Marqeta.ProgramReserve,
          Marqeta.AutoReload,
          Marqeta.ACHReceiving,
          Marqeta.AccountHolderFundingSources
        ],
        "Spend Controls": [
          Marqeta.VelocityControls,
          Marqeta.AuthorizationControls,
          Marqeta.MCCGroups,
          Marqeta.MerchantGroups,
          Marqeta.AcceptedCountries
        ],
        "Card Lifecycle": [
          Marqeta.CardTransitions,
          Marqeta.BulkCardOrders,
          Marqeta.PINs,
          Marqeta.DigitalWalletsManagement,
          Marqeta.TokenizationAsAService
        ],
        "Identity & Compliance": [
          Marqeta.KYCVerification,
          Marqeta.UserTransitions,
          Marqeta.BusinessTransitions,
          Marqeta.AccountHolderGroups
        ],
        "Fees & Rewards": [
          Marqeta.Fees,
          Marqeta.FeeCharges,
          Marqeta.FeeRefunds
        ],
        Disputes: [
          Marqeta.DisputesVisa,
          Marqeta.DisputesMastercard,
          Marqeta.DisputesPulse,
          Marqeta.DisputesEvidenceCollection
        ],
        Credit: [
          Marqeta.Credit.Accounts,
          Marqeta.Credit.Cards,
          Marqeta.Credit.Applications,
          Marqeta.Credit.Bundles,
          Marqeta.Credit.Products,
          Marqeta.Credit.Policies,
          Marqeta.Credit.Payments,
          Marqeta.Credit.PaymentSchedules,
          Marqeta.Credit.PaymentSources,
          Marqeta.Credit.JournalEntries,
          Marqeta.Credit.LedgerEntries,
          Marqeta.Credit.Statements,
          Marqeta.Credit.Disputes,
          Marqeta.Credit.Adjustments,
          Marqeta.Credit.Rewards,
          Marqeta.Credit.Delinquency,
          Marqeta.Credit.Transitions,
          Marqeta.Credit.Substatuses,
          Marqeta.Credit.Refunds,
          Marqeta.Credit.BalanceRefunds
        ],
        "DiVA (Analytics)": [
          Marqeta.DiVA.Authorizations,
          Marqeta.DiVA.Settlements,
          Marqeta.DiVA.Declines,
          Marqeta.DiVA.Loads,
          Marqeta.DiVA.Chargebacks,
          Marqeta.DiVA.CardCounts,
          Marqeta.DiVA.UserCounts,
          Marqeta.DiVA.ActivityBalances,
          Marqeta.DiVA.ClearingDetail,
          Marqeta.DiVA.CreditAccounts,
          Marqeta.DiVA.DirectDeposit,
          Marqeta.DiVA.Views
        ],
        Platform: [
          Marqeta.Client,
          Marqeta.Config,
          Marqeta.Error,
          Marqeta.Telemetry,
          Marqeta.Pagination,
          Marqeta.Stream,
          Marqeta.Webhooks,
          Marqeta.GatewayJIT,
          Marqeta.Simulations,
          Marqeta.Sandbox
        ]
      ]
    ]
  end
end
