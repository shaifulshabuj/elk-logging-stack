# ELK Stack Setup Guide

This document provides detailed instructions for setting up and running the ELK Stack (Elasticsearch, Logstash, and Kibana) using Docker Compose.

## Prerequisites

- Docker and Docker Compose installed
- At least 4GB of available RAM
- At least 10GB of free disk space

## Installation Steps

### 1. Clone the Repository

If you haven't already, clone or download this repository to your local machine.

### 2. Review Configuration Files

The stack comes with pre-configured settings in the following locations:

- **Elasticsearch**: `config/elasticsearch/`
  - `elasticsearch.yml`: Main configuration
  - `index_lifecycle_policy.json`: Retention policies
  - `index_templates.json`: Index templates and mappings

- **Logstash**: `config/logstash/`
  - `logstash.conf`: Pipeline configuration

- **Kibana**: `config/kibana/`
  - `kibana.yml`: Main configuration
  - `setup_kibana.sh`: Script for automatic dashboard setup

### 3. Start the ELK Stack

Run the provided script to start all services:

```bash
./restart_elk.sh
```

This script will:
- Stop any running ELK containers
- Clean up orphaned volumes
- Start the stack with docker-compose
- Wait for all services to be available
- Automatically open Kibana in your default browser

Alternatively, you can start the stack manually:

```bash
docker-compose up -d
```

### 4. Verify the Installation

Once started, you can access the following services:

- **Elasticsearch**: [http://localhost:9200](http://localhost:9200)
- **Kibana**: [http://localhost:5601](http://localhost:5601)
- **Logstash**: Port 5000 (TCP), 5044 (Beats), 9600 (API)

Check if Elasticsearch is running:

```bash
curl http://localhost:9200/_cluster/health
```

Verify Kibana is accessible by opening http://localhost:5601 in your browser.

### 5. Initial Setup

The first time you start the stack, the following will happen automatically:

1. Elasticsearch will be initialized with index patterns and lifecycle policies
2. Kibana will be configured with:
   - Index patterns for different log types (syslog, application, webserver)
   - Saved searches for common queries
   - Visualizations for log analysis
   - A main dashboard showing log activity

## Configuration Details

### Elasticsearch

Elasticsearch is configured as a single-node cluster with the following settings:

- Single-node discovery type for local development
- 512MB heap size (adjustable in docker-compose.yml)
- Security features disabled for ease of development
- Index lifecycle management for log rotation and retention

### Logstash

Logstash is configured to:

- Accept logs from multiple sources (Beats, TCP, HTTP)
- Parse common log formats (syslog, JSON, web server logs)
- Forward processed logs to Elasticsearch
- Output to stdout for debugging

### Kibana

Kibana is set up with:

- Connection to Elasticsearch
- Default visualizations and dashboards
- Monitoring capabilities for the stack components

## Data Persistence

Elasticsearch data is persisted using Docker volumes. If you need to reset all data, use:

```bash
docker-compose down -v
```

## Resource Usage

The default configuration is optimized for local development:

- Elasticsearch: 512MB heap (1GB total with overhead)
- Logstash: 256MB heap
- Kibana: ~500MB

You can adjust these values in the docker-compose.yml file if needed.