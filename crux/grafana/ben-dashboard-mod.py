import json
import ast
import argparse
import urllib.request
import copy

parser = argparse.ArgumentParser(description='')
parser.add_argument('--dashboard', type=str)
args = parser.parse_args()

dashbrd = args.dashboard

uf = urllib.request.urlopen("http://localhost:8000")
metrics = uf.read().decode()

with open(dashbrd, "r") as jsonFile:
    dashboard = json.load(jsonFile)

nodes=[]
for line in metrics.split("\n"):
    if line.startswith("#") or "ben" in line or line == "":
        continue
    nodes.append(line.split()[0])
    # print(line)


for panel in dashboard["panels"]:
    try:
        if(panel["title"] == "Node Utilization"):
            print(nodes)
            currRefId='A' #TODO:fix? shouldnt be able to reach Z. JS2 max of 25 instances
            query=panel["targets"][0]
            newTargets=[]
            for i in range(0,len(nodes), 2):
                source=nodes[i].split("_")[0]
                query["expr"]=f"{nodes[i]} / {nodes[i+1]}"
                query["legendFormat"]=source
                query["refId"]=currRefId
                currRefId=chr(ord(currRefId)+1)
                newTargets.append(copy.deepcopy(query))
            # print(newTargets)
            panel["targets"]=newTargets
    except:
        continue

with open(dashbrd, "w") as jsonFile:
    json.dump(dashboard, jsonFile)