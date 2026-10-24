let
    T = LoginEnterprise_PBI.TestExports
in
    T[Run]({
        T[Check]("exports load", () => T[Token] = "tok-SECRET-123"),
        T[Check]("window rolling", () => T[Window](30, false, null, null, #datetimezone(2026, 10, 20, 17, 0, 0, 0, 0))[DayCount] = 31)
    })
