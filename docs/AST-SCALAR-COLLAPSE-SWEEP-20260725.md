# Scalar-collapse AST sweep — Kritical.Lens.SchemaCompleteness

**Date (UTC):** 07/25/2026 07:28:16  
**Repo:** `Kritical.Lens.SchemaCompleteness` · **Branch:** `main` · **Commit:** `7c9936a`  
**Tool:** `Kritical.Lens.AstSweep` v1.0.0, rules KSC001 v1.3.0, KSC002 v1.0.0  
**Host:** PowerShell 7.5.3  
**Basis:** VERIFIED-BY-EXECUTION — every file below was AST-parsed by the run that produced this document.  
**Recheck trigger:** re-run after any change to this repo's PowerShell, or when a new KSC rule is added.

## Regenerate

```powershell
& 'C:\Users\joshl\OneDrive - Kritical Pty Ltd\Github\Kritical.Lens\scripts\Invoke-KritAstSweepEstate.ps1' -OutDir <dir> -WriteRepoDoc
```

## Why this sweep exists

`Get-Content` returns `object[]` for 2+ lines, a **bare `[string]`** for exactly one line,
and `$null` for an empty file. On 2026-07-25 a single unwrapped `$lines = Get-Content $Path`
in `Kritical.Lens.CodeGraph\src\Private\_RawParse.ps1` therefore indexed into a string,
yielded a `[System.Char]`, and **aborted the entire parse of a 6,876-file repo** —
producing no documentation at all. `Import-Csv`, `Select-String`, `Get-ChildItem`,
`Get-Item` and `Import-Clixml` all collapse the same way. This sweep looks for that shape
estate-wide. See `Kritical.Lens/src/AstRules/` for the rule definitions.

## Result

| Metric | Value |
|---|---|
| Files AST-parsed | 13 |
| Findings | 0 |
| Parse-error files (BLIND SPOTS) | 0 |
| Files skipped, NOT examined (BLIND SPOTS) | 0 |
| Rule errors | 0 |

**No findings.** Every `Get-Content` / `Import-Csv` / `Select-String` /
`Get-ChildItem` / `Get-Item` / `Import-Clixml` result in this repo that is later
indexed or has `.Length`/`.Count` read is either `@()`-wrapped, array-cast, or
uses `-Raw`. Read the non-coverage section below before treating this as complete.

## Coverage and NON-coverage

### KSC001 — Scalar/array collapse on a collection-producing command v1.3.0

**WHAT WAS TESTED:** An assignment whose value comes from a command that COLLAPSES to a bare scalar at exactly
one result and to $null at zero results (Get-Content, Import-Csv, Select-String,
Get-ChildItem, Import-Clixml, Get-Item and aliases), where the assignment is NOT wrapped in
@() / ,() / an array cast, AND the assigned variable is later indexed, or has .Length or
.Count read. Detected by correlating the AST assignment node with the AST usage nodes of
the same variable.

**WHAT WAS NOT TESTED:** (1) Variable correlation is BY NAME AND LINE ORDER within one file, not scope-accurate
dataflow — a same-named variable in a different function later in the same file will match,
so every HIT IS A CANDIDATE that must be confirmed by reading the site. (2) Collapse
reached through an intermediate variable ($a = Get-Content f; $b = $a; $b[0]) is NOT
detected. (3) Collapse across files/functions (returned from one function, indexed in
another) is NOT detected. (4) Producers outside the configurable list (custom functions
that emit collections, .NET calls, Invoke-RestMethod) are NOT detected. (5) foreach over
the variable is recorded as Enumerate but NOT reported — it is benign on PS7 and the task
that commissioned this rule scoped it out. (6) The rule reads source only; it does not run
the code, so it cannot say whether a 0- or 1-item input is REACHABLE in practice — that
judgement is human and must be recorded per finding.

### KSC002 — New-Object List[object] is PSObject-wrapped and breaks @() v1.0.0

**WHAT WAS TESTED:** A variable assigned from `New-Object System.Collections.Generic.List[object]` (T is exactly
System.Object) that is later passed through an @() array-subexpression. New-Object returns a
PSObject-wrapped instance and PSEnumerableBinder.MaybeDebase throws
"ArgumentException: Argument types do not match" for that exact shape. Verified by execution
on pwsh 7.5.3 / .NET 9.0.8.

**WHAT WAS NOT TESTED:** (1) Correlation is BY VARIABLE NAME AND LINE ORDER within one file, not scope-accurate
dataflow. (2) The @() may be applied in a DIFFERENT file or function (e.g. the list is
returned and the caller wraps it) — not detected. (3) Other PSObject-wrapping producers
(New-Object on other generic types whose T is System.Object, e.g. a custom generic) are not
enumerated beyond List. (4) The rule reports the ASSIGNMENT even when the @() site is
unreachable at runtime; reachability is a human judgement. (5) Not verified on Windows
PowerShell 5.1 or on .NET versions other than 9.0.8 — the recheck trigger is a pwsh or .NET
upgrade.

**HOW IT WAS ESTABLISHED:** static AST analysis of source only. The sweep did not
execute this repo's code, so it cannot prove a flagged site is ever reached with a 0-
or 1-item input, nor that an unflagged site is safe at runtime.

---
Author: **Joshua Finley** · **Kritical Pty Ltd**

