defmodule Marqeta.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    config = Marqeta.Config.load!()

    children = [
      {Finch,
       name: Marqeta.Finch,
       pools: %{
         config.base_url => [
           count: config.pool_count,
           protocol: :http2,
           size: config.pool_size
         ]
       }},
      {Marqeta.RateLimiter, config},
      {Marqeta.Telemetry.Reporter, []}
    ]

    Supervisor.start_link(children,
      name: Marqeta.Supervisor,
      strategy: :one_for_one
    )
  end
end
