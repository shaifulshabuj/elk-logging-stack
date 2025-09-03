# Building the ELK Logging Stack Workspace

This guide provides comprehensive instructions for building and setting up the ELK (Elasticsearch, Logstash, Kibana) logging stack workspace from scratch.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Workspace Setup](#workspace-setup)
3. [Building the Stack](#building-the-stack)
4. [Verification](#verification)
5. [Development Workflow](#development-workflow)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

Before building the workspace, ensure you have the following installed:

### Required Software

- **Docker**: Version 20.0 or higher
  ```bash
  # Check Docker version
  docker --version
  ```

- **Docker Compose**: Version 2.0 or higher
  ```bash
  # Check Docker Compose version
  docker compose version
  ```

- **Git**: For cloning the repository
  ```bash
  # Check Git version
  git --version
  ```

- **curl**: For testing API endpoints
  ```bash
  # Check curl availability
  curl --version
  ```

- **jq**: For parsing JSON responses (optional but recommended)
  ```bash
  # Install jq
  # macOS: brew install jq
  # Ubuntu/Debian: apt-get install jq
  # CentOS/RHEL: yum install jq
  ```

### System Requirements

- **RAM**: Minimum 4GB available (8GB recommended)
- **Disk Space**: At least 10GB free space
- **Network**: Internet access for downloading Docker images
- **Ports**: The following ports should be available:
  - 9200 (Elasticsearch HTTP)
  - 9300 (Elasticsearch Transport)
  - 5601 (Kibana Web UI)
  - 5000/5001 (Logstash TCP Input)
  - 5044 (Logstash Beats Input)
  - 9600 (Logstash Monitoring API)
  - 8080 (Sample Application)

## Workspace Setup

### 1. Clone the Repository

```bash
# Clone the repository
git clone https://github.com/shaifulshabuj/elk-logging-stack.git

# Navigate to the project directory
cd elk-logging-stack

# Verify repository contents
ls -la
```

Expected output should include:
```
docker-compose.yml
restart_elk.sh
test_elk_stack.sh
config/
docs/
sample-app/
README.md
```

### 2. Understand the Project Structure

```
elk-logging-stack/
├── BUILD.md                    # This file - workspace building guide
├── README.md                   # Project overview and quick start
├── docker-compose.yml          # Main orchestration file
├── restart_elk.sh              # Script to start/restart the ELK stack
├── test_elk_stack.sh           # Comprehensive testing script
├── config/                     # Configuration files
│   ├── elasticsearch/          # Elasticsearch configuration
│   │   ├── elasticsearch.yml   # Main ES configuration
│   │   ├── index_lifecycle_policy.json  # Data retention policies
│   │   ├── index_templates.json         # Index templates
│   │   └── init_elasticsearch.sh        # ES initialization script
│   ├── kibana/                 # Kibana configuration
│   │   ├── kibana.yml          # Main Kibana configuration
│   │   ├── setup_kibana.sh     # Kibana setup script
│   │   └── sample-app-dashboards.ndjson # Pre-built dashboards
│   └── logstash/               # Logstash configuration
│       └── logstash.conf       # Log processing pipeline
├── docs/                       # Detailed documentation
│   ├── SETUP.md               # Detailed setup instructions
│   ├── USAGE.md               # How to use and extend the stack
│   ├── DASHBOARDS.md          # Dashboard creation guide
│   └── TROUBLESHOOTING.md     # Common issues and solutions
└── sample-app/                # Example Node.js application
    ├── Dockerfile             # Sample app container
    ├── package.json           # Node.js dependencies
    └── app.js                 # Sample application code
```

### 3. Verify Prerequisites

Run the prerequisites check:

```bash
# Check Docker
docker --version

# Check Docker Compose
docker compose version

# Verify Docker daemon is running
docker info

# Check available system resources
docker system df

# Run the automated verification script
./verify_workspace.sh
```

## Building the Stack

### Method 1: Automated Build (Recommended)

Use the provided script for a fully automated setup:

```bash
# Make the script executable (if not already)
chmod +x restart_elk.sh

# Start the ELK stack
./restart_elk.sh
```

This script will:
1. Stop any existing ELK containers
2. Clean up orphaned Docker volumes
3. Pull the latest Docker images
4. Start all services in the correct order
5. Wait for services to become healthy
6. Automatically open Kibana in your browser

### Method 2: Manual Build

For more control over the build process:

```bash
# 1. Pull all required Docker images
docker compose pull

# 2. Build any custom images (sample app)
docker compose build

# 3. Start the services
docker compose up -d

# 4. Monitor the startup process
docker compose logs -f
```

### Build Process Explanation

The build process creates the following containers:

1. **Elasticsearch** (`elasticsearch`)
   - Single-node cluster configuration
   - Data persistence with Docker volumes
   - Health checks and auto-restart policies

2. **Logstash** (`logstash`)
   - Multi-input pipeline (TCP, Beats, HTTP)
   - Log parsing and transformation
   - Output to Elasticsearch

3. **Kibana** (`kibana`)
   - Web interface for log visualization
   - Pre-configured dashboards and index patterns
   - Connected to Elasticsearch

4. **Initialization Containers**
   - `elasticsearch-init`: Sets up index templates and lifecycle policies
   - `kibana-init`: Configures dashboards and visualizations

5. **Sample Application** (`sample-app`)
   - Node.js application demonstrating log integration
   - Sends logs to Logstash for testing

## Verification

### 1. Check Service Health

```bash
# Check all container status
docker compose ps

# Check service health
docker compose logs --tail=20 elasticsearch
docker compose logs --tail=20 logstash
docker compose logs --tail=20 kibana
```

### 2. Test Service Connectivity

```bash
# Test Elasticsearch
curl -s http://localhost:9200/_cluster/health

# Test Kibana
curl -s http://localhost:5601/api/status

# Test Logstash
curl -s http://localhost:9600/_node/stats
```

### 3. Run Comprehensive Tests

```bash
# Run the full test suite
chmod +x test_elk_stack.sh
./test_elk_stack.sh
```

This will test:
- Service connectivity
- Log ingestion (syslog, JSON, Apache logs)
- Log parsing and field extraction
- Search functionality
- Kibana dashboards

### 4. Access the Web Interface

Open your browser and navigate to:
- **Kibana**: http://localhost:5601
- **Elasticsearch**: http://localhost:9200
- **Sample App**: http://localhost:8080

## Development Workflow

### Starting the Workspace

```bash
# Quick start (recommended)
./restart_elk.sh

# Or manual start
docker compose up -d
```

### Stopping the Workspace

```bash
# Stop all services
docker compose down

# Stop and remove all data (complete reset)
docker compose down -v
```

### Viewing Logs

```bash
# View logs from all services
docker compose logs -f

# View logs from specific service
docker compose logs -f elasticsearch
docker compose logs -f logstash
docker compose logs -f kibana
```

### Making Configuration Changes

1. **Logstash Configuration**:
   ```bash
   # Edit the pipeline configuration
   nano config/logstash/logstash.conf
   
   # Restart Logstash to apply changes
   docker compose restart logstash
   ```

2. **Elasticsearch Configuration**:
   ```bash
   # Edit elasticsearch configuration
   nano config/elasticsearch/elasticsearch.yml
   
   # Restart Elasticsearch
   docker compose restart elasticsearch
   ```

3. **Kibana Configuration**:
   ```bash
   # Edit kibana configuration
   nano config/kibana/kibana.yml
   
   # Restart Kibana
   docker compose restart kibana
   ```

### Testing Log Ingestion

```bash
# Test syslog format
echo "Apr 15 10:15:23 myhost sshd[1234]: Test message" | nc localhost 5001

# Test JSON format
echo '{"level":"INFO","message":"Test JSON log","service":"test"}' | nc localhost 5001

# Test Apache log format
echo '192.168.1.1 - - [15/Apr/2025:10:15:23 +0000] "GET / HTTP/1.1" 200 1234' | nc localhost 5001
```

## Troubleshooting

### Common Build Issues

1. **Port Already in Use**
   ```bash
   # Check what's using the port
   lsof -i :9200  # or :5601, :5000, etc.
   
   # Stop conflicting services or change ports in docker-compose.yml
   ```

2. **Insufficient Memory**
   ```bash
   # Check available memory
   free -h
   
   # Reduce heap sizes in docker-compose.yml if needed
   ```

3. **Docker Permission Issues**
   ```bash
   # Add user to docker group (Linux)
   sudo usermod -aG docker $USER
   # Then log out and back in
   ```

4. **Container Startup Failures**
   ```bash
   # Check container logs
   docker compose logs <service-name>
   
   # Check system resources
   docker system df
   docker system prune  # Clean up if needed
   ```

### Service-Specific Issues

1. **Elasticsearch Won't Start**
   - Check available memory (needs at least 1GB)
   - Verify vm.max_map_count on Linux: `sysctl vm.max_map_count`
   - Increase if needed: `sudo sysctl -w vm.max_map_count=262144`

2. **Kibana Connection Issues**
   - Verify Elasticsearch is running and healthy
   - Check Kibana logs for connection errors
   - Ensure correct Elasticsearch URL in kibana.yml

3. **Logstash Not Processing Logs**
   - Check Logstash logs for parsing errors
   - Verify input port configuration
   - Test connectivity: `telnet localhost 5001`

### Getting Help

1. **Check the Documentation**
   - [SETUP.md](docs/SETUP.md) - Detailed setup instructions
   - [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues
   - [USAGE.md](docs/USAGE.md) - How to use the stack

2. **Run Diagnostics**
   ```bash
   # System information
   docker info
   docker compose config
   
   # Service health
   ./test_elk_stack.sh
   ```

3. **Check Resources**
   - Docker Hub pages for official images
   - Elastic Stack documentation
   - GitHub issues in this repository

## Next Steps

After successfully building the workspace:

1. **Explore Kibana**: Visit http://localhost:5601 and explore the pre-built dashboards
2. **Send Test Logs**: Use the sample application or test scripts to generate logs
3. **Customize Configuration**: Modify parsing rules, add new log sources
4. **Create Dashboards**: Build custom visualizations for your data
5. **Scale Up**: Consider production deployment options

For detailed usage instructions, see [USAGE.md](docs/USAGE.md).