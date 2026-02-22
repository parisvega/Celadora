# Celadora Economy and Compliance Notes (v0.1)

## Current Scope
Celadora v0.1 uses an internal soft currency (`Celador Credits`) and a local simulated marketplace. No real-money payments, crypto transfers, or tokenized assets are executed.

## Why Real-Money Trading Is Deferred
Real-money economies introduce legal and operational obligations that exceed prototype scope:
- Financial regulation exposure varies by jurisdiction.
- Consumer protection and dispute handling become mandatory.
- Tax reporting and accounting treatment are required.

## KYC/AML and Anti-Fraud Considerations
If value becomes withdrawable or tokenized, a production system typically needs:
- Identity verification (KYC)
- Anti-money-laundering monitoring (AML)
- Transaction monitoring, sanctions screening, and suspicious-activity workflows
- Fraud detection and account-risk controls

These controls must be designed with legal counsel and compliance specialists before launch.

## Why Server Authority Is Required
Client-side authority is insufficient for economies with value:
- Clients can be modified to forge inventory/currency states.
- Trade settlement must be atomic and auditable.
- Anti-cheat requires server-side verification of resource generation, combat rewards, and market operations.

## Optional Token Integration Path (Future)
A token module can be added later as an optional integration layer:
1. Keep a strict feature flag with default OFF.
2. Route all token operations through a backend service with compliance gating.
3. Use custody/bridge providers only after legal review.
4. Log every transfer request and settlement event for auditability.
5. Preserve gameplay when token services are disabled.

`TokenBridge` scripts in v0.1 are intentionally stubbed and disabled.
