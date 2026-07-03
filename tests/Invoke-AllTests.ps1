#requires -Version 7.0
<#
.SYNOPSIS
    Runs the Kritical.Lens.SchemaCompleteness test suite (no Pester
    dependency — plain assertion-based).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot

Import-Module (Join-Path $repo 'src/Kritical.Lens.SchemaCompleteness.psd1') -Force

$totalPass = 0
$totalFail = 0
$failedTests = @()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        $script:totalPass++
    } else {
        $script:totalFail++
        $script:failedTests += $Message
        Write-Host ("  FAIL: {0}" -f $Message) -ForegroundColor Red
    }
}

Write-Host "== Kritical.Lens.SchemaCompleteness tests ==" -ForegroundColor Cyan

$fixtureDir = Join-Path $PSScriptRoot 'Fixtures'
$invPath    = Join-Path $fixtureDir 'minimal-inventory.json'

$result = Invoke-KriticalLensSchemaCompleteness `
    -InventoryPath $invPath `
    -ModuleDir     $fixtureDir `
    -ModuleFilter  'Kritical-M365*.psm1'

Assert-True ($null -ne $result) 'Returns a result object'
Assert-True ($null -ne $result.Summary) 'Result has Summary'
Assert-True ($result.Summary.C1.Pass -eq 2) ("C1 pass count is 2 (SampleUser + SamplePolicy) — got {0}" -f $result.Summary.C1.Pass)
Assert-True ($result.Summary.C1.Fail -eq 1) ("C1 fail count is 1 (MissingCoverage) — got {0}" -f $result.Summary.C1.Fail)
Assert-True ($result.Summary.C6.Pass -eq 2) ("C6 pass count is 2 — got {0}" -f $result.Summary.C6.Pass)
Assert-True ($result.Summary.C2.Fail -eq 0) ("C2 fail count is 0 (all covered params present) — got {0}" -f $result.Summary.C2.Fail)
Assert-True ($result.Summary.C5.Pass -ge 1) ("C5 pass count >= 1 (UserType ValidateSet covered) — got {0}" -f $result.Summary.C5.Pass)

# The Rows collection should include exactly one 'RESOURCE-MISSING-KRITICAL-PRIMITIVE' finding for MissingCoverage
$missing = @($result.Rows | Where-Object { $_.Class -eq 'RESOURCE-MISSING-KRITICAL-PRIMITIVE' })
Assert-True ($missing.Count -eq 1) ("Exactly one MissingCoverage finding — got {0}" -f $missing.Count)
if ($missing.Count -gt 0) {
    Assert-True ($missing[0].Resource -eq 'MissingCoverage') "Missing coverage row names MissingCoverage"
}

# Markdown emit smoke
$mdPath = Join-Path $env:TEMP ('kritical-lens-test-{0}.md' -f (Get-Random))
$jsonPath = Join-Path $env:TEMP ('kritical-lens-test-{0}.json' -f (Get-Random))
$result2 = Invoke-KriticalLensSchemaCompleteness `
    -InventoryPath $invPath `
    -ModuleDir     $fixtureDir `
    -ModuleFilter  'Kritical-M365*.psm1' `
    -OutputMd      $mdPath `
    -OutputJson    $jsonPath

Assert-True (Test-Path $mdPath)   ("Markdown file emitted to {0}" -f $mdPath)
Assert-True (Test-Path $jsonPath) ("JSON file emitted to {0}" -f $jsonPath)

if (Test-Path $mdPath) {
    $md = Get-Content -Raw $mdPath
    Assert-True ($md -match 'schema completeness verdict') 'Markdown carries title'
    Assert-True ($md -match 'Per-gate verdict')            'Markdown carries per-gate section'
    Remove-Item $mdPath -Force -ErrorAction SilentlyContinue
}
if (Test-Path $jsonPath) {
    $j = Get-Content -Raw $jsonPath | ConvertFrom-Json
    Assert-True ($j.Generator -eq 'Kritical.Lens.SchemaCompleteness') 'JSON identifies generator'
    Assert-True ($j.Universe.Resources -eq 3) ("JSON Universe.Resources=3 — got {0}" -f $j.Universe.Resources)
    Remove-Item $jsonPath -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host ("Passes: {0}  Fails: {1}" -f $totalPass, $totalFail) -ForegroundColor $(if ($totalFail) {'Red'} else {'Green'})
if ($totalFail -gt 0) { exit 1 }
