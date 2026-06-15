import Config

config :marqeta,
  base_url: "http://localhost:9999",
  application_token: "test_app_token",
  admin_access_token: "test_admin_token",
  pool_size: 2,
  timeout: 5_000,
  retry_max_attempts: 0,
  log_level: :none,
  sandbox: true
