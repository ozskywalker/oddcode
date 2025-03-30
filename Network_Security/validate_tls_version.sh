#!/bin/bash

# Usage message
usage() {
  echo "Usage: $0 <IP/FQDN> [TLS version (1.0, 1.1, 1.2, 1.3)] [--port <port number>]"
  echo "Example: $0 example.com 1.2 --port 3000"
  exit 1
}

# Function to validate IP or FQDN
validate_ip_fqdn() {
  local ip_fqdn=$1
  if [[ $ip_fqdn =~ ^([a-zA-Z0-9][-a-zA-Z0-9]*\.)+[a-zA-Z]{2,}$ || $ip_fqdn =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    return 0
  else
    return 1
  fi
}

# Function to validate TLS version
validate_tls_version() {
  local tls_version=$1
  case $tls_version in
    1.0|1.1|1.2|1.3)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Function to validate port number
validate_port() {
  local port=$1
  if [[ $port =~ ^[0-9]+$ && $port -ge 1 && $port -le 65535 ]]; then
    return 0
  else
    return 1
  fi
}

# Check if at least 1 argument is provided
if [ $# -lt 1 ]; then
  echo "Error: Missing arguments."
  usage
fi

# Validate IP/FQDN
if ! validate_ip_fqdn "$1"; then
  echo "Error: Invalid IP or FQDN."
  usage
fi

# Set default TLS version to 1.2 if not specified
tls_version="1.2"

# Check if TLS version is provided
if [ $# -ge 2 ] && [[ $2 != "--port" ]]; then
  if validate_tls_version "$2"; then
    tls_version="$2"
  else
    echo "Error: Invalid TLS version. Valid versions are 1.0, 1.1, 1.2, 1.3."
    usage
  fi
fi

# Default port to 443 if not provided
port=443

# Handle optional --port argument
if [ $# -ge 3 ] && [ "$3" == "--port" ]; then
  if validate_port "$4"; then
    port=$4
  else
    echo "Error: Invalid port number. Port must be an integer between 1 and 65535."
    usage
  fi
elif [ $# -ge 3 ] && [ "$3" != "--port" ]; then
  echo "Error: Too many or invalid arguments."
  usage
fi

# Execute curl command with validated inputs
echo "Running curl with IP/FQDN: $1, TLS Version: $tls_version, Port: $port"
curl -k -I -v --tlsv"$tls_version" --tls-max "$tls_version" https://"$1":"$port"
