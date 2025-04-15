# Adding New Log Sources to ELK Stack

This guide explains how to add different types of log sources to your ELK Stack for centralized logging and analysis.

## Overview

The ELK Stack can ingest logs from many different sources, including:

1. Direct TCP/UDP inputs
2. File-based logs
3. Log shippers (Filebeat, Logstash, Fluentd, etc.)
4. HTTP inputs
5. Application-specific connectors

## Supported Input Methods

Our ELK Stack configuration currently supports these input methods:

| Method | Port | Protocol | Configuration |
|--------|------|----------|---------------|
| Beats | 5044 | TCP | For Filebeat, Metricbeat, etc. |
| TCP/JSON | 5000 | TCP | Send JSON-formatted logs |
| HTTP | 8080 | HTTP | POST JSON-formatted logs |
| File | - | - | Mount volumes with log files |

## Adding a New Application Log Source

### Method 1: Direct TCP Connection (for containerized apps)

1. Configure your application to send logs in JSON format to Logstash:

```javascript
// Node.js example using winston
const winston = require('winston');
const { LogstashTransport } = require('winston-logstash-transport');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new LogstashTransport({
      host: 'logstash',
      port: 5000
    })
  ]
});

// Usage example
logger.info('User logged in', { userId: 123, ipAddress: '192.168.1.1' });
```

2. Ensure your application container is on the same network as the ELK stack:

```yaml
# Add to your application's docker-compose.yml
services:
  your-app:
    # ... other configuration
    networks:
      - elk

networks:
  elk:
    external: true
    name: elk-logging-stack_elk
```

### Method 2: Using Filebeat (for applications with log files)

1. Install Filebeat on the host system or in a container

2. Configure Filebeat to watch your log files and forward to Logstash:

```yaml
# filebeat.yml
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /path/to/your/application/logs/*.log
  fields:
    type: application_name
    environment: development
  fields_under_root: true

output.logstash:
  hosts: ["logstash:5044"]
```

3. Start Filebeat:

```bash
filebeat -e -c filebeat.yml
```

### Method 3: Direct HTTP POST (for web applications)

Send logs directly via HTTP POST to Logstash:

```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"timestamp":"2025-04-15T12:34:56.789Z","level":"INFO","message":"Test log entry","service":"my-service"}' \
  http://localhost:8080
```

## Customizing Log Parsing for New Sources

If your log format is not automatically parsed correctly, you'll need to add a custom parser to the Logstash configuration:

1. Edit `config/logstash/logstash.conf`
2. Add a new conditional section to the filter block:

```
filter {
  # ...existing filters...
  
  else if [type] == "your_log_type" {
    # Parse your custom log format
    grok {
      match => { "message" => "%{CUSTOMPATTERN:field_name}" }
    }
    
    # Add additional processing as needed
    date {
      match => [ "timestamp_field", "ISO8601" ]
    }
  }
}
```

3. Restart the Logstash service:

```bash
docker-compose restart logstash
```

## Adding a New Index Pattern in Kibana

Once your logs are flowing into Elasticsearch, you may want to create a dedicated index pattern:

1. Open Kibana at http://localhost:5601
2. Navigate to Stack Management → Index Patterns
3. Click "Create index pattern"
4. Enter the pattern that matches your indices (e.g., `your-application-*`)
5. Select `@timestamp` as the Time field
6. Click "Create index pattern"

## Best Practices for Log Formatting

To get the most out of the ELK Stack, format your logs with these fields:

1. **timestamp**: ISO8601 format (2025-04-15T12:34:56.789Z)
2. **level**: Log level (INFO, WARN, ERROR, etc.)
3. **message**: The main log message
4. **service**: The name of the service generating the log
5. **environment**: The environment (dev, prod, etc.)
6. **trace_id**: For distributed tracing (if applicable)

Example of an ideal log entry:

```json
{
  "timestamp": "2025-04-15T12:34:56.789Z",
  "level": "ERROR",
  "message": "Failed to process payment",
  "service": "payment-service",
  "environment": "development",
  "trace_id": "abc123",
  "user_id": 456,
  "error": "Insufficient funds",
  "additional_field": "any additional context"
}
```

## Testing New Log Sources

After configuring a new log source, generate some test logs and verify they appear in Kibana:

1. Generate test logs from your application
2. Open Kibana → Discover
3. Select the appropriate index pattern
4. Verify your logs appear and are correctly formatted
5. Check that timestamp, fields, and structured data are properly parsed