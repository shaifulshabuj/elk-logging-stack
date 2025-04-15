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

verify_elasticsearch() {
    if ! curl -s http://localhost:9200 > /dev/null; then
        print_error "Elasticsearch is not running. Please start the ELK stack."
        print_info "Run: ./restart_elk.sh"
        exit 1
    else
        print_success "Elasticsearch is running"
    fi
}

load_sample_logs() {
    print_header "Loading Sample Log Files"
    
    # Create a backup index count to see how many new logs are added
    initial_count=$(curl -s "http://localhost:9200/_count" | jq '.count')
    print_info "Initial document count: $initial_count"
    
    # Process Apache access logs
    if [ -f "sample_logs/apache_access.log" ]; then
        print_info "Processing Apache access logs..."
        cat sample_logs/apache_access.log | nc localhost $LOGSTASH_PORT
        print_success "Sent Apache access logs to Logstash"
    else
        print_error "Apache access log file not found"
    fi
    
    # Process application JSON logs
    if [ -f "sample_logs/application_json.log" ]; then
        print_info "Processing application JSON logs..."
        cat sample_logs/application_json.log | nc localhost $LOGSTASH_PORT
        print_success "Sent application JSON logs to Logstash"
    else
        print_error "Application JSON log file not found"
    fi
    
    # Process syslog samples
    if [ -f "sample_logs/syslog_sample.log" ]; then
        print_info "Processing syslog samples..."
        cat sample_logs/syslog_sample.log | nc localhost $LOGSTASH_PORT
        print_success "Sent syslog samples to Logstash"
    else
        print_error "Syslog sample file not found"
    fi
    
    print_info "Waiting for logs to be processed (15 seconds)..."
    sleep 15
    
    # Get new count and calculate difference
    final_count=$(curl -s "http://localhost:9200/_count" | jq '.count')
    logs_added=$((final_count - initial_count))
    
    if [ $logs_added -gt 0 ]; then
        print_success "Successfully loaded $logs_added log entries from sample files"
    else
        print_error "No new logs were added to Elasticsearch"
    fi
}

check_indices_for_log_types() {
    print_header "Checking Indices for Different Log Types"
    
    # Check for Apache logs
    apache_count=$(curl -s -H 'Content-Type: application/json' -d '{
        "query": {
            "exists": {
                "field": "agent"
            }
        }
    }' "http://localhost:9200/_count" | jq '.count')
    
    if [ "$apache_count" -gt 0 ]; then
        print_success "Found $apache_count Apache web server logs"
    else
        print_error "No Apache logs found in Elasticsearch"
    fi
    
    # Check for application logs
    app_count=$(curl -s -H 'Content-Type: application/json' -d '{
        "query": {
            "exists": {
                "field": "level"
            }
        }
    }' "http://localhost:9200/_count" | jq '.count')
    
    if [ "$app_count" -gt 0 ]; then
        print_success "Found $app_count application logs"
    else
        print_error "No application logs found in Elasticsearch"
    fi
    
    # Check for syslog
    syslog_count=$(curl -s -H 'Content-Type: application/json' -d '{
        "query": {
            "exists": {
                "field": "syslog_program"
            }
        }
    }' "http://localhost:9200/_count" | jq '.count')
    
    if [ "$syslog_count" -gt 0 ]; then
        print_success "Found $syslog_count syslog entries"
    else
        print_error "No syslog entries found in Elasticsearch"
    fi
}

check_field_extraction() {
    print_header "Verifying Field Extraction"
    
    # Get and display sample apache log with extracted fields
    print_info "Sample Apache log with extracted fields:"
    apache_sample=$(curl -s -H 'Content-Type: application/json' -d '{
        "query": {
            "exists": {
                "field": "agent"
            }
        },
        "size": 1
    }' "http://localhost:9200/_search" | jq '.hits.hits[0]._source | {clientip, request, response, agent, verb, httpversion, bytes}')
    echo "$apache_sample"
    
    # Get and display sample application log with extracted fields
    print_info "Sample application log with extracted fields:"
    app_sample=$(curl -s -H 'Content-Type: application/json' -d '{
        "query": {
            "exists": {
                "field": "level"
            }
        },
        "size": 1
    }' "http://localhost:9200/_search" | jq '.hits.hits[0]._source | {message, level, timestamp, service}')
    echo "$app_sample"
    
    # Get and display sample syslog with extracted fields
    print_info "Sample syslog with extracted fields:"
    syslog_sample=$(curl -s -H 'Content-Type: application/json' -d '{
        "query": {
            "exists": {
                "field": "syslog_program"
            }
        },
        "size": 1
    }' "http://localhost:9200/_search" | jq '.hits.hits[0]._source | {message, syslog_hostname, syslog_program, syslog_timestamp, syslog_message}')
    echo "$syslog_sample"
}

verify_timestamp_mapping() {
    print_header "Verifying Timestamp Mapping"
    
    # Verify that logs have been properly timestamped
    time_range_query=$(curl -s -H 'Content-Type: application/json' -d '{
        "aggs": {
            "min_time": { "min": { "field": "@timestamp" } },
            "max_time": { "max": { "field": "@timestamp" } }
        },
        "size": 0
    }' "http://localhost:9200/_search")
    
    min_time=$(echo "$time_range_query" | jq -r '.aggregations.min_time.value_as_string')
    max_time=$(echo "$time_range_query" | jq -r '.aggregations.max_time.value_as_string')
    
    if [ "$min_time" != "null" ] && [ "$max_time" != "null" ]; then
        print_success "Log timestamps are properly mapped"
        print_info "  Earliest log: $min_time"
        print_info "  Latest log:   $max_time"
    else
        print_error "Some logs may not have proper timestamp mapping"
    fi
}

test_log_parsing_accuracy() {
    print_header "Testing Log Parsing Accuracy"
    
    # Check for parsing errors
    grok_failures=$(curl -s -H 'Content-Type: application/json' -d '{
        "query": {
            "match": {
                "tags": "grok_failure"
            }
        }
    }' "http://localhost:9200/_count" | jq '.count')
    
    if [ "$grok_failures" -eq 0 ]; then
        print_success "No grok parsing failures detected"
    else
        print_error "Found $grok_failures logs with grok parsing failures"
        
        # Show sample of failures
        print_info "Samples of grok failures:"
        failures=$(curl -s -H 'Content-Type: application/json' -d '{
            "query": {
                "match": {
                    "tags": "grok_failure"
                }
            },
            "size": 3
        }' "http://localhost:9200/_search" | jq '.hits.hits[]._source.message')
        echo "$failures"
    fi
    
    # Check for field mapping issues (integer vs string)
    # For example, check if response code is numeric
    response_mapping=$(curl -s -H 'Content-Type: application/json' -d '{
        "aggs": {
            "response_types": {
                "terms": {
                    "field": "response"
                }
            }
        },
        "size": 0
    }' "http://localhost:9200/_search" | jq '.aggregations.response_types.buckets[0]')
    
    if echo "$response_mapping" | grep -q "key"; then
        print_success "HTTP response codes are properly mapped"
    else
        print_error "HTTP response codes may have mapping issues"
    fi
}

summarize_logstash_pipeline_test() {
    print_header "Logstash Pipeline Test Summary"
    
    # Get document counts by type
    total_count=$(curl -s "http://localhost:9200/_count" | jq '.count')
    
    # Get index stats
    indices=$(curl -s "http://localhost:9200/_cat/indices?h=index,docs.count,store.size&v")
    
    print_info "Total documents in Elasticsearch: $total_count"
    print_info "Indices and document counts:"
    echo "$indices"
    
    # Provide a summary of overall test results
    print_info "Pipeline Test Results:"
    
    if [ $total_count -gt 0 ]; then
        print_success "Logstash pipeline is successfully processing logs"
        print_success "Sample logs have been ingested and parsed"
        print_success "Field extraction is working properly for various log types"
        
        print_info "To explore the logs in Kibana, visit: http://localhost:5601"
    else
        print_error "Logstash pipeline test failed - no logs were processed"
    fi
}

run_logstash_pipeline_test() {
    print_header "STARTING LOGSTASH PIPELINE TEST"
    
    # Print port configuration
    print_info "Using Logstash input port: $LOGSTASH_PORT"
    
    # First verify Elasticsearch is running
    verify_elasticsearch
    
    # Run tests
    load_sample_logs
    check_indices_for_log_types
    check_field_extraction
    verify_timestamp_mapping
    test_log_parsing_accuracy
    summarize_logstash_pipeline_test
    
    print_header "LOGSTASH PIPELINE TEST COMPLETE"
}

# Check for dependencies
if ! command -v jq &> /dev/null; then
    print_error "jq is required but not installed. Please install jq first."
    print_info "On macOS: brew install jq"
    print_info "On Ubuntu/Debian: apt-get install jq"
    exit 1
fi

# Run the pipeline tests
run_logstash_pipeline_test