// Fixture mirror table — Company schema, DELIBERATE GAPS:
//  * missing scalar "status"  (M2 fail)
//  * missing flattened Address "city" (M3 fail)
// present: id (Company Id), name, street.
table 60120 "Fixture Company Mirror"
{
    fields
    {
        field(1; "Entry No."; Integer) { }
        field(2; "Id"; Text[100]) { }
        field(3; "Name"; Text[250]) { }
        field(10; "Street"; Text[100]) { }
    }
}
