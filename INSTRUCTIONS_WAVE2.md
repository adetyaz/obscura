# INSTRUCTIONS.md
# Obscura Protocol — Wave 2
# Government Contract · Freelancer Invoice · Reputation Scoring · Default Escalation

---

## CRITICAL: READ THIS FIRST

Read `fhe-assistant/core.md` from the root of this repository before writing any code.
Keep it loaded for the entire session. Every FHE decision traces back to it.

---

## 1. WHAT YOU ARE BUILDING

Wave 2 expands the protocol with three new capabilities:

**1. Government Contract Receivable**
A Kenyan construction firm submits a $500,000 Ministry of Works invoice. Two documents are encrypted on submission — the invoice and a government contract reference number. FHE verifies the reference matches a known government entity without revealing which ministry. The token is classified as government-backed tier and receives an elevated risk score automatically.

**2. Freelancer Invoice**
A Nigerian developer submits a $15,000 invoice from a UK fintech client. Individual KYC via Privara — lighter than business KYB. Routed to the retail pool ($1K–$50K). Privara handles USDC → NGN FX conversion at disbursement. No crypto knowledge required from the freelancer.

**3. Encrypted Reputation Scoring**
Every successful repayment updates an encrypted score stored in CreditOracle. After 3+ repayments, the borrower qualifies for higher advance rates (85–90%) and lower fees. The score is never exposed — only its effect on credit scoring output is visible. The score is portable across pool tiers.

**4. Default Escalation**
If a borrower does not repay after the grace period expires, the lender triggers escalation. Multi-party threshold decryption unlocks buyer identity and invoice amount. The lender receives full documentation for legal recovery. This is the only moment any invoice data is ever decrypted in the protocol.

---

## 2. CURRENT STATE OF THE CODEBASE

The following contracts are already deployed and working from Wave 1. Do not rewrite them from scratch — extend them.

- `CredentialRegistry.sol` — stores encrypted KYB credentials, issues verified status
- `InvoiceVault.sol` — encrypts invoice fields, mints ERC-1155 tokens
- `CreditOracle.sol` — computes risk scores on encrypted data
- `FinancingPool.sol` — handles funding, escrow, repayment, settlement

The following routes exist:
- `/sme` — SME dashboard
- `/lender` — Lender dashboard

Do not break any existing Wave 1 functionality. All Wave 2 changes are additive.

---

## 3. PACKAGE VERSIONS — USE THESE EXACTLY

| Package | Version |
|---|---|
| `@fhenixprotocol/cofhe-contracts` | `0.1.3` |
| `@cofhe/sdk` | `0.4.0` |
| `@cofhe/hardhat-plugin` | `0.4.0` |
| `@cofhe/mock-contracts` | `0.4.0` |
| `@fhenixprotocol/cofhe-errors` | `1.0.2` |
| `@reineira-os/sdk` | latest |
| `viem` | latest stable |
| `svelte` | `5.x` |
| `@sveltejs/kit` | latest stable |
| `solidity` | `^0.8.24` |

**`cofhejs` does not exist.** Do not use it. The correct package is `@cofhe/sdk`.

---

## 4. NETWORK

**Network:** Base Sepolia
**Chain ID:** 84532
**RPC:** https://sepolia.base.org
**Explorer:** https://sepolia.basescan.org
**CoFHE plugin name:** `base-sepolia`

---

## 5. CONTRACT CHANGES

### CredentialRegistry.sol — add individual KYC tier

Wave 1 only had KYB. Wave 2 adds individual KYC for freelancers.

```solidity
enum CredentialType { NONE, KYB, KYC_INDIVIDUAL }

mapping(address => CredentialType) private credentialTypes;

// Called by Privara SDK — not by a single owner wallet
function setVerifiedKYB(address wallet) external onlyPrivara {
    credentialTypes[wallet] = CredentialType.KYB;
}

function setVerifiedKYC(address wallet) external onlyPrivara {
    credentialTypes[wallet] = CredentialType.KYC_INDIVIDUAL;
}

function getCredentialType(address wallet) external view returns (CredentialType) {
    return credentialTypes[wallet];
}
```

Access control is multi-party — Privara signs credential transactions. No single owner wallet can verify addresses unilaterally.

---

### InvoiceVault.sol — add pool tier + government reference field

```solidity
enum PoolTier { INSTITUTIONAL, GOVERNMENT, RETAIL }

struct InvoiceToken {
    euint128 encryptedAmount;
    euint128 encryptedDueDate;
    bytes encryptedBuyer;
    bytes encryptedGovRef;   // empty for non-government invoices
    PoolTier tier;
    uint8 riskScore;
    address originator;
    bool active;
}
```

New submission function for government invoices:
```solidity
function submitGovernmentInvoice(
    inEuint128 calldata encryptedAmount,
    inEuint128 calldata encryptedDueDate,
    bytes calldata encryptedBuyer,
    bytes calldata encryptedGovRef
) external onlyVerifiedKYB {
    euint128 amount = FHE.asEuint128(encryptedAmount);
    FHE.allowTransient(amount, address(creditOracle));
    // store encryptedGovRef as ciphertext
    // mint token with GOVERNMENT tier
}
```

New submission function for freelancer invoices:
```solidity
function submitFreelancerInvoice(
    inEuint128 calldata encryptedAmount,
    inEuint128 calldata encryptedDueDate,
    bytes calldata encryptedBuyer
) external onlyVerifiedKYC {
    // same pattern — mint token with RETAIL tier
}
```

Read `fhe-assistant/core.md` — access control section — before writing any `FHE.allow*` calls.

---

### CreditOracle.sol — add reputation scoring + government tier scoring

```solidity
// Encrypted reputation scores per borrower
mapping(address => euint32) private reputationScores;
mapping(address => uint8) public repaymentCounts;

// Called by FinancingPool on every successful repayment
function updateReputation(address borrower) external onlyFinancingPool {
    repaymentCounts[borrower]++;
    reputationScores[borrower] = FHE.add(
        reputationScores[borrower],
        FHE.asEuint32(10)
    );
}

// Returns advance rate tier based on repayment history
function getAdvanceRateTier(address borrower) external view returns (uint8) {
    if (repaymentCounts[borrower] >= 3) return 90;
    return 85;
}

// Government invoices score higher — FHE verifies gov reference
function scoreGovernmentInvoice(uint256 tokenId) external returns (uint8) {
    // FHE checks encryptedGovRef matches a known government entity hash
    // Returns score in 88–100 range
}
```

Never expose the raw reputation score. Only `getAdvanceRateTier()` is readable externally.

FHE rules apply to all operations above:
- Never use `if (ebool)` — use `FHE.select()`
- Always `FHE.allow*` before cross-contract encrypted value passing
- Decryption is async — use callback patterns

---

### FinancingPool.sol — add grace period + default escalation

```solidity
uint256 public constant GRACE_PERIOD = 14 days;

enum PositionStatus { ACTIVE, REPAID, GRACE, ESCALATED, SETTLED }

struct Position {
    uint256 tokenId;
    address lender;
    address borrower;
    uint256 advanceAmount;
    uint256 fee;
    uint256 maturityDate;
    uint256 gracePeriodEnd;
    PositionStatus status;
}

// Lender triggers after grace period expires
function triggerEscalation(uint256 tokenId) external {
    Position storage pos = positions[tokenId];
    require(msg.sender == pos.lender, "Not lender");
    require(block.timestamp > pos.gracePeriodEnd, "Grace period active");
    require(pos.status == PositionStatus.GRACE, "Not in grace");
    pos.status = PositionStatus.ESCALATED;
    emit EscalationTriggered(tokenId, pos.lender, pos.borrower);
    // Frontend listens for this event and calls decryptForTx
    // The contract does not handle plaintext — decryption happens client-side
    // via the Threshold Network
}

event EscalationTriggered(uint256 indexed tokenId, address lender, address borrower);
event GracePeriodStarted(uint256 indexed tokenId, uint256 gracePeriodEnd);
```

No single wallet can force-settle or force-close a position. Settlement is triggered only by repayment or escalation, never by an admin function.

---

## 6. POOL CONFIGURATION

```solidity
struct PoolConfig {
    uint256 minTicket;      // USDC with 6 decimals
    uint256 maxTicket;
    uint8   advanceRate;    // percentage e.g. 85 = 85%
    uint16  discountRateBps;// basis points p.a. e.g. 1000 = 10%
    uint8   maxTenorDays;
}

// Institutional
minTicket:        50_000e6
maxTicket:     5_000_000e6
advanceRate:           85
discountRateBps:      800   // 8% p.a.
maxTenorDays:         180

// Government-backed
minTicket:       100_000e6
maxTicket:    10_000_000e6
advanceRate:           80
discountRateBps:     1000   // 10% p.a.
maxTenorDays:         180

// Retail (freelancers + micro-SMEs)
minTicket:         1_000e6
maxTicket:        50_000e6
advanceRate:           80
discountRateBps:     1200   // 12% p.a.
maxTenorDays:          90
```

---

## 7. CLIENT SDK — @cofhe/sdk v0.4.0

The SDK follows a three-step lifecycle: config → client → connect.

```typescript
import { createCofheConfig, createCofheClient } from '@cofhe/sdk/web'
import { Encryptable, FheTypes, CofheError } from '@cofhe/sdk'
import { chains } from '@cofhe/sdk/chains'

// Initialise
const config = createCofheConfig({ supportedChains: [chains.baseSepolia] })
const client = createCofheClient(config)
await client.connect(publicClient, walletClient)
// Keys and WASM load lazily on first encryptInputs call

// Encrypt inputs
const [encAmount, encDueDate] = await client
  .encryptInputs([
    Encryptable.uint128(BigInt(amount)),
    Encryptable.uint128(BigInt(dueDate)),
  ])
  .execute()

// Permit
await client.permits.getOrCreateSelfPermit()

// Decrypt for UI
const score = await client
  .decryptForView(ctHash, FheTypes.Uint8)
  .execute()

// Decrypt for on-chain use — used in escalation flow
const result = await client
  .decryptForTx(ctHash, FheTypes.Address)
  .execute()
// result contains plaintext + Threshold Network signature

// Error handling
try { ... } catch (err) {
  if (err instanceof CofheError) console.error(err.code, err.message)
}
```

---

## 8. FRONTEND CHANGES

### New routes
```
src/routes/
├── sme/+page.svelte          ← update: add gov + freelancer invoice type selector
├── lender/+page.svelte       ← update: add grace period countdown + escalation button
└── freelancer/+page.svelte   ← NEW: individual KYC + retail invoice flow
```

### Invoice type selector on SME dashboard
Three submission paths selectable by the SME:
- Corporate invoice (existing)
- Government contract (two fields: invoice + contract reference)
- Freelancer invoice (routes to `/freelancer`)

### Grace period + escalation on lender dashboard
```typescript
// Watch for positions entering grace
publicClient.watchContractEvent({
  address: ADDRESSES.FinancingPool,
  abi: FINANCING_POOL_ABI,
  eventName: 'GracePeriodStarted',
  onLogs: (logs) => {
    // Show countdown timer on lender dashboard
  }
})

// Watch for escalation confirmation
publicClient.watchContractEvent({
  address: ADDRESSES.FinancingPool,
  abi: FINANCING_POOL_ABI,
  eventName: 'EscalationTriggered',
  onLogs: async (logs) => {
    const { tokenId } = logs[0].args
    const buyerCtHash = await publicClient.readContract({
      address: ADDRESSES.InvoiceVault,
      abi: INVOICE_VAULT_ABI,
      functionName: 'getEncryptedBuyer',
      args: [tokenId]
    })
    // Threshold Network decryption — returns plaintext + signature
    const result = await fhe.client
      .decryptForTx(buyerCtHash, FheTypes.Address)
      .execute()
    // Show buyer identity to lender as recovery documentation
  }
})
```

### Reputation tier display on SME dashboard
```typescript
// Do NOT show the raw encrypted score — show only the rate tier effect
const tier = await publicClient.readContract({
  address: ADDRESSES.CreditOracle,
  abi: CREDIT_ORACLE_ABI,
  functionName: 'getAdvanceRateTier',
  args: [walletAddress]
})
// Display: "Your advance rate: 90% (earned through repayment history)"
```

### Svelte 5 rules — unchanged
- Use runes exclusively: `$state()`, `$derived()`, `$effect()`, `$props()`
- No Svelte 4 syntax: no `$:`, no `writable()`, no `export let`
- Stores are `.svelte.ts` files

---

## 8. PRIVARA — WAVE 2 ADDITIONS

Individual KYC is lighter than KYB. Privara handles both flows:

```typescript
// Business KYB (existing)
await privara.issueCredential({ wallet, type: 'KYB', jurisdiction: 'KE' })

// Individual KYC (new in Wave 2)
await privara.issueCredential({ wallet, type: 'KYC_INDIVIDUAL', jurisdiction: 'NG' })

// FX off-ramp — USDC to NGN at disbursement
await privara.transfer({
  to: recipientAddress,
  amount: amountUSDC,
  token: 'USDC',
  outputCurrency: 'NGN',  // convert at disbursement
  network: 'base-sepolia',
})
```

Read the installed `@reineira-os/sdk` types before writing any Privara integration code. Do not assume the API surface.

---

## 9. CONTRACT ADDRESSES

Redeploy any contract whose ABI has changed. CreditOracle and FinancingPool both have new functions and must be redeployed.

```typescript
// src/lib/contracts/addresses.ts
export const ADDRESSES = {
  CredentialRegistry: '0x...' as `0x${string}`,
  InvoiceVault:       '0x...' as `0x${string}`,
  CreditOracle:       '0x...' as `0x${string}`,  // redeploy — new reputation functions
  FinancingPool:      '0x...' as `0x${string}`,  // redeploy — new escalation logic
} as const
```

---

## 10. USER STORIES — BUILD IN THIS ORDER

### US-07: Government contract verification
**Done when:** SME submits invoice + government contract reference, both encrypted, FHE verifies government entity match without revealing the ministry, token receives GOVERNMENT tier classification and elevated risk score.

### US-08: Freelancer KYC + retail pool
**Done when:** Individual connects wallet, completes lighter KYC via Privara, submits freelancer invoice, routed to retail pool, USDC advance disbursed with NGN conversion via Privara.

### US-09: Reputation score accumulation
**Done when:** Successful repayment calls `CreditOracle.updateReputation()`, repayment count increments on-chain, SME dashboard shows improved advance rate eligibility after 3rd repayment.

### US-10: Default escalation
**Done when:** Position passes maturity, enters grace period visible on lender dashboard with countdown, lender triggers escalation after grace expires, `decryptForTx` returns buyer identity + amount with Threshold Network signature, lender dashboard shows recovery documentation.

---

## 11. DESIGN SYSTEM — UNCHANGED

- `--paper: #f5f2eb` — background
- `--ink: #0a0a08` — primary text
- `--accent: #c8401a` — CTAs, active states
- `--muted: #6b6657` — secondary text
- `--border: #d4cfc3` — dividers
- `--teal: #1a6b5c` — success, verified

Typography: DM Serif Display / Instrument Sans / DM Mono. No gradients. No shadows.

---

## 12. KEY DOCUMENTATION

| Topic | URL |
|---|---|
| Compatibility + versions | https://cofhe-docs.fhenix.zone/get-started/introduction/compatibility |
| Client SDK overview | https://cofhe-docs.fhenix.zone/client-sdk/introduction/overview |
| Encrypting inputs | https://cofhe-docs.fhenix.zone/client-sdk/guides/encrypting-inputs |
| Permits | https://cofhe-docs.fhenix.zone/client-sdk/guides/permits |
| Decrypt to view | https://cofhe-docs.fhenix.zone/client-sdk/guides/decrypt-to-view |
| Decrypt to transact | https://cofhe-docs.fhenix.zone/client-sdk/guides/decrypt-to-tx |
| Writing decrypt result | https://cofhe-docs.fhenix.zone/client-sdk/guides/writing-decrypt-result |
| FHE library | https://cofhe-docs.fhenix.zone/fhe-library/introduction/overview |
| FHE API reference | https://cofhe-docs.fhenix.zone/fhe-library/reference/fhe-sol |
| Best practices | https://cofhe-docs.fhenix.zone/fhe-library/introduction/best-practices |
| Migration from cofhejs | https://cofhe-docs.fhenix.zone/client-sdk/introduction/migrating-from-cofhejs |
| cofhe-contracts v0.1.3 | https://github.com/FhenixProtocol/cofhe-contracts/tree/v0.1.3 |
| @cofhe/sdk GitHub | https://github.com/FhenixProtocol/cofhesdk |
| Base Sepolia explorer | https://sepolia.basescan.org |

---

## 13. RULES

1. Read `fhe-assistant/core.md` before writing any Solidity
2. Use `@cofhe/sdk` v0.4.0 — `cofhejs` is dead
3. Use `@fhenixprotocol/cofhe-contracts` v0.1.3
4. Never store plaintext sensitive data on-chain
5. Never use `if (ebool)` — always `FHE.select()`
6. Always `FHE.allow*` before passing encrypted values between contracts
7. No single-owner control — credential verification goes through Privara, no admin bypasses
8. Do not break Wave 1 functionality — all changes are additive
9. Build user stories in order: US-07 → US-08 → US-09 → US-10
10. Confirm each user story is testable before moving to the next
11. Use Svelte 5 runes exclusively
12. Use viem exclusively — no ethers.js
13. Read installed package types before writing any Privara integration — do not assume

---

*Obscura Protocol · Wave 2 · @cofhe/sdk v0.4.0 · @fhenixprotocol/cofhe-contracts v0.1.3 · Base Sepolia*
