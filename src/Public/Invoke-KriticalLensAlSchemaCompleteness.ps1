function Invoke-KriticalLensAlSchemaCompleteness {
<#
.SYNOPSIS
    Kritical Lens — AL mirror-table schema-completeness proof.  Walks a
    Pax8→BC→Shopify connector's .al mirror TABLES against the Pax8 partner
    OpenAPI upstream and proves every mirror carries the source fields it
    should, reporting missing-field coverage per mirror.

.DESCRIPTION
    This is the AL sibling of Invoke-KriticalLensSchemaCompleteness (which
    audits a Microsoft365DSC PowerShell surface).  Where that one proves a
    PowerShell module set covers a DSC schema, this one proves a set of AL
    "mirror" tables (the local staging copies of upstream Pax8 catalog /
    pricing / subscription / invoice / company data) each carry every field
    the corresponding Pax8 OpenAPI schema declares.

    Ground truth is the Pax8 partner OpenAPI spec — the SAME spec the
    connector's own AL header comments cite ("Canonical schema source").
    No upstream field list is hard-coded: the analyzer reads the spec live,
    so a new Pax8 property surfaces as newly-missing until the mirror adds it.

    Four gates run per mirror (mirror<->schema pairing from
    _KriticalLensPax8MirrorMap; upstream field list from the spec):

      M1  Mirror table exists          (an .al table with the mapped object id)
      M2  Every upstream SCALAR field present on the mirror (per-field)
      M3  Flattened nested-ref scalar sub-fields present
          (e.g. Company.address.street -> "Street" column on 60120)
      M4  Every upstream CHILD ARRAY has its own mirror table present
          (e.g. Company.contacts -> Contact mirror 60121 exists)

    AL field captions are matched to camelCase Pax8 properties by a
    normalization (lower-case, alphanumeric, connector-prefix-stripped) so
    "Pax8 Company Id" matches "companyId".  Matching is intentionally lenient
    on naming and strict on PRESENCE — the question is coverage, not spelling.

.PARAMETER SpecPath
    Path to the Pax8 partner OpenAPI JSON (reference/pax8-openapi/partner-endpoints.json).

.PARAMETER AlRoot
    Root directory of the connector's .al files (parsed via KritLensAlParser).

.PARAMETER MaxFiles
    Cap for quick smoke runs.  Default 0 = every .al file.

.PARAMETER OutputMd
    Optional Markdown verdict path.

.PARAMETER OutputJson
    Optional machine-readable JSON detail path.

.OUTPUTS
    PSCustomObject with Summary, ByMirror, Rows, ByClass, MdPath, JsonPath.

.EXAMPLE
    Invoke-KriticalLensAlSchemaCompleteness `
        -SpecPath   ./reference/pax8-openapi/partner-endpoints.json `
        -AlRoot     ../Kritical.AL.D365BC.Connector.Pax8-to-Storefront `
        -OutputMd   ./reports/al-schema-completeness.md `
        -OutputJson ./reports/al-schema-completeness.json
#>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$SpecPath,
        [Parameter(Mandatory)][string]$AlRoot,
        [int]$MaxFiles = 0,
        [string]$OutputMd,
        [string]$OutputJson
    )

    if (-not (Test-Path -LiteralPath $AlRoot)) {
        throw "AL root not found: $AlRoot"
    }
    if (-not (Get-Command ConvertTo-KritAlFileModel -ErrorAction SilentlyContinue)) {
        throw "KritLensAlParser not loaded — Import-Module KritLensAlParser.psm1 before calling this analyzer."
    }

    $schemas = _KriticalLensLoadPax8Schemas -SpecPath $SpecPath
    $mirrorMap = _KriticalLensPax8MirrorMap
    Write-Verbose ("Kritical.Lens.AlSchemaCompleteness: {0} Pax8 schemas, {1} mapped mirrors" -f $schemas.Count, $mirrorMap.Count)

    $alIndex = _KriticalLensBuildAlFieldIndex -AlRoot $AlRoot -MaxFiles $MaxFiles
    Write-Verbose ("Kritical.Lens.AlSchemaCompleteness: {0} AL tables parsed" -f $alIndex.Count)

    $summary = @{
        M1 = @{ Pass = 0; Fail = 0 }
        M2 = @{ Pass = 0; Fail = 0 }
        M3 = @{ Pass = 0; Fail = 0 }
        M4 = @{ Pass = 0; Fail = 0 }
    }
    $rows = @()
    $byMirror = @()

    foreach ($mid in ($mirrorMap.Keys | Sort-Object)) {
        $spec = $mirrorMap[$mid]
        $schema = $schemas[$spec.Schema]
        $al = $alIndex[[int]$mid]
        $label = $spec.Label

        # M1 — mirror table exists
        $m1 = ($null -ne $al)
        if ($m1) { $summary.M1.Pass++ } else { $summary.M1.Fail++ }
        if (-not $m1) {
            $rows += [pscustomobject]@{
                Mirror = $label; MirrorId = $mid; Field = '(all)'
                Class  = 'MIRROR-TABLE-MISSING'
                Detail = ('No .al table with object id {0} found under AlRoot' -f $mid)
            }
            $byMirror += [pscustomobject]@{
                Mirror = $label; MirrorId = $mid; Schema = $spec.Schema
                Exists = $false; UpstreamFields = 0; Covered = 0; Missing = 0; CoveragePct = 0.0
                MissingFields = @()
            }
            continue
        }

        if ($null -eq $schema) {
            $rows += [pscustomobject]@{
                Mirror = $label; MirrorId = $mid; Field = '(schema)'
                Class  = 'UPSTREAM-SCHEMA-NOT-IN-SPEC'
                Detail = ('Mapped Pax8 schema "{0}" not found in the OpenAPI spec' -f $spec.Schema)
            }
            continue
        }

        # Build the expected upstream field set: schema scalars + flattened
        # nested-ref scalars.
        $expected = [System.Collections.Generic.List[object]]::new()
        foreach ($s in $schema.Scalars) {
            $expected.Add([pscustomobject]@{ Prop = $s; Source = $spec.Schema; Gate = 'M2' })
        }
        foreach ($refName in $spec.FlattenRefs) {
            $refSchema = $schemas[$refName]
            if ($null -eq $refSchema) { continue }
            foreach ($s in $refSchema.Scalars) {
                $expected.Add([pscustomobject]@{ Prop = $s; Source = $refName; Gate = 'M3' })
            }
        }

        # M2/M3 — per-field presence
        $covered = 0
        $missing = [System.Collections.Generic.List[string]]::new()
        foreach ($e in $expected) {
            $tok = _KriticalLensNormalizeFieldToken $e.Prop
            $present = $al.Tokens.Contains($tok)
            if ($present) {
                $covered++
                if ($e.Gate -eq 'M2') { $summary.M2.Pass++ } else { $summary.M3.Pass++ }
            } else {
                $missing.Add($e.Prop)
                if ($e.Gate -eq 'M2') { $summary.M2.Fail++ } else { $summary.M3.Fail++ }
                $cls = if ($e.Gate -eq 'M2') { 'MISSING-UPSTREAM-FIELD' } else { 'MISSING-FLATTENED-FIELD' }
                $rows += [pscustomobject]@{
                    Mirror = $label; MirrorId = $mid; Field = $e.Prop
                    Class  = $cls
                    Detail = ('Pax8 {0}.{1} has no matching column on mirror {2}' -f $e.Source, $e.Prop, $mid)
                }
            }
        }

        # M4 — every upstream child array has its own mirror table present,
        # UNLESS that child schema is flattened onto this mirror (FlattenRefs).
        foreach ($arrProp in $schema.Arrays.Keys) {
            $childSchema = $schema.Arrays[$arrProp]
            if ($spec.FlattenRefs -contains $childSchema) { continue }  # flattened here, not a separate mirror
            if ($childSchema -eq '(scalar-array)') { continue }         # primitive array, no mirror expected
            $childMirror = $mirrorMap.GetEnumerator() | Where-Object { $_.Value.Schema -eq $childSchema } | Select-Object -First 1
            if ($childMirror -and $alIndex.ContainsKey([int]$childMirror.Key)) {
                $summary.M4.Pass++
            } else {
                $summary.M4.Fail++
                $rows += [pscustomobject]@{
                    Mirror = $label; MirrorId = $mid; Field = $arrProp
                    Class  = 'CHILD-COLLECTION-NOT-MIRRORED'
                    Detail = ('Pax8 {0}.{1} (array of {2}) has no dedicated mirror table' -f $spec.Schema, $arrProp, $childSchema)
                }
            }
        }

        $upstreamCount = $expected.Count
        $pct = if ($upstreamCount) { [math]::Round(($covered / $upstreamCount) * 100, 1) } else { 100.0 }
        $byMirror += [pscustomobject]@{
            Mirror = $label; MirrorId = $mid; Schema = $spec.Schema
            Exists = $true; UpstreamFields = $upstreamCount; Covered = $covered
            Missing = $missing.Count; CoveragePct = $pct
            MissingFields = @($missing)
        }
    }

    $byClass = $rows | Group-Object Class | Sort-Object Count -Descending | ForEach-Object {
        [pscustomobject]@{ Class = $_.Name; Count = $_.Count }
    }

    if ($OutputMd) {
        $md = New-Object System.Text.StringBuilder
        $null = $md.AppendLine('# Kritical Lens — AL mirror-table schema completeness')
        $null = $md.AppendLine('')
        $null = $md.AppendLine('## Universe')
        $null = $md.AppendLine(('- Pax8 upstream schemas in spec: **{0}**' -f $schemas.Count))
        $null = $md.AppendLine(('- Mirror tables mapped: **{0}**' -f $mirrorMap.Count))
        $null = $md.AppendLine(('- AL tables parsed under AlRoot: **{0}**' -f $alIndex.Count))
        $null = $md.AppendLine('')
        $null = $md.AppendLine('## Per-gate verdict')
        $null = $md.AppendLine('')
        $null = $md.AppendLine('| Gate | Description | Pass | Fail | Ready % |')
        $null = $md.AppendLine('|---|---|---:|---:|---:|')
        $descs = @{
            'M1' = 'Mirror table exists'
            'M2' = 'Upstream scalar field present on mirror'
            'M3' = 'Flattened nested-ref field present'
            'M4' = 'Child array has its own mirror table'
        }
        foreach ($g in 'M1','M2','M3','M4') {
            $p = $summary[$g].Pass; $f = $summary[$g].Fail; $tot = $p + $f
            $pct = if ($tot) { [math]::Round(($p / $tot) * 100, 1) } else { 100.0 }
            $null = $md.AppendLine(('| {0} | {1} | {2} | {3} | {4}% |' -f $g, $descs[$g], $p, $f, $pct))
        }
        $null = $md.AppendLine('')
        $null = $md.AppendLine('## Per-mirror coverage')
        $null = $md.AppendLine('')
        $null = $md.AppendLine('| Mirror | Id | Pax8 schema | Exists | Upstream | Covered | Missing | Coverage % |')
        $null = $md.AppendLine('|---|---:|---|:--:|---:|---:|---:|---:|')
        foreach ($m in $byMirror) {
            $null = $md.AppendLine(('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7}% |' -f `
                $m.Mirror, $m.MirrorId, $m.Schema, $(if ($m.Exists) { 'yes' } else { 'NO' }),
                $m.UpstreamFields, $m.Covered, $m.Missing, $m.CoveragePct))
        }
        $null = $md.AppendLine('')
        if ($byClass) {
            $null = $md.AppendLine('## Gap classes')
            $null = $md.AppendLine('')
            $null = $md.AppendLine('| Class | Count |')
            $null = $md.AppendLine('|---|---:|')
            foreach ($c in $byClass) { $null = $md.AppendLine(('| {0} | {1} |' -f $c.Class, $c.Count)) }
            $null = $md.AppendLine('')
        }
        if ($rows.Count -gt 0) {
            $null = $md.AppendLine('## Missing-field findings')
            $null = $md.AppendLine('')
            $null = $md.AppendLine('| Mirror | Id | Field | Class | Detail |')
            $null = $md.AppendLine('|---|---:|---|---|---|')
            $take = [Math]::Min($rows.Count, 200)
            for ($i = 0; $i -lt $take; $i++) {
                $r = $rows[$i]
                $null = $md.AppendLine(('| {0} | {1} | {2} | {3} | {4} |' -f $r.Mirror, $r.MirrorId, $r.Field, $r.Class, $r.Detail))
            }
        }
        $dir = Split-Path -Parent $OutputMd
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        Set-Content -LiteralPath $OutputMd -Value $md.ToString() -Encoding utf8
    }

    if ($OutputJson) {
        $obj = [ordered]@{
            Generator = 'Kritical.Lens.AlSchemaCompleteness'
            Version   = '1.0.0'
            Utc       = (Get-Date).ToUniversalTime().ToString('o')
            SpecPath  = $SpecPath
            AlRoot    = $AlRoot
            Universe  = @{ Pax8Schemas = $schemas.Count; MirrorsMapped = $mirrorMap.Count; AlTablesParsed = $alIndex.Count }
            Summary   = $summary
            ByMirror  = @($byMirror)
            ByClass   = @($byClass)
            Rows      = @($rows)
        }
        $dir = Split-Path -Parent $OutputJson
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        $obj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputJson -Encoding utf8
    }

    [pscustomobject]@{
        Summary  = $summary
        ByMirror = @($byMirror)
        ByClass  = @($byClass)
        Rows     = @($rows)
        MdPath   = $OutputMd
        JsonPath = $OutputJson
    }
}
