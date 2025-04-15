#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${YELLOW}Stopping any running ELK stack containers...${NC}"
docker compose down

echo -e "${YELLOW}Removing any orphaned volumes...${NC}"
docker volume prune -f

echo -e "${YELLOW}Starting ELK stack...${NC}"
docker compose up -d

echo -e "${YELLOW}Waiting for services to start up...${NC}"
COUNTER=0
MAX_WAIT=120 # Maximum wait time in seconds
INTERVAL=5   # Check interval in seconds

echo -e "${YELLOW}Waiting for Elasticsearch to be ready...${NC}"
until curl -s http://localhost:9200/_cluster/health | grep -q '\"status\":\"green\"\|\"status\":\"yellow\"' || [ $COUNTER -eq $MAX_WAIT ]; do
    printf '.'
    sleep $INTERVAL
    COUNTER=$((COUNTER + INTERVAL))
done

if [ $COUNTER -lt $MAX_WAIT ]; then
    echo -e "\n${GREEN}Elasticsearch is up and running!${NC}"
else
    echo -e "\n${RED}Timed out waiting for Elasticsearch.${NC}"
    echo "Check logs with: docker compose logs elasticsearch"
fi

COUNTER=0
echo -e "${YELLOW}Waiting for Kibana to be ready...${NC}"
until curl -s http://localhost:5601/api/status | grep -q '"state":"green"' || [ $COUNTER -eq $MAX_WAIT ]; do
    printf '.'
    sleep $INTERVAL
    COUNTER=$((COUNTER + INTERVAL))
done

if [ $COUNTER -lt $MAX_WAIT ]; then
    echo -e "\n${GREEN}Kibana is up and running!${NC}"
else
    echo -e "\n${RED}Timed out waiting for Kibana.${NC}"
    echo "Check logs with: docker compose logs kibana"
fi

COUNTER=0
echo -e "${YELLOW}Waiting for Logstash to be ready...${NC}"
until curl -s http://localhost:9600/_node/stats | grep -q 'pipeline' || [ $COUNTER -eq $MAX_WAIT ]; do
    printf '.'
    sleep $INTERVAL
    COUNTER=$((COUNTER + INTERVAL))
done

if [ $COUNTER -lt $MAX_WAIT ]; then
    echo -e "\n${GREEN}Logstash is up and running!${NC}"
else
    echo -e "\n${RED}Timed out waiting for Logstash.${NC}"
    echo "Check logs with: docker compose logs logstash"
fi

echo -e "\n${GREEN}All services have been started!${NC}"
echo -e "Elasticsearch: http://localhost:9200"
echo -e "Kibana:        http://localhost:5601"
echo -e "Logstash:      http://localhost:9600"

# Open Kibana in the default browser
echo -e "\n${YELLOW}Opening Kibana in your default browser...${NC}"
case "$(uname -s)" in
    Darwin)  # macOS
        open http://localhost:5601
        ;;
    Linux)
        if command -v xdg-open > /dev/null; then
            xdg-open http://localhost:5601
        else
            echo -e "${YELLOW}Couldn't open browser automatically. Please visit http://localhost:5601 manually.${NC}"
        fi
        ;;
    *)
        echo -e "${YELLOW}Couldn't open browser automatically. Please visit http://localhost:5601 manually.${NC}"
        ;;
esac

echo -e "\n${GREEN}ELK stack restart completed.${NC}"
echo "Use the following commands for troubleshooting:"
echo "  docker compose logs -f               # View logs from all services"
echo "  docker compose logs -f elasticsearch # View Elasticsearch logs"
echo "  docker compose logs -f logstash      # View Logstash logs"
echo "  docker compose logs -f kibana        # View Kibana logs"