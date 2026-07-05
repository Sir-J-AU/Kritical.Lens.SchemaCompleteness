function _KriticalLensExtractParamMap {
    <#
    .SYNOPSIS
        Given a FunctionDefinitionAst, returns a hashtable keyed by
        parameter name, valued by { TypeName; Mandatory; ValidateSet[] }.
    #>
    param($FnAst)

    $map = @{}
    if (-not $FnAst -or -not $FnAst.Body.ParamBlock) { return $map }

    foreach ($p in $FnAst.Body.ParamBlock.Parameters) {
        $pname = $p.Name.VariablePath.UserPath
        $pTypeName = if ($p.StaticType) { $p.StaticType.Name } else { '' }
        $mandatory = $false
        $validateSet = @()

        foreach ($attr in $p.Attributes) {
            if ($attr.TypeName.Name -eq 'Parameter') {
                foreach ($na in $attr.NamedArguments) {
                    if ($na.ArgumentName -eq 'Mandatory') {
                        # .5231 (lens-hunt): shorthand [Parameter(Mandatory)] omits the
                        # expression (ExpressionOmitted = $true) and means $true; only
                        # an explicit '=$false' should be treated as not mandatory.
                        if ($na.ExpressionOmitted) {
                            $mandatory = $true
                        } else {
                            $mandatory = ($na.Argument -and $na.Argument.Extent.Text -match '\$true')
                        }
                    }
                }
            } elseif ($attr.TypeName.Name -eq 'ValidateSet') {
                foreach ($arg in $attr.PositionalArguments) {
                    # .5231 (lens-hunt): strip either single or double surrounding
                    # quotes so [ValidateSet("x")] compares equal to schema values.
                    $v = $arg.Extent.Text -replace '^["'']|["'']$',''
                    $validateSet += $v
                }
            }
        }

        $map[$pname] = [pscustomobject]@{
            TypeName    = $pTypeName
            Mandatory   = $mandatory
            ValidateSet = $validateSet
        }
    }
    return $map
}

function _KriticalLensEvaluateResource {
    <#
    .SYNOPSIS
        Runs the six gates (C1..C6) for one resource against its primitive
        candidate.  Returns per-gate booleans plus a list of finding rows.
    #>
    param(
        $Resource,
        $Primitive
    )

    $findings = @()
    $c1 = ($Primitive -and $Primitive.NewFn)
    $c6 = ($Primitive -and $Primitive.GetFn)

    if (-not $c1) {
        $findings += [pscustomobject]@{
            Resource = $Resource.ResourceName
            Param    = '(all)'
            Class    = 'RESOURCE-MISSING-KRITICAL-PRIMITIVE'
            Detail   = 'No New- function with COVERS-DSC-RESOURCE marker was found for this resource'
        }
        return [pscustomobject]@{
            C1 = $c1
            C6 = $c6
            PerParam = @()
            Findings = $findings
        }
    }

    $newParamMap = _KriticalLensExtractParamMap -FnAst $Primitive.NewFnAst
    $perParam = @()

    foreach ($p in $Resource.Parameters) {
        $pname = $p.Name
        $krit = $newParamMap[$pname]

        $c2 = $null -ne $krit
        $c3 = $null; $c4 = $null; $c5 = $null

        if (-not $c2) {
            $findings += [pscustomobject]@{
                Resource = $Resource.ResourceName
                Param    = $pname
                Class    = 'PARAM-MISSING-IN-KRITICAL'
                Detail   = ('Schema declares {0} ({1}) but the Kritical param block does not' -f $pname, $p.DataType)
            }
            $perParam += [pscustomobject]@{ Name=$pname; C2=$false }
            continue
        }

        $schemaMandatory = ($p.Mandatory -eq $true)
        $c3 = ($schemaMandatory -eq $krit.Mandatory)
        if (-not $c3) {
            $findings += [pscustomobject]@{
                Resource = $Resource.ResourceName
                Param    = $pname
                Class    = 'MANDATORY-MISMATCH'
                Detail   = ('schema={0} kritical={1}' -f $schemaMandatory, $krit.Mandatory)
            }
        }

        $schemaBase = _KriticalLensCleanBase $p.DataType
        $expected = $script:KriticalLensDataTypeMap[$schemaBase]
        $kritBase = _KriticalLensCleanBase $krit.TypeName
        if ($schemaBase -match '^MSFT_' -or $schemaBase -eq '') {
            $c4 = $true
        } elseif ($expected) {
            $c4 = ($expected -contains $kritBase) -or ($kritBase -eq 'object')
        } else {
            $c4 = $true
        }
        if (-not $c4) {
            $findings += [pscustomobject]@{
                Resource = $Resource.ResourceName
                Param    = $pname
                Class    = 'TYPE-MISMATCH'
                Detail   = ('schema={0} kritical={1}' -f $p.DataType, $krit.TypeName)
            }
        }

        if ($p.AllowedValues -and $p.AllowedValues.Count -gt 0) {
            $missing = @($p.AllowedValues | Where-Object { $krit.ValidateSet -notcontains $_ })
            $c5 = ($missing.Count -eq 0)
            if (-not $c5) {
                $findings += [pscustomobject]@{
                    Resource = $Resource.ResourceName
                    Param    = $pname
                    Class    = 'VALIDATESET-MISSING-VALUES'
                    Detail   = ('missing: {0}' -f ($missing -join '|'))
                }
            }
        }

        $perParam += [pscustomobject]@{
            Name = $pname; C2 = $true; C3 = $c3; C4 = $c4; C5 = $c5
        }
    }

    return [pscustomobject]@{
        C1 = $c1
        C6 = $c6
        PerParam = $perParam
        Findings = $findings
    }
}
