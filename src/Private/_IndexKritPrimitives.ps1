function _KriticalLensIndexPrimitives {
    <#
    .SYNOPSIS
        Walks every .psm1 in a directory, indexes functions marked with a
        `# COVERS-DSC-RESOURCE: <ResourceName>` comment.  Returns a
        hashtable keyed by ResourceName, valued by best New/Get candidate.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ModuleDir,
        [string]$ModuleFilter = 'Kritical-M365*.psm1',
        [Parameter(Mandatory)][string]$FunctionPrefix,
        [string]$SupersetHint
    )

    if (-not (Test-Path -LiteralPath $ModuleDir)) {
        throw "Module directory does not exist: $ModuleDir"
    }

    $candidatesByResource = @{}
    $modules = Get-ChildItem -Path $ModuleDir -Filter $ModuleFilter -File |
        Where-Object { $_.Name -notmatch '\.bak\.' }

    foreach ($mod in $modules) {
        $body = Get-Content -LiteralPath $mod.FullName -Raw
        $tokens = $null; $errs = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $mod.FullName, [ref]$tokens, [ref]$errs)
        if ($errs -and $errs.Count -gt 0) {
            Write-Warning ("Kritical.Lens: parse errors in {0} — skipping ({1} errors)" -f $mod.Name, $errs.Count)
            continue
        }
        $fnAsts = $ast.FindAll(
            { param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] },
            $true)

        $markerRegex = [regex]'(?m)^\s*#\s*COVERS-DSC-RESOURCE:\s*(?<res>[A-Za-z0-9]+)'
        $lines = $body -split "`n"

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $m = $markerRegex.Match($lines[$i])
            if (-not $m.Success) { continue }
            $resName = $m.Groups['res'].Value

            for ($j = $i + 1; $j -lt [Math]::Min($i + 20, $lines.Count); $j++) {
                if ($lines[$j] -match ('^\s*function\s+(?<fn>(New|Get)-{0}[A-Za-z0-9_]+)' -f [regex]::Escape($FunctionPrefix))) {
                    $fnName = $matches['fn']
                    $fnAst = $fnAsts | Where-Object { $_.Name -eq $fnName } | Select-Object -First 1
                    if (-not $candidatesByResource.ContainsKey($resName)) {
                        $candidatesByResource[$resName] = @{ New = @(); Get = @() }
                    }
                    $paramCount = if ($fnAst -and $fnAst.Body.ParamBlock) {
                        $fnAst.Body.ParamBlock.Parameters.Count
                    } else { 0 }
                    $entry = [pscustomobject]@{
                        Module     = $mod.BaseName
                        FnName     = $fnName
                        FnAst      = $fnAst
                        ParamCount = $paramCount
                    }
                    if ($fnName -like 'New-*') {
                        $candidatesByResource[$resName].New += $entry
                    } elseif ($fnName -like 'Get-*') {
                        $candidatesByResource[$resName].Get += $entry
                    }
                    break
                }
            }
        }
    }

    # Flatten: prefer any function whose name contains the SupersetHint
    # (guaranteed 100% schema-derived).  Fall back to the highest
    # parameter-count handcraft otherwise.
    $result = @{}
    foreach ($resName in $candidatesByResource.Keys) {
        $cands = $candidatesByResource[$resName]

        $bestNew = $null
        if ($SupersetHint) {
            $bestNew = $cands.New | Where-Object { $_.FnName -like ("*$SupersetHint*") } | Select-Object -First 1
        }
        if (-not $bestNew) {
            $bestNew = $cands.New | Sort-Object -Property ParamCount -Descending | Select-Object -First 1
        }

        $bestGet = $null
        if ($SupersetHint) {
            $bestGet = $cands.Get | Where-Object { $_.FnName -like ("*$SupersetHint*") } | Select-Object -First 1
        }
        if (-not $bestGet) {
            $bestGet = $cands.Get | Sort-Object -Property ParamCount -Descending | Select-Object -First 1
        }

        $result[$resName] = [pscustomobject]@{
            Module   = if ($bestNew) { $bestNew.Module } elseif ($bestGet) { $bestGet.Module } else { '' }
            NewFn    = if ($bestNew) { $bestNew.FnName } else { $null }
            NewFnAst = if ($bestNew) { $bestNew.FnAst  } else { $null }
            GetFn    = if ($bestGet) { $bestGet.FnName } else { $null }
            GetFnAst = if ($bestGet) { $bestGet.FnAst  } else { $null }
        }
    }
    return $result
}
