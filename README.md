# Obscura

> Private RWA infrastructure for SME credit. Encrypt an invoice. Get liquidity. Nothing hits the chain in plaintext.

---

## The Problem

Invoice financing is a $3 trillion global market. SMEs across Lagos, Nairobi, Jakarta, and Karachi hold billions in unpaid invoices from Tier-1 corporates and government entities. Lenders have idle capital seeking real-world yield. The market mechanism is understood. The demand is proven.

Yet the market has not moved on-chain at scale — for one specific reason: **privacy.**

To finance an invoice on-chain today, an SME must permanently expose their client relationships, invoice amounts, buyer identity, and payment history to every competitor, regulator, and observer on the network. No serious business accepts this. Centrifuge proved the mechanics work. Goldfinch proved the demand is real in emerging markets. Neither solved privacy. Neither scaled.

**FHE is the only cryptographic primitive that enables computation on encrypted data without decryption.** Obscura runs credit scoring, yield calculation, and compliance checks directly on ciphertext — returning only the result. Nothing touches plaintext on-chain, ever.

---

## What Obscura Does

Obscura is a privacy-preserving invoice financing protocol built on Fhenix CoFHE and Privara.

- **SMEs** tokenize unpaid invoices as encrypted real-world assets
- **Lenders** finance them by reviewing FHE-computed risk scores — never raw invoice data
- **Regulators** receive threshold compliance proofs on demand — without seeing invoice amounts or counterparty identities

The core flow:

```
Invoice → Encrypted RWA Token → Private Financing Market → Confidential Yield → Selective Compliance Disclosure
```

---

## Who It's For

**SME Originators** — Businesses in emerging markets holding unpaid invoices from creditworthy buyers. They need liquidity now, not in 90 days when the invoice settles, and cannot afford to expose client relationships on a public ledger.

**Lenders** — DeFi participants, African asset managers, and institutional capital allocators seeking real-world yield with privacy-preserving due diligence. They want verified, risk-scored receivables — not the legal exposure of seeing sensitive SME business data.

---

## Core Features

### Encrypted Position Vaults

Invoice data — amount, buyer identity, due date — is encrypted via Fhenix CoFHE on submission and minted as a private ERC-1155 RWA token. The token is tradeable on the financing marketplace. The underlying data is ciphertext, always.

### FHE Credit Scoring

The `CreditOracle` contract computes a risk score directly on encrypted invoice fields — verifying amount ranges, buyer creditworthiness, and tenor — returning only a plaintext score (e.g. A–, 87/100). No raw data is exposed to lenders at any point.

### Compliant Private Payment Rails

Privara handles KYB/KYC onboarding, stablecoin disbursement, sanctions screening, and FX off-ramp — all without exposing identity data on-chain. Encrypted credentials are issued at onboarding and produce boolean compliance checks when queried.

### Confidential Yield & Settlement

Lenders fund invoices at a discount rate. At maturity, the contract auto-settles — lender receives principal plus financing fee. Yield computation runs in encrypted space throughout. Default escalation triggers multi-party threshold decryption, the only moment any invoice data is ever decrypted.

### Selective Disclosure for Compliance

SMEs and lenders generate threshold proofs on demand — "total receivables exceed $X" or "all counterparties are non-sanctioned" — without revealing invoice amounts, buyer names, or business relationships. Regulators receive exactly what they need and nothing more.

### Encrypted Reputation Scoring

Successful repayments update an encrypted on-chain reputation score. After 3+ repayments, borrowers qualify for higher advance rates and lower fees. The score is privacy-preserving and portable across pool tiers.

---

## Pool Architecture

Three pool tiers, one set of contracts. Differentiation is in parameters and credential requirements.

| Pool              | Ticket Size  | Advance Rate | Discount Rate | Credential              |
| ----------------- | ------------ | ------------ | ------------- | ----------------------- |
| Institutional     | $50K – $5M   | 80–85%       | 8–10% p.a.    | KYB + Accredited Lender |
| Government-backed | $100K – $10M | 75–80%       | 10–12% p.a.   | KYB + Gov Contract Ref  |
| Retail            | $1K – $50K   | 75–80%       | 12–15% p.a.   | Individual KYC          |

---

## Three Workflows

**Corporate Invoice** — A Lagos FMCG supplier submits an $80,000 invoice from Unilever Nigeria. Fhenix encrypts all fields, a risk score is computed, a lender funds 85% at 8% annualised, Privara disburses $68,000 USDC to the SME. At maturity, the contract auto-settles.

**Government Contract** — A Kenyan construction firm submits a $500,000 invoice against a Ministry of Works contract. The government reference is encrypted and verified via FHE oracle, the token is flagged as government-backed tier, and an institutional lender funds 80% cross-border via Privara.

**Freelancer Invoice** — A Nigerian developer submits a $15,000 invoice from a UK fintech. Individual KYC via Privara, routed to the retail pool, 80% advance disbursed with NGN off-ramp available. Reputation score begins accumulating.

---

## Tech Stack

| Layer                | Technology                                      |
| -------------------- | ----------------------------------------------- |
| FHE computation      | Fhenix CoFHE coprocessor on Base Sepolia        |
| Solidity FHE library | cofhe-contracts v0.0.13                         |
| Client SDK           | @cofhe/sdk                                      |
| Payment rails        | Privara (`@reineira-os/sdk`)                    |
| Token standards      | ERC-1155 (private RWA token) + ERC-4626 (vault) |
| Frontend             | SvelteKit + Svelte 5                            |
| Web3 client          | viem                                            |
| Network              | Base Sepolia (testnet)                          |

---

## Smart Contracts

| Contract                 | Responsibility                                                               |
| ------------------------ | ---------------------------------------------------------------------------- |
| `CredentialRegistry.sol` | Encrypted KYB/KYC credentials via Privara. Issues boolean compliance checks. |
| `InvoiceVault.sol`       | Encrypts invoice fields, mints private ERC-1155 RWA token.                   |
| `CreditOracle.sol`       | FHE credit scoring engine. Computes risk score on encrypted inputs.          |
| `FinancingPool.sol`      | Funding, escrow, repayment, yield settlement, default escalation.            |

---

## Roadmap

### Wave 1 — Buildathon ✦ current

Corporate invoice flow end-to-end on Base Sepolia. Real Fhenix FHE encryption. Privara KYB and USDC disbursement. SME and lender dashboards. Mock buyer oracle data.

### Wave 2

Government contract receivables and freelancer invoice flows. Default escalation with threshold decryption. Encrypted reputation scoring begins accumulating.

### Wave 3

Live oracle feeds replace mock data. Privara full FX off-ramp for NGN, KES, IDR. Selective disclosure proof generator for regulators. First real invoice financed.

### Wave 4

Permissionless pool factory — any institution deploys a private credit facility with custom parameters. Dedicated auditor interface for regulatory proof verification.

### Wave 5

Private secondary market for invoice tokens. Protocol governance token. Cross-border trade finance expansion.

---

## Why FHE, Not ZK or MPC

| Approach                                  | Why it fails                                                                         |
| ----------------------------------------- | ------------------------------------------------------------------------------------ |
| Public blockchain (Centrifuge, Goldfinch) | All invoice data permanently visible — no serious business accepts this              |
| Off-chain database                        | Defeats crypto's purpose. Requires trusting a centralised party with plaintext.      |
| Zero-knowledge proofs                     | Can verify statements about data but cannot compute on private inputs                |
| Multi-party computation                   | Requires all parties online simultaneously. Not production-ready at this scale.      |
| **FHE (Obscura)**                         | **Computation runs on ciphertext. Results come out. Nothing in between is visible.** |

---

## Market Opportunity

| Segment                    | Size                    |
| -------------------------- | ----------------------- |
| Global invoice financing   | $3 trillion             |
| African SME credit gap     | $330 billion            |
| On-chain RWA tokenisation  | $50 billion and growing |
| Cross-border trade finance | $10 trillion            |

---

## Competitive Position

Obscura = Centrifuge's invoice model + Goldfinch's emerging market focus + FHE privacy that neither has.

---

_Built on Fhenix CoFHE and Privara · Base Sepolia · Akindo WaveHack 2026_

# sv

Everything you need to build a Svelte project, powered by [`sv`](https://github.com/sveltejs/cli).

## Creating a project

If you're seeing this, you've probably already done this step. Congrats!

```sh
# create a new project
npx sv create my-app
```

To recreate this project with the same configuration:

```sh
# recreate this project
npx sv@0.13.0 create --template minimal --types ts --add prettier eslint vitest="usages:unit,component" playwright tailwindcss="plugins:none" mcp="ide:vscode+setup:remote" --install npm ./
```

## Developing

Once you've created a project and installed dependencies with `npm install` (or `pnpm install` or `yarn`), start a development server:

```sh
npm run dev

# or start the server and open the app in a new browser tab
npm run dev -- --open
```

## Building

To create a production version of your app:

```sh
npm run build
```

You can preview the production build with `npm run preview`.

> To deploy your app, you may need to install an [adapter](https://svelte.dev/docs/kit/adapters) for your target environment.
