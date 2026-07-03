@{
    RootModule           = 'Kritical.Lens.SchemaCompleteness.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'e2c1a4b8-8a2f-4d3b-9b7f-7c5e9a1b2d3f'
    Author               = 'Joshua Finley'
    CompanyName          = 'Kritical Pty Ltd'
    Copyright            = '(c) 2026 Kritical Pty Ltd. All rights reserved.'
    Description          = 'Kritical Lens — Microsoft365DSC schema-parity proof. Walks the Microsoft365DSC .schema.mof inventory against a target PowerShell module set and proves every resource, every parameter, every AllowedValue is covered with correct type + Mandatory + ValidateSet fidelity. Emits a per-gate verdict plus a machine-readable JSON detail. First public slice of the Kritical Lens family.'

    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')

    FunctionsToExport = @(
        'Invoke-KriticalLensSchemaCompleteness'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('Kritical','Lens','Microsoft365DSC','UTCM','Schema','Parity','Audit','PowerShell','PSGallery')
            LicenseUri   = 'https://github.com/Sir-J-AU/Kritical.Lens.SchemaCompleteness/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/Sir-J-AU/Kritical.Lens.SchemaCompleteness'
            IconUri      = 'https://kritical.net/assets/horizontal_logo.png'
            ReleaseNotes = @'
1.0.0 — Initial public release.
  * Invoke-KriticalLensSchemaCompleteness — walks a Microsoft365DSC schema
    inventory against a PowerShell module set, emits a per-gate verdict
    across C1..C6 (primitive exists, every param, Mandatory match, DataType
    family, ValidateSet completeness, read-side accessor).
  * Extracted from the Kritical connector's internal audit toolkit as
    the first standalone Lens family slice.
  * Compatible with any module set that marks its resource-covering
    functions with a `# COVERS-DSC-RESOURCE: <ResourceName>` comment
    immediately preceding the function definition.
'@
        }
    }
}
