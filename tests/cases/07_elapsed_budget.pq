// Real engine clock probe and delayed production-fetch seam. No static clock can pass these checks.
let
    T = LoginEnterprise_PBI.TestExports,
    start = DateTimeZone.UtcNow(),
    later = if start = start then Function.InvokeAfter(DateTimeZone.UtcNow, #duration(0,0,0,0.15)) else start,
    delayed = T[FakeCtx]((r,q,a) => Function.InvokeAfter(() => T[Ok]([items={}]), #duration(0,0,0,0.15)), [BudgetSeconds=0.05]),
    retry = T[FakeCtx]((r,q,a) => T[Raw](503,"busy"), [BudgetSeconds=0.05, RetryDelays={0.15}])
in T[Run]({
    T[Check]("forced UTC clock advances during one evaluation", () => Duration.TotalSeconds(later-start)>=0.10),
    T[CheckError]("elapsed budget is checked after a delayed response", () => T[GetAllItems](delayed,"x",[]), "Elapsed request budget"),
    T[CheckError]("retry wait cannot bypass elapsed budget", () => T[GetAllItems](retry,"x",[]), "Elapsed request budget")
})
