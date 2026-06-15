defmodule Marqeta do
  @moduledoc """
  Production-grade Elixir client for the Marqeta Core, Credit, and DiVA APIs.

  ## Quick start

      config :marqeta,
        base_url: "https://sandbox-api.marqeta.com/v3",
        application_token: System.fetch_env!("MARQETA_APP_TOKEN"),
        admin_access_token: System.fetch_env!("MARQETA_ADMIN_TOKEN")

      {:ok, user} = Marqeta.Users.create(%{
        first_name: "Jane",
        last_name: "Doe",
        email: "jane@example.com",
        identifications: [%{type: "SSN", value: "123456789"}]
      })

  ## API coverage

    * **Core** — Users, Cards, CardProducts, Businesses, Transactions, Balances
    * **Funding** — GPAOrders, ProgramFundingSources, ACH, InstantFunding, AutoReload
    * **Spend controls** — VelocityControls, AuthorizationControls, MCCGroups
    * **Card lifecycle** — CardTransitions, BulkCardOrders, PINs, DigitalWallets
    * **Compliance** — KYCVerification, FraudFeedback, ThreeDSecure
    * **Disputes** — Visa, Mastercard, PULSE, Evidence Collection
    * **Credit** (25 modules) — Full credit platform
    * **DiVA** (35 modules) — All analytics and reporting views
    * **Platform** — Webhooks, GatewayJIT, Simulations, Sandbox, CommandoMode

  See `Marqeta.Config` for all configuration options.
  See `Marqeta.Error` for the error type and all error codes.
  See `Marqeta.Stream` for lazy auto-pagination across list endpoints.
  See `Marqeta.Telemetry` for observability hooks and metrics definitions.
  """

  @version "1.0.0"

  @doc "Returns the library version string."
  @spec version() :: String.t()
  def version, do: @version

  @doc """
  Pings the Marqeta platform.

  Useful for health checks and verifying credentials.

  ## Example

      {:ok, %{"version" => "3"}} = Marqeta.ping()
  """
  @spec ping(keyword()) :: {:ok, map()} | {:error, Marqeta.Error.t()}
  def ping(opts \\ []), do: Marqeta.Client.get("/ping", opts)

  @doc "Pings the Marqeta platform. Raises `Marqeta.Error` on failure."
  @spec ping!(keyword()) :: map()
  def ping!(opts \\ []) do
    case ping(opts) do
      {:ok, resp} -> resp
      {:error, err} -> raise err
    end
  end
end
