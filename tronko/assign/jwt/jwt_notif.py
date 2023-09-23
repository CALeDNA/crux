import os
import jwt
import datetime
import requests
import argparse
from dotenv import load_dotenv

parser = argparse.ArgumentParser(description='Trigger JWT notification for finished tronko processing.')
parser.add_argument('--status', type=str, required=True, help='Project tronko status')
parser.add_argument('--project', type=str, required=True, help='Corresponding projectID')
parser.add_argument('--primers', type=str, required=True, help='Comma separated string of failed primers')
args = parser.parse_args()

# Load environment variables from .env file
load_dotenv()

# Retrieve JWT_SECRET from environment variables
jwt_secret = os.getenv("JWT_SECRET")
api_url =  os.getenv("EDNA_EXPLORER_API_URL")

status=args.status
projectID=args.project
primers=args.primers

message=""
if(status == "COMPLETED"):
    message="Project status has been updated to COMPLETED."
else:
    message=f"Project status has been updated to PROCESSING_FAILED. The following primers failed: {primers}"
# Payload data
payload = {
    "projectID": f"{projectID}",
    "projectStatus": f"{status}",
    "message": f"{message}",
    "exp": datetime.datetime.utcnow() + datetime.timedelta(seconds=30)
}

# Generate JWT
encoded_jwt = jwt.encode(payload, jwt_secret, algorithm='HS256')

# API endpoint URL
api_url = f"{api_url}/api/external/updateProjectStatus"

# Sending POST request with the generated JWT as an Authorization header
response = requests.post(
    api_url,
    headers={
        'Authorization': f'Bearer {encoded_jwt}'
    }
)

# Output response
print(f"Response Status Code: {response.status_code}")
print(f"Response JSON: {response.json()}")