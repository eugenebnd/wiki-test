#!/bin/bash

# 1. Remove secrets field from default and cbdp service accounts
# 2. Delete the associated Kubernetes secret objects

# Define color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse command line arguments
DRY_RUN=false
CLUSTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --cluster=*)
      CLUSTER="${1#*=}"
      shift
      ;;
    --cluster)
      if [[ -n "$2" && "$2" != --* ]]; then
        CLUSTER="$2"
        shift 2
      else
        echo "Error: Missing value for --cluster parameter"
        exit 1
      fi
      ;;
    *)
      echo "Unknown parameter: $1"
      echo "Usage: $0 [--dry-run] [--cluster=CLUSTER_NAME]"
      exit 1
      ;;
  esac
done

# Set up kubectl cluster context if provided
KUBECTL_CMD="kubectl"
if [[ -n "$CLUSTER" ]]; then
  KUBECTL_CMD="kubectl --context=$CLUSTER"
  echo "Using cluster context: $CLUSTER"
fi

if $DRY_RUN; then
  echo -e "${YELLOW}DRY RUN MODE: No changes will be applied${NC}"
fi

echo "Starting to process service accounts and their secrets..."

# Counters for tracking progress
sa_patched_count=0
secrets_removed_count=0

# Define which service accounts to process
# TARGET_SERVICE_ACCOUNTS=("default" "cbdp", "grafana")
TARGET_SERVICE_ACCOUNTS=("default" "cbdp")

while read -r line; do
  namespace=$(echo "$line" | awk '{print $1}')
  name=$(echo "$line" | awk '{print $2}')
  secret=$(echo "$line" | awk '{print $3}')

  echo "Found ServiceAccount: $name in namespace: $namespace with secret: $secret"

  # Check if the service account is in our target list
  if [[ " ${TARGET_SERVICE_ACCOUNTS[@]} " =~ " ${name} " ]]; then
    echo "Removing secrets field from $name service account in namespace $namespace..."
    if $DRY_RUN; then
      echo -e "  ${YELLOW}DRY RUN:${NC} Would patch serviceaccount $name -n \"$namespace\" -p '{\"secrets\": null}'"
      ((sa_patched_count++))
    else
      if $KUBECTL_CMD patch serviceaccount "$name" -n "$namespace" -p '{"secrets": null}'; then
        echo -e "  ${GREEN}SUCCESS:${NC} Secrets field removed from $name service account in $namespace"
        ((sa_patched_count++))
      else
        echo "  FAILED: Could not remove secrets field from $name service account in $namespace"
      fi
    fi

    # Delete the Kubernetes secret object
    echo "Removing secret object $secret from namespace $namespace..."
    if $DRY_RUN; then
      if $KUBECTL_CMD get secret "$secret" -n "$namespace" &>/dev/null; then
        echo -e "  ${YELLOW}DRY RUN:${NC} Would delete secret \"$secret\" from namespace \"$namespace\""
        ((secrets_removed_count++))
      else
        echo "  ${YELLOW}DRY RUN NOTE:${NC} Secret object $secret not found in namespace $namespace, it might have been removed already"
      fi
    else
      if $KUBECTL_CMD get secret "$secret" -n "$namespace" &>/dev/null; then
        if $KUBECTL_CMD delete secret "$secret" -n "$namespace"; then
          echo -e "  ${GREEN}SUCCESS:${NC} Secret object $secret removed from namespace $namespace"
          ((secrets_removed_count++))
        else
          echo "  FAILED: Could not remove secret object $secret from namespace $namespace"
        fi
      else
        echo "  NOTE: Secret object $secret not found in namespace $namespace, it might have been removed already"
      fi
    fi
  fi

  echo "------------------------------------------------"
done < <($KUBECTL_CMD get serviceaccounts -A -o yaml | yq '.items[] | select(.secrets != null and .secrets | length > 0) | .metadata.namespace + " " + .metadata.name + " " + .secrets[0].name')

echo "Summary:"
if $DRY_RUN; then
  echo -e "${YELLOW}DRY RUN SUMMARY:${NC}"
  echo "- Would patch $sa_patched_count service accounts (default and cbdp)"
  echo "- Would remove $secrets_removed_count Kubernetes secret objects"
else
  echo "- Patched $sa_patched_count service accounts (default and cbdp)"
  echo "- Removed $secrets_removed_count Kubernetes secret objects"
fi
echo "Completed."