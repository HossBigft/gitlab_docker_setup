#!/usr/bin/env sh

# Exit in case of error
set -e

SCRIPT_PATH="$0"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/.env}"

load_dotenv() {
    if [ ! -f "$ENV_FILE" ]; then
        echo "Error: $ENV_FILE not found" >&2
        exit 1
    fi

    while IFS='=' read -r key value || [ -n "$key" ]; do
        # Trim whitespace
        key="$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        value="$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

        case "$key" in
            ''|\#*) continue ;;
        esac

        eval "export $key=\$value"

        if [ "$DEBUG" = "1" ]; then
            echo "[dotenv] Loaded $key=$value"
        fi
    done < "$ENV_FILE"
}

# Enable with DEBUG=1 load_dotenv
load_dotenv