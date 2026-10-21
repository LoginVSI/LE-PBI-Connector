// Public interface compatibility: function names, parameter names/order, Key-credential entry point, early validation.
let
    T = LoginEnterprise_PBI.TestExports,
    names = (f) => Record.FieldNames(Type.FunctionParameters(Value.Type(f))),
    req = (f) => Type.FunctionRequiredParameters(Value.Type(f))
in
    T[Run]({
        T[Check]("legacy function keeps name, parameter names and order", () => names(LoginEnterprise_PBI.Contents) = {"FQDN", "ApiToken", "DaysBack", "UseDateRange", "StartDateParam", "EndDateParam"}),
        T[Check]("legacy function still requires FQDN and ApiToken only", () => req(LoginEnterprise_PBI.Contents) = 2),
        T[Check]("Key function takes no token parameter", () => names(LoginEnterprise_PBI.ContentsKey) = {"FQDN", "DaysBack", "UseDateRange", "StartDateParam", "EndDateParam"} and req(LoginEnterprise_PBI.ContentsKey) = 1),
        T[Check]("both functions return a table type", () => Type.Is(Type.FunctionReturn(Value.Type(LoginEnterprise_PBI.Contents)), type table) and Type.Is(Type.FunctionReturn(Value.Type(LoginEnterprise_PBI.ContentsKey)), type table)),
        T[CheckError]("legacy function rejects a bad FQDN before any request", () => Table.RowCount(T[Impl]("http://nope", "token")), "HTTPS only"),
        T[CheckError]("legacy function rejects an invalid date range before any request", () => Table.RowCount(T[Impl]("demo.loginvsi.com", "token", null, true, #date(2026, 1, 2), #date(2026, 1, 1))), "after End Date")
    })
