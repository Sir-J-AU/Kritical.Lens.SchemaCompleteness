# Kritical-M365Sample — test fixture for Kritical.Lens.SchemaCompleteness
#
# Two resources are covered by primitives with matching schema shape.
# One (MissingCoverage) is intentionally absent so the C1 gate has both
# a pass and a fail path exercised.

# COVERS-DSC-RESOURCE: SampleUser
function New-KriticalSampleUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$UserPrincipalName,
        [string]$DisplayName,
        [bool]$AccountEnabled,
        [ValidateSet('Guest','Member')][string]$UserType
    )
    # Body would call the Graph API here.
}

# COVERS-DSC-RESOURCE: SampleUser
function Get-KriticalSampleUser {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$UserPrincipalName)
    # Read-side accessor.
}

# COVERS-DSC-RESOURCE: SamplePolicy
function New-KriticalSamplePolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter(Mandatory)][bool]$IsEnabled
    )
}

# COVERS-DSC-RESOURCE: SamplePolicy
function Get-KriticalSamplePolicy {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$DisplayName)
}
