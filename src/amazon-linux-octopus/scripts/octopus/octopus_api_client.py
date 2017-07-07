import requests
import json
import pprint

class OctopusApiClient:	

	def __init__(self, octopus_url, octopus_api_key, logging):
		if octopus_url is None or not octopus_url:
			raise ValueError("octopus_url was not specified")
		
		if octopus_api_key is None or not octopus_api_key:
			raise ValueError("octopus_api_key was not specified")

		self.__octopus_url = octopus_url
		self.__octopus_api_key = octopus_api_key
		self.__logging = logging
		self.__logging.debug("Created OctopusApiClient with url = '{0}'".format(octopus_url))
		
	def get_environment_by_name(self, environment_name):		
		self.__log_retrieval_attempt("environment", "name", environment_name)
		environments = self.__get_resource('environments/all', params=None)
		filter_desc = "environments by name = '{0}'".format(environment_name)					
		return self.__single_or_none(environments, lambda env: env['Name'] == environment_name, filter_desc)

	def get_and_check_env(environment_name):
		environment = self.get_environment_by_name(environment_name)
		if environment is None:
			raise ValueError("Could not find an environment with name: '{0}'".format(environment_name))
		return environment

	def get_machine_by_name(self, machine_name):
		if not machine_name:
			raise ValueError("The supplied machine name was blank (well, specifically it evaluated to false)")

		filter_desc = "machines by name = '{0}'".format(machine_name)	
		skip = 0
		while True:
			self.__log_retrieval_attempt("machine", "name", machine_name)
			request = "machines?skip={0}".format(skip)
			machines = (self.__get_resource(request, params=None))['Items']
			if len(machines) == 0:
				self.__logging.info("Machine with name {0} could not be found. Ran out of machines in Octopus".format(machine_name))
				return None				
			match = self.__single_or_none(machines, lambda machine: machine['Name'] == machine_name, filter_desc)
			if match is None:
				skip = skip + 30
			else:
				return match
		
	def get_project_by_name(self, project_name):								
		self.__log_retrieval_attempt("project", "name", project_name)
		projects = self.__get_resource('projects/all', params=None)		
		filter_desc = "projects by name = '{0}'".format(project_name)
		return self.__single_or_none(projects, lambda env: env['Name'] == project_name, filter_desc)
	
	def get_and_check_project(project_name):
		project = self.get_project_by_name(project_name)
		if project is None:
			raise ValueError("Could not find project with name: '{0}'".format(project_name))
		return project

	def get_deployments(self, environment_id, project_id):
		self.__log_retrieval_attempt("deployments", "environment/project", environment_id + "/" + project_id)
		query_string_params = { 
			'environments': environment_id,
			'projects' : project_id 
		}
		response = self.__get_resource('deployments', params=query_string_params)
		return response['Items']
	
	def latest_deployment(deployments):
		def was_task_successful(deployment):
			task = self.get_task_by_id(deployment['TaskId'])
			return task['FinishedSuccessfully']
			
		only_successful_deployments = filter(was_task_successful, deployments)
		sorted_successful_deployments = sorted(only_successful_deployments, key=lambda d: d['Created'], reverse=True)
		
		return sorted_successful_deployments[0] if len(sorted_successful_deployments) > 0 else None

	def get_releases(self, project_id):
		self.__log_retrieval_attempt("releases", "project id", project_id)
		endpoint = "projects/{0}/releases".format(project_id)
		result = self.__get_resource(endpoint, params=None)
		return result['Items']
		
	def get_task_by_id(self, task_id):
		self.__log_retrieval_attempt("task", "id", task_id)
		task_path = 'tasks/' + str(task_id)
		return self.__get_resource(task_path, params=None)
		
	def get_release_by_id(self, release_id):
		self.__log_retrieval_attempt("release", "id", release_id)
		release_path = 'releases/' + str(release_id)
		return self.__get_resource(release_path, params=None)
		
	def add_machine_to_environment(self, environment_id, roles, ssh_fingerprint, local_fqdn, hostname, octopus_account):
		self.__logging.info("Attempting to add machine to environment '{0}'".format(environment_id))
		request_data = {
			"Endpoint" : {
				"CommunicationStyle" : "Ssh",
				"Fingerprint" : ssh_fingerprint,
				"Host" : local_fqdn,
				"Port" : "22",
				"Uri" : "ssh://" + local_fqdn + ":22/",
				"AccountId" : octopus_account
			},
			"Status" : "Unknown",
			"Name" : hostname,
			"EnvironmentIds" : [environment_id],
			"Roles" : roles
		}
		
		was_created = self.__post_resource('machines', request_data) 
		log_part = "successfully added" if was_created else "NOT successfully added" 
		self.__logging.info("Machine was {0} to environment '{1}'".format(log_part, environment_id))
		return was_created

	def remove_machine(self, machine_id):
		if not machine_id:
			raise ValueError("The supplied machine id was blank (well, specifically it evaluated to false)") 
		self.__logging.debug("Attempting to remove machine with id {0}".format(machine_id))
		was_removed = self.__delete_resource('machines/{0}'.format(machine_id)) 
		log_part = "successfully removed" if was_removed else "NOT successfully removed" 
		self.__logging.info("Machine {0} was {1}".format(machine_id, log_part))
		return was_removed

	def find_latest_version(environment_id, project_id):
		deployments = self.get_deployments(environment_id, project_id)
		if len(deployments) > 0:
			latest_dep = self.latest_deployment(deployments)
			
			if latest_dep is not None:
				release = self.get_release_by_id(latest_dep['ReleaseId'])
				return release['Version']
			
		# fallback to just using the most recent release	
		return "latest"

	def __api_request_headers(self):
		return {
			'content-type': 'application/json',
			'X-Octopus-ApiKey': self.__octopus_api_key
		}
				
	def __get_resource(self, resource_path, params):
		endpoint = self.__octopus_url + '/api/' + resource_path
		response = requests.get(endpoint, params=params, headers=self.__api_request_headers())
		self.__log_api_call(endpoint, None, "GET", response)
		return response.json()	
		
	def __post_resource(self, resource_path, data):
		endpoint = self.__octopus_url + '/api/' + resource_path
		response = requests.post(endpoint, data=json.dumps(data), headers=self.__api_request_headers())
		self.__log_api_call(endpoint, data, "POST", response)
		return response.status_code == 201

	def __delete_resource(self, resource_path):
		endpoint = self.__octopus_url + '/api/' + resource_path
		response = requests.delete(endpoint, headers=self.__api_request_headers())
		self.__log_api_call(endpoint, None, "DELETE", response)
		return response.status_code == 200
		
	def __single_or_none(self, collection, filter_func, filter_desc):
		matching = filter(filter_func, collection)
		result = None if len(matching) < 1 else matching[0]
		was_found = "NOT FOUND" if result is None else "FOUND"
		self.__logging.info("Filtering {0} => {1}.".format(filter_desc, was_found))
		return result
	
	def __log_retrieval_attempt(self, resource_type, resource_prop, resource_prop_value):
		self.__logging.info("Attempting to retrieve " + resource_type + " with " + resource_prop + " '" + resource_prop_value + "'")
		
	def __log_api_call(self, request_endpoint, request_body, method, response):
		self.__logging.info("API REQUEST - " + method + " request to " + request_endpoint)
		self.__logging.debug("Request Body:\n" + json.dumps(request_body, indent=4))
		self.__logging.info("API RESPONSE - Status Code = " + str(response.status_code))
		self.__logging.debug("Response Body:\n " + json.dumps(response.json(), indent=4))