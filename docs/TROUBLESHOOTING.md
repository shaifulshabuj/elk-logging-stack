# ELK Stack Troubleshooting Guide

This guide provides solutions for common issues encountered when using the ELK Stack for centralized logging.

## Elasticsearch Issues

### Elasticsearch Won't Start

**Symptoms**:
- Elasticsearch container exits shortly after starting
- Logs show memory-related errors

**Solutions**:
1. **Increase Memory Limits**:
   - Edit `docker-compose.yml` and increase the `ES_JAVA_OPTS` memory settings
   - Default is `-Xms512m -Xmx512m`, try increasing to `-Xms1g -Xmx1g`

2. **Check System Resources**:
   - Ensure your host has sufficient available memory
   - Run `free -h` to check available memory

3. **Check Permissions**:
   - Ensure the data directory has correct permissions
   - Run `docker compose down -v` to remove volumes and try again

### Cluster Health is Red

**Symptoms**:
- Elasticsearch is running but health check shows "red" status
- Logs show unassigned shards

**Solutions**:
1. **Check Disk Space**:
   - Ensure there's sufficient disk space
   - Run `df -h` to check available space

2. **Reset Cluster State**:
   ```bash
   curl -X PUT "localhost:9200/_cluster/settings" -H 'Content-Type: application/json' -d'
   {
     "persistent": {
       "cluster.routing.allocation.enable": "all"
     }
   }'
   ```

3. **Force Allocation of Unassigned Shards**:
   ```bash
   curl -X POST "localhost:9200/_cluster/reroute?retry_failed=true" -H 'Content-Type: application/json'
   ```

## Logstash Issues

### Logs Not Being Processed

**Symptoms**:
- Logs are sent to Logstash but don't appear in Elasticsearch
- No errors in Logstash logs

**Solutions**:
1. **Check Logstash Pipeline**:
   - Verify your `logstash.conf` has the correct input configuration
   - Ensure filters match your log format
   - Check that output is correctly configured for Elasticsearch

2. **Enable Debug Output**:
   - Add a stdout output to your Logstash configuration:
   ```
   output {
     elasticsearch { ... }
     stdout { codec => rubydebug }
   }
   ```
   - Restart Logstash and check logs with `docker compose logs -f logstash`

3. **Test Input Directly**:
   - Send a test message to Logstash:
   ```bash
   echo '{"message":"test message", "timestamp":"2025-04-15T12:00:00.000Z"}' | nc localhost 5000
   ```

### Grok Pattern Failures

**Symptoms**:
- Logs showing "_grokparsefailure" tag
- Fields not being extracted correctly

**Solutions**:
1. **Test Your Grok Patterns**:
   - Use the [Grok Debugger](http://localhost:5601/app/dev_tools#/grokdebugger) in Kibana
   - Paste your pattern and sample log to debug

2. **Start Simple**:
   - Begin with a basic pattern matching just a few fields
   - Gradually add complexity once the basics work

3. **Use Grok Constructor**:
   - Try the online [Grok Constructor](https://grokconstructor.appspot.com/) tool
   - It helps build patterns interactively

## Kibana Issues

### Cannot Access Kibana

**Symptoms**:
- Kibana URL returns error or doesn't load
- Browser shows connection refused

**Solutions**:
1. **Check Kibana Status**:
   - Run `docker compose ps` to verify Kibana is running
   - Check logs with `docker compose logs kibana`

2. **Check Elasticsearch Connection**:
   - Verify Elasticsearch is running and healthy
   - Check Kibana configuration points to correct Elasticsearch URL

3. **Restart Kibana**:
   - Try restarting just Kibana: `docker compose restart kibana`
   - Wait 30 seconds for it to initialize

### No Data in Kibana

**Symptoms**:
- Kibana loads but shows "No results found"
- Index patterns show no data

**Solutions**:
1. **Verify Data in Elasticsearch**:
   - Check indices exist: `curl localhost:9200/_cat/indices`
   - Check document count: `curl localhost:9200/_count`

2. **Check Time Range**:
   - Kibana filters by time - ensure your time range includes when logs were ingested
   - Try expanding to "Last 30 days" or a custom larger range

3. **Verify Index Patterns**:
   - Go to Stack Management → Index Patterns
   - Ensure patterns match your actual indices
   - Recreate index pattern if necessary

### Visualizations Show "No Results"

**Symptoms**:
- Dashboard loads but visualizations show "No results found"
- Data exists in Discover view

**Solutions**:
1. **Check Filters**:
   - Look for active filters at dashboard level
   - Remove any filters that might be too restrictive

2. **Check Query**:
   - Visualizations may have built-in queries
   - Edit visualization and check its query settings

3. **Rebuild Visualization**:
   - Try recreating the visualization with simpler settings
   - Start with a basic count metric

## Network & Connectivity Issues

### Services Can't Communicate

**Symptoms**:
- Components start but can't connect to each other
- Logs show connection refused errors

**Solutions**:
1. **Check Docker Network**:
   - Verify all services are on the same network in docker-compose.yml
   - Run `docker network inspect elk-logging-stack_elk`

2. **Use Service Names**:
   - Services should reference each other by container name
   - Use `elasticsearch` not `localhost` in Logstash/Kibana configs

3. **Check Port Mappings**:
   - Verify ports are correctly mapped in docker-compose.yml
   - Check for port conflicts with `netstat -tuln`

### External Services Can't Connect

**Symptoms**:
- External applications can't send logs to Logstash
- Connection timeouts when trying to access ELK from another system

**Solutions**:
1. **Check Firewall Rules**:
   - Ensure needed ports are allowed through firewall
   - Common ports: 5044, 5000, 9200, 5601

2. **Verify Port Bindings**:
   - Make sure services bind to 0.0.0.0 not 127.0.0.1
   - Check docker-compose.yml port mappings use format "host:container"

3. **Network Mode**:
   - Consider using host network mode for easier external access:
   ```yaml
   network_mode: "host"
   ```

## Performance Issues

### Slow Elasticsearch Queries

**Symptoms**:
- Kibana dashboards load slowly
- Searches take a long time to complete

**Solutions**:
1. **Optimize Indices**:
   - Use ILM to manage index lifecycle
   - Consider using rollover for large indices

2. **Add Index Caching**:
   ```bash
   curl -X PUT "localhost:9200/_all/_settings" -H 'Content-Type: application/json' -d'
   {
     "index.queries.cache.enabled": true
   }'
   ```

3. **Limit Time Range**:
   - Query smaller time ranges
   - Use date filters to limit search scope

### High CPU/Memory Usage

**Symptoms**:
- Host system becoming unresponsive
- Docker stats shows high resource usage

**Solutions**:
1. **Increase Resource Limits**:
   - Adjust memory limits in docker-compose.yml
   - Consider using resource constraints for containers

2. **Optimize Logstash**:
   - Review complex grok patterns
   - Use the dissect filter instead of grok for simple logs (faster)
   - Consider adding queue settings:
   ```yaml
   pipeline.batch.size: 125
   pipeline.batch.delay: 50
   ```

3. **Use Filebeat Instead of Direct Input**:
   - For high-volume logs, use Filebeat to buffer and send
   - This offloads parsing from Logstash

## Common Error Messages

### "max virtual memory areas vm.max_map_count [65530] is too low"

**Solution**:
```bash
# Temporary fix
sudo sysctl -w vm.max_map_count=262144

# Permanent fix (add to /etc/sysctl.conf)
vm.max_map_count=262144
```

### "Cannot allocate memory"

**Solution**:
- Reduce Java heap size in docker-compose.yml
- Free up system memory by stopping unnecessary services
- Add swap space to your system

### "No living connections"

**Solution**:
- Check Elasticsearch is running and accessible
- Verify network connectivity between services
- Check for correct hostnames in configuration

## Data Management Issues

### Indices Growing Too Large

**Solutions**:
1. **Implement Index Lifecycle Management**:
   - Set up ILM policies for automatic rollover
   - Configure retention policies to delete old indices

2. **Use Index Templates with Sharding**:
   - Create templates with appropriate sharding
   ```bash
   curl -X PUT "localhost:9200/_template/logs_template" -H 'Content-Type: application/json' -d'
   {
     "index_patterns": ["logs-*"],
     "settings": {
       "number_of_shards": 2,
       "number_of_replicas": 0
     }
   }'
   ```

3. **Filter Unnecessary Logs**:
   - Add filters in Logstash to drop low-value logs
   - Only index important fields

### How to Reset Everything and Start Fresh

If you need a complete reset:

```bash
# Stop all containers
docker compose down -v

# Remove Elasticsearch data
sudo rm -rf data/elasticsearch/*

# Restart with clean state
docker compose up -d
```

## Getting Help

If you encounter issues not covered in this guide:

1. **Check Docker Logs**:
   ```bash
   docker compose logs -f
   docker compose logs -f elasticsearch
   docker compose logs -f logstash
   docker compose logs -f kibana
   ```

2. **Elasticsearch Health**:
   ```bash
   curl -X GET "localhost:9200/_cluster/health?pretty"
   ```

3. **Check Stack Versions**:
   Ensure all components are using compatible versions (Elasticsearch, Logstash, and Kibana versions should match)

4. **Search Online Resources**:
   - [Elastic Stack Documentation](https://www.elastic.co/guide/index.html)
   - [Elastic Community Forums](https://discuss.elastic.co/)
   - Stack Overflow tags: [elasticsearch](https://stackoverflow.com/questions/tagged/elasticsearch), [logstash](https://stackoverflow.com/questions/tagged/logstash), [kibana](https://stackoverflow.com/questions/tagged/kibana)