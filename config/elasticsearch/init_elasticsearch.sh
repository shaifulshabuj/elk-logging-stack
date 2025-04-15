#!/bin/bash

# Wait for Elasticsearch to be available
until curl -s http://elasticsearch:9200 > /dev/null; do
    echo "Waiting for Elasticsearch to be available..."
    sleep 10
done

echo "Elasticsearch is up! Creating index lifecycle policy..."

# Create index lifecycle policy
curl -X PUT "http://elasticsearch:9200/_ilm/policy/logs_policy" -H "Content-Type: application/json" -d @/usr/local/init/index_lifecycle_policy.json

echo "Creating index template..."

# Create index template
curl -X PUT "http://elasticsearch:9200/_index_template/logs_template" -H "Content-Type: application/json" -d @/usr/local/init/index_templates.json

echo "Elasticsearch initialization completed successfully!"