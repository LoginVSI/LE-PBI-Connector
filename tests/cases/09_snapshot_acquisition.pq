// Reproduces old stored snapshot failures independently of page size/cache. Facts keep the same run identities.
let
    T=LoginEnterprise_PBI.TestExports,
    old=T[Run_]("old","ApplicationTest","2025-01-01T00:00:00Z","2025-01-01T00:05:00Z"),
    selected=T[Run_]("selected","ApplicationTest","2026-09-24T10:00:00Z","2026-09-24T10:05:00Z"),
    snapshot=[name="Retained snapshot",workload=[steps={[type="AppReference",appId="app",applicationName="App",runOnce=true]}]],
    W=T[Window](null,true,#date(2026,9,18),#date(2026,9,24)),
    handler=(r,q,a) =>
        if r="tests/test-runs" then
            if Record.HasFields(q,"include") or Record.HasFields(q,"from") or Record.HasFields(q,"to") or Record.HasFields(q,"filter") or q[count]<>"1000" or q[orderBy]<>"created" or q[direction]<>"asc" then T[Raw](500,"old snapshot expansion failed")
            else T[Ok](T[Page](if q[testType]="applicationTest" then {old & [testRunConfigurationSnapshot=null],selected & [testRunConfigurationSnapshot=null]} else {},q))
        else if r="test-runs/old" then T[Raw](500,"old snapshot expansion failed")
        else if r="test-runs/selected" and q[include]="testRunConfigurationSnapshot" then T[Ok](selected & [testRunConfigurationSnapshot=snapshot])
        else T[Raw](500,"unexpected request"),
    ctx=T[FakeCtx](handler),runs=T[GetTestRunsRaw](ctx,W),
    selectedResult=List.First(List.Select(runs,each _[id]="selected")),
    workload=T[GetWorkloadSteps](T[TestRunsToTable](runs))
in T[Run]({
    T[Check]("catalog never expands snapshots and retains old run metadata",()=>List.Count(runs)=2 and List.First(runs)[id]="old"),
    T[Check]("selected snapshot name and workload retained",()=>selectedResult[testRunConfigurationSnapshot][name]="Retained snapshot" and Table.RowCount(workload)=1 and workload{0}[appId]="app"),
    T[CheckError]("selected snapshot failure remains a refresh failure",()=>List.First(T[GetTestRunsRaw](T[FakeCtx]((r,q,a)=>if r="test-runs/selected" then T[Raw](500,"snapshot failure") else handler(r,q,a)),W){1}[testRunConfigurationSnapshot][workload][steps])[appId],"HTTP 500"),
    T[Check]("production retry flags bypass cache only on retry",()=>T[WebOptions]("synthetic","x",[],0,30)[IsRetry]=false and T[WebOptions]("synthetic","x",[],1,30)[IsRetry]=true and T[WebOptions]("synthetic","x",[],2,30)[IsRetry]=true)
})
