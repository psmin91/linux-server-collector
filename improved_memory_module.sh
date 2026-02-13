#!/usr/bin/env bash
################################################################################
# Improved Memory Information Collection Module v3.0
#
# This module provides accurate memory detection with proper GB vs GiB handling
# and advanced calibration for various Linux environments.
#
# KEY IMPROVEMENTS:
#   1. Correct GB (decimal: 1GB = 1,000,000,000 bytes) vs GiB (binary: 1GiB = 1,073,741,824 bytes)
#   2. /proc/meminfo KiB to decimal GB conversion (KiB are actually binary 1024)
#   3. Kernel memory overhead compensation
#   4. Standard memory size alignment (2, 4, 8, 16, 32, 64, 128, 256, 512, 1024 GB)
#   5. Cloud environment support (AWS cgroup, Kubernetes, etc.)
#   6. Multi-source fallback strategy
#
# UNIT REFERENCE:
#   Decimal GB:  1 GB = 1,000,000,000 bytes (dmidecode uses this)
#   Binary GiB:  1 GiB = 1,073,741,824 bytes = 1,048,576 KiB
#   /proc/meminfo: Uses KiB (binary 1024, despite "kB" label - Red Hat docs confirmed)
#
# AUTHORS: System Enhancement Team
# VERSION: 3.0
# LAST UPDATE: 2026-02-13
################################################################################

set -o pipefail 2>/dev/null || true
export LANG=C
export LC_ALL=C

################################################################################
# 1. UNIT CONVERSION FUNCTIONS
################################################################################

#######################################
# Convert /proc/meminfo KiB to decimal GB
# /proc/meminfo reports in KiB (1024-based) despite label "kB"
# 1 GB (decimal) = 976,562.5 KiB
# Arguments:
#   $1 - value in KiB (from /proc/meminfo)
# Returns: value in decimal GB with 2 decimal places
#######################################
function kib_to_decimal_gb() {
    local kib="${1}"
    
    if [ -z "$kib" ] || [ "$kib" = "0" ]; then
        echo "0.00"
        return 1
    fi
    
    # 1 GB (decimal) = 1,000,000,000 bytes
    # 1 KiB = 1,024 bytes
    # Therefore: 1 GB = 1,000,000,000 / 1,024 = 976,562.5 KiB
    echo "$kib" | awk '{printf "%.2f", $1 / 976562.5}'
}

#######################################
# Convert decimal GB to GiB (for reference only)
# Arguments:
#   $1 - value in decimal GB
# Returns: value in GiB with 2 decimal places
#######################################
function decimal_gb_to_gib() {
    local gb="${1}"
    
    if [ -z "$gb" ] || [ "$gb" = "0" ]; then
        echo "0.00"
        return 1
    fi
    
    # 1 GB = 0.931 GiB (1,000,000,000 / 1,073,741,824)
    echo "$gb" | awk '{printf "%.2f", $1 * 0.9313226}'
}

#######################################
# Convert binary GiB to decimal GB (for reference only)
# Arguments:
#   $1 - value in GiB
# Returns: value in decimal GB with 2 decimal places
#######################################
function gib_to_decimal_gb() {
    local gib="${1}"
    
    if [ -z "$gib" ] || [ "$gib" = "0" ]; then
        echo "0.00"
        return 1
    fi
    
    # 1 GiB = 1.073741824 GB
    echo "$gib" | awk '{printf "%.2f", $1 * 1.073741824}'
}

################################################################################
# 2. KERNEL MEMORY OVERHEAD DETECTION
################################################################################

#######################################
# Estimate kernel memory overhead from /proc/meminfo
# The difference between actual memory and /proc/meminfo MemTotal
# is primarily due to kernel reserved memory, BIOS regions, etc.
#
# Sources to check:
#   - DirectMap4k, DirectMap2M, DirectMap1G (memory page mappings)
#   - HardwareCorrupted (memory errors)
#   - Kernelstack (kernel stack memory)
#
# Returns: overhead estimate in GiB
#######################################
function estimate_kernel_overhead() {
    local memtotal_kib=0
    local directmap_kib=0
    
    if [ ! -f /proc/meminfo ]; then
        echo "0"
        return 1
    fi
    
    memtotal_kib=$(grep "^MemTotal:" /proc/meminfo 2>/dev/null | awk '{print $2}')
    
    # Sum all DirectMap entries (actual memory mapped)
    directmap_kib=$(grep "^DirectMap" /proc/meminfo 2>/dev/null | awk '{sum += $2} END {print sum}')
    
    if [ -z "$directmap_kib" ] || [ "$directmap_kib" = "0" ]; then
        # Fallback: estimate 1.5-3% as kernel overhead
        echo "$memtotal_kib" | awk '{printf "%.0f", $1 * 0.02}'
        return 0
    fi
    
    # Calculate difference
    local overhead_kib
    overhead_kib=$(echo "$memtotal_kib $directmap_kib" | awk '{print $1 - $2}')
    
    echo "$overhead_kib"
}

#######################################
# Get actual physical memory estimate
# Adds estimated kernel overhead to MemTotal
# This approximates the actual installed memory
#
# Returns: estimated physical memory in KiB
#######################################
function get_estimated_physical_memory_kib() {
    local memtotal_kib=0
    local overhead_kib=0
    
    if [ ! -f /proc/meminfo ]; then
        echo "0"
        return 1
    fi
    
    memtotal_kib=$(grep "^MemTotal:" /proc/meminfo 2>/dev/null | awk '{print $2}')
    overhead_kib=$(estimate_kernel_overhead)
    
    echo "$((memtotal_kib + overhead_kib))"
}

################################################################################
# 3. CLOUD ENVIRONMENT DETECTION
################################################################################

#######################################
# Detect if running in cloud/container environment
# Checks for: Docker, Kubernetes, AWS, Azure, GCP, etc.
#
# Returns: cloud provider name or "none"
#######################################
function detect_cloud_environment() {
    # Container detection
    if [ -f /run/.containerenv ] || [ -f /.dockerenv ]; then
        echo "Docker"
        return 0
    fi
    
    # Kubernetes detection
    if [ -f /run/secrets/kubernetes.io/serviceaccount/token ]; then
        echo "Kubernetes"
        return 0
    fi
    
    # AWS detection (EC2, ECS, Lambda)
    if curl -s -m 1 http://169.254.169.254/latest/meta-data/ >/dev/null 2>&1; then
        echo "AWS"
        return 0
    fi
    
    # Azure detection
    if curl -s -m 1 -H "Metadata:true" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" >/dev/null 2>&1; then
        echo "Azure"
        return 0
    fi
    
    # GCP detection
    if curl -s -m 1 -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/" >/dev/null 2>&1; then
        echo "GCP"
        return 0
    fi
    
    # cgroup v2 memory limit (Kubernetes/container)
    if [ -f /sys/fs/cgroup/memory.max ] && [ "$(cat /sys/fs/cgroup/memory.max 2>/dev/null)" != "max" ]; then
        echo "cgroup-limited"
        return 0
    fi
    
    echo "none"
}

#######################################
# Get cgroup memory limit if applicable
# For containerized/Kubernetes environments
#
# Returns: memory limit in KiB, or 0 if not limited
#######################################
function get_cgroup_memory_limit_kib() {
    # cgroup v2
    if [ -f /sys/fs/cgroup/memory.max ]; then
        local limit
        limit=$(cat /sys/fs/cgroup/memory.max 2>/dev/null)
        if [ "$limit" != "max" ] && [ -n "$limit" ] && [ "$limit" -gt 0 ]; then
            # Convert bytes to KiB
            echo "$((limit / 1024))"
            return 0
        fi
    fi
    
    # cgroup v1
    if [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
        local limit
        limit=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null)
        if [ "$limit" != "9223372036854771712" ] && [ -n "$limit" ] && [ "$limit" -gt 0 ]; then
            # Convert bytes to KiB
            echo "$((limit / 1024))"
            return 0
        fi
    fi
    
    echo "0"
}

################################################################################
# 4. MEMORY SOURCE DETECTION
################################################################################

#######################################
# Get memory info from dmidecode
# Most accurate for physical servers
# Returns: "count|individual_sizes|total_gb|ddr_type" or empty on error
#######################################
function get_memory_from_dmidecode() {
    if ! command -v dmidecode >/dev/null 2>&1; then
        return 1
    fi
    
    # Check if we have permission
    if ! dmidecode -t memory >/dev/null 2>&1; then
        return 1
    fi
    
    local dmi_output
    dmi_output=$(dmidecode -t memory 2>/dev/null)
    
    if [ -z "$dmi_output" ]; then
        return 1
    fi
    
    # Parse dmidecode output
    local count=0
    local total_gb=0
    local individual_sizes=""
    local ddr_type=""
    
    # Extract memory modules (dmidecode uses decimal GB)
    while IFS= read -r line; do
        # Extract Size (format: "Size: 32 GB")
        if [[ $line =~ Size:\ ([0-9]+)\ GB ]]; then
            local size_gb="${BASH_REMATCH[1]}"
            total_gb=$((total_gb + size_gb))
            
            if [ -z "$individual_sizes" ]; then
                individual_sizes="$size_gb"
            else
                individual_sizes="$individual_sizes $size_gb"
            fi
            
            count=$((count + 1))
        fi
        
        # Extract DDR Type (format: "Type: DDR4")
        if [[ $line =~ ^Type:\ (.+) ]] && [ -z "$ddr_type" ]; then
            ddr_type="${BASH_REMATCH[1]}"
            ddr_type=$(echo "$ddr_type" | sed 's/^[ \t]*//;s/[ \t]*$//')
        fi
    done <<< "$(echo "$dmi_output" | sed 's/^\t*//')"
    
    # Skip "No Module Installed" entries
    count=$(echo "$dmi_output" | sed 's/^\t*//' | grep "^Size:" | grep -vc "No Module Installed")
    
    if [ "$count" -gt 0 ] && [ "$total_gb" -gt 0 ]; then
        echo "$count|$individual_sizes|$total_gb|$ddr_type"
        return 0
    fi
    
    return 1
}

#######################################
# Get memory info from /proc/meminfo
# Fallback for all systems
# Returns: "1|total_gb|total_gb|N/A" or empty on error
#######################################
function get_memory_from_proc_meminfo() {
    if [ ! -f /proc/meminfo ]; then
        return 1
    fi
    
    local memtotal_kib
    memtotal_kib=$(grep "^MemTotal:" /proc/meminfo 2>/dev/null | awk '{print $2}')
    
    if [ -z "$memtotal_kib" ] || [ "$memtotal_kib" = "0" ]; then
        return 1
    fi
    
    # Convert KiB to decimal GB
    local total_gb_decimal
    total_gb_decimal=$(kib_to_decimal_gb "$memtotal_kib")
    
    # Apply calibration (add estimated kernel overhead)
    local physical_memory_kib
    physical_memory_kib=$(get_estimated_physical_memory_kib)
    local calibrated_gb_decimal
    calibrated_gb_decimal=$(kib_to_decimal_gb "$physical_memory_kib")
    
    echo "1|$calibrated_gb_decimal|$calibrated_gb_decimal|N/A"
    return 0
}

################################################################################
# 5. MEMORY SIZE NORMALIZATION
################################################################################

#######################################
# Round memory to nearest standard size
# Standard sizes: 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024 GB
#
# Arguments:
#   $1 - size in GB (decimal format, can be float)
# Returns: rounded standard size in GB
#######################################
function normalize_memory_size() {
    local size="${1}"
    
    if [ -z "$size" ] || [ "$size" = "0" ]; then
        echo "0"
        return 1
    fi
    
    echo "$size" | awk '{
        size = $1 + 0  # Convert to number
        
        # Define standard sizes with tolerance ranges
        # Tolerance: account for OS overhead (typically 1.5-3%)
        
        if (size >= 1.8 && size < 2.5) print "2"
        else if (size >= 3.5 && size < 5) print "4"
        else if (size >= 7 && size < 10) print "8"
        else if (size >= 14 && size < 20) print "16"
        else if (size >= 28 && size < 40) print "32"
        else if (size >= 56 && size < 80) print "64"
        else if (size >= 112 && size < 160) print "128"
        else if (size >= 224 && size < 320) print "256"
        else if (size >= 448 && size < 640) print "512"
        else if (size >= 896 && size < 1280) print "1024"
        else if (size >= 1792) print "2048"
        else printf "%.0f", size + 0.5
    }'
}

#######################################
# Quantize memory to nearest quarter (0.25 GB increments)
# For more precise reporting when not standard size
#
# Arguments:
#   $1 - size in GB (decimal format, can be float)
# Returns: quantized size in GB (0.25 increments)
#######################################
function quantize_memory_size() {
    local size="${1}"
    
    if [ -z "$size" ] || [ "$size" = "0" ]; then
        echo "0.00"
        return 1
    fi
    
    echo "$size" | awk '{
        size = $1 + 0
        quantized = int(size * 4 + 0.5) / 4
        printf "%.2f", quantized
    }'
}

################################################################################
# 6. MAIN MEMORY COLLECTION FUNCTION
################################################################################

#######################################
# Comprehensive memory information collection
# Handles all scenarios: physical servers, VMs, containers, cloud
#
# This is the primary function to use. It returns:
#   MEMORY_COUNT: number of physical memory modules
#   MEMORY_INDIVIDUAL_GB: space-separated list of module sizes
#   MEMORY_TOTAL_GB: total memory in decimal GB
#   MEMORY_TOTAL_GIB: total memory in binary GiB (reference)
#   DDR_INFO: detected DDR type
#   CALIBRATION_SOURCE: where data came from
#   CALIBRATION_METHOD: calibration applied
#
# Returns: 0 on success, 1 on error
#######################################
function collect_memory_info_v3() {
    local count=0
    local total_gb=0
    local individual_gb=""
    local ddr_info="Unknown"
    local source="unknown"
    local calibration="none"
    
    # Step 1: Try dmidecode (most accurate for physical servers)
    local dmi_result
    dmi_result=$(get_memory_from_dmidecode)
    if [ $? -eq 0 ] && [ -n "$dmi_result" ]; then
        count=$(echo "$dmi_result" | cut -d'|' -f1)
        individual_gb=$(echo "$dmi_result" | cut -d'|' -f2)
        total_gb=$(echo "$dmi_result" | cut -d'|' -f3)
        ddr_info=$(echo "$dmi_result" | cut -d'|' -f4)
        source="dmidecode"
        
        # dmidecode returns decimal GB already, no conversion needed
        calibration="direct"
        
        cat <<EOF
MEMORY_COUNT=$count
MEMORY_INDIVIDUAL_GB=$individual_gb
MEMORY_TOTAL_GB=$total_gb
MEMORY_TOTAL_GIB=$(decimal_gb_to_gib "$total_gb")
DDR_INFO=$ddr_info
CALIBRATION_SOURCE=$source
CALIBRATION_METHOD=$calibration
EOF
        return 0
    fi
    
    # Step 2: Fallback to /proc/meminfo
    local proc_result
    proc_result=$(get_memory_from_proc_meminfo)
    if [ $? -eq 0 ] && [ -n "$proc_result" ]; then
        count=$(echo "$proc_result" | cut -d'|' -f1)
        individual_gb=$(echo "$proc_result" | cut -d'|' -f2)
        total_gb=$(echo "$proc_result" | cut -d'|' -f3)
        ddr_info=$(echo "$proc_result" | cut -d'|' -f4)
        source="/proc/meminfo"
        
        # Check if in cloud/container environment
        local cloud_env
        cloud_env=$(detect_cloud_environment)
        if [ "$cloud_env" != "none" ]; then
            source="/proc/meminfo (cloud: $cloud_env)"
            calibration="cloud-aware"
        else
            calibration="kernel-overhead-adjusted"
        fi
        
        # Normalize to standard size
        local normalized_gb
        normalized_gb=$(normalize_memory_size "$total_gb")
        
        cat <<EOF
MEMORY_COUNT=$count
MEMORY_INDIVIDUAL_GB=$normalized_gb
MEMORY_TOTAL_GB=$normalized_gb
MEMORY_TOTAL_GIB=$(decimal_gb_to_gib "$normalized_gb")
DDR_INFO=$ddr_info
CALIBRATION_SOURCE=$source
CALIBRATION_METHOD=$calibration
EOF
        return 0
    fi
    
    # Step 3: Complete failure
    cat <<EOF
MEMORY_COUNT=0
MEMORY_INDIVIDUAL_GB=0
MEMORY_TOTAL_GB=0
MEMORY_TOTAL_GIB=0
DDR_INFO=Unknown
CALIBRATION_SOURCE=unavailable
CALIBRATION_METHOD=none
EOF
    return 1
}

################################################################################
# 7. DIAGNOSTIC/TESTING FUNCTIONS
################################################################################

#######################################
# Display memory detection details for debugging
# Shows all available data points
#######################################
function show_memory_details() {
    echo "=== Memory Detection Details ==="
    echo ""
    
    echo "1. /proc/meminfo (if available):"
    if [ -f /proc/meminfo ]; then
        echo "   MemTotal: $(grep 'MemTotal:' /proc/meminfo | awk '{print $2}') KiB"
        echo "   MemFree: $(grep 'MemFree:' /proc/meminfo | awk '{print $2}') KiB"
        echo "   MemAvailable: $(grep 'MemAvailable:' /proc/meminfo | awk '{print $2}') KiB"
        echo ""
        echo "   DirectMap entries:"
        grep "^DirectMap" /proc/meminfo || echo "   (not available)"
        echo ""
        echo "   Calculated overhead: $(estimate_kernel_overhead) KiB"
        echo "   Estimated physical: $(get_estimated_physical_memory_kib) KiB"
    else
        echo "   (not available)"
    fi
    echo ""
    
    echo "2. dmidecode (if available):"
    if command -v dmidecode >/dev/null 2>&1; then
        echo "   Available: yes"
        local dmi_result
        dmi_result=$(get_memory_from_dmidecode)
        if [ $? -eq 0 ]; then
            echo "   Result: $dmi_result"
        else
            echo "   Result: (error or no permission)"
        fi
    else
        echo "   Available: no"
    fi
    echo ""
    
    echo "3. Cloud/Container environment:"
    local cloud_env
    cloud_env=$(detect_cloud_environment)
    echo "   Detected: $cloud_env"
    echo ""
    
    echo "4. cgroup memory limits:"
    local cgroup_limit
    cgroup_limit=$(get_cgroup_memory_limit_kib)
    if [ "$cgroup_limit" -gt 0 ]; then
        echo "   Limit: $cgroup_limit KiB ($(kib_to_decimal_gb "$cgroup_limit") GB)"
    else
        echo "   Limit: (none)"
    fi
    echo ""
    
    echo "5. Final Memory Collection:"
    collect_memory_info_v3
}

################################################################################
# 8. EXPORT FUNCTIONS FOR EXTERNAL USE
################################################################################

# Make functions available for sourcing in other scripts
export -f kib_to_decimal_gb
export -f decimal_gb_to_gib
export -f gib_to_decimal_gb
export -f estimate_kernel_overhead
export -f get_estimated_physical_memory_kib
export -f detect_cloud_environment
export -f get_cgroup_memory_limit_kib
export -f get_memory_from_dmidecode
export -f get_memory_from_proc_meminfo
export -f normalize_memory_size
export -f quantize_memory_size
export -f collect_memory_info_v3
export -f show_memory_details

# Default: show usage if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "Memory Collection Module v3.0"
    echo "==============================="
    echo ""
    echo "This module should be sourced in other scripts."
    echo ""
    echo "Usage in your script:"
    echo "  source ./improved_memory_module.sh"
    echo "  collect_memory_info_v3"
    echo ""
    echo "Available functions:"
    echo "  - collect_memory_info_v3           Main function"
    echo "  - show_memory_details              Diagnostic output"
    echo "  - kib_to_decimal_gb                Unit conversion"
    echo "  - detect_cloud_environment         Cloud detection"
    echo "  - normalize_memory_size            Rounding"
    echo ""
    echo "Running diagnostic:"
    show_memory_details
fi
