#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Restarting Sample Application for ELK Stack...${NC}"

# Check if we're in the elk-logging-stack directory
if [ ! -d "sample-app" ]; then
  echo -e "${RED}Error: This script must be run from the elk-logging-stack directory${NC}"
  exit 1
fi

# Check if docker is running
if ! docker info > /dev/null 2>&1; then
  echo -e "${RED}Error: Docker is not running or not accessible${NC}"
  exit 1
fi

# Function to check if container exists
container_exists() {
  docker ps -a --format '{{.Names}}' | grep -q "^$1$"
  return $?
}

# Function to check if container is running
container_running() {
  docker ps --format '{{.Names}}' | grep -q "^$1$"
  return $?
}

# Stop and remove existing sample-app container if it exists
if container_exists "sample-app"; then
  echo -e "${YELLOW}Stopping existing sample-app container...${NC}"
  docker stop sample-app > /dev/null
  docker rm sample-app > /dev/null
  echo -e "${GREEN}Removed existing sample-app container${NC}"
fi

# Check if ELK stack is running
if ! container_running "elasticsearch" || ! container_running "logstash" || ! container_running "kibana"; then
  echo -e "${YELLOW}Warning: One or more ELK stack components not running${NC}"
  echo -e "${YELLOW}Do you want to start the full ELK stack? (y/n)${NC}"
  read -r response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo -e "${YELLOW}Starting ELK stack...${NC}"
    docker compose up -d elasticsearch logstash kibana
    echo -e "${GREEN}ELK stack is starting up...${NC}"
    echo -e "${YELLOW}Waiting for ELK stack to be ready (this may take a minute)...${NC}"
    sleep 60  # Wait for ELK stack to be ready
  else
    echo -e "${YELLOW}Continuing without restarting ELK stack${NC}"
  fi
fi

# Build and start the sample-app
echo -e "${YELLOW}Building and starting the sample-app...${NC}"
docker compose up -d --build sample-app

# Check if sample-app started successfully
if container_running "sample-app"; then
  echo -e "${GREEN}Sample Application started successfully!${NC}"
  echo -e "${GREEN}You can access it at: http://localhost:8080${NC}"
  echo -e "${YELLOW}Available endpoints:${NC}"
  echo -e "  - ${GREEN}http://localhost:8080/${NC} (Home page)"
  echo -e "  - ${GREEN}http://localhost:8080/info${NC} (Generate info logs)"
  echo -e "  - ${GREEN}http://localhost:8080/warn${NC} (Generate warning logs)"
  echo -e "  - ${GREEN}http://localhost:8080/error${NC} (Generate error logs)"
  echo -e "  - ${GREEN}http://localhost:8080/exception${NC} (Generate exception logs)"
  echo -e "  - ${GREEN}http://localhost:8080/generate?count=50${NC} (Generate 50 random logs)"
  echo -e "${YELLOW}Check the logs in Kibana at: http://localhost:5601${NC}"
else
  echo -e "${RED}Failed to start Sample Application${NC}"
  echo -e "${YELLOW}Logs from sample-app:${NC}"
  docker logs sample-app
fi