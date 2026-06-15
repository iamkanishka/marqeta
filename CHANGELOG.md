# Changelog

All notable changes to this project are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

---

## [1.0.0] - 2026-06-15

### Added
- Initial release
- Full Core API coverage: Users, Cards, CardProducts, Businesses, Transactions, Balances
- Full Funding coverage: GPAOrders, ProgramFundingSources, ProgramGatewayFundingSources,
  AccountHolderFundingSources, IntraAccountTransfers, ProgramTransfers, ProgramReserve,
  FundingViaACH, InstantFunding, AutoReload, ACHReceiving
- Full Spend Controls: VelocityControls, AuthorizationControls, MCCGroups, MerchantGroups,
  AcceptedCountries
- Full Card Lifecycle: CardTransitions, BulkCardOrders, PINs, DigitalWalletsManagement,
  TokenizationAsAService
- Full Compliance: KYCVerification, UserTransitions, BusinessTransitions, AccountHolderGroups,
  FraudFeedback, ThreeDSecure
- Full Fees: Fees, FeeCharges, FeeRefunds
- Full Disputes: DisputesVisa, DisputesMastercard, DisputesPulse, DisputesEvidenceCollection
- Full Credit Platform (25 modules): Accounts, Cards, Applications, Bundles, Products, Policies,
  Payments, PaymentSchedules, PaymentSources, JournalEntries, LedgerEntries, Statements,
  Disputes, Adjustments, Rewards, RewardAccounts, RewardRedemptions, RewardRules,
  RewardConversions, RewardGlobalConfigurations, Delinquency, Transitions, Substatuses,
  Refunds, BalanceRefunds
- Full DiVA API (35 modules): All analytics and reporting views
- Platform: Webhooks, GatewayJIT, CommandomMode, SelfServiceCredentials, Simulations, Sandbox
- HTTP/2 connection pooling via Finch
- Automatic retry with exponential backoff and jitter
- Lazy streaming for all paginated list endpoints via `Marqeta.Stream`
- Telemetry events for all HTTP requests with built-in metrics definitions
- Token-bucket rate limiter GenServer
- Typed error structs with retryability flags and field-level errors
- Webhook HMAC-SHA256 signature verification
- Gateway JIT Funding request/response builder helpers
- Config validation via NimbleOptions with persistent_term caching
- ExMachina test factory with realistic fixtures for all resource types
- Bypass-based HTTP mock helpers for unit tests
- Credo + Dialyzer + ExCoveralls integration
- GitHub Actions CI with matrix testing (Elixir 1.16/1.17, OTP 26/27)
- Full hex docs with grouped module documentation

[Unreleased]: https://github.com/iamkanishka/marqeta/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/iamkanishka/marqeta/releases/tag/v1.0.0
