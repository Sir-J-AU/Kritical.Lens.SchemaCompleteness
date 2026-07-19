function _KriticalLensLoadPax8Schemas {
    <#
    .SYNOPSIS
        Loads the Pax8 partner OpenAPI component schemas as the UPSTREAM
        ground truth for AL mirror-table coverage.

    .DESCRIPTION
        Returns a hashtable keyed by schema name (Company / Pricing /
        Subscription / Invoice / InvoiceItem / UsageLine / ...), valued by a
        pscustomobject with:
          Scalars  — property names whose OpenAPI shape is a scalar
                     (string/number/boolean/integer) — these are the fields a
                     flat AL mirror table is expected to carry.
          Refs     — property name -> referenced schema name (single nested
                     object, e.g. Company.address -> Address).
          Arrays   — property name -> item schema name (child collections,
                     e.g. Company.contacts -> Contact) — NOT expected on the
                     parent mirror (they are mirrored in their own table).

        The spec is the SOLE source of truth: no upstream field list is
        hard-coded here.  If Pax8 adds a property to a schema, the next run
        picks it up automatically and reports it as newly-missing on the
        mirror until the mirror carries it.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SpecPath
    )

    if (-not (Test-Path -LiteralPath $SpecPath)) {
        throw "Pax8 OpenAPI spec not found: $SpecPath"
    }

    try {
        $spec = Get-Content -LiteralPath $SpecPath -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse Pax8 OpenAPI spec '$SpecPath': $($_.Exception.Message)"
    }

    if ($null -eq $spec.components -or $null -eq $spec.components.schemas) {
        throw "Pax8 OpenAPI spec '$SpecPath' has no components.schemas block."
    }

    $schemas = @{}
    foreach ($sp in $spec.components.schemas.PSObject.Properties) {
        $name = $sp.Name
        $node = $sp.Value
        $scalars = [System.Collections.Generic.List[string]]::new()
        $refs = @{}
        $arrays = @{}

        if ($node.PSObject.Properties.Name -contains 'properties' -and $node.properties) {
            foreach ($pp in $node.properties.PSObject.Properties) {
                $pname = $pp.Name
                $pval  = $pp.Value

                $directRef = $null
                if ($pval.PSObject.Properties.Name -contains '$ref') { $directRef = $pval.'$ref' }

                # allOf: [ { $ref } ] — OpenAPI idiom for "this property IS this
                # nested schema" (Pax8 uses it for Subscription.commitmentTerm).
                if (-not $directRef -and ($pval.PSObject.Properties.Name -contains 'allOf') -and $pval.allOf) {
                    foreach ($branch in $pval.allOf) {
                        if ($branch.PSObject.Properties.Name -contains '$ref') { $directRef = $branch.'$ref'; break }
                    }
                }

                $ptype = $null
                if ($pval.PSObject.Properties.Name -contains 'type') { $ptype = $pval.type }

                # An array is signalled by type=array OR by the presence of an
                # `items` node (Pax8's Pricing.rates omits the explicit type).
                $hasItems = ($pval.PSObject.Properties.Name -contains 'items' -and $pval.items)

                if ($directRef) {
                    $refs[$pname] = ($directRef -split '/')[-1]
                } elseif ($ptype -eq 'array' -or $hasItems) {
                    $itemRef = $null
                    if ($hasItems -and ($pval.items.PSObject.Properties.Name -contains '$ref')) {
                        $itemRef = ($pval.items.'$ref' -split '/')[-1]
                    }
                    if ($itemRef) { $arrays[$pname] = $itemRef } else { $arrays[$pname] = '(scalar-array)' }
                } else {
                    # scalar (string/number/integer/boolean) OR untyped -> treat as scalar field
                    $scalars.Add($pname)
                }
            }
        }

        $schemas[$name] = [pscustomobject]@{
            Name    = $name
            Scalars = @($scalars)
            Refs    = $refs
            Arrays  = $arrays
        }
    }
    return $schemas
}
