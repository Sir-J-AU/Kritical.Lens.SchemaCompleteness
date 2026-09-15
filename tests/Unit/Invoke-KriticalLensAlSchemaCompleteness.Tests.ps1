#requires -Version 7.0
# Pester tests for Invoke-KriticalLensAlSchemaCompleteness (GAP 1 — AL mirror-
# table schema-completeness analyzer). Deterministic fixture-based unit tests
# plus a real-repo smoke test gated on the connector repo being present.

# --- Discovery-phase gates (must run OUTSIDE BeforeAll so -Skip: sees them) ---
$ParserPath = 'C:\Users\joshl\OneDrive - Kritical Pty Ltd\Github\KRTPax8ToShopifyConnector\scripts\lib\KritLensAlParser.psm1'
$ParserLoaded = Test-Path -LiteralPath $ParserPath
$ConnectorRoot = 'C:\Users\joshl\OneDrive - Kritical Pty Ltd\Github\Kritical.AL.D365BC.Connector.Pax8-to-Storefront'
$ConnectorSpec = 'C:\Users\joshl\OneDrive - Kritical Pty Ltd\Github\KRTPax8ToShopifyConnector\reference\pax8-openapi\partner-endpoints.json'
$LiveAvailable = $ParserLoaded -and (Test-Path -LiteralPath $ConnectorRoot) -and (Test-Path -LiteralPath $ConnectorSpec)

BeforeAll {
    $repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:ParserPath = 'C:\Users\joshl\OneDrive - Kritical Pty Ltd\Github\KRTPax8ToShopifyConnector\scripts\lib\KritLensAlParser.psm1'
    if (Test-Path -LiteralPath $script:ParserPath) { Import-Module $script:ParserPath -Force }
    Import-Module (Join-Path $repo 'src/Kritical.Lens.SchemaCompleteness.psd1') -Force

    $script:FixtureDir  = Join-Path $repo 'tests/Fixtures'
    $script:SpecFixture = Join-Path $script:FixtureDir 'pax8-spec-fixture.json'
    $script:AlFixture   = Join-Path $script:FixtureDir 'al'

    $script:ConnectorRoot = 'C:\Users\joshl\OneDrive - Kritical Pty Ltd\Github\Kritical.AL.D365BC.Connector.Pax8-to-Storefront'
    $script:ConnectorSpec = 'C:\Users\joshl\OneDrive - Kritical Pty Ltd\Github\KRTPax8ToShopifyConnector\reference\pax8-openapi\partner-endpoints.json'
}

Describe 'Invoke-KriticalLensAlSchemaCompleteness — fixture' -Skip:(-not $ParserLoaded) {

    BeforeAll {
        $script:res = Invoke-KriticalLensAlSchemaCompleteness `
            -SpecPath $script:SpecFixture -AlRoot $script:AlFixture
    }

    It 'returns a result object with Summary + ByMirror + Rows' {
        $script:res | Should -Not -BeNullOrEmpty
        $script:res.Summary | Should -Not -BeNullOrEmpty
        $script:res.ByMirror | Should -Not -BeNullOrEmpty
    }

    It 'the fully-covered Pricing mirror (60100) reports 100% coverage' {
        $m = $script:res.ByMirror | Where-Object { $_.MirrorId -eq 60100 }
        $m | Should -Not -BeNullOrEmpty
        $m.Exists | Should -BeTrue
        $m.Missing | Should -Be 0
        $m.CoveragePct | Should -Be 100.0
    }

    It 'the gapped Company mirror (60120) reports exactly the 2 seeded gaps' {
        $m = $script:res.ByMirror | Where-Object { $_.MirrorId -eq 60120 }
        $m | Should -Not -BeNullOrEmpty
        $m.Exists | Should -BeTrue
        $m.Missing | Should -Be 2
        # missing "status" (scalar) + "city" (flattened Address)
        $m.MissingFields | Should -Contain 'status'
        $m.MissingFields | Should -Contain 'city'
    }

    It 'raises a MISSING-UPSTREAM-FIELD finding for Company.status' {
        $f = $script:res.Rows | Where-Object { $_.MirrorId -eq 60120 -and $_.Field -eq 'status' -and $_.Class -eq 'MISSING-UPSTREAM-FIELD' }
        $f | Should -Not -BeNullOrEmpty
    }

    It 'raises a MISSING-FLATTENED-FIELD finding for the Address.city column' {
        $f = $script:res.Rows | Where-Object { $_.MirrorId -eq 60120 -and $_.Field -eq 'city' -and $_.Class -eq 'MISSING-FLATTENED-FIELD' }
        $f | Should -Not -BeNullOrEmpty
    }

    It 'does NOT demand a separate mirror for Pricing.rates (flattened Rate)' {
        $f = $script:res.Rows | Where-Object { $_.Field -eq 'rates' -and $_.Class -eq 'CHILD-COLLECTION-NOT-MIRRORED' }
        $f | Should -BeNullOrEmpty
    }

    It 'emits Markdown + JSON when requested' {
        $md = Join-Path $env:TEMP ("al-sc-{0}.md" -f (Get-Random))
        $js = Join-Path $env:TEMP ("al-sc-{0}.json" -f (Get-Random))
        $null = Invoke-KriticalLensAlSchemaCompleteness -SpecPath $script:SpecFixture -AlRoot $script:AlFixture -OutputMd $md -OutputJson $js
        Test-Path $md | Should -BeTrue
        Test-Path $js | Should -BeTrue
        (Get-Content -Raw $md) | Should -Match 'AL mirror-table schema completeness'
        $j = Get-Content -Raw $js | ConvertFrom-Json
        $j.Generator | Should -Be 'Kritical.Lens.AlSchemaCompleteness'
        Remove-Item $md, $js -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Invoke-KriticalLensAlSchemaCompleteness — real connector repo smoke' -Skip:(-not $LiveAvailable) {

    BeforeAll {
        $script:live = Invoke-KriticalLensAlSchemaCompleteness `
            -SpecPath $script:ConnectorSpec -AlRoot $script:ConnectorRoot
    }

    It 'finds the real Pax8 mirror tables (M1 pass count > 0)' {
        $script:live.Summary.M1.Pass | Should -BeGreaterThan 0
    }

    It 'produces a per-mirror coverage row for the Pricing Mirror (60100)' {
        $m = $script:live.ByMirror | Where-Object { $_.MirrorId -eq 60100 -and $_.Exists }
        $m | Should -Not -BeNullOrEmpty
        $m.UpstreamFields | Should -BeGreaterThan 0
    }
}
