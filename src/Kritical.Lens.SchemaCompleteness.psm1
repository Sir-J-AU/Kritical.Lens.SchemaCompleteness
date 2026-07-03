#requires -Version 7.0

$here = $PSScriptRoot

foreach ($sub in @('Private','Public')) {
    $dir = Join-Path $here $sub
    if (-not (Test-Path $dir)) { continue }
    Get-ChildItem -Path $dir -Filter '*.ps1' -File |
        Sort-Object Name |
        ForEach-Object { . $_.FullName }
}

Export-ModuleMember -Function 'Invoke-KriticalLensSchemaCompleteness'
