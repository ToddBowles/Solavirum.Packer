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
parser.add_argument('-e','--octopusenvironmentname',help='The name of the octopus environment to register this machine in', required=True)
parser.add_argument('-a','--octopusaccount',help='Octopus Account', required=True)
parser.add_argument('-r','--octopusroles',help='Octopus Roles (comma separated)', required=True)
parser.add_argument('-sk', '--sshkeyfilepath', help='Path to the ssh public key', required=True)
parser.add_argument('-l','--logfile',help='Path to a log file', required=False)
args = parser.parse_args()

log_file_name = configure(args.logfile)

logging.info("Attempting to register the current machine as an Octopus tentacle")
 
def get_ssh_fingerprint():
  try:
    rsa_key_file = open(args.sshkeyfilepath, 'r').read()    
    key = base64.b64decode(rsa_key_file.strip().split()[1].encode('ascii'))
    fp_plain = hashlib.md5(key).hexdigest()
    return ':'.join(a+b for a,b in zip(fp_plain[::2], fp_plain[1::2]))
  except IOError as e:
    logging.exception("I/O error({0}): {1}".format(e.errno, e.strerror))
    sys.exit(1)
  except Exception as e:
    logging.exception("Unexpected error {0}".format(e))
    sys.exit(1)
  
def get_name():
  try:
    body = requests.get("http://169.254.169.254/latest/dynamic/instance-identity/document").content
    parsed = json.loads(body)
    return parsed['instanceId']
  except Exception as e:
    logging.exception("A failure occurred while attempting to determine the Tentacle name using the AWS meta data service (i.e. instance id). Will default to the hostname. Error: {0}".format(e))
    return socket.gethostname()

octopus_client = OctopusApiClient(args.octopusurl, args.octopusapikey, logging)
environment = octopus_client.get_environment_by_name(args.octopusenvironmentname)
success = octopus_client.add_machine_to_environment(
  environment_id = environment['Id'], 
  roles = args.octopusroles.split(","), 
  ssh_fingerprint = get_ssh_fingerprint(), 
  local_fqdn = socket.getfqdn(), 
  hostname = get_name(),
  octopus_account = args.octopusaccount
) 

if not success:
  sys.exit("This machine was NOT added to Octopus. For more information (DEBUG level logs), check the log file at {0}".format(log_file_name)) # exit code 1