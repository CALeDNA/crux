import subprocess
import glob
import http.server
from prometheus_client import start_http_server,Gauge,Info,CollectorRegistry
from typing import Iterable

REGISTRY = CollectorRegistry()

TOTALJOBS=Gauge('ben_jobs_total', 'Total ben jobs created')
RUNNINGJOBS=Gauge('ben_running_jobs_total', 'Total ben jobs currently running')
QUEUEDJOBS=Gauge('ben_queued_jobs_total', 'Total ben jobs currently queued')
FINISHEDJOBS=Gauge('ben_finished_jobs_total', 'Total ben jobs finished')

REGISTRY.register(TOTALJOBS)
REGISTRY.register(RUNNINGJOBS)
REGISTRY.register(QUEUEDJOBS)
REGISTRY.register(FINISHEDJOBS)


class ServerHandler(http.server.BaseHTTPRequestHandler):
  def do_GET(self):
    self.send_response(200)
    self.end_headers()
    self.wfile.write(b"Hello World!")

    isFinished, isRunning, isQueued, totalJobs = benlist()

    TOTALJOBS.set(totalJobs)
    RUNNINGJOBS.set(isRunning)
    QUEUEDJOBS.set(isQueued)
    FINISHEDJOBS.set(isFinished)

    bennodes()

def benlist():
  benServers=glob.glob("/tmp/ben-*")
  for server in benServers:
    result = subprocess.run(["/etc/ben/ben", "-s", f"{server}/socket-default", "list"], capture_output=True)
    result = result.stdout.decode().strip().splitlines()
    isRunning = 0
    isQueued = 0
    isFinished = 0
    for row in result:
        cols=row.split()
        if(len(cols)>3):
          if(cols[3] == "r"):
            isRunning += 1
          else:
            isFinished += 1
        else:
          isQueued += 1
  totalJobs = isRunning + isQueued + isFinished
  return isFinished, isRunning, isQueued, totalJobs

def bennodes():
  result = subprocess.run(["/etc/ben/ben", "-s", "/tmp/ben-ubuntu/socket-default", "nodes"], capture_output=True)
  result = result.stdout.decode().strip().splitlines()
  for i in result:
    i = i.split()
    if len(i) == 4 and i[0] != "#":
      size=i[3]
      running=i[2]
      name=i[1].replace('-','_')
      try:
        i=Gauge(f'{name}_running', 'ben node')
        i.set(running)
        REGISTRY.register(i)
        i=Gauge(f'{name}_size', 'ben node')
        i.set(size)
        REGISTRY.register(i)
      except:
        i=REGISTRY._names_to_collectors[f'{name}_running']
        i.set(running)
        i=REGISTRY._names_to_collectors[f'{name}_size']
        i.set(size)
      

if __name__ == "__main__":
    start_http_server(8000,registry=REGISTRY)
    server = http.server.HTTPServer(('', 8001), ServerHandler)
    print("Prometheus metrics available on port 8000 /metrics")
    print("HTTP server available on port 8001")
    server.serve_forever()