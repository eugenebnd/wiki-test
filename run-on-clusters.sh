
#!/bin/bash

# Script to execute remove-sa-and-secrets.sh on multiple clusters from a list
# Usage: ./run-on-clusters.sh [--dry-run] [--cluster-list=FILE_PATH]

# Define color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default values
DRY_RUN=false
CLUSTER_LIST="cluster-list.txt"
SCRIPT_PATH="$(dirname "$0")/remove-sa-and-secrets.sh"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --cluster-list=*)
      CLUSTER_LIST="${1#*=}"
      shift
      ;;
    --cluster-list)
      if [[ -n "$2" && "$2" != --* ]]; then
        CLUSTER_LIST="$2"
        shift 2
      else
        echo -e "${RED}Error: Missing value for --cluster-list parameter${NC}"
        exit 1
      fi
      ;;
    *)
      echo -e "${RED}Unknown parameter: $1${NC}"
      echo "Usage: $0 [--dry-run] [--cluster-list=FILE_PATH]"
      exit 1
      ;;
  esac
done

# Check if the script exists
if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo -e "${RED}Error: Script not found at $SCRIPT_PATH${NC}"
  exit 1
fi

# Check if the cluster list exists
if [[ ! -f "$CLUSTER_LIST" ]]; then
  echo -e "${RED}Error: Cluster list file not found at $CLUSTER_LIST${NC}"
  echo "Please create a file with one cluster name per line"
  exit 1
fi

# Check that the script is executable
if [[ ! -x "$SCRIPT_PATH" ]]; then
  echo -e "${YELLOW}Warning: Making script executable: $SCRIPT_PATH${NC}"
  chmod +x "$SCRIPT_PATH"
fi

# Print header and settings
echo -e "${BLUE}${BOLD}=== Kubernetes Legacy Token Removal - Multi-Cluster Execution ===${NC}"
echo -e "${BOLD}Script:${NC} $SCRIPT_PATH"
echo -e "${BOLD}Cluster list:${NC} $CLUSTER_LIST"
if $DRY_RUN; then
  echo -e "${YELLOW}DRY RUN MODE: No changes will be applied${NC}"
fi
echo

# Count the clusters
TOTAL_CLUSTERS=$(grep -v '^\s*#\|^\s*$' "$CLUSTER_LIST" | wc -l)
echo -e "${BOLD}Total clusters to process:${NC} $TOTAL_CLUSTERS"
echo

# Initialize counters
SUCCESSFUL_CLUSTERS=0
FAILED_CLUSTERS=0
SKIPPED_CLUSTERS=0

# Process each cluster
COUNTER=0
while IFS= read -r line || [[ -n "$line" ]]; do
  # Skip comments and empty lines
  if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// /}" ]]; then
    continue
  fi

  CLUSTER=$(echo "$line" | tr -d '[:space:]')
  ((COUNTER++))

  echo -e "${BLUE}${BOLD}[${COUNTER}/${TOTAL_CLUSTERS}] Processing cluster: ${CLUSTER}${NC}"

  # Check if the cluster context exists
  if ! kubectl config get-contexts "$CLUSTER" &>/dev/null; then
    echo -e "${YELLOW}WARNING: Cluster context '$CLUSTER' not found. Skipping...${NC}"
    ((SKIPPED_CLUSTERS++))
    echo -e "${BOLD}------------------------------------------------------------${NC}\n"
    continue
  fi

  # Execute the script for this cluster
  DRY_RUN_ARG=""
  if $DRY_RUN; then
    DRY_RUN_ARG="--dry-run"
  fi

  echo -e "${BOLD}Executing: $SCRIPT_PATH $DRY_RUN_ARG --cluster=$CLUSTER${NC}"
  if "$SCRIPT_PATH" $DRY_RUN_ARG --cluster="$CLUSTER"; then
    echo -e "${GREEN}Successfully processed cluster: $CLUSTER${NC}"
    ((SUCCESSFUL_CLUSTERS++))
  else
    echo -e "${RED}Failed to process cluster: $CLUSTER${NC}"
    ((FAILED_CLUSTERS++))
  fi

  echo -e "${BOLD}------------------------------------------------------------${NC}\n"
done < "$CLUSTER_LIST"

# Print summary
echo -e "${BLUE}${BOLD}=== Summary ===${NC}"
echo -e "${BOLD}Total clusters:${NC} $TOTAL_CLUSTERS"
echo -e "${GREEN}Successfully processed:${NC} $SUCCESSFUL_CLUSTERS"
echo -e "${RED}Failed:${NC} $FAILED_CLUSTERS"
echo -e "${YELLOW}Skipped:${NC} $SKIPPED_CLUSTERS"

if $DRY_RUN; then
  echo -e "\n${YELLOW}This was a dry run. No actual changes were made.${NC}"
  echo -e "To apply changes, run the script without the --dry-run flag."
fi

echo -e "\n${BLUE}${BOLD}=== Completed ====${NC}"

# Exit with non-zero if any failures
if [[ $FAILED_CLUSTERS -gt 0 ]]; then
  exit 1
fi

exit 0