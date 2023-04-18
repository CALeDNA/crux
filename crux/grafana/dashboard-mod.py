import json
import ast
import argparse

parser = argparse.ArgumentParser(description='')
parser.add_argument('--dashboard', type=str)
parser.add_argument('--datasource', type=str)
args = parser.parse_args()

dashbrd = args.dashboard
datasrc = args.datasource


with open(dashbrd, "r") as jsonFile:
    dashboard = json.load(jsonFile)

datasources=[]
with open(datasrc, "r") as datasourcesFile:
    for line in datasourcesFile:
        if "uid:" in line:
            datasources.append(line.split(":")[-1].strip())

for panel in dashboard["panels"]:
    try:
        if(panel["datasource"]["uid"] == "-- Mixed --"):
            currRefId='A' #TODO:fix? shouldnt be able to reach Z. JS2 max of 25 instances
            source=panel["targets"][0]
            origUid=source["datasource"]["uid"]
            newDatasources=[]
            for datasource in datasources:
                newSource=str(source).replace(origUid,datasource)
                newSource=ast.literal_eval(newSource)
                newSource["refId"]=currRefId
                currRefId=chr(ord(currRefId)+1)
                newDatasources.append(newSource)
            panel["targets"]=newDatasources
    except:
        continue

with open(dashbrd, "w") as jsonFile:
    json.dump(dashboard, jsonFile)
