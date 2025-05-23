# Removing Legacy Kubernetes Service Account Tokens

This document describes a set of scripts designed to help remove legacy auto-generated service account tokens in Kubernetes clusters. These tokens are often found in the `secrets` field of `ServiceAccount` objects and as separate `Secret` objects.

## Scripts Overview

There are two main scripts:

1.  `remove-sa-and-secrets.sh`: Operates on a single Kubernetes cluster to patch specific service accounts and delete their associated secrets.
2.  `run-on-clusters.sh`: A wrapper script to execute `remove-sa-and-secrets.sh` across multiple Kubernetes clusters.

## `remove-sa-and-secrets.sh`

This script performs the following actions on a targeted Kubernetes cluster:

1.  **Identifies Service Accounts:** It looks for service accounts that have a `secrets` field populated.
2.  **Targets Specific Service Accounts:** By default, it targets service accounts named `default` and `cbdp`.
3.  **Patches Service Accounts:** For the targeted service accounts, it removes the `secrets` field by patching the `ServiceAccount` object. This prevents new pods from automatically mounting these legacy tokens.
4.  **Deletes Secret Objects:** It then deletes the corresponding `Secret` objects that were associated with these service accounts.

### Prerequisites for `remove-sa-and-secrets.sh`

*   **`kubectl`:** Must be installed and configured to communicate with your Kubernetes cluster.
*   **`yq`:** Must be installed. `yq` is a command-line YAML processor, used by this script to parse YAML output from `kubectl`.
*   **Cluster Access:** You need appropriate permissions to `get`, `patch` service accounts and `get`, `delete` secrets in the relevant namespaces.

### Command-line Arguments for `remove-sa-and-secrets.sh`

*   `--dry-run`: (Optional) If provided, the script will print the actions it *would* take without actually making any changes to the cluster. This is highly recommended for a preliminary check.
*   `--cluster=<CLUSTER_CONTEXT_NAME>`: (Optional) Specifies the `kubectl` context to use for operations. If not provided, it uses the current default context.

## `run-on-clusters.sh`

This script facilitates running `remove-sa-and-secrets.sh` on a list of Kubernetes clusters.

### Functionality of `run-on-clusters.sh`

1.  **Reads Cluster List:** It reads a list of cluster context names from a specified file (default: `cluster-list.txt`).
2.  **Iterates and Executes:** For each cluster in the list, it:
    *   Checks if the `kubectl` context exists.
    *   Executes `remove-sa-and-secrets.sh` targeting that cluster.
3.  **Reports Summary:** Provides a summary of successfully processed, failed, and skipped clusters.

### Prerequisites for `run-on-clusters.sh`

*   `remove-sa-and-secrets.sh`: This script must be present in the same directory as `run-on-clusters.sh` and must be executable (`chmod +x remove-sa-and-secrets.sh`).
*   **Cluster List File:** A text file containing one Kubernetes context name per line.

### Command-line Arguments for `run-on-clusters.sh`

*   `--dry-run`: (Optional) If provided, this flag is passed down to `remove-sa-and-secrets.sh` for each cluster, meaning no actual changes will be made.
*   `--cluster-list=<FILE_PATH>`: (Optional) Specifies the path to the file containing the list of cluster names. Defaults to `cluster-list.txt` in the current directory.

## Usage Instructions

1.  **Obtain the Scripts:**
    *   Clone the repository containing these scripts or download `remove-sa-and-secrets.sh` and `run-on-clusters.sh` into the same directory.

2.  **Ensure Prerequisites:**
    *   Install `kubectl` and `yq`.
    *   Make `remove-sa-and-secrets.sh` executable: `chmod +x remove-sa-and-secrets.sh`.

3.  **Prepare Cluster List (for `run-on-clusters.sh`):**
    *   Create a file named `cluster-list.txt` (or a custom name if using `--cluster-list`).
    *   Add the `kubectl` context name of each target cluster, one per line. Example:
        ```
        cluster-prod-us-east-1
        cluster-dev-europe-west-2
        # This is a comment and will be skipped
        cluster-staging-asia-south-1
        ```

4.  **Perform a Dry Run (Recommended):**
    *   **For a single cluster:**
        ```bash
        ./remove-sa-and-secrets.sh --dry-run --cluster=<YOUR_CLUSTER_CONTEXT>
        ```
    *   **For multiple clusters:**
        ```bash
        ./run-on-clusters.sh --dry-run --cluster-list=my-clusters.txt
        ```
    *   Review the output carefully to ensure the script identifies the correct service accounts and secrets for modification/deletion.

5.  **Execute the Scripts:**
    *   Once you are confident with the dry run output:
    *   **For a single cluster:**
        ```bash
        ./remove-sa-and-secrets.sh --cluster=<YOUR_CLUSTER_CONTEXT>
        ```
    *   **For multiple clusters:**
        ```bash
        ./run-on-clusters.sh --cluster-list=my-clusters.txt
        ```

## Important Notes and Warnings

*   **Impact:** These scripts make changes to `ServiceAccount` configurations and delete `Secret` objects. While targeted at legacy tokens, ensure you understand the potential impact.
*   **Backup:** Before running these scripts in a production environment, ensure you have appropriate backups or a way to revert changes if necessary.
*   **Permissions:** The `kubectl` context used must have sufficient permissions to patch service accounts and delete secrets across all relevant namespaces.
*   **`TARGET_SERVICE_ACCOUNTS`:** The `remove-sa-and-secrets.sh` script has a variable `TARGET_SERVICE_ACCOUNTS` (currently `("default" "cbdp")`). If you need to target different service accounts, you will need to modify this variable within the script.
*   **Non-default Namespaces:** The script processes service accounts across all namespaces (`-A` flag in `kubectl get serviceaccounts`).
*   **Idempotency:**
    *   Patching the service account to set `{"secrets": null}` is idempotent.
    *   Deleting a secret is not idempotent; if the secret is already deleted, the script will note that it was not found. The script attempts to get the secret before deleting.
*   **Review Scripts:** It is always a good practice to review the script content before execution to understand its operations fully.
