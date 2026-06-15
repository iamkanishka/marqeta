defmodule Marqeta.Cards do
  @moduledoc """
  Create and manage physical and virtual payment cards.

  Cards are always associated with a user and derived from a card product.

  ## Card states

    * `UNACTIVATED`  — newly issued, requires explicit activation
    * `ACTIVE`       — active and usable for transactions
    * `SUSPENDED`    — temporarily frozen; no transactions
    * `TERMINATED`   — permanently closed; cannot be reactivated
    * `LIMITED`      — restricted to certain transaction types
    * `UNSUPPORTED`  — card type not supported in current context

  ## Attribute precedence

  `card` → `bulkissuance` → `cardproduct` (higher overrides lower,
  does not overwrite lower-precedence values).

  ## Examples

      # Virtual card
      {:ok, card} = Marqeta.Cards.create(%{
        user_token: "user_01",
        card_product_token: "cp_01"
      })

      # Physical card with shipping
      {:ok, card} = Marqeta.Cards.create(%{
        user_token: "user_01",
        card_product_token: "physical_cp_01",
        fulfillment: %{
          card_personalization: %{text: %{name_line_1: %{value: "Jane Doe"}}},
          shipping: %{
            method: "TWO_DAY",
            recipient_address: %{
              first_name: "Jane",
              last_name: "Doe",
              address1: "123 Main St",
              city: "San Francisco",
              state: "CA",
              zip: "94105",
              country: "USA"
            }
          }
        }
      })

      # Reissue with same PAN (lost / damaged replacement)
      {:ok, card} = Marqeta.Cards.create(%{
        user_token: "user_01",
        card_product_token: "cp_01",
        reissue_pan_from_card_token: "old_card_token"
      })
  """

  use Marqeta.Resource, path: "/cards", resource: "card", create: false, get: false

  alias Marqeta.Client
  alias Marqeta.Error
  alias Marqeta.Stream, as: MStream

  # ---------------------------------------------------------------------------
  # Overridden create — supports show_pan / show_cvv_number query params
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new card.

  ## Options

    * `:show_pan`        — include full PAN in response (PCI DSS required)
    * `:show_cvv_number` — include CVV2 in response (PCI DSS required)
  """
  @spec create(map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def create(params \\ %{}, opts \\ []) do
    {sensitive, req_opts} = Keyword.split(opts, [:show_cvv_number, :show_pan])
    Client.post("/cards" <> sensitive_query(sensitive), params, req_opts)
  end

  # ---------------------------------------------------------------------------
  # Overridden get — supports show_pan / show_cvv_number query params
  # ---------------------------------------------------------------------------

  @doc """
  Retrieves a card by token.

  ## Options

    * `:show_pan`        — include full PAN in response (PCI DSS required)
    * `:show_cvv_number` — include CVV2 in response (PCI DSS required)
  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get(token, opts \\ []) do
    {sensitive, req_opts} = Keyword.split(opts, [:show_cvv_number, :show_pan])
    Client.get("/cards/#{token}" <> sensitive_query(sensitive), req_opts)
  end

  @doc """
  Retrieves a card with the full PAN and CVV2 included.

  Requires PCI DSS compliance. Sets `fulfillment_status` to `DIGITALLY_PRESENTED`.
  """
  @spec show_pan(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def show_pan(token, opts \\ []) do
    get(token, Keyword.merge(opts, show_cvv_number: true, show_pan: true))
  end

  @doc "Lists cards matching the last 4 digits of their PAN. Returns up to 10 per page."
  @spec list_by_last_four(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_by_last_four(last_four, params \\ %{}, opts \\ []) do
    Client.get("/cards", Keyword.put(opts, :params, Map.put(params, :last_four, last_four)))
  end

  @doc "Lists all cards for a user."
  @spec list_by_user(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_by_user(user_token, params \\ %{}, opts \\ []) do
    Client.get("/cards/user/#{user_token}", Keyword.put(opts, :params, params))
  end

  @doc "Returns a lazy stream of all cards for a user."
  @spec stream_by_user(String.t(), map()) :: Enumerable.t()
  def stream_by_user(user_token, params \\ %{}) do
    MStream.stream(fn p -> list_by_user(user_token, p) end, params)
  end

  @doc "Lists all cards for a business."
  @spec list_by_business(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_by_business(token, params \\ %{}, opts \\ []) do
    Client.get("/cards/business/#{token}", Keyword.put(opts, :params, params))
  end

  @doc "Returns a lazy stream of all cards for a business."
  @spec stream_by_business(String.t(), map()) :: Enumerable.t()
  def stream_by_business(token, params \\ %{}) do
    MStream.stream(fn p -> list_by_business(token, p) end, params)
  end

  @doc "Lists transactions for a card."
  @spec transactions(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def transactions(token, params \\ %{}, opts \\ []) do
    Client.get("/transactions/card/#{token}", Keyword.put(opts, :params, params))
  end

  @doc "Returns a lazy stream of transactions for a card."
  @spec stream_transactions(String.t(), map()) :: Enumerable.t()
  def stream_transactions(token, params \\ %{}) do
    MStream.stream(fn p -> transactions(token, p) end, params)
  end

  @doc "Returns merchant-specific data about where a card has been used."
  @spec merchant_scope(String.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def merchant_scope(token, params \\ %{}, opts \\ []) do
    Client.get("/cards/#{token}/merchantscope", Keyword.put(opts, :params, params))
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec sensitive_query(keyword()) :: String.t()
  defp sensitive_query([]), do: ""

  defp sensitive_query(opts) do
    parts =
      Enum.flat_map(opts, fn
        {:show_pan, true} -> [{"show_pan", "true"}]
        {:show_cvv_number, true} -> [{"show_cvv_number", "true"}]
        _ -> []
      end)

    if parts == [], do: "", else: "?" <> URI.encode_query(parts)
  end
end
