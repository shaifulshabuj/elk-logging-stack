#!/bin/bash

# Workspace Build Verification Script
# This script verifies that the ELK logging stack workspace is properly set up

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

print_header() {
    echo -e "\n${BOLD}${YELLOW}$1${NC}\n"
}

print_success() {
    echo -e "  ${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "  ${RED}✗ $1${NC}"
}

print_info() {
    echo -e "  ${YELLOW}→ $1${NC}"
}

print_header "ELK Stack Workspace Build Verification"

# Check prerequisites
print_header "Checking Prerequisites"

# Check Docker
if command -v docker &> /dev/null; then
    docker_version=$(docker --version 2>/dev/null)
    print_success "Docker is installed: $docker_version"
    
    # Check if Docker daemon is running
    if docker info &> /dev/null; then
        print_success "Docker daemon is running"
    else
        print_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
else
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check Docker Compose
if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    if docker compose version &> /dev/null; then
        compose_version=$(docker compose version 2>/dev/null)
        print_success "Docker Compose is available: $compose_version"
    else
        compose_version=$(docker-compose --version 2>/dev/null)
        print_success "Docker Compose is available: $compose_version"
    fi
else
    print_error "Docker Compose is not available. Please install Docker Compose."
    exit 1
fi

# Check curl
if command -v curl &> /dev/null; then
    print_success "curl is available"
else
    print_error "curl is not installed. Some testing features will not work."
fi

# Check jq (optional)
if command -v jq &> /dev/null; then
    print_success "jq is available (for advanced testing)"
else
    print_info "jq is not installed (optional - for advanced JSON parsing)"
fi

# Check system resources
print_header "Checking System Resources"

# Check available memory
if command -v free &> /dev/null; then
    memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$memory_gb" -ge 4 ]; then
        print_success "Available memory: ${memory_gb}GB (sufficient)"
    else
        print_error "Available memory: ${memory_gb}GB (4GB+ recommended)"
    fi
else
    print_info "Cannot check memory on this system"
fi

# Check available disk space
disk_space=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$disk_space" -ge 10 ]; then
    print_success "Available disk space: ${disk_space}GB (sufficient)"
else
    print_error "Available disk space: ${disk_space}GB (10GB+ recommended)"
fi

# Check project structure
print_header "Checking Project Structure"

required_files=(
    "docker-compose.yml"
    "restart_elk.sh"
    "test_elk_stack.sh"
    "BUILD.md"
    "README.md"
    "config/elasticsearch"
    "config/logstash"
    "config/kibana"
    "docs"
    "sample-app"
)

for file in "${required_files[@]}"; do
    if [ -e "$file" ]; then
        print_success "$file exists"
    else
        print_error "$file is missing"
    fi
done

# Check if scripts are executable
print_header "Checking Script Permissions"

scripts=("restart_elk.sh" "test_elk_stack.sh" "restart_sample_app.sh" "test_logstash_pipeline.sh")

for script in "${scripts[@]}"; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            print_success "$script is executable"
        else
            print_info "$script is not executable (will be made executable when run)"
        fi
    else
        print_info "$script not found"
    fi
done

# Validate Docker Compose configuration
print_header "Validating Docker Compose Configuration"

if docker compose config --quiet 2>/dev/null; then
    print_success "docker-compose.yml is valid"
else
    print_error "docker-compose.yml has configuration errors"
    docker compose config 2>&1
fi

# Check port availability
print_header "Checking Port Availability"

ports=(9200 5601 5000 5001 5044 9600 8080)

for port in "${ports[@]}"; do
    if command -v lsof &> /dev/null; then
        if lsof -i:$port &> /dev/null; then
            print_error "Port $port is already in use"
        else
            print_success "Port $port is available"
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln | grep -q ":$port "; then
            print_error "Port $port is already in use"
        else
            print_success "Port $port is available"
        fi
    else
        print_info "Cannot check port $port availability (no lsof or netstat)"
    fi
done

# Test Docker image pulling capability
print_header "Testing Docker Image Access"

test_images=(
    "docker.elastic.co/elasticsearch/elasticsearch:7.14.0"
    "docker.elastic.co/logstash/logstash:7.14.0"
    "docker.elastic.co/kibana/kibana:7.14.0"
)

for image in "${test_images[@]}"; do
    if docker image inspect "$image" &> /dev/null; then
        print_success "$image is already available locally"
    else
        print_info "$image needs to be pulled (will happen during build)"
    fi
done

print_header "Build Verification Summary"

echo -e "${GREEN}✓ Basic workspace verification completed${NC}"
echo -e "${YELLOW}To build the ELK stack workspace:${NC}"
echo -e "  1. Run: ${BOLD}./restart_elk.sh${NC}"
echo -e "  2. Wait for services to start (2-5 minutes)"
echo -e "  3. Open Kibana: ${BOLD}http://localhost:5601${NC}"
echo -e "  4. Test the stack: ${BOLD}./test_elk_stack.sh${NC}"
echo ""
echo -e "${YELLOW}For detailed instructions, see:${NC}"
echo -e "  - ${BOLD}BUILD.md${NC} - Complete build guide"
echo -e "  - ${BOLD}README.md${NC} - Quick start"
echo -e "  - ${BOLD}docs/SETUP.md${NC} - Detailed setup"
echo ""
echo -e "${GREEN}Happy logging! 🚀${NC}"