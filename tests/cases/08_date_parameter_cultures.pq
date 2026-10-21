// Real M parsing checks. These do not establish Desktop date-control acceptance.
let
    T = LoginEnterprise_PBI.TestExports,
    cultures = {"en-US", "en-GB", "de-DE", "nl-NL"},
    expected = #date(2026,9,24)
in T[Run](
    List.Transform(cultures, (culture) =>
        T[Check]("ISO date parses under " & culture,
            () => Date.FromText("2026-09-24", [Culture=culture]) = expected))
    & {
        T[Check]("US regional date remains compatible", () => Date.FromText("9/24/2026",[Culture="en-US"]) = expected),
        T[Check]("selected end includes the full UTC day", () =>
            let w=T[Window](null,true,#date(2026,9,18),expected)
            in w[ToText]="2026-09-25T00:00:00Z" and w[EndDate]=expected)
    }
)
