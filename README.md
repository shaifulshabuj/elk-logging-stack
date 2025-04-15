# Centralized Logging with ELK Stack

A comprehensive centralized logging solution using the Elasticsearch, Logstash, and Kibana (ELK) stack. This project provides a Docker Compose-based setup for collecting, processing, analyzing, and visualizing logs from various sources.

## Features

- **Containerized ELK Stack**: Full Elasticsearch, Logstash, and Kibana setup using Docker Compose
- **Multi-source Log Ingestion**: Support for syslog, JSON application logs, and web server access logs
- **Automated Setup**: Scripts for initializing Elasticsearch and Kibana
- **Custom Dashboards**: Pre-configured Kibana dashboards for log analysis
- **Index Lifecycle Management**: Configured retention policies for efficient storage
- **Custom Log Parsing**: Logstash filters for different log formats
- **Testing Tools**: Scripts to verify stack functionality and log processing

## Prerequisites

- Docker and Docker Compose
- At least 4GB of RAM available for the ELK stack
- Bash shell environment (for setup scripts)
- jq (for testing scripts)

## Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/shaifulshabuj/elk-logging-stack.git
   cd elk-logging-stack
   ```

2. Start the ELK stack:
   ```bash
   ./restart_elk.sh
   ```

3. Access Kibana:
   - Open http://localhost:5601 in your browser
   - Default username: `elastic`
   - Default password: `changeme`

## Directory Structure

```
elk-logging-stack/
├── config/                 # Configuration files
│   ├── elasticsearch/      # Elasticsearch configuration
│   ├── kibana/             # Kibana configuration
│   └── logstash/           # Logstash pipeline configuration
├── docker-compose.yml      # Docker Compose definition
├── docs/                   # Documentation
├── sample_logs/            # Sample log files for testing
├── test_elk_stack.sh       # Test script for ELK stack
├── test_logstash_pipeline.sh # Test script for Logstash pipeline
└── restart_elk.sh          # Script to restart the ELK stack
```

## Sending Logs

### Syslog Format
```bash
echo "Apr 15 10:15:23 myhost sshd[1234]: Failed password for user from 10.0.0.1" | nc localhost 5001
```

### JSON Format
```bash
echo '{"timestamp":"2023-04-15T10:15:23.456Z","level":"ERROR","service":"payment-service","message":"Payment failed"}' | nc localhost 5001
```

### Apache Log Format
```bash
echo '192.168.1.20 - user123 [15/Apr/2023:10:15:23 +0000] "GET /api/v1/products HTTP/1.1" 200 1234 "http://example.com" "Mozilla/5.0"' | nc localhost 5001
```

## Testing

Run the full test suite:
```bash
./test_elk_stack.sh
```

Test just the Logstash pipeline:
```bash
./test_logstash_pipeline.sh
```

## Documentation

For detailed documentation, see the following guides in the `docs/` directory:

- [Setup Guide](docs/SETUP.md) - Detailed setup instructions
- [Usage Guide](docs/USAGE.md) - How to add new log sources
- [Dashboard Guide](docs/DASHBOARDS.md) - Creating custom dashboards
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md) - Solutions for common issues

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.