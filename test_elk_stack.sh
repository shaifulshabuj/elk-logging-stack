#!/bin/bash

# Colors for output formatting
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Logstash port configuration - port 5001 maps to container port 5000
LOGSTASH_PORT=5001

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

wait_for_elasticsearch() {
    print_info "Waiting for Elasticsearch to be ready..."
    until curl -s http://localhost:9200/_cluster/health | grep -q '\"status\":\"green\"\|\"status\":\"yellow\"'; do
        echo -n "."
        sleep 2
    done
    echo ""
}

wait_for_kibana() {
    print_info "Waiting for Kibana to be ready..."
    until curl -s http://localhost:5601/api/status | grep -q '"state":"green"'; do
        echo -n "."
        sleep 2
    done
    echo ""
}

test_elasticsearch_health() {
    print_header "Testing Elasticsearch Health"
    
    # Check if Elasticsearch is running
    if curl -s http://localhost:9200 > /dev/null; then
        print_success "Elasticsearch is running"
        
        # Check cluster health
        health=$(curl -s http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        if [ "$health" == "green" ] || [ "$health" == "yellow" ]; then
            print_success "Elasticsearch cluster health is $health"
        else
            print_error "Elasticsearch cluster health is $health"
        fi
        
        # Check number of nodes
        nodes=$(curl -s http://localhost:9200/_cat/nodes | wc -l)
        print_info "Number of nodes: $nodes"
        
        # Check indices
        indices=$(curl -s http://localhost:9200/_cat/indices)
        if [ -n "$indices" ]; then
            print_success "Elasticsearch indices exist"
            echo "$indices"
        else
            print_error "No Elasticsearch indices found"
        fi
    else
        print_error "Elasticsearch is not running"
    fi
}

test_log_ingestion() {
    print_header "Testing Log Ingestion"
    
    # Test syslog ingestion
    print_info "Testing syslog ingestion..."
    echo "Apr 15 10:15:23 testhost sshd[1234]: Test syslog message from ELK test script" | nc localhost $LOGSTASH_PORT
    sleep 5
    
    # Test JSON log ingestion
    print_info "Testing JSON log ingestion..."
    echo '{"timestamp":"2025-04-15T10:15:23.456Z","level":"INFO","service":"test-service","message":"Test JSON message from ELK test script"}' | nc localhost $LOGSTASH_PORT
    sleep 5
    
    # Test Apache log ingestion
    print_info "Testing Apache log ingestion..."
    echo '192.168.1.20 - testuser [15/Apr/2025:10:15:23 +0000] "GET /test-page HTTP/1.1" 200 1234 "http://example.com/test" "ELK-Test-Agent"' | nc localhost $LOGSTASH_PORT
    sleep 5
    
    # Verify logs were ingested
    print_info "Verifying log ingestion..."
    count=$(curl -s "http://localhost:9200/_count?q=ELK+test+script" | grep -o '"count":[0-9]*' | cut -d':' -f2)
    if [ "$count" -gt 0 ]; then
        print_success "Successfully ingested $count test log entries"
    else
        print_error "Failed to ingest test logs"
    fi
}

test_log_parsing() {
    print_header "Testing Log Parsing"
    
    # Verify syslog parsing
    print_info "Testing syslog parsing..."
    syslog_query=$(curl -s "http://localhost:9200/_search?q=sshd+AND+testhost" -H 'Content-Type: application/json' | jq .)
    
    if echo "$syslog_query" | grep -q "testhost"; then
        print_success "Syslog parsing successful"
        echo "$syslog_query" | jq '.hits.hits[0]._source | {message, syslog_hostname, syslog_program, syslog_message}'
    else
        print_error "Syslog parsing failed"
    fi
    
    # Verify JSON parsing
    print_info "Testing JSON log parsing..."
    json_query=$(curl -s "http://localhost:9200/_search?q=test-service" -H 'Content-Type: application/json' | jq .)
    
    if echo "$json_query" | grep -q "test-service"; then
        print_success "JSON log parsing successful"
        echo "$json_query" | jq '.hits.hits[0]._source | {message, level, service, timestamp}'
    else
        print_error "JSON log parsing failed"
    fi
    
    # Verify Apache log parsing
    print_info "Testing Apache log parsing..."
    apache_query=$(curl -s "http://localhost:9200/_search?q=ELK-Test-Agent" -H 'Content-Type: application/json' | jq .)
    
    if echo "$apache_query" | grep -q "ELK-Test-Agent"; then
        print_success "Apache log parsing successful"
        echo "$apache_query" | jq '.hits.hits[0]._source | {clientip, request, response, agent}'
    else
        print_error "Apache log parsing failed"
    fi
}

test_search_functionality() {
    print_header "Testing Search Functionality"
    
    # Test basic search
    print_info "Testing basic full-text search..."
    search_result=$(curl -s "http://localhost:9200/_search?q=test" | jq '.hits.total.value')
    print_info "Search for 'test' returned $search_result results"
    
    # Test field-specific search
    print_info "Testing field-specific search..."
    field_search=$(curl -s -H 'Content-Type: application/json' -d '{
        "query": {
            "bool": {
                "must": [
                    { "match": { "level": "INFO" } }
                ]
            }
        }
    }' "http://localhost:9200/_search" | jq '.hits.total.value')
    print_info "Search for level:INFO returned $field_search results"
    
    # Test date range search
    print_info "Testing date range search..."
    date_search=$(curl -s -H 'Content-Type: application/json' -d '{
        "query": {
            "range": {
                "@timestamp": {
                    "gte": "now-1h",
                    "lte": "now"
                }
            }
        }
    }' "http://localhost:9200/_search" | jq '.hits.total.value')
    print_info "Search for logs from the last hour returned $date_search results"
    
    if [ "$search_result" -gt 0 ] && [ "$field_search" -gt 0 ] && [ "$date_search" -gt 0 ]; then
        print_success "Search functionality tests passed"
    else
        print_error "Not all search functionality tests passed"
    fi
}

test_kibana_dashboards() {
    print_header "Testing Kibana Dashboards"
    
    # Check if Kibana is running
    if curl -s http://localhost:5601 > /dev/null; then
        print_success "Kibana is running"
        
        # Check for index patterns
        index_patterns=$(curl -s "http://localhost:5601/api/saved_objects/_find?type=index-pattern&per_page=100" -H 'kbn-xsrf: true' | jq '.saved_objects | length')
        if [ "$index_patterns" -gt 0 ]; then
            print_success "Found $index_patterns index patterns"
        else
            print_error "No index patterns found"
        fi
        
        # Check for visualizations
        visualizations=$(curl -s "http://localhost:5601/api/saved_objects/_find?type=visualization&per_page=100" -H 'kbn-xsrf: true' | jq '.saved_objects | length')
        if [ "$visualizations" -gt 0 ]; then
            print_success "Found $visualizations visualizations"
        else
            print_error "No visualizations found"
        fi
        
        # Check for dashboards
        dashboards=$(curl -s "http://localhost:5601/api/saved_objects/_find?type=dashboard&per_page=100" -H 'kbn-xsrf: true' | jq '.saved_objects | length')
        if [ "$dashboards" -gt 0 ]; then
            print_success "Found $dashboards dashboards"
        else
            print_error "No dashboards found"
        fi
        
        # Check main dashboard
        main_dashboard=$(curl -s "http://localhost:5601/api/saved_objects/_find?type=dashboard&search=Logs%20Overview&per_page=100" -H 'kbn-xsrf: true' | jq -r '.saved_objects[0]?.id')
        if [ -n "$main_dashboard" ] && [ "$main_dashboard" != "null" ]; then
            print_success "Main dashboard 'Logs Overview' found"
            print_info "Dashboard ID: $main_dashboard"
            
            # Check dashboard panels
            dashboard_details=$(curl -s "http://localhost:5601/api/saved_objects/dashboard/$main_dashboard" -H 'kbn-xsrf: true')
            panel_count=$(echo "$dashboard_details" | jq -r '.attributes.panelsJSON' | jq 'length')
            if [ -n "$panel_count" ] && [ "$panel_count" -gt 0 ]; then
                print_success "Dashboard has $panel_count panels/visualizations"
            else
                print_error "Dashboard has no panels or visualizations"
            fi
        else
            print_error "Main dashboard 'Logs Overview' not found"
        fi
    else
        print_error "Kibana is not running"
    fi
}

verify_log_data_exists() {
    print_header "Verifying Log Data in Elasticsearch"
    
    # Check total document count
    doc_count=$(curl -s "http://localhost:9200/_count" | jq '.count')
    if [ "$doc_count" -gt 0 ]; then
        print_success "Elasticsearch contains $doc_count documents"
        return 0
    else
        print_error "No documents found in Elasticsearch"
        
        # If no documents, send some test logs to seed the system
        print_info "Sending test logs to seed the system..."
        
        # Send syslog
        for i in {1..5}; do
            echo "Apr 15 10:$i:23 testhost-$i sshd[$i]: Test syslog message $i from ELK test script" | nc localhost $LOGSTASH_PORT
        done
        
        # Send JSON logs
        for i in {1..5}; do
            level="INFO"
            if [ $((i % 2)) -eq 0 ]; then
                level="ERROR"
            fi
            echo "{\"timestamp\":\"2025-04-15T10:$i:23.456Z\",\"level\":\"$level\",\"service\":\"test-service-$i\",\"message\":\"Test JSON message $i from ELK test script\"}" | nc localhost $LOGSTASH_PORT
        done
        
        # Send Apache logs
        for i in {1..5}; do
            status=$((200 + i % 4 * 100))
            echo "192.168.1.$i - testuser-$i [15/Apr/2025:10:$i:23 +0000] \"GET /test-page-$i HTTP/1.1\" $status 123$i \"http://example.com/test\" \"ELK-Test-Agent/$i\"" | nc localhost $LOGSTASH_PORT
        done
        
        print_info "Waiting for logs to be processed (15 seconds)..."
        sleep 15
        
        # Check count again
        doc_count=$(curl -s "http://localhost:9200/_count" | jq '.count')
        if [ "$doc_count" -gt 0 ]; then
            print_success "Successfully seeded Elasticsearch with $doc_count documents"
            return 0
        else
            print_error "Failed to seed Elasticsearch with test data"
            return 1
        fi
    fi
}

run_all_tests() {
    print_header "STARTING ELK STACK TESTING"
    
    # Wait for services to be ready
    wait_for_elasticsearch
    wait_for_kibana
    
    # Run all tests
    test_elasticsearch_health
    
    if verify_log_data_exists; then
        test_log_ingestion
        test_log_parsing
        test_search_functionality
        test_kibana_dashboards
        
        print_header "ELK STACK TESTING COMPLETE"
    else
        print_header "TESTING HALTED - NO LOG DATA AVAILABLE"
    fi
}

# Check for dependencies
if ! command -v jq &> /dev/null; then
    print_error "jq is required but not installed. Please install jq first."
    print_info "On macOS: brew install jq"
    print_info "On Ubuntu/Debian: apt-get install jq"
    exit 1
fi

# Check if ELK stack is running
if ! curl -s http://localhost:9200 > /dev/null; then
    print_error "Elasticsearch is not running. Starting ELK stack..."
    ./restart_elk.sh
    sleep 10
fi

# Print port configuration
print_info "Using Logstash input port: $LOGSTASH_PORT"

# Run all tests
run_all_tests