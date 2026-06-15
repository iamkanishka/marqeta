import Config

if config_env() == :prod do
  config :marqeta,
    base_url:
      System.get_env("MARQETA_BASE_URL") ||
        raise("MARQETA_BASE_URL environment variable is not set"),
    application_token:
      System.get_env("MARQETA_APPLICATION_TOKEN") ||
        raise("MARQETA_APPLICATION_TOKEN environment variable is not set"),
    admin_access_token:
      System.get_env("MARQETA_ADMIN_ACCESS_TOKEN") ||
        raise("MARQETA_ADMIN_ACCESS_TOKEN environment variable is not set"),
    pool_size: System.get_env("MARQETA_POOL_SIZE", "25") |> String.to_integer(),
    timeout: System.get_env("MARQETA_TIMEOUT_MS", "30000") |> String.to_integer(),
    retry_max_attempts: System.get_env("MARQETA_RETRY_MAX_ATTEMPTS", "3") |> String.to_integer()
end
