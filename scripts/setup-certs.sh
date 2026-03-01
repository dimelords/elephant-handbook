#!/bin/bash

# Elephant - Certificate Setup Script
# Generates local development certificates using mkcert

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CERT_DIR="${HOME}/.config/mkcert"
CERT_FILE="$CERT_DIR/localhost.pem"
KEY_FILE="$CERT_DIR/localhost-key.pem"

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if mkcert is installed
if ! command -v mkcert &> /dev/null; then
    print_error "mkcert is not installed"
    echo
    echo "Please install mkcert:"
    echo "  macOS:  brew install mkcert"
    echo "  Linux:  See https://github.com/FiloSottile/mkcert#installation"
    echo
    exit 1
fi

# Create certs directory
mkdir -p "$CERT_DIR"

# Check if certificates already exist
if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
    print_info "Certificates already exist at:"
    print_info "  - $CERT_FILE"
    print_info "  - $KEY_FILE"
    
    # Check if they're still valid
    if openssl x509 -checkend 86400 -noout -in "$CERT_FILE" &> /dev/null; then
        print_info "Certificates are valid for at least 24 more hours"
        exit 0
    else
        print_warn "Certificates are expiring soon, regenerating..."
        rm -f "$CERT_FILE" "$KEY_FILE"
    fi
fi

# Install local CA if not already installed
print_info "Installing local CA..."
mkcert -install

# Generate certificates
print_info "Generating certificates for localhost..."
mkcert -cert-file "$CERT_FILE" -key-file "$KEY_FILE" localhost 127.0.0.1 ::1

print_info "✓ Certificates generated successfully!"
echo
echo "Certificate: $CERT_FILE"
echo "Private Key: $KEY_FILE"
echo
