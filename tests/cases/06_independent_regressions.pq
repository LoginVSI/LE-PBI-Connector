// Independent adversarial fixtures, derived from contract semantics rather than connector behavior.
let
    T = LoginEnterprise_PBI.TestExports,
    W = T[Window](null, true, #date(2026,10,20), #date(2026,10,20)),
    R = {T[Run_]("r", "LoadTest", "2026-10-19T00:00:00Z", null)},
    rows = {[id="a"], [id="b"], [id="c"]},
    capped = (r,q,a) => T[Ok]([items = List.Range(rows, List.Min({Number.FromText(q[offset]),3}), if Number.FromText(q[offset]) < 3 then 1 else 0), offset=Number.FromText(q[offset]), totalCount=null]),
    // Strict from and inclusive to. An exact-midnight point must be retained once.
    aggregate = (r,q,a) => T[Ok](if q[from] < "2026-10-20T00:00:00Z" then {[timestamp="2026-10-20T00:00:00Z",score=0,count=1]} else {}),
    sessions = {
        [id="active",created="2026-10-19T00:00:00Z",loginStartTime="2026-10-19T00:01:00Z",sessionEndTime=null],
        [id="atEnd",created="2026-10-21T00:00:00Z",loginStartTime="2026-10-21T00:00:00Z",sessionEndTime=null],
        [id="endedAtStart",created="2026-10-19T00:00:00Z",loginStartTime="2026-10-19T00:01:00Z",sessionEndTime="2026-10-20T00:00:00Z"],
        [id="failed",created="2026-10-20T10:00:00Z",loginStartTime=null,sessionEndTime=null,loginState="failed"]
    },
    sessionTable = T[GetUserSessions](T[FakeCtx]((r,q,a) => T[Ok](T[Page](sessions,q))),R,W)
in T[Run]({
    T[Check]("capped pages without totalCount must not truncate", () => List.Count(T[GetAllItems](T[FakeCtx](capped),"x",[]))=3),
    T[Check]("strict lower aggregate boundary retains exact midnight", () => Table.RowCount(T[GetAggregatedEUXResults](T[FakeCtx](aggregate),R,W))=1),
    T[Check]("session half-open overlap retains active and failed; excludes end-only and ended-at-start", () => List.Sort(sessionTable[id])={"active","failed"}),
    T[CheckError]("200 null is not a documented empty result", () => T[GetAllItems](T[FakeCtx]((r,q,a)=>T[Raw](200,"null")),"x",[]), "null JSON"),
    T[CheckError]("negative total is malformed", () => T[GetAllItems](T[FakeCtx]((r,q,a)=>T[Ok]([items={},totalCount=-1])),"x",[]), "Invalid totalCount"),
    T[CheckError]("underreported total is an error", () => T[GetAllItems](T[FakeCtx]((r,q,a)=>T[Ok]([items=rows,totalCount=1])),"x",[]), "Inconsistent totalCount"),
    T[CheckError]("offset must echo requested offset", () => T[GetAllItems](T[FakeCtx]((r,q,a)=>T[Ok]([items=rows,totalCount=3,offset=99])),"x",[]), "offset mismatch"),
    T[CheckError]("scalar paged items are malformed", () => T[GetAllItems](T[FakeCtx]((r,q,a)=>T[Ok]([items={1},totalCount=1])),"x",[]), "Invalid item"),
    T[CheckError]("late 404 cannot turn a partial result into success", () => T[GetAllItems](T[FakeCtx]((r,q,a)=>if q[offset]="0" then T[Ok]([items=rows]) else T[Raw](404,"gone")),"x",[],true), "Not found"),
    T[CheckError]("malformed timestamp cannot silently disappear", () => Table.RowCount(T[GetMeasurements](T[FakeCtx]((r,q,a)=>T[Ok](T[Page]({[timestamp="2026-10-20TgarbageZ"]},q))),R,W)), "invalid timestamp"),
    T[CheckError]("malformed nested records cannot silently lose columns", () => T[GetTests](T[FakeCtx]((r,q,a)=>T[Ok](T[Page]({[id="x",connectionResources=123]},q)))){0}[connector_type], "Invalid record column"),
    T[CheckError]("non-record aggregate items cannot silently disappear", () => T[GetList](T[FakeCtx]((r,q,a)=>T[Ok]({123})),"x",[]), "Invalid record"),
    T[CheckError]("production per-run 404 is not an empty success", () => Table.RowCount(T[GetMeasurements](T[FakeCtx]((r,q,a)=>T[Raw](404,"gone")),R,W)), "Not found"),
    T[Check]("host rejection must not echo credentials in userinfo", () => let e=try T[Ctx]("secret@example.com", "t")[Fqdn] in e[HasError] and not Text.Contains(e[Error][Message],"secret")),
    T[CheckError]("page cap checked before making extra fetch", () => T[GetAllItems](T[FakeCtx]((r,q,a)=>if q[offset]<>"0" then error "unexpected extra fetch" else T[Ok]([items=rows]),[MaxPages=1]),"x",[]), "safety limit")
})
