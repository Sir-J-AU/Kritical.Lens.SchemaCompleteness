# [LENS-ENGINE] Kritical.Lens.SchemaCompleteness — README (human)

> The **linter** member of the Kritical Lens family — a schema-completeness checker. Asserts
> every declared field is populated, every referenced table exists, and every table has its
> expected companion index/permset entries.

| | |
|---|---|
| **Module** | `Kritical.Lens.SchemaCompleteness` |
| **Category** | `linter` |
| **Public surface** | `Invoke-KriticalLensSchemaCompleteness` |
| **Depends on** | `Krit.OmniFramework`, `Kritical.Lens.CodeGraph` |
| **Wave** | `.5177` · testable |

## What it does
Walks a **Microsoft365DSC schema inventory** against a target PowerShell surface and asserts
completeness across three axes:
- **field coverage** — every declared field is actually populated
- **table coverage** — every referenced table exists
- **permset completeness** — every table has its expected companion index / permission-set entries

**Audits:** `schema-field-coverage`, `schema-table-coverage`, `schema-permset-completeness`.

## Why it matters
A schema that declares fields/tables but doesn't populate or back them is a silent
correctness hole — the AL/M365DSC equivalent of a dangling reference. This linter is the
gate that catches "declared but not delivered" before it ships. (Tag `UTCM` in the manifest
ties it to the estate's config-management surface.)

## Layout
```
src/Public/Invoke-KriticalLensSchemaCompleteness.ps1   entry
src/meta.json   Lens contract (category=linter, wave .5177)
Install.ps1 · tests/ · docs/
```
Output: `ALBrain/contracts/schema-completeness-<utc>.json` (disk, 90-day retention).

## Family
Child of the `Kritical.Lens` umbrella; sits on `Kritical.Lens.CodeGraph`. Ingests via the
umbrella emitter-registry contract. Sibling of the other completeness/parity checks in the fleet.

---
*Companion machine doc: `README-AI.md` (`kritical-readme-ai/v1`). Generated from live `meta.json`
+ psd1 + source — new files only, does not touch `README.md`.*
