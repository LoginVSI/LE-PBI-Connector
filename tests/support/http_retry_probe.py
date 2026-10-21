"""Real Web.Contents cache/retry probe on loopback. Only synthetic credentials are used."""
import argparse
import json
from pathlib import Path
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from uuid import uuid4


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--pqtest',required=True)
    parser.add_argument('--mez',required=True)
    parser.add_argument('--output',required=True)
    args=parser.parse_args()
    root=Path(__file__).resolve().parents[2]
    work=root/'.cache'/('http-retry-'+uuid4().hex)
    work.mkdir(parents=True)
    counts={}
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            name=self.path.rsplit('/',1)[-1]
            counts[name]=counts.get(name,0)+1
            number=counts[name]
            status=500 if name=='transient' and number==1 else 200
            body=json.dumps({'nonce':number,'ok':status==200}).encode()
            self.send_response(status)
            self.send_header('Content-Type','application/json')
            self.send_header('Cache-Control','max-age=600')
            self.send_header('Content-Length',str(len(body)))
            self.end_headers();self.wfile.write(body)
        def log_message(self,*args):
            pass
    server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
    threading.Thread(target=server.serve_forever,daemon=True).start()
    origin='http://127.0.0.1:'+str(server.server_port)
    query=work/'probe.pq'
    query.write_text('''let
    T=LoginEnterprise_PBI.TestExports,
    root="ORIGIN",
    fetch=(route,attempt) =>
        let response=Web.Contents(root,Record.RemoveFields(T[WebOptions](T[Token],route,[],attempt,5),{"ManualCredentials"})),
            status=Value.Metadata(response)[Response.Status],body=Binary.Buffer(response)
        in if status=status and body=body then [Status=status,Body=body] else error "unreachable",
    value=(route,attempt) => Json.Document(fetch(route,attempt)[Body])[nonce],
    controlFirst=value("cache-control",0),
    controlSecond=if controlFirst=1 then Function.InvokeAfter(()=>value("cache-control",0),#duration(0,0,0,0.1)) else -1,
    bypassFirst=value("cache-bypass",0),
    bypassSecond=if bypassFirst=1 then Function.InvokeAfter(()=>value("cache-bypass",1),#duration(0,0,0,0.1)) else -1,
    context=T[FakeCtx]((route,q,attempt)=>fetch(route,attempt),[RetryDelays={0,0}]),
    retried=T[Request](context,"transient",[],false)[Json]
in T[Run]({
    T[Check]("normal request reuses cached 200 response",()=>controlFirst=1 and controlSecond=1),
    T[Check]("production IsRetry=true bypasses cached 200 response",()=>bypassFirst=1 and bypassSecond=2),
    T[Check]("production retry makes a second HTTP request after 500",()=>retried[ok]=true and retried[nonce]=2)
})
'''.replace('ORIGIN',origin),encoding='utf-8')
    cache=work/'credentials.json'
    credential={'AuthenticationKind':'Anonymous','AuthenticationProperties':{},'PrivacySetting':'None','Permissions':[]}
    try:
        setup=subprocess.run([args.pqtest,'set-credential','-dsk','Web','-dsp',origin,'-cfp',str(cache)],input=json.dumps(credential),capture_output=True,text=True,timeout=30)
        result=subprocess.run([args.pqtest,'run-test','-e',args.mez,'-q',str(query),'-cfp',str(cache)],capture_output=True,text=True,timeout=90)
        (work/'result.json').write_text(result.stdout,encoding='utf-8')
        try:
            records=json.loads(result.stdout)
            passed=result.returncode==0 and records and all(x.get('Status')=='Passed' for x in records)
            errors=[x.get('Error') for x in records if x.get('Status')!='Passed']
        except (ValueError,TypeError):
            passed=False;errors=['PQTest output did not parse']
        summary={'realPowerQueryExecution':True,'productionCacheOptionsUsed':True,'contextDifference':'Extension-only ManualCredentials omitted from standalone query Web.Contents; production cache flags and retry orchestration are unchanged.','loopbackOnly':True,'syntheticCredentialsOnly':True,'status':'passed' if passed else 'failed','httpRequestCounts':counts,'pqtestExit':result.returncode,'credentialSetupExit':setup.returncode,'errors':errors}
        Path(args.output).write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
        print(json.dumps(summary,indent=2))
        return 0 if passed else 1
    finally:
        server.shutdown();server.server_close()

if __name__=='__main__':
    raise SystemExit(main())
