import Config

config :marqeta,
  base_url: "https://sandbox-api.marqeta.com/v3",
  application_token: "your_application_token",
  admin_access_token: "your_admin_access_token",
  pool_size: 10,
  pool_count: 1,
  timeout: 30_000,
  connect_timeout: 5_000,
  retry_max_attempts: 3,
  retry_base_delay: 500,
  retry_max_delay: 10_000,
  retry_jitter: true,
  sandbox: true,
  telemetry_prefix: [:marqeta],
  log_level: :info,
  custom_headers: [],
  http_client: Marqeta.HTTP.ReqClient

import_config "#{config_env()}.exs"
