{
  "schema": "kritical-readme-ai/v1",
  "generatedUtc": "2026-07-16",
  "generatedFrom": ["src/meta.json", "src/Kritical.Lens.SchemaCompleteness.psd1", "src/Public/Invoke-KriticalLensSchemaCompleteness.ps1"],
  "repo": {
    "name": "Kritical.Lens.SchemaCompleteness",
    "family": "Kritical.Lens",
    "category": "linter",
    "wave": ".5177",
    "testable": true,
    "purpose": "Schema completeness checker — walks a Microsoft365DSC schema inventory against a target PowerShell surface and asserts every declared field is populated, every referenced table exists, every table has its expected companion index/permset entries.",
    "dependsOn": ["Krit.OmniFramework", "Kritical.Lens.CodeGraph"]
  },
  "publicApi": [
    { "name": "Invoke-KriticalLensSchemaCompleteness", "does": "assert field coverage + table coverage + permset completeness against a schema inventory" }
  ],
  "audits": ["schema-field-coverage", "schema-table-coverage", "schema-permset-completeness"],
  "role": "linter catching 'declared but not delivered' schema holes (dangling-reference equivalent) before ship; UTCM-tagged (config-management surface)",
  "output": { "pathTemplate": "ALBrain/contracts/schema-completeness-<utc>.json", "sink": "disk", "retention": "days 90" },
  "family": { "umbrella": "Kritical.Lens", "sitsOn": "Kritical.Lens.CodeGraph" },
  "provenance": { "note": "New files only; README.md untouched.", "lane": "L4", "batch": "remaining Lens children (wake 29) — COMPLETES the Lens family" }
}
