# Wave 1 User Stories

## Summary

| ID    | Title                                  | Actor        |
| ----- | -------------------------------------- | ------------ |
| US-01 | Wallet connection & KYB onboarding     | SME          |
| US-02 | Invoice submission & encryption        | SME          |
| US-03 | FHE credit scoring                     | Protocol     |
| US-04 | Lender onboarding & marketplace access | Lender       |
| US-05 | Invoice funding & advance disbursement | Lender + SME |
| US-06 | Repayment & auto-settlement            | SME + Lender |

- **US-01** — SME connects wallet, completes KYB via Privara. Encrypted credential minted to CredentialRegistry. Unverified wallets cannot submit invoices.
- **US-02** — SME submits invoice (amount, buyer, due date). Fhenix CoFHE encrypts all fields. InvoiceVault mints a private ERC-1155 token. Nothing visible on marketplace except risk score.
- **US-03** — CreditOracle runs FHE computation on encrypted invoice fields. Returns a 0–100 risk score. No raw data exposed.
- **US-04** — Lender connects wallet, completes accredited lender verification. Dashboard shows risk score, advance amount, discount rate, tenor — nothing else.
- **US-05** — Lender funds invoice at a discount. FinancingPool locks token in escrow. Privara releases USDC advance to SME wallet. Both dashboards update.
- **US-06** — SME repays at maturity. Contract auto-settles: lender gets principal + fee. Token burned, position closed on both dashboards.

---

## US-01 — Wallet Connection & KYB Onboarding (SME)

> As an SME, I want to connect my wallet and complete business verification so that I can access the protocol and submit invoices.

- SME connects wallet via standard web3 modal
- Privara KYB flow launches and collects business credentials
- Encrypted credential minted to `CredentialRegistry.sol` as ciphertext
- SME receives a verified status on their dashboard — no raw credential data visible on-chain
- Unverified wallets cannot submit invoices

---

## US-02 — Invoice Submission & Encryption (SME)

> As an SME, I want to submit an invoice so that it is encrypted and tokenized as a private RWA without exposing my buyer or invoice amount to anyone.

- SME inputs invoice amount, buyer name, and due date in the dashboard
- Fhenix coprocessor encrypts all invoice fields on submission
- `InvoiceVault.sol` mints a private ERC-1155 token representing the invoice
- Token appears on the financing marketplace — amount and buyer name not visible
- SME dashboard confirms submission with token ID and encrypted status

---

## US-03 — FHE Credit Scoring (Protocol)

> As the protocol, I want to compute a credit risk score on encrypted invoice data so that lenders can assess risk without seeing any raw invoice information.

- `CreditOracle.sol` runs FHE computation on encrypted invoice fields
- Checks: invoice amount within pool range, buyer creditworthiness above threshold (mock oracle), due date within tenor
- Returns a risk score (e.g. A–, 87/100) — no raw data exposed
- Score attached to the invoice token on the marketplace
- Invoices failing the credit check are flagged as ineligible — SME notified without reason detail

---

## US-04 — Lender Onboarding & Marketplace Access (Lender)

> As a lender, I want to connect my wallet and access the financing marketplace so that I can browse invoices by risk score and fund them.

- Lender connects wallet and completes accredited lender verification via Privara
- Lender dashboard displays available invoices showing: risk score, advance amount, discount rate, tenor — nothing else
- Invoice amounts and buyer identities are not shown at any point
- Lender can filter by risk tier and tenor

---

## US-05 — Invoice Funding & Advance Disbursement (Lender + SME)

> As a lender, I want to fund an invoice at a discount rate so that the SME receives a stablecoin advance and I hold a claim on the full settlement amount at maturity.

- Lender selects an invoice and confirms funding terms (advance %, discount rate)
- SME accepts terms on-chain
- `FinancingPool.sol` locks the invoice token in escrow
- Privara releases USDC advance to SME wallet
- Both dashboards update: SME shows advance received, lender shows active position

---

## US-06 — Repayment & Auto-Settlement (SME + Lender)

> As an SME, I want to repay the advance at maturity so that the lender receives their principal plus financing fee and the invoice token is closed.

- SME triggers repayment from their dashboard
- `FinancingPool.sol` auto-settles: lender receives principal + fee
- Invoice token burned, position closed on both dashboards
- Transaction confirmed on-chain with settlement receipt

---

## Implementation Status

### US-01 — Wallet Connection & KYB Onboarding

**Flow:** Connect wallet → role select → KYB form → `selfVerify()` on-chain → verified status

| Step                                  | File                    |
| ------------------------------------- | ----------------------- |
| Wallet connect / restore / disconnect | `wallet.svelte.ts`      |
| viem clients (Base Sepolia)           | `client.ts`             |
| `window.ethereum` type                | `app.d.ts`              |
| Layout + wallet UI (header, badge)    | `+layout.svelte`        |
| Role selection page                   | `+page.svelte`          |
| KYB form + `selfVerify()` tx          | `+page.svelte`          |
| CredentialRegistry ABI                | `CredentialRegistry.ts` |
| Contract addresses                    | `addresses.ts`          |

**Status: OK** — `selfVerify()` calls match ABI, `checkVerified()` reads `isVerified`, localStorage persistence works.

---

### US-02 — Invoice Submission & Encryption

**Flow:** FHE init → encrypt amount + due date → `submitInvoice()` on-chain → ERC-1155 minted

| Step                                  | File                        |
| ------------------------------------- | --------------------------- |
| FHE init + `encryptUint128()`         | `client.ts`                 |
| Invoice submit form (standalone page) | `+page.svelte`              |
| Invoice submit modal (alternative)    | `InvoiceSubmitModal.svelte` |
| InvoiceVault ABI                      | `InvoiceVault.ts`           |
| Contract addresses                    | `addresses.ts`              |

**Status: OK** — `encryptUint128()` returns `{ ctHash, securityZone, utype, signature }` matching the deployed `InEuint128` struct. Both the page and modal pass this tuple to `submitInvoice`.

**Fixed:** Stale "Fhenix Helium" text → "Base Sepolia" in the invoice page.

---

### US-03 — FHE Credit Scoring

**Flow:** SME requests score → `requestScore()` → `finalizeScore(tokenId, score, sig)` → score visible

| Step                                                              | File              |
| ----------------------------------------------------------------- | ----------------- |
| `requestScore()` + `finalizeScore()`                              | `sme.svelte.ts`   |
| `loadInvoices()` reads `scoreRequested`, `scoreReady`, `getScore` | `sme.svelte.ts`   |
| Score request / finalize buttons                                  | `+page.svelte`    |
| CreditOracle ABI                                                  | `CreditOracle.ts` |

**Status: OK** — `finalizeScore` now passes 3 args `(tokenId, 7, '0x')` matching the deployed ABI. Score display and tier grading work.

**Fixed:** FHE status panel showed "Fhenix Helium / 8008135" → now "Base Sepolia / 84532".

---

### US-04 — Lender Onboarding & Marketplace Access

**Flow:** Connect wallet → select lender role → marketplace loads scored unfunded invoices

| Step                                                         | File               |
| ------------------------------------------------------------ | ------------------ |
| Role selection                                               | `+page.svelte`     |
| `loadListings()` — reads all invoices, scores, funded status | `lender.svelte.ts` |
| Marketplace UI with tier/tenor filters                       | `+page.svelte`     |
| CreditOracle ABI (score reads)                               | `CreditOracle.ts`  |
| InvoiceVault ABI (meta reads)                                | `InvoiceVault.ts`  |
| FinancingPool ABI (`isFunded` check)                         | `FinancingPool.ts` |

**Status: OK** — Amounts show "●●●● USDC" (encrypted). Lender sees score, tier, originator, date — no raw amounts or buyer identities.

---

### US-05 — Invoice Funding & Advance Disbursement

**Flow:** Lender selects invoice → sets advance/discount rates → `fundInvoice()` on-chain → Privara mock disbursement

| Step                                       | File                                            |
| ------------------------------------------ | ----------------------------------------------- |
| Fund position page (rate sliders, confirm) | `src/routes/lender/fund/[tokenId]/+page.svelte` |
| `fundInvoice()` tx                         | `lender.svelte.ts`                              |
| Fund confirm modal (alternative UI)        | `FundConfirmModal.svelte`                       |
| Privara USDC disbursement (Wave 1 mock)    | `client.ts`                                     |
| FinancingPool ABI                          | `FinancingPool.ts`                              |
| Portfolio sidebar (lender positions)       | `+page.svelte`                                  |

**Status: OK** — `fundInvoice(tokenId, advanceRateBps, discountRateBps)` matches ABI. Privara mock returns synthetic txId. Both dashboards update.

**Fixed:** Stale "Fhenix Helium" text → "Base Sepolia" in the fund page.

---

### US-06 — Repayment & Auto-Settlement

**Flow:** SME requests settlement → `finalizeSettlement(tokenId, repay, sig)` → SME repays ETH → position settled

| Step                                                                              | File                                          |
| --------------------------------------------------------------------------------- | --------------------------------------------- |
| Repay page (request settlement, finalize, repay)                                  | `src/routes/sme/repay/[tokenId]/+page.svelte` |
| `requestSettlement()` + `finalizeSettlement()` + `repay()`                        | `sme.svelte.ts`                               |
| `loadInvoices()` reads `settlementRequested`, `settlementReady`, `getRepayAmount` | `sme.svelte.ts`                               |
| FinancingPool ABI                                                                 | `FinancingPool.ts`                            |
| Settlement status in lender portfolio                                             | `+page.svelte`                                |

**Status: OK** — `finalizeSettlement` now passes 3 args `(tokenId, repayAmount, '0x')` matching the deployed ABI. `repay()` sends ETH via `value: amount`.

---

## Shared Infrastructure

| File              | Purpose                                   |
| ----------------- | ----------------------------------------- |
| `client.ts`       | Base Sepolia public + wallet clients      |
| `addresses.ts`    | 4 deployed contract addresses             |
| `toast.svelte.ts` | Toast notifications                       |
| `Toast.svelte`    | Toast UI                                  |
| `+layout.svelte`  | Shell: header, nav, wallet badge, restore |
| `layout.css`      | Tailwind + theme                          |
