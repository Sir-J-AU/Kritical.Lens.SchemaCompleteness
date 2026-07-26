# Stale-scope truncation findings — Kritical.Lens.SchemaCompleteness

**Provenance**

| Field | Value |
|---|---|
| Date (UTC, absolute) | 2026-07-25T04:11Z – 05:20Z |
| Repo | `Kritical.Lens.SchemaCompleteness` |
| Branch | `main` |
| Commit SHA at observation | `7c9936a5e27d6e768207b46526a458403e4aff69` |
| Working tree at observation | dirty (1 entries) — other lanes may be active; **nothing in this repo was modified**, this is a findings document only |
| Estate-level report | `C:\temp\STALE-SCOPE-TRUNCATION-HUNT-20260725.md` |

**Bug class hunted.** A filter, range, list, limit or timeout is hardcoded once; the codebase
or its upstream data grows past it; the code keeps reporting SUCCESS while covering only a
fraction of what it claims. It never errors. It always looks green.

> **No code in this repo was changed by this hunt.** Findings are reports. Severity ranking and
> the estate-wide picture are in the estate-level report above.

---
## H4 (HIGH) — a 12-entry hardcoded map bounds the work loop for a gate that reports a coverage percentage

`src/Private/_Pax8MirrorMap.ps1:27-42` — consumed at
`src/Public/Invoke-KriticalLensAlSchemaCompleteness.ps1:95`, where
`foreach ($mid in ($mirrorMap.Keys | Sort-Object))` is the **entire** work loop for gates
M1/M2/M3/M4.

```powershell
# 12 entries: 60100,60120,60121,60185,60187,60218,60189,60219,60222,60223,50139,50140
```

The docstring calls itself *"The authoritative map"* and claims *"no upstream field list is
hard-coded"* — true for **fields**, false for the **table set**, which is what bounds the
report.

**Authoritative source:** the connector's own AL table objects — already parsed into `$alIndex`
at line 83, and available in the `KriticalBrain.lens.al_object` corpus — joined to
`components.schemas` in the Pax8 spec.

**Computed exclusion** (against `Kritical.AL.D365BC.Connector.Pax8-to-Storefront` @ `0bd96a84`):

```
AL files: 840 ; AL table objects (non-extension): 69
Ids in _Pax8MirrorMap: 12   (all 12 present in the connector)
AL tables NOT in the map: 57
Tables whose NAME contains 'Mirror': 20
  ...of which NOT in _Pax8MirrorMap: 10      -> 50% of mirror tables never gated
```

Never gated: `60160 Pax8 Shopify Customer Mirror`, `60186 Pax8 Provisioning Mirror`,
`60188 Pax8 Product Dependency Mirror`, `60220 Pax8 Subscription Hist Mirror`,
`60275 Krit Pax8 Company Mirror`, `60277 Krit Pax8 CompMapping Mirror`,
`60280 Krit Pax8 Contact Mirror`, `60284 Krit Pax8 Inv Header Mirror`,
`60285 Krit Pax8 Inv Line Mirror`, `60292 Pax8 Quote Mirror`.

Spec side (`Kritical-Pax8API/specs/partner-endpoints.json`): 26 schemas total, 9 referenced by
the map. After discounting legitimate exclusions (FlattenRefs, envelopes, write DTOs),
**9 real data schemas with 52 properties are unmirrored and unreported**: `Commitment`(10),
`ContactType`(2), `Dependencies`(2), `LineItem`(11), `Order`(8), `Product`(8),
`ProductDependency`(2), `ProvisioningDetail`(6), `SubscriptionCommitment`(3).

**Two distinct lies produced:**
- **False green** — the report's `## Per-gate verdict` M1/M2/M3/M4 `Ready %` columns are
  computed over 12 tables and presented as connector-wide readiness.
- **False red** — gate M4 (lines 164-178) resolves child-array mirrors *from the same 12-entry
  map*, so `Subscription.provisioningDetails` → `ProvisioningDetail` emits
  `CHILD-COLLECTION-NOT-MIRRORED` **even though `60186 Pax8 Provisioning Mirror` exists on
  disk**. Same for `ProductDependency` vs `60188`.

**Evidence:** VERIFIED-BY-EXECUTION.

## Checked and CLEAN — do not re-litigate
- `_KriticalLensLoadPax8Schemas.ps1` is genuinely spec-driven with no hardcoded field lists;
  it handles `$ref`, `allOf`, and typeless-`items` arrays correctly.
- `Invoke-KriticalLensAlSchemaCompleteness.ps1:243` — the 200-row MD cap is display-only; the
  JSON `Rows` collection is complete.

## Recommended fix
Derive the mirror set from `$alIndex` / `lens.al_object` and report unmapped mirror tables as a
`MIRROR-NOT-MAPPED` finding class instead of omitting them from the denominator.
---

## Method

Multiple independent detection methods were used throughout, because **a low count from one
detector means the detector missed, not that the code is clean**: ripgrep regex sweeps,
PowerShell `Select-String` over enumerated file censuses, and — where quantification was
needed — direct execution, AST introspection, manifest parsing, or filesystem enumeration.

**Note on tooling:** `rg` is **not** on PATH inside the Bash tool on this host. The first
sweep of this hunt returned 0 hits for every pattern; that was a detector failure, not a clean
result. Use the Grep tool or PowerShell `Select-String`, and verify any zero with a second
method.

**Evidence tags** used above: VERIFIED-BY-EXECUTION (command run, output quoted) /
READ-FROM-SOURCE / INFERRED / UNKNOWN. A skip is never recorded as a pass.
