#!/usr/bin/env sh

# Exit on error
set -e

. "$(dirname "$0")/load_dotenv.sh"

SCRIPT_PATH="$0"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
STACK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TRAEFIK_DIR="$(cd "$STACK_DIR/.." && pwd)/traefik"
TRAEFIK_NETWORK_NAME="traefik-public"
log() {
    level="$1"
    shift
    echo "[$level] $*" >&2
}

generate_password() {
    length=$1
    char_set="A-Za-z0-9!@#$%^&*()-_=+[]{}|;:,.<>?"
    tr -dc "$char_set" </dev/urandom | head -c "$length"
    echo
}

setup_traefik() {
    create_traefik_network_if_needed
    
    log INFO "Setting up Traefik reverse proxy in $TRAEFIK_DIR"
    mkdir -p "$TRAEFIK_DIR"
    ln -sf "$STACK_DIR/docker-compose.traefik.yml" "$TRAEFIK_DIR/docker-compose.yml"
    touch "$TRAEFIK_DIR/.env"

    PASSWORD=$(generate_password 15)
    log INFO "Generated Traefik dashboard password: $PASSWORD"

    HASHED_PASSWORD=$(openssl passwd -apr1 "$PASSWORD")

    cat > "$TRAEFIK_DIR/.env" <<EOF
USERNAME=admin
HASHED_PASSWORD='$HASHED_PASSWORD'
DOMAIN=$GITLAB_DOMAIN
EMAIL=admin@$GITLAB_DOMAIN
ALLOWED_IPS=
EOF

    log INFO "Traefik .env file created at $TRAEFIK_DIR/.env"
}


is_traefik_ready() {
    dashboard_url="http://traefik.${GITLAB_DOMAIN}"
    TRAEFIK_DASHBOARD_DOMAIN="traefik.${GITLAB_DOMAIN}"
    log INFO "Waiting for Traefik dashboard at $dashboard_url..."

    HTTP_TIMEOUT_S=5

    status_code=$(curl -sk -o /dev/null -w "%{http_code}" "$dashboard_url" -m "$HTTP_TIMEOUT_S" --connect-to "$TRAEFIK_DASHBOARD_DOMAIN:80:127.0.0.1:80" || echo "timeout")

    if [ "$status_code" = "200" ] || [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
        log INFO "Traefik dashboard is up (HTTP $status_code)."
        return
    fi

    log ERROR "Traefik dashboard did not become ready in time. HTTP response code $status_code"
    exit 1
}

create_traefik_network_if_needed() {
    log INFO "Checking if the Traefik network exists..."
    
    if ! sudo docker network ls | grep -q "$TRAEFIK_NETWORK_NAME"; then
        log INFO "Creating Traefik network..."
        sudo docker network create "$TRAEFIK_NETWORK_NAME"
        log INFO "Created network $TRAEFIK_NETWORK_NAME"
    else
        log INFO "Traefik network already exists."
    fi
}


main() {
    load_dotenv

    log INFO "Initializing environment..."

    setup_traefik

    log INFO "Starting Traefik..."
    (cd "$TRAEFIK_DIR" && sudo docker compose up -d)
    is_traefik_ready

    log INFO "Initialization complete."
}

main
