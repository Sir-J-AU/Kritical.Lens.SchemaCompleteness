function _KriticalLensPax8MirrorMap {
    <#
    .SYNOPSIS
        The authoritative map from an AL mirror TABLE (by object id) to the
        Pax8 upstream OpenAPI schema it is expected to mirror, plus which
        nested single-object refs are flattened onto that same table.

    .DESCRIPTION
        This is the ONE place a mirror<->schema pairing is declared.  The
        upstream FIELD LIST is never hard-coded here — it is read live from
        the Pax8 OpenAPI spec by _KriticalLensLoadPax8Schemas.  This map only
        states "table X mirrors schema Y, with nested Z flattened in", which
        is a design fact about the connector, not spec content.

        FlattenRefs: nested single-object schemas whose SCALAR sub-properties
        are expected to appear as columns ON the mirror table itself
        (e.g. Company.address -> Address flattened into Street/City/...).

        Child ARRAY properties on the upstream schema (Company.contacts,
        Pricing.rates, Subscription.provisioningDetails) are deliberately NOT
        expected on the parent mirror — they are mirrored in their own tables,
        checked by the M4 gate.
    #>
    [CmdletBinding()]
    param()

    return @{
        # --- Pax8 API connector mirror tables (60xxx) ---
        60100 = @{ Schema = 'Pricing';       FlattenRefs = @('Rate');    Label = 'Pax8 Pricing Mirror' }
        60120 = @{ Schema = 'Company';       FlattenRefs = @('Address'); Label = 'Pax8 Company Mirror' }
        60121 = @{ Schema = 'Contact';       FlattenRefs = @();          Label = 'Pax8 Contact Mirror' }
        60185 = @{ Schema = 'ProductDetail'; FlattenRefs = @();          Label = 'Pax8 Product Identity Mirror' }
        60187 = @{ Schema = 'UsageLine';     FlattenRefs = @();          Label = 'Pax8 Usage Mirror' }
        60218 = @{ Schema = 'UsageSummary';  FlattenRefs = @();          Label = 'Pax8 Usage Summary Mirror' }
        60189 = @{ Schema = 'Subscription';  FlattenRefs = @();          Label = 'Pax8 Subscription Line Mirror' }
        60219 = @{ Schema = 'Subscription';  FlattenRefs = @();          Label = 'Pax8 Subscription Mirror' }
        60222 = @{ Schema = 'Invoice';       FlattenRefs = @();          Label = 'Pax8 Invoice Mirror' }
        60223 = @{ Schema = 'InvoiceItem';   FlattenRefs = @();          Label = 'Pax8 Invoice Item Mirror' }
        # --- native V2 subscription mirror tables (50xxx) ---
        50139 = @{ Schema = 'Subscription';  FlattenRefs = @();          Label = 'KritPax8SubHeaderV2' }
        50140 = @{ Schema = 'Subscription';  FlattenRefs = @();          Label = 'KritPax8SubLineV2' }
    }
}

function _KriticalLensNormalizeFieldToken {
    <#
    .SYNOPSIS
        Normalise an AL field caption OR a Pax8 camelCase property name to a
        comparable token: lower-case, alphanumeric only, leading 'pax8' /
        'krit' connector prefixes stripped.  "Pax8 Company Id" and
        "companyId" both -> "companyid".
    #>
    param([string]$Raw)
    if ($null -eq $Raw) { return '' }
    $t = $Raw.ToLowerInvariant()
    $t = $t -replace '[^a-z0-9]', ''
    if ($t.StartsWith('pax8')) { $t = $t.Substring(4) }
    elseif ($t.StartsWith('krit')) { $t = $t.Substring(4) }
    return $t
}

function _KriticalLensBuildAlFieldIndex {
    <#
    .SYNOPSIS
        Parse every .al file under AlRoot with KritLensAlParser and return a
        hashtable keyed by AL object id, valued by a pscustomobject with the
        parsed object plus a normalized-field-token set for O(1) lookup.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$AlRoot,
        [int]$MaxFiles = 0
    )

    $files = @(Get-ChildItem -Path $AlRoot -Filter '*.al' -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '\.bak\.' })
    if ($MaxFiles -gt 0) { $files = @($files | Select-Object -First $MaxFiles) }

    $byId = @{}
    foreach ($f in $files) {
        $raw = ''
        try { $raw = Get-Content -LiteralPath $f.FullName -Raw } catch { continue }
        if (-not $raw) { continue }
        $model = ConvertTo-KritAlFileModel -RawText $raw -RelPath $f.Name
        foreach ($o in $model.objects) {
            if ($o.kind -ne 'table') { continue }
            if ($null -eq $o.alId) { continue }
            $tokenSet = [System.Collections.Generic.HashSet[string]]::new()
            $fieldNames = [System.Collections.Generic.List[string]]::new()
            foreach ($fld in $o.fields) {
                if ($fld.isModify) { continue }
                $nm = $fld.name
                $fieldNames.Add($nm)
                [void]$tokenSet.Add((_KriticalLensNormalizeFieldToken $nm))
            }
            $byId[[int]$o.alId] = [pscustomobject]@{
                AlId       = [int]$o.alId
                Name       = $o.name
                RelPath    = $f.Name
                FieldNames = @($fieldNames)
                Tokens     = $tokenSet
            }
        }
    }
    return $byId
}
