function Invoke-KriticalLensSchemaCompleteness {
<#
.SYNOPSIS
    Walks a Microsoft365DSC schema inventory against a target PowerShell
    module set and proves every resource, every parameter, and every
    AllowedValue is covered with correct type, Mandatory, and ValidateSet
    fidelity.

.DESCRIPTION
    Kritical.Lens.SchemaCompleteness is the first standalone slice of the
    Kritical Lens family — the collective intelligence layer that lets any
    consumer prove a claim about a codebase with hard evidence rather than
    marketing words.

    Six gates run per resource:

      C1  Primitive exists                (`New-<Prefix><Resource>` found)
      C2  Every schema parameter present in the primitive's param block
      C3  Mandatory attribute matches the schema
      C4  DataType maps to a compatible PowerShell type family
      C5  ValidateSet covers every AllowedValue from the schema
      C6  Read-side accessor exists       (`Get-<Prefix><Resource>` found)

    The auditor discovers primitive functions by scanning target modules
    for the marker comment `# COVERS-DSC-RESOURCE: <ResourceName>`
    immediately preceding a function definition.  Modules that follow that
    convention drop straight in.

.PARAMETER InventoryPath
    Path to the Microsoft365DSC schema inventory JSON — the file produced
    by walking `.schema.mof` files and emitting one object per resource
    with a Parameters array of name, DataType, Mandatory, AllowedValues.

.PARAMETER ModuleDir
    Directory containing the target `.psm1` modules whose function-set is
    being audited for schema parity.

.PARAMETER ModuleFilter
    Optional glob filter for module filenames.  Defaults to `Kritical-M365*.psm1`.

.PARAMETER FunctionPrefix
    Function-name prefix expected on covering functions (for example the
    prefix `Kritical` in `New-KriticalAADUser`).  Defaults to `Kritical`.

.PARAMETER SupersetHint
    Optional substring that identifies the schema-derived superset variant
    of a function name.  When present, that variant is preferred over
    hand-crafted alternatives for the audit.  Defaults to `Dsc`.

.PARAMETER OutputMd
    Path to the Markdown verdict file.  When omitted, no Markdown is emitted.

.PARAMETER OutputJson
    Path to the machine-readable JSON detail file.  When omitted, no JSON
    is emitted.

.OUTPUTS
    PSCustomObject with fields Summary, ByClass, Rows, MdPath, JsonPath.

.EXAMPLE
    Invoke-KriticalLensSchemaCompleteness `
        -InventoryPath ./m365dsc-schema-inventory.json `
        -ModuleDir     ./src/modules `
        -OutputMd      ./reports/schema-completeness.md `
        -OutputJson    ./reports/schema-completeness.json
#>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$InventoryPath,
        [Parameter(Mandatory)][string]$ModuleDir,
        [string]$ModuleFilter   = 'Kritical-M365*.psm1',
        [string]$FunctionPrefix = 'Kritical',
        [string]$SupersetHint   = 'Dsc',
        [string]$OutputMd,
        [string]$OutputJson
    )

    if (-not (Test-Path -LiteralPath $InventoryPath)) {
        throw "Schema inventory not found: $InventoryPath"
    }
    if (-not (Test-Path -LiteralPath $ModuleDir)) {
        throw "Module directory not found: $ModuleDir"
    }

    Write-Verbose ("Kritical.Lens.SchemaCompleteness: loading inventory {0}" -f $InventoryPath)
    try {
        $inv = Get-Content -LiteralPath $InventoryPath -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse schema inventory JSON '$InventoryPath': $($_.Exception.Message)"
    }

    # .5231 (lens-hunt): a syntactically valid JSON without a Resources key would
    # silently audit zero resources; fail loudly instead of reporting a hollow pass.
    if ($null -eq $inv -or -not ($inv.PSObject.Properties.Name -contains 'Resources')) {
        throw "Schema inventory '$InventoryPath' has no 'Resources' property; expected an object with a Resources array."
    }

    $resources = @($inv.Resources | Where-Object { $_.ResourceName })
    Write-Verbose ("Kritical.Lens.SchemaCompleteness: {0} resources in inventory" -f $resources.Count)

    $primitives = _KriticalLensIndexPrimitives `
        -ModuleDir      $ModuleDir `
        -ModuleFilter   $ModuleFilter `
        -FunctionPrefix $FunctionPrefix `
        -SupersetHint   $SupersetHint

    Write-Verbose ("Kritical.Lens.SchemaCompleteness: {0} primitives indexed" -f $primitives.Count)

    $summary = @{
        C1 = @{ Pass = 0; Fail = 0 }
        C2 = @{ Pass = 0; Fail = 0 }
        C3 = @{ Pass = 0; Fail = 0 }
        C4 = @{ Pass = 0; Fail = 0 }
        C5 = @{ Pass = 0; Fail = 0 }
        C6 = @{ Pass = 0; Fail = 0 }
    }
    $rows = @()

    foreach ($r in ($resources | Sort-Object ResourceName)) {
        $prim = $primitives[$r.ResourceName]
        $eval = _KriticalLensEvaluateResource -Resource $r -Primitive $prim

        if ($eval.C1) { $summary.C1.Pass++ } else { $summary.C1.Fail++ }
        if ($eval.C6) { $summary.C6.Pass++ } else { $summary.C6.Fail++ }

        foreach ($pp in $eval.PerParam) {
            if ($pp.C2) { $summary.C2.Pass++ } else { $summary.C2.Fail++ }
            if ($pp.PSObject.Properties['C3'] -and $pp.C3 -ne $null) {
                if ($pp.C3) { $summary.C3.Pass++ } else { $summary.C3.Fail++ }
            }
            if ($pp.PSObject.Properties['C4'] -and $pp.C4 -ne $null) {
                if ($pp.C4) { $summary.C4.Pass++ } else { $summary.C4.Fail++ }
            }
            if ($pp.PSObject.Properties['C5'] -and $pp.C5 -ne $null) {
                if ($pp.C5) { $summary.C5.Pass++ } else { $summary.C5.Fail++ }
            }
        }

        foreach ($f in $eval.Findings) { $rows += $f }
    }

    $paramTotal    = ($resources | ForEach-Object { $_.Parameters.Count } | Measure-Object -Sum).Sum
    $resourceTotal = $resources.Count

    $byClass = $rows | Group-Object Class | Sort-Object Count -Descending | ForEach-Object {
        [pscustomobject]@{ Class = $_.Name; Count = $_.Count }
    }

    # Optional Markdown emit
    if ($OutputMd) {
        $md = New-Object System.Text.StringBuilder
        $null = $md.AppendLine('# Kritical Lens — schema completeness verdict')
        $null = $md.AppendLine('')
        $null = $md.AppendLine('## Universe')
        $null = $md.AppendLine(('- Resources in schema inventory: **{0}**' -f $resourceTotal))
        $null = $md.AppendLine(('- Parameter instances in schema: **{0}**' -f $paramTotal))
        $null = $md.AppendLine(('- Kritical primitives indexed: **{0}**' -f $primitives.Count))
        $null = $md.AppendLine('')
        $null = $md.AppendLine('## Per-gate verdict')
        $null = $md.AppendLine('')
        $null = $md.AppendLine('| Gate | Description | Pass | Fail | Ready % |')
        $null = $md.AppendLine('|---|---|---:|---:|---:|')
        $descs = @{
            'C1' = 'Primitive exists (New-)'
            'C2' = 'Every schema param present in Kritical param block'
            'C3' = 'Mandatory attribute matches schema'
            'C4' = 'DataType maps to compatible PowerShell type'
            'C5' = 'ValidateSet covers every AllowedValue'
            'C6' = 'Read-side accessor exists (Get-)'
        }
        foreach ($g in 'C1','C2','C3','C4','C5','C6') {
            $p = $summary[$g].Pass; $f = $summary[$g].Fail
            $tot = $p + $f
            $pct = if ($tot) { [math]::Round(($p / $tot) * 100, 1) } else { 0 }
            $null = $md.AppendLine(('| {0} | {1} | {2} | {3} | {4}% |' -f $g, $descs[$g], $p, $f, $pct))
        }
        $null = $md.AppendLine('')
        if ($byClass) {
            $null = $md.AppendLine('## Top gap classes')
            $null = $md.AppendLine('')
            $null = $md.AppendLine('| Class | Count |')
            $null = $md.AppendLine('|---|---:|')
            foreach ($c in $byClass) {
                $null = $md.AppendLine(('| {0} | {1} |' -f $c.Class, $c.Count))
            }
            $null = $md.AppendLine('')
        }
        if ($rows.Count -gt 0) {
            $null = $md.AppendLine('## First 100 actionable findings')
            $null = $md.AppendLine('')
            $null = $md.AppendLine('| Resource | Param | Class | Detail |')
            $null = $md.AppendLine('|---|---|---|---|')
            $take = [Math]::Min($rows.Count, 100)
            for ($i = 0; $i -lt $take; $i++) {
                $r = $rows[$i]
                $d = $r.Detail
                if ($d.Length -gt 120) { $d = $d.Substring(0,117) + '...' }
                $null = $md.AppendLine(('| {0} | {1} | {2} | {3} |' -f $r.Resource, $r.Param, $r.Class, $d))
            }
        }
        Set-Content -LiteralPath $OutputMd -Value $md.ToString() -Encoding utf8
    }

    # Optional JSON emit
    if ($OutputJson) {
        $obj = [ordered]@{
            Generator = 'Kritical.Lens.SchemaCompleteness'
            Version   = '1.0.0'
            Utc       = (Get-Date).ToUniversalTime().ToString('o')
            Universe  = @{ Resources = $resourceTotal; Parameters = $paramTotal; Primitives = $primitives.Count }
            Summary   = $summary
            ByClass   = $byClass
            Rows      = @($rows)
        }
        $obj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputJson -Encoding utf8
    }

    [pscustomobject]@{
        Summary  = $summary
        ByClass  = @($byClass)
        Rows     = @($rows)
        MdPath   = $OutputMd
        JsonPath = $OutputJson
    }
}
