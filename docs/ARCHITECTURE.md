# Architecture

`Kritical.Lens.SchemaCompleteness` is a small, self-contained PowerShell 7
module. The layout follows the standard Kritical PowerShell family shape.

```text
src/
  Kritical.Lens.SchemaCompleteness.psd1     # Manifest
  Kritical.Lens.SchemaCompleteness.psm1     # Auto-loads Private/ then Public/
  Private/
    _DataTypeMap.ps1                        # Schema -> PS type-family map + helper
    _IndexKritPrimitives.ps1                # AST walker + COVERS-DSC-RESOURCE indexer
    _GateEval.ps1                           # Per-resource six-gate evaluator
  Public/
    Invoke-KriticalLensSchemaCompleteness.ps1
tests/
  Invoke-AllTests.ps1                       # Fifteen assertions, no Pester
  Fixtures/
    minimal-inventory.json
    Kritical-M365Sample.psm1
```

## Data flow

```text
schema inventory JSON  ────┐
                           │
                           ▼
                _KriticalLensIndexPrimitives
                (AST walk of target modules,
                 discovers COVERS-DSC-RESOURCE markers)
                           │
                           ▼
                per-resource evaluator
                (_KriticalLensEvaluateResource)
                           │
                           ▼
                per-gate summary + finding rows
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
           Markdown       JSON     PSCustomObject
           (-OutputMd)  (-OutputJson) (return value)
```

## Design points

- **Zero dependencies.** No Pester, no external modules, no Microsoft.Graph.
- **AST-based discovery.** Every primitive is located via the PowerShell
  language parser — no regex assumptions about function-body shape.
- **Convention-driven.** The single-line comment marker
  `# COVERS-DSC-RESOURCE: <ResourceName>` is the only contract between
  the auditor and the target module set.
- **Two-track superset preference.** When multiple candidate functions
  cover the same resource, the one whose name contains the configured
  `SupersetHint` substring wins. Handcrafted functions become the friendly
  surface; the auto-generated superset acts as the parity backstop.
- **Type-family matching, not strict equality.** `Boolean` maps to
  `bool` / `switch` / `SwitchParameter`. `UInt32` maps to `int` / `Int32`
  / `long` / `Int64`. This lets primitives use whichever PowerShell type
  reads best without failing the audit on cosmetic mismatches.
- **Complex types are accepted at face value.** Any schema `DataType`
  starting with `MSFT_` is treated as compatible with `[hashtable]`,
  `[object]`, or `[psobject]`. C4 gate does not penalise complex
  cross-type coercion — that's a different audit.

## Running the tests

```powershell
pwsh ./tests/Invoke-AllTests.ps1
```

Fifteen assertions cover: primitive discovery, per-gate pass counts,
missing-coverage finding shape, Markdown emission, and JSON emission.
No network access, no Graph auth, no external module load.
