#!/bin/bash

# Configuration module
# Handles loading, parsing, and validating configuration

# Load configuration from YAML file
load_config() {
    if [ ! -f "config.yaml" ]; then
        error "config.yaml not found"
        exit 1
    fi
    eval $(parse_yaml config.yaml)
    validate_config
}

# Parse YAML file into shell variables
parse_yaml() {
    local prefix=$2
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
    sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
    awk -F$fs '{
        indent = length($1)/2;
        vname[indent] = $2;
        for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
        }
    }'
}

# Validate configuration values
validate_config() {
    info "Validating configuration..."

    # Check required fields
    local required_fields=(
        "namespace"
        "services.world-simulator.name"
        "services.world-simulator.port"
        "services.base-tower.name"
        "services.base-tower.port"
        "services.postgres.name"
        "services.postgres.port"
        "services.triangle.name"
        "services.triangle.port"
        "kubernetes.ingress.host"
        "kubernetes.ingress.class"
    )

    for field in "${required_fields[@]}"; do
        if [ -z "${!field}" ]; then
            error "Missing required configuration field: $field"
            exit 1
        fi
    done

    # Validate port numbers
    for service in world-simulator base-tower postgres triangle; do
        local port_var="services_${service}_port"
        if ! [[ "${!port_var}" =~ ^[0-9]+$ ]] || [ "${!port_var}" -lt 1 ] || [ "${!port_var}" -gt 65535 ]; then
            error "Invalid port number for $service: ${!port_var}"
            exit 1
        fi
    done

    # Validate URLs
    for env in development production; do
        local api_url_var="services_world_simulator_${env}_api_url"
        if [ -n "${!api_url_var}" ] && ! [[ "${!api_url_var}" =~ ^https?:// ]]; then
            error "Invalid API URL for $env: ${!api_url_var}"
            exit 1
        fi
    done

    info "Configuration validation passed"
}
