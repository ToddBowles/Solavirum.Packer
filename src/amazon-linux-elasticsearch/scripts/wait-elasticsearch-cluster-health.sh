#!/bin/bash

elasticsearch_url=${1:-"http://localhost:9200"}
desired_es_status=${2:-"yellow"}
maxAttempts=${3:-40}
waitSeconds=${4:-15}

echo "Waiting for Elasticsearch cluster health at [$elasticsearch_url] to return 200 OK and be [$desired_es_status]. Will execute at most [$maxAttempts] attempts, waiting [$waitSeconds] seconds between attempts"

response_file="/tmp/elk-elasticsearch/cluster-health-response.json"

attempts=0
expected=200

function try-cat-file
{
    if [[ -f $1 ]]; then 
        cat $1
    else
        echo "File [$1] was not found"
    fi
}

while true; do
    status=$(curl -XGET --output "$response_file" -w '%{http_code}' --silent -H "accept:application/json" "$elasticsearch_url/_cluster/health?pretty";)

    if [[ $status -eq $expected ]]; then 
        echo "Elasticsearch cluster health of [$elasticsearch_url] was [$expected]. Last response was:"
        try-cat-file $response_file

        echo "Checking cluster status"
        es_status=$(cat $response_file | jq -r '.status';)

        if [[ $es_status -eq $desired_es_status ]]; then
            echo "Elasticsearch cluster health status of [$elasticsearch_url] ([$es_status]) was equal to desired status [$desired_es_status]. All is well"
            break 
        fi
    fi
    
    if [[ $attempts -ge $maxAttempts ]]; then
        echo "Elasticsearch cluster health of [$elasticsearch_url] was not [$desired_es_status] after [$attempts] total attempts, waiting [$waitSeconds] seconds between attempts. Last response was:"
        try-cat-file $response_file
        exit 1
    fi

    attempts=$(($attempts + 1))
    echo "Elasticsearch cluster health of [$elasticsearch_url] did not meet the condition of status [200] and cluster health [$desired_es_status]. This was attempt [$attempts/$maxAttempts]. Waiting [$waitSeconds] and then trying again.  Status was [$status] and last response was:"
    try-cat-file $response_file

    sleep $waitSeconds
done