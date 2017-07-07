# --------------------------------------------------------- #
# This script will register this machine with an octopus server,
# which can then use ssh to push releases to this machine.
# 
# The API calls are abstracted in the OctopusApiClient class.
# --------------------------------------------------------- #

import argparse
import socket
import base64
import hashlib
import sys
import logging
import requests
import json
from octopus_api_client import OctopusApiClient
from logging_configuration import configure

parser = argparse.ArgumentParser(description='Octopus deployment target registration script.')
parser.add_argument('-u','--octopusurl', help='Octopus Deploy URL',required=True)
parser.add_argument('-k','--octopusapikey',help='Octopus API Key', required=True)
parser.add_argument('-l','--logfile',help='Path to a log file', required=False)
args = parser.parse_args()

log_file_name = configure(args.logfile)

logging.info("Attempting to remove the current machine from Octopus")
  
def get_tentacle_name_from_instance_id():
  body = requests.get("http://169.254.169.254/latest/dynamic/instance-identity/document").content
  parsed = json.loads(body)
  return parsed['instanceId']

def get_tentacle_name_from_host():
  return socket.gethostname()

octopus_client = OctopusApiClient(args.octopusurl, args.octopusapikey, logging)

def remove_machine(name, description):
  try:
    machine = octopus_client.get_machine_by_name(name)
    return octopus_client.remove_machine(machine['Id'])
  except Exception as e:
    logging.exception("An unexpected error occurred while attempting to remove the Octopus Tentacle named {0} (named using {1}). Error: {2}".format(name, description, e))
    return False

success = remove_machine(get_tentacle_name_from_instance_id(), "AWS instance id")
if not success:
  success = remove_machine(get_tentacle_name_from_host(), "hostname")

if not success:
  sys.exit("This machine was NOT removed from Octopus. For more information (DEBUG level logs), check the log file at {0}".format(log_file_name)) # exit code 1