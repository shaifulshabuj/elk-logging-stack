# Sample Application Integration Guide

This technical guide explains how the sample application integrates with the ELK (Elasticsearch, Logstash, Kibana) stack and how to implement similar integrations in other applications.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Logger Configuration](#logger-configuration)
3. [Log Transport](#log-transport)
4. [Data Structure and Format](#data-structure-and-format)
5. [Logstash Parsing Configuration](#logstash-parsing-configuration)
6. [Kibana Visualization Setup](#kibana-visualization-setup)
7. [Integration Steps for Other Applications](#integration-steps-for-other-applications)

## Architecture Overview

The sample application integrates with the ELK stack using the following architecture:

```
┌───────────────┐   TCP/JSON    ┌──────────┐    ┌──────────────┐    ┌────────┐
│ Sample App    │ ───────────> │ Logstash │ ──> │ Elasticsearch │ ──> │ Kibana │
│ (Node.js)     │   (Port 5000) │          │    │              │    │        │
└───────────────┘               └──────────┘    └──────────────┘    └────────┘
```

Key components:
- **Application**: Node.js Express server with Winston logger
- **Log Transport**: TCP socket connection to Logstash
- **Log Format**: Structured JSON with standardized fields
- **Kibana Dashboards**: Pre-configured visualizations for application logs

## Logger Configuration

The sample application uses Winston, a popular Node.js logging library, with the following configuration:

```javascript
// From sample-app/app.js
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  defaultMeta: { service: 'sample-app' },
  transports: [
    // Console transport for local debugging
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    }),
    
    // TCP transport to send logs to Logstash
    new winston.transports.Stream({
      stream: require('net').connect({
        host: process.env.LOGSTASH_HOST || 'localhost',
        port: process.env.LOGSTASH_PORT || 5000
      })
    })
  ]
});
```

Important aspects of this configuration:
1. **JSON Format**: Logs are formatted as JSON for structured logging
2. **Timestamp**: Each log entry includes a timestamp
3. **Service Tag**: All logs are tagged with `service: 'sample-app'` for identification
4. **Multiple Transports**: Logs are sent to both console and Logstash
5. **Environment Variables**: Connection settings can be configured via environment variables

## Log Transport

The sample application sends logs to Logstash via TCP socket connection:

1. **Connection Method**: TCP socket to Logstash on port 5000
2. **Format**: JSON-encoded messages
3. **Reconnection**: The TCP stream automatically attempts to reconnect if the connection fails

Logstash is configured to accept these logs through a TCP input with JSON codec:

```
# From config/logstash/logstash.conf
input {
  tcp {
    port => 5000
    codec => json
  }
  // ...other inputs...
}
```

## Data Structure and Format

The application sends logs with the following structure:

```json
{
  "@timestamp": "2025-04-15T12:00:00.000Z",
  "level": "info",
  "message": "User action description",
  "service": "sample-app",
  
  // Additional contextual data (varies by log type)
  "userId": 123,
  "action": "login",
  "result": "success",
  "duration": 45,
  "error": "Error details (if applicable)"
}
```

**Standard Fields**:
- `@timestamp`: ISO8601 timestamp
- `level`: Log level (info, warn, error)
- `message`: Human-readable log message
- `service`: Application or service name

**Context-Specific Fields**:
- HTTP requests include method, URL, status code, duration
- Errors include error message and stack trace
- User actions include user ID and action type

## Logstash Parsing Configuration

Logstash processes the JSON logs using the following filter configuration:

```
# From config/logstash/logstash.conf
filter {
  if [type] == "json" {
    # JSON logs are already parsed by the codec
    # Just need to handle the timestamp
    date {
      match => [ "timestamp", "ISO8601" ]
    }
    mutate {
      add_field => { "[@metadata][index]" => "application" }
    }
  }
  
  # Add common fields for all log types
  mutate {
    add_field => { "environment" => "development" }
  }
}
```

**Key Steps**:
1. Logstash identifies JSON-formatted logs by type
2. The timestamp is parsed from ISO8601 format
3. Logs are tagged with metadata for proper indexing
4. Common fields like environment are added to all logs

## Kibana Visualization Setup

Kibana dashboards for the sample application logs are defined in `config/kibana/sample-app-dashboards.json` and include:

1. **Request Count Visualization**: Displays total requests to the sample app
2. **Error Count Visualization**: Shows the number of error logs
3. **Response Time Graph**: Plots the average response time over time
4. **Log Table**: Displays detailed log entries with key fields

The setup script (`setup_kibana.sh`) automatically imports these visualizations when the ELK stack starts:

```bash
# Import sample app dashboards
curl -X POST "http://kibana:5601/api/kibana/dashboards/import" \
  -H 'kbn-xsrf: true' \
  -H 'Content-Type: application/json' \
  -d @/usr/share/kibana/config/sample-app-dashboards.json
```

## Integration Steps for Other Applications

To integrate another application with this ELK stack:

### 1. Configure Logging Library

For Node.js applications:
```javascript
// Example with Winston
const winston = require('winston');
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  defaultMeta: { service: 'your-service-name' },
  transports: [
    new winston.transports.Stream({
      stream: require('net').connect({
        host: process.env.LOGSTASH_HOST || 'localhost',
        port: process.env.LOGSTASH_PORT || 5000
      })
    })
  ]
});
```

For Java applications (using Logback with Logstash encoder):
```xml
<!-- logback.xml -->
<appender name="LOGSTASH" class="net.logstash.logback.appender.LogstashTcpSocketAppender">
  <destination>localhost:5000</destination>
  <encoder class="net.logstash.logback.encoder.LogstashEncoder">
    <customFields>{"service":"your-service-name"}</customFields>
  </encoder>
</appender>
```

For Python applications (using python-logstash):
```python
import logging
import logstash

logger = logging.getLogger('python-logger')
logger.setLevel(logging.INFO)

# Add logstash handler
logstash_handler = logstash.TCPLogstashHandler(
    'localhost', 5000, version=1)
logger.addHandler(logstash_handler)
```

### 2. Structure Log Messages

Follow these guidelines for log structure:
- Include a descriptive message
- Use consistent log levels (info, warn, error)
- Add a service name to identify the application
- Include contextual data as additional fields
- Use ISO8601 for any timestamps

### 3. Create Custom Visualizations

Create custom Kibana visualizations for your application:
1. Create saved searches filtering for your service name
2. Build visualizations based on your application-specific metrics
3. Combine visualizations into a dashboard
4. Export the dashboard configuration for automation

### 4. Update Docker Configuration

Add your application to the docker-compose.yml:
```yaml
your-app:
  build:
    context: ./your-app
  container_name: your-app
  environment:
    - LOGSTASH_HOST=logstash
    - LOGSTASH_PORT=5000
  depends_on:
    - logstash
  networks:
    - elk
```

### 5. Test the Integration

1. Generate test logs from your application
2. Verify logs are received by Logstash
3. Check that logs are indexed in Elasticsearch
4. Confirm that your visualizations display data correctly

For detailed examples of different logging libraries and integration patterns, see the sample application code.