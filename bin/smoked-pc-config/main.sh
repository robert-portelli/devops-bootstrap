#!/usr/bin/env bash
#exec > >(tee -a smoked-pc-config.log) 2>&1 # if you want logs also in separate file

LOG_LEVEL="INFO"  # Default log level
LOG_TO_CONSOLE=false  # Default: don't log to console

# Define log levels
declare -A LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
    [WARNING]=2
    [ERROR]=3
)

# Parse arguments to set log level and log-to-console option
parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --log-level)
                shift
                if [[ -n "$1" ]] && [[ "${LOG_LEVELS[$1]}" ]]; then
                    LOG_LEVEL="$1"
                else
                    echo "Invalid log level: $1. Valid options are: DEBUG, INFO, WARNING, ERROR."
                    exit 1
                fi
                ;;
            --log-to-console)
                LOG_TO_CONSOLE=true
                ;;
            --help|-h)
                echo "Usage: $0 [--log-level {DEBUG|INFO|WARNING|ERROR}] [--log-to-console]"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Usage: $0 [--log-level {DEBUG|INFO|WARNING|ERROR}] [--log-to-console]"
                exit 1
                ;;
        esac
        shift
    done
}

# Log message function
lm() {
    local level=$1
    local message=$2

    if (( LOG_LEVELS[$level] >= LOG_LEVELS[$LOG_LEVEL] )); then
        logger -t "smoked-pc-config-$level" "$message"
        if [[ "$LOG_TO_CONSOLE" == true ]]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
        fi
    fi
}

declare -A repo_matches  # Declare an associative array

get_smoked_config_paths() {
    local paths
    paths=$(git ls-files | grep '\.ST-pre-commit-config\.yaml$') || { echo "No .ST-pre-commit-config.yaml files found!"; exit 1; }
    echo "$paths"
}

check_for_matches() {
    local paths="$1"
    local repo_lines="$2"

    while IFS= read -r repo_line; do
        repo_matches["$repo_line"]="none,0"  # Default value: "no path, 0 matches"
        local all_paths=()  # Array to store all matching paths
        local total_count=0  # Counter for total matches

        while IFS= read -r path; do
            match_count=$(grep -cF "$repo_line" "$path")  # Count matches in the file
            if (( match_count > 0 )); then
                all_paths+=("$path")  # Add the path to the array
                total_count=$((total_count + match_count))  # Increment the total count
            fi
        done <<< "$paths"

        if (( total_count > 0 )); then
            # Join all paths with spaces and store in the associative array
            local joined_paths
            joined_paths=$(IFS=' '; echo "${all_paths[*]}")
            repo_matches["$repo_line"]="$joined_paths,$total_count"
        fi
    done <<< "$repo_lines"

    # Print the results
    lm "DEBUG" "Results:"
    for key in "${!repo_matches[@]}"; do
        IFS=',' read -r paths count <<< "${repo_matches[$key]}"
        lm "DEBUG" "Key: $key"
        lm "DEBUG" "  Paths: $paths"
        lm "DEBUG" "  Match Count: $count"
        lm "DEBUG" "***************************************"
    done
}

validate_matches() {
    lm "INFO" "Validating matches..."

    for key in "${!repo_matches[@]}"; do
        IFS=',' read -r paths count <<< "${repo_matches[$key]}"

        if (( count == 0 )); then
            lm "ERROR" "❌ Missing repo: $key (No matches found)"
        elif (( count > 1 )); then
            lm "WARNING" "⚠️  Multiple matches for repo: $key"
            lm "DEBUG" "Paths with multiple matches: $paths"
        else
            lm "INFO" "✅ Exactly one match for repo: $key (Path: $paths)"
        fi
    done
}

compare_repo_chunks() {
    lm "INFO" "Comparing repo chunks..."

    for key in "${!repo_matches[@]}"; do
        IFS=',' read -r path count <<< "${repo_matches[$key]}"

        if (( count != 1 )); then
            lm "WARNING" "Skipping comparison for $key due to multiple or zero matches."
            continue
        fi

        # Extract chunk from .pre-commit-config.yaml
        pre_commit_chunk=$(awk -v repo_line="$key" '
        BEGIN {found=0}
        $0 ~ repo_line {found=1}
        found && /^[[:space:]]*- repo:/ && $0 != repo_line {found=0}
        found {print}
        ' ".pre-commit-config.yaml")

        # Extract chunk from .ST-pre-commit-config.yaml
        st_pre_commit_chunk=$(awk -v repo_line="$key" '
        BEGIN {found=0}
        $0 ~ repo_line {found=1}
        found && /^[[:space:]]*- repo:/ && $0 != repo_line {found=0}
        found {print}
        ' "$path")

        # Compare chunks
        if [[ "$pre_commit_chunk" == "$st_pre_commit_chunk" ]]; then
            lm "INFO" "✅ Success: $key chunks match!"
        else
            lm "WARNING" "⚠️ Warning: $key chunks do not match!"
            lm "DEBUG" "Expected: $pre_commit_chunk"
            lm "DEBUG" "Found: $st_pre_commit_chunk"
        fi
    done

    lm "INFO" "Chunk comparison complete."
}

summary_report() {
    local total_repos="${#repo_matches[@]}"
    local successful=0
    local failed=0

    for key in "${!repo_matches[@]}"; do
        IFS=',' read -r _ count <<< "${repo_matches[$key]}"
        if (( count == 1 )); then
            successful=$((successful + 1))
        else
            failed=$((failed + 1))
        fi
    done

    lm "INFO" "Summary Report:"
    lm "INFO" "Total repos checked: $total_repos"
    lm "INFO" "Successful matches: $successful"
    lm "INFO" "Failed or missing matches: $failed"
}

main() {
    local config_file=".pre-commit-config.yaml"
    local repos_chunk
    local repo_lines
    local paths

    parse_arguments "$@"

    # Check if the YAML config file exists
    if [[ ! -f "$config_file" ]]; then
        echo "Error: $config_file not found!"
        exit 1
    fi

    # Capture the `repos:` chunk in a variable
    repos_chunk=$(awk '
    /^ *repos:/ {found=1; next}
    found && /^[[:space:]]*-/ {print; next}
    found && !/^[[:space:]]/ {found=0}
    ' "$config_file")
    #echo "$repos_chunk"

    # Save the lines containing 'repo:' to a variable
    repo_lines=$(echo "$repos_chunk" | grep -E '.*repo:.*')
    #echo "$repo_lines"

    # Get paths to .ST-pre-commit-config.yaml files
    paths=$(get_smoked_config_paths)
    #echo "$paths"

    # Check for matches
    check_for_matches "$paths" "$repo_lines"
    #declare -p repo_matches
    lm "INFO" "Starting validation and comparison..."

    validate_matches
    compare_repo_chunks

    lm "INFO" "All checks complete!"
    summary_report
}

# Run the script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
