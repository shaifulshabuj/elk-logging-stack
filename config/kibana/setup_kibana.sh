#!/bin/sh

# Wait for Kibana to be ready
echo "Waiting for Kibana to be ready..."
until curl -s http://kibana:5601/api/status | grep -q '"state":"green"'; do
    echo "Waiting for Kibana..."
    sleep 10
done

echo "Kibana is ready. Setting up index patterns..."

# Create logs index pattern
curl -X POST "kibana:5601/api/saved_objects/index-pattern/logs-*" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "attributes": {
      "title": "logs-*",
      "timeFieldName": "@timestamp"
    }
  }'

echo "Index pattern created successfully."

# Set default index pattern
curl -X POST "kibana:5601/api/kibana/settings" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "changes": {
      "defaultIndex": "logs-*"
    }
  }'

echo "Default index pattern set."

echo "Kibana setup completed successfully!"