// Pagination, error classification, retry, sanitisation. Synthetic fixtures through an injected fetch function.
let
    T = LoginEnterprise_PBI.TestExports,
    items = (n) => List.Transform({1 .. n}, each [id = "i" & Text.From(_), n = _]),
    ctxWith = (handler, ov) => T[FakeCtx](handler, ov),
    serve = (all) => (route, q, a) => T[Ok](T[Page](all, q)),
    ids = (l) => List.Transform(l, each _[id]),
    // 2500 items, page size 1000 => 3 pages; handler fails the test if paging params are ever duplicated/odd
    strict = (route, q, a) =>
        if q[count] <> "1000" then T[Raw](500, "unexpected count " & q[count])
        else if not List.Contains({"0", "1000", "2000", "2500"}, q[offset]) then T[Raw](500, "unexpected offset " & q[offset])
        else T[Ok](T[Page](items(2500), q)),
    r2500 = T[GetAllItems](ctxWith(strict, null), "x", [orderBy = "name"]),
    // caller wrongly supplies count/offset: connector must override exactly once
    dupParams = T[GetAllItems](ctxWith(strict, null), "x", [count = "5", offset = "7", includeTotalCount = "false", orderBy = "name"]),
    exact2000 = T[GetAllItems](ctxWith((r, q, a) => T[Ok]([items = T[Page](items(2000), q)[items]]), null), "x", []),
    noTotalShort = T[GetAllItems](ctxWith((r, q, a) => T[Ok]([items = T[Page](items(1500), q)[items]]), null), "x", []),
    capped = T[GetAllItems](ctxWith((r, q, a) => T[Ok](T[Page](items(1200), q & [count = "500"])), null), "x", []),
    laterFail = (route, q, a) => if q[offset] = "2000" then T[Raw](500, "internal boom " & T[Token]) else T[Ok](T[Page](items(2500), q)),
    sameAgain = (route, q, a) => T[Ok]([items = List.FirstN(items(5000), 1000), totalCount = 5000]),
    shortOfTotal = (route, q, a) => T[Ok]([items = if q[offset] = "0" then items(50) else {}, totalCount = 100]),
    errOf = (f) => let r = try f() in if r[HasError] then r[Error][Message] else "(no error)",
    attemptsSeen = (route, q, a) => if a < 2 then T[Raw](503, "busy") else T[Ok]([items = if q[offset] = "0" then {[id = "ok"]} else {}]),
    notLeaked = (msg) => not Text.Contains(msg, T[Token])
in
    T[Run]({
        T[Check]("2500 items across 3 pages, none lost, none duplicated, in order", () => List.Count(r2500) = 2500 and List.Count(List.Distinct(ids(r2500))) = 2500 and r2500{0}[n] = 1 and r2500{2499}[n] = 2500),
        T[Check]("caller-supplied count/offset do not produce duplicate/odd paging parameters", () => List.Count(dupParams) = 2500),
        T[Check]("exact multiple of page size terminates", () => List.Count(exact2000) = 2000),
        T[Check]("no totalCount, short last page terminates", () => List.Count(noTotalShort) = 1500),
        T[Check]("server that caps page size below request still returns everything (totalCount-driven)", () => List.Count(capped) = 1200 and List.Count(List.Distinct(ids(capped))) = 1200),
        T[CheckError]("later-page failure fails the whole read (no partial success)", () => T[GetAllItems](ctxWith(laterFail, null), "x", []), "HTTP 500"),
        T[Check]("error text never contains the API token", () => notLeaked(errOf(() => T[GetAllItems](ctxWith(laterFail, null), "x", [])))),
        T[CheckError]("non-progress (same page forever) is detected", () => T[GetAllItems](ctxWith(sameAgain, null), "x", []), "no progress"),
        T[CheckError]("fewer items than totalCount is reported as incomplete", () => T[GetAllItems](ctxWith(shortOfTotal, null), "x", []), "Incomplete result"),
        T[CheckError]("page limit raises instead of truncating", () => T[GetAllItems](ctxWith(serve(items(10000)), [MaxPages = 3]), "x", []), "safety limit"),
        T[CheckError]("malformed JSON is an error", () => T[GetAllItems](ctxWith((r, q, a) => T[Raw](200, "<html>not json"), null), "x", []), "not valid JSON"),
        T[CheckError]("wrong shape (no items array) is an error", () => T[GetAllItems](ctxWith((r, q, a) => T[Ok]([foo = 1]), null), "x", []), "'items' array"),
        T[CheckError]("401 gives an actionable auth message", () => T[GetAllItems](ctxWith((r, q, a) => T[Raw](401, "nope"), null), "x", []), "Authentication failed"),
        T[CheckError]("403 gives a permission message", () => T[GetAllItems](ctxWith((r, q, a) => T[Raw](403, "nope"), null), "x", []), "Access denied"),
        T[CheckError]("404 on a top-level list is an error", () => T[GetAllItems](ctxWith((r, q, a) => T[Raw](404, "nf"), null), "x", []), "Not found"),
        T[Check]("404 on per-run subresource (allowNotFound) is 'unavailable' => empty", () => T[GetAllItems](ctxWith((r, q, a) => T[Raw](404, "nf"), null), "x", [], true) = {}),
        T[Check]("204 is successful-empty", () => T[GetAllItems](ctxWith((r, q, a) => T[Raw](204, ""), null), "x", []) = {}),
        T[Check]("200 with empty items is successful-empty", () => T[GetAllItems](ctxWith((r, q, a) => T[Ok]([items = {}, totalCount = 0]), null), "x", []) = {}),
        T[Check]("transient 503 is retried (bounded) and succeeds", () => List.Count(T[GetAllItems](ctxWith(attemptsSeen, [RetryDelays = {0, 0}]), "x", [])) = 1),
        T[CheckError]("persistent 503 stops after bounded retries and reports attempts", () => T[GetAllItems](ctxWith((r, q, a) => T[Raw](503, "busy"), [RetryDelays = {0, 0}]), "x", []), "after 3 attempt(s)"),
        T[CheckError]("400 is not retried and explains contract mismatch", () => T[GetAllItems](ctxWith((r, q, a) => if a > 0 then T[Raw](200, "{}") else T[Raw](400, "bad"), [RetryDelays = {0, 0}]), "x", []), "rejected the request parameters"),
        T[CheckError]("transport/TLS failure gives actionable text", () => T[GetAllItems](ctxWith((r, q, a) => error Error.Record("DataSource.Error", "The remote certificate is invalid"), null), "x", []), "never disables certificate validation"),
        T[CheckError]("lazy failure inside the returned record (as Web.Contents does) is still classified", () => T[GetAllItems](ctxWith((r, q, a) => [Status = error Error.Record("DataSource.Error", "TLS handshake failed"), Body = ""], null), "x", []), "never disables certificate validation"),
        T[Check]("response body echoing the token is scrubbed", () => notLeaked(errOf(() => T[GetAllItems](ctxWith((r, q, a) => T[Raw](400, "bad token " & T[Token]), null), "x", [])))),
        T[CheckError]("GetList wrong shape is an error", () => T[GetList](ctxWith((r, q, a) => T[Ok]([foo = 1]), null), "x", []), "expected an array"),
        T[Check]("GetList accepts bare array and {items}", () => List.Count(T[GetList](ctxWith((r, q, a) => T[Ok]({[id="1"], [id="2"]}), null), "x", [])) = 2 and List.Count(T[GetList](ctxWith((r, q, a) => T[Ok]([items = {[id="1"]}]), null), "x", [])) = 1),
        T[CheckError]("blank token rejected before any request", () => T[Ctx]("demo.loginvsi.com", "  ")[Token], "token is blank"),
        T[CheckError]("http:// FQDN rejected", () => T[Ctx]("http://demo.loginvsi.com", "t")[Fqdn], "HTTPS only"),
        T[CheckError]("FQDN with path rejected", () => T[Ctx]("demo.loginvsi.com/api", "t")[Fqdn], "host name"),
        T[Check]("https:// prefix and trailing slash tolerated", () => T[Ctx]("https://Demo.loginvsi.com/", "t")[Fqdn] = "Demo.loginvsi.com")
    })
