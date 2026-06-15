defmodule Marqeta.Users do
  @moduledoc """
  Manage individual cardholders (users) on the Marqeta platform.

  ## User states

    * `UNVERIFIED` — created, identity not yet verified
    * `LIMITED`    — partial verification; restricted transaction access
    * `ACTIVE`     — fully verified and operational
    * `SUSPENDED`  — temporarily frozen; no transactions permitted
    * `CLOSED`     — permanently closed

  ## Identification types

  `SSN`, `PASSPORT`, `DRIVERS_LICENSE`, `SIN`, `TIN`, `CPF`

  ## Example

      {:ok, user} = Marqeta.Users.create(%{
        first_name: "Jane",
        last_name: "Doe",
        email: "jane@example.com",
        address1: "123 Main St",
        city: "San Francisco",
        state: "CA",
        postal_code: "94105",
        country: "USA",
        birth_date: "1990-01-15",
        identifications: [%{type: "SSN", value: "123456789"}]
      })
  """

  use Marqeta.Resource, path: "/users", resource: "user"

  alias Marqeta.Client
  alias Marqeta.Error
  alias Marqeta.Stream, as: MStream

  @doc "Searches for users by one or more criteria (email, first_name, last_name, phone, ssn)."
  @spec search(map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def search(params, opts \\ []) do
    Client.post("/users/lookup", params, opts)
  end

  @doc "Searches for users. Raises `Marqeta.Error` on failure."
  @spec search!(map(), keyword()) :: map()
  def search!(params, opts \\ []) do
    case search(params, opts) do
      {:ok, result} -> result
      {:error, err} -> raise err
    end
  end

  @doc "Lists child users of a parent user (for hierarchical account structures)."
  @spec list_children(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_children(token, params \\ %{}, opts \\ []) do
    Client.get("/users/#{token}/children", Keyword.put(opts, :params, params))
  end

  @doc "Lists all cards belonging to a user."
  @spec list_cards(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_cards(token, params \\ %{}, opts \\ []) do
    Client.get("/cards/user/#{token}", Keyword.put(opts, :params, params))
  end

  @doc "Returns a lazy stream of all cards for a user."
  @spec stream_cards(String.t(), map()) :: Enumerable.t()
  def stream_cards(token, params \\ %{}) do
    MStream.stream(fn p -> list_cards(token, p) end, params)
  end

  @doc "Returns the GPA balance for a user."
  @spec balances(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def balances(token, opts \\ []) do
    Client.get("/balances/#{token}", opts)
  end

  @doc "Lists MSA (Merchant-Specific Account) balances for a user."
  @spec list_msa_balances(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_msa_balances(token, params \\ %{}, opts \\ []) do
    Client.get("/balances/#{token}/msas", Keyword.put(opts, :params, params))
  end

  @doc "Lists transactions for a user."
  @spec transactions(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def transactions(token, params \\ %{}, opts \\ []) do
    Client.get("/transactions/user/#{token}", Keyword.put(opts, :params, params))
  end

  @doc "Returns a lazy stream of all transactions for a user."
  @spec stream_transactions(String.t(), map()) :: Enumerable.t()
  def stream_transactions(token, params \\ %{}) do
    MStream.stream(fn p -> transactions(token, p) end, params)
  end

  @doc "Lists users in an account holder group."
  @spec list_by_account_holder_group(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def list_by_account_holder_group(group_token, params \\ %{}, opts \\ []) do
    Client.get(
      "/accountholdergroups/#{group_token}/users",
      Keyword.put(opts, :params, params)
    )
  end

  @doc "Lists addresses associated with a user."
  @spec list_addresses(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_addresses(token, params \\ %{}, opts \\ []) do
    Client.get("/users/#{token}/addresses", Keyword.put(opts, :params, params))
  end

  @doc "Lists notes on a user."
  @spec list_notes(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_notes(token, params \\ %{}, opts \\ []) do
    Client.get("/users/#{token}/notes", Keyword.put(opts, :params, params))
  end

  @doc "Creates a note on a user."
  @spec create_note(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create_note(token, params, opts \\ []) do
    Client.post("/users/#{token}/notes", params, opts)
  end

  @doc "Updates a note on a user."
  @spec update_note(String.t(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def update_note(user_token, note_token, params, opts \\ []) do
    Client.put("/users/#{user_token}/notes/#{note_token}", params, opts)
  end

  @doc "Retrieves KYC verification status for a user."
  @spec kyc_status(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def kyc_status(token, opts \\ []) do
    Client.get("/kyc/user/#{token}", opts)
  end

  @doc "Generates a single sign-on (SSO) token for the cardholder portal."
  @spec sso_token(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def sso_token(token, params \\ %{}, opts \\ []) do
    Client.post("/users/#{token}/ssotokens", params, opts)
  end
end
