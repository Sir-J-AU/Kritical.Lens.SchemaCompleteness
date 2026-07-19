// Fixture mirror table — Pricing schema, FULLY covered (M2 + M3 flattened Rate).
table 60100 "Fixture Pricing Mirror"
{
    fields
    {
        field(1; "Entry No."; Integer) { }
        field(10; "Product Id"; Text[50]) { }
        field(11; "Product Name"; Text[250]) { }
        field(20; "Billing Term"; Text[50]) { }
        field(24; "Unit Of Measurement"; Text[50]) { }
        field(30; "Partner Buy Rate"; Decimal) { }
        field(31; "Suggested Retail Price"; Decimal) { }
    }
}
