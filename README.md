# Kritical.Lens.SchemaCompleteness

> The first standalone slice of the **Kritical Lens&trade;** family — a
> PowerShell 7 module that proves a Microsoft365DSC-compatible module set
> covers every resource, every parameter, every AllowedValue in the
> upstream schema with correct DataType, Mandatory, and ValidateSet
> fidelity. Hard evidence, no marketing.

Made in Australia by **[Kritical Pty Ltd](https://kritical.net)** — a
Seriously Kritical&trade; Production.

<div align="center">

[![PowerShell 7+](https://img.shields.io/badge/PowerShell-7%2B-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![Windows • macOS • Linux](https://img.shields.io/badge/OS-Windows%20%C2%B7%20macOS%20%C2%B7%20Linux-13365C)](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)
[![License MIT](https://img.shields.io/badge/License-MIT-15AFD1)](./LICENSE)
[![Tests 15/15](https://img.shields.io/badge/tests-15%2F15-15AFD1)](./tests/Invoke-AllTests.ps1)

</div>

---

## What it is

`Kritical.Lens.SchemaCompleteness` runs six schema-parity gates over any
PowerShell module set that follows the `COVERS-DSC-RESOURCE` convention
and reports pass / fail counts per gate plus a machine-readable finding
list:

| Gate | What it proves |
|---|---|
| **C1** | A `New-` primitive exists for every resource in the schema |
| **C2** | Every schema parameter is present in the primitive's param block |
| **C3** | The primitive's `Mandatory` attribute matches the schema |
| **C4** | The primitive's parameter type maps to a compatible PowerShell type family |
| **C5** | The primitive's `ValidateSet` covers every `AllowedValue` in the schema |
| **C6** | A read-side `Get-` accessor exists for every resource |

Emits both a Markdown verdict and a machine-readable JSON detail. Zero
dependencies beyond PowerShell 7.

---

## Install

```powershell
Install-Module -Name Kritical.Lens.SchemaCompleteness -Scope CurrentUser
Import-Module  Kritical.Lens.SchemaCompleteness
```

Requires PowerShell 7 or later. Cross-platform — Windows, macOS, Linux.

---

## Quick start

```powershell
Invoke-KriticalLensSchemaCompleteness `
    -InventoryPath ./m365dsc-schema-inventory.json `
    -ModuleDir     ./src/modules `
    -OutputMd      ./reports/schema-completeness.md `
    -OutputJson    ./reports/schema-completeness.json
```

Returns a summary object; writes the Markdown verdict and JSON detail
alongside.

---

## How your modules opt in

`Kritical.Lens.SchemaCompleteness` discovers the primitive functions in
your module set by looking for a single-line comment marker directly
above each function definition:

```powershell
# COVERS-DSC-RESOURCE: AADUser
function New-KriticalAADUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$UserPrincipalName,
        [string]$DisplayName,
        [ValidateSet('Guest','Member')][string]$UserType
    )
    # ...
}
```

The auditor then compares the discovered function's parameter block
against the resource's declared parameters in your schema inventory.

Any module set that follows this convention drops straight in. The
function-name prefix and superset-variant hint are configurable via the
`-FunctionPrefix` and `-SupersetHint` parameters.

---

## Schema inventory shape

The `-InventoryPath` file is a JSON document with a `Resources` array,
one entry per Microsoft365DSC resource:

```json
{
  "Resources": [
    {
      "ResourceName": "AADUser",
      "Parameters": [
        {
          "Name": "UserPrincipalName",
          "DataType": "String",
          "Mandatory": true,
          "AllowedValues": []
        },
        {
          "Name": "UserType",
          "DataType": "String",
          "Mandatory": false,
          "AllowedValues": ["Guest","Member"]
        }
      ]
    }
  ]
}
```

Any tool that walks Microsoft365DSC `.schema.mof` files and emits this
shape works out of the box. A minimal example lives at
[`tests/Fixtures/minimal-inventory.json`](./tests/Fixtures/minimal-inventory.json).

---

## Design principles

- **Hard evidence over marketing.** Every claim reduces to a numeric
  pass / fail against a specific gate.
- **No external dependencies.** Pure PowerShell 7. No Pester, no
  Microsoft.Graph modules, no MOF compiler.
- **Convention-driven discovery.** One line of comment per function
  makes any module set auditable — no attribute framework, no metadata
  registry, no build step.
- **Two-format output.** Markdown for humans, JSON for machines.
- **Verbose without being noisy.** `-Verbose` traces every phase; the
  default output is quiet apart from the returned summary object.

---

## The Kritical Lens family

Kritical.Lens.SchemaCompleteness is the first public slice of the
**Kritical Lens&trade;** family — the collective intelligence layer that
lets any consumer prove a claim about a codebase with hard evidence.
Individual Lens modules are extracted as standalone public repositories
as each hits a real 1.0.0 quality bar.

The Lens umbrella lives at
[Sir-J-AU/Kritical.Lens](https://github.com/Sir-J-AU/Kritical.Lens).

---

## License and credits

MIT. Copyright &copy; 2026 **Kritical Pty Ltd**. Author: **Joshua Finley**.

Built as an extraction from the internal audit toolkit that shipped
alongside the Kritical Microsoft365DSC → UTCM parity programme.

---

<div align="center">

<sub>Kritical Pty Ltd &nbsp;·&nbsp; ABN 39 687 048 086 &nbsp;·&nbsp; Geelong VIC, Australia
<br/>+61 1300 274 655 &nbsp;·&nbsp; [sales@kritical.net](mailto:sales@kritical.net) &nbsp;·&nbsp; [kritical.net](https://kritical.net)</sub>

</div>
