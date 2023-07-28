import subprocess
import glob
import http.server
from prometheus_client import start_http_server,Gauge,Info,CollectorRegistry
from flask import Flask, request, Response
from typing import Iterable
import os
import time

REGISTRY = CollectorRegistry()

TOTALJOBS=Gauge('ben_jobs_total', 'Total ben jobs created')
RUNNINGJOBS=Gauge('ben_running_jobs_total', 'Total ben jobs currently running')
QUEUEDJOBS=Gauge('ben_queued_jobs_total', 'Total ben jobs currently queued')
FINISHEDJOBS=Gauge('ben_finished_jobs_total', 'Total ben jobs finished')

REGISTRY.register(TOTALJOBS)
REGISTRY.register(RUNNINGJOBS)
REGISTRY.register(QUEUEDJOBS)
REGISTRY.register(FINISHEDJOBS)

app = Flask(__name__)

@app.route('/', methods=['GET'])
def ben():

  metric_data = bennodes()
  metric_data = "\n".join([f"{metric}\n" for metric in metric_data])

  isFinished, isRunning, isQueued, totalJobs = benlist()
  TOTALJOBS.set(totalJobs)
  RUNNINGJOBS.set(isRunning)
  QUEUEDJOBS.set(isQueued)
  FINISHEDJOBS.set(isFinished)

  return Response(metric_data, content_type='text/plain')

def benlist():
  isRunning = 0
  isQueued = 0
  isFinished = 0
  benServers=glob.glob("/tmp/ben-*")
  current_time = time.strftime("%Y%m%d%H%M%S")
  for server in benServers:
    if(subprocess.run(["/etc/ben/ben", "list", "-s", server], capture_output=False).returncode == 0):
      result = subprocess.run(["/etc/ben/ben", "-s", server, "list"], capture_output=True)
      result = result.stdout.decode().strip().splitlines()
      for row in result:
          cols=row.split()
          if(len(cols)>3):
            if(cols[3] == "r"):
              isRunning += 1
            else:
              isFinished += 1
          else:
            isQueued += 1
      # save `ben list` to a file to view
      basename=os.path.basename(server)
      print(f"/etc/ben/{server}.txt")
      # Delete previous file(s) with the same basename
      existing_file = glob.glob(f"/etc/ben/jobs/{basename}" + "*")
      if existing_file:
        for file in existing_file:
            os.remove(file)
      with open(os.path.join("/etc/ben/jobs", f"{basename}_{current_time}.txt"), "w") as file:
        file.write("\n".join(result))
  totalJobs = isRunning + isQueued + isFinished
  return isFinished, isRunning, isQueued, totalJobs

def bennodes():
  benServers=glob.glob("/tmp/ben-*")
  metric_data=[]
  for server in benServers:
    if(subprocess.run(["/etc/ben/ben", "list", "-s", server], capture_output=False).returncode == 0):
      result = subprocess.run(["/etc/ben/ben", "-s", server, "nodes"], capture_output=True)
      result = result.stdout.decode().strip().splitlines()
      for i in result:
        i = i.split()
        server=server.split('/')[-1].replace('-','_')
        if len(i) == 4 and i[0] != "#":
          size=i[3]
          running=i[2]
          name=i[1].replace('-','_')
          try:
            i=Gauge(f'{name}_{server}_running', 'ben node')
            i.set(running)
            REGISTRY.register(i)
            i=Gauge(f'{name}_{server}_size', 'ben node')
            i.set(size)
            REGISTRY.register(i)
            metric_data.append(f'{name}_{server}_running {running}')
            metric_data.append(f'{name}_{server}_size {size}')
          except:
            i=REGISTRY._names_to_collectors[f'{name}_{server}_running']
            i.set(running)
            i=REGISTRY._names_to_collectors[f'{name}_{server}_size']
            i.set(size)
            metric_data.append(f'{name}_{server}_running {running}')
            metric_data.append(f'{name}_{server}_size {size}')
  return metric_data


          
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)