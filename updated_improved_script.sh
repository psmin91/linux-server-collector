#!/usr/bin/env bash
################################################################################
# Linux Server Configuration Information Collector v2.0
# 
# Improved version with comprehensive support for multiple Linux distributions
# and edge case handling.
#
# SUPPORTED OPERATING SYSTEMS & ENVIRONMENTS:
#
#   [RHEL Family]
#   - RHEL 7.x, 8.x, 9.x+
#   - CentOS 7.x, 8.x, Stream
#   - Rocky Linux 8.x, 9.x+
#   - AlmaLinux 8.x, 9.x+
#   - Fedora 35+
#
#   [Debian Family]
#   - Ubuntu 18.04 LTS, 20.04 LTS, 22.04 LTS, 24.04 LTS
#   - Debian 10 (Buster), 11 (Bullseye), 12 (Bookworm)
#   - Linux Mint
#   - Raspberry Pi OS
#
#   [Other Distros]
#   - SUSE / openSUSE
#   - Arch Linux
#
#   [Deployment Types]
#   - Physical Servers (on-premises)
#   - Virtual Machines (VMware, KVM, Hyper-V, Xen, VirtualBox)
#   - Cloud Instances (AWS EC2, Azure VMs, GCP, Naver Cloud)
#   - Container Environments (Docker, LXC, Kubernetes)
#
# REQUIREMENTS:
#   - Bash 3.x or higher
#   - Standard utilities: grep, awk, sed, cut
#   - dmidecode (optional, improves HW detection)
#   - /proc/cpuinfo and /proc/meminfo
#   - Root/sudo access recommended for full capabilities
#
# USAGE:
#   sudo ./improved_script.sh [--json] [--verbose] [--debug]
#   sudo ./improved_script.sh > server_info.json
#
# OPTIONS:
#   --json      Output as JSON (default)
#   --verbose   Show warnings and non-critical issues
#   --debug     Show debug information (requires --verbose)
#
################################################################################

set -o pipefail 2>/dev/null || true
export LANG=C
export LC_ALL=C

# ===========================
# GLOBAL CONFIGURATION
# ===========================

# Global variables
INFRA_TYPE="Unknown"
PERMISSION_LEVEL="user"  # user or root
IS_CONTAINER=0
VERBOSE_MODE=0
DEBUG_MODE=0
JSON_OUTPUT=1

# Capabilities detection
HAS_DMIDECODE=0
HAS_LSB_RELEASE=0
HAS_SYSTEMD=0

# ===========================
# UTILITY FUNCTIONS
# ===========================

#######################################
# Debug logging function
#######################################
function debug_log() {
    if [ "$DEBUG_MODE" = "1" ]; then
        echo "DEBUG: $*" >&2
    fi
}

#######################################
# Warning logging function
#######################################
function warn_log() {
    if [ "$VERBOSE_MODE" = "1" ] || [ "$DEBUG_MODE" = "1" ]; then
        echo "WARN: $*" >&2
    fi
}

#######################################
# Initialize system environment
#######################################
function init_environment() {
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        PERMISSION_LEVEL="root"
    else
        PERMISSION_LEVEL="user"
        warn_log "Not running as root. Some information may be limited or unavailable."
    fi

    # Check for required tools
    if command -v dmidecode >/dev/null 2>&1; then
        HAS_DMIDECODE=1
        debug_log "dmidecode found"
    else
        debug_log "dmidecode not found, using fallback methods"
    fi

    if command -v lsb_release >/dev/null 2>&1; then
        HAS_LSB_RELEASE=1
        debug_log "lsb_release found"
    fi

    if command -v systemctl >/dev/null 2>&1; then
        HAS_SYSTEMD=1
        debug_log "systemd detected"
    fi

    # Detect if running in container
    if [ -f /proc/1/cgroup ] && grep -qaE 'docker|lxc|kubepods|cri-o|containerd' /proc/1/cgroup 2>/dev/null; then
        IS_CONTAINER=1
        debug_log "Container environment detected via /proc/1/cgroup"
    elif [ -f /run/.containerenv ] || [ -f /.dockerenv ]; then
        IS_CONTAINER=1
        debug_log "Container environment detected via container marker files"
    fi
}

#######################################
# Sanitize value for JSON output
# Arguments:
#   $1 - value to sanitize
# Returns: sanitized string
#######################################
function sanitize_json_value() {
    local value="${1}"
    # Remove double quotes
    value=$(echo "$value" | sed 's/"//g' 2>/dev/null)
    # Remove backslashes
    value=$(echo "$value" | sed 's/\\//g' 2>/dev/null)
    # Remove newlines and carriage returns
    value=$(echo "$value" | tr -d '\n\r' 2>/dev/null)
    # Truncate to 200 characters
    value=$(echo "$value" | head -c 200)
    echo "$value"
}

#######################################
# Print JSON formatted output
# Arguments:
#   $1 - title
#   $2 - result (OK/NOK)
#   $3 - value
#######################################
function print_json() {
    local title="${1}"
    local result="${2}"
    local value="${3}"

    # Sanitize value
    value=$(sanitize_json_value "$value")

    echo '    {'
    echo "      \"title\" : \"${title}\","
    echo "      \"result\" : \"${result}\","
    echo "      \"value\" : \"${value}\""
    echo '    },'
}

# ===========================
# INFRASTRUCTURE DETECTION
# ===========================

#######################################
# Detect infrastructure type
# Sets: INFRA_TYPE
#######################################
function detect_infra_type() {
    debug_log "Starting infrastructure type detection"

    # Container detection has highest priority
    if [ "$IS_CONTAINER" = "1" ]; then
        INFRA_TYPE="Container"
        debug_log "Infrastructure type: Container"
        return 0
    fi

    # Try dmidecode for detailed detection
    if [ "$HAS_DMIDECODE" = "1" ] && [ "$PERMISSION_LEVEL" = "root" ]; then
        local manufacturer product version

        manufacturer=$(dmidecode -s system-manufacturer 2>/dev/null | grep -v "^#" | head -1 | tr '[:upper:]' '[:lower:]' 2>/dev/null)
        product=$(dmidecode -s system-product-name 2>/dev/null | grep -v "^#" | head -1 | tr '[:upper:]' '[:lower:]' 2>/dev/null)
        version=$(dmidecode -s system-version 2>/dev/null | grep -v "^#" | head -1 | tr '[:upper:]' '[:lower:]' 2>/dev/null)

        debug_log "DMI: manufacturer=$manufacturer, product=$product, version=$version"

        # AWS detection
        if echo "$manufacturer $product $version" | grep -qEi "amazon|ec2|aws"; then
            INFRA_TYPE="AWS"
            debug_log "Infrastructure type: AWS (DMI detection)"
            return 0
        fi

        # Azure detection
        if echo "$manufacturer $product $version" | grep -qEi "microsoft.*virtual machine|microsoft corporation.*virtual machine"; then
            INFRA_TYPE="Azure"
            debug_log "Infrastructure type: Azure (DMI detection)"
            return 0
        fi

        # GCP detection
        if echo "$manufacturer $product $version" | grep -qEi "google|gce|google compute"; then
            INFRA_TYPE="GCP"
            debug_log "Infrastructure type: GCP (DMI detection)"
            return 0
        fi

        # Naver Cloud detection
        if echo "$manufacturer $product $version" | grep -qEi "navercloud|ncloud"; then
            INFRA_TYPE="NaverCloud"
            debug_log "Infrastructure type: Naver Cloud (DMI detection)"
            return 0
        fi

        # VM detection (VMware, VirtualBox, KVM, Hyper-V, Xen, Parallels, Nutanix)
        if echo "$manufacturer $product $version" | grep -qEi "vmware|virtualbox|kvm|hyper-v|xen|qemu|innotek|parallels|nutanix|bochs|vbox"; then
            INFRA_TYPE="VM"
            debug_log "Infrastructure type: Virtual Machine (DMI detection)"
            return 0
        fi

        # Physical server with recognized manufacturer
        if [ -n "$manufacturer" ] && [ "$manufacturer" != "unknown" ]; then
            INFRA_TYPE="Physical"
            debug_log "Infrastructure type: Physical (DMI detection)"
            return 0
        fi
    fi

    # Fallback: Cloud-init detection
    if [ -d /var/lib/cloud ] || [ -f /etc/cloud/cloud.cfg ]; then
        debug_log "cloud-init detected"
        if [ -f /etc/cloud/cloud.cfg ]; then
            if grep -qEi "ec2|aws" /etc/cloud/cloud.cfg 2>/dev/null; then
                INFRA_TYPE="AWS"
                debug_log "Infrastructure type: AWS (cloud-init detection)"
                return 0
            elif grep -qi "azure" /etc/cloud/cloud.cfg 2>/dev/null; then
                INFRA_TYPE="Azure"
                debug_log "Infrastructure type: Azure (cloud-init detection)"
                return 0
            elif grep -qEi "gce|google" /etc/cloud/cloud.cfg 2>/dev/null; then
                INFRA_TYPE="GCP"
                debug_log "Infrastructure type: GCP (cloud-init detection)"
                return 0
            fi
        fi
    fi

    # Check for cloud-specific tools
    if [ -f /opt/aws/bin/cfn-init ] || [ -d /opt/aws ] || [ -f /usr/bin/aws ]; then
        INFRA_TYPE="AWS"
        debug_log "Infrastructure type: AWS (cloud tool detection)"
    elif [ -f /usr/sbin/waagent ] || [ -d /var/lib/waagent ]; then
        INFRA_TYPE="Azure"
        debug_log "Infrastructure type: Azure (cloud tool detection)"
    elif [ -f /usr/bin/gcloud ] || [ -d /usr/share/google ]; then
        INFRA_TYPE="GCP"
        debug_log "Infrastructure type: GCP (cloud tool detection)"
    else
        # Default fallback based on /proc
        if [ -f /proc/cpuinfo ]; then
            # Try to detect from CPU flags
            if grep -qi "hypervisor" /proc/cpuinfo; then
                INFRA_TYPE="VM"
                debug_log "Infrastructure type: Virtual Machine (CPU flags detection)"
            else
                INFRA_TYPE="Physical"
                debug_log "Infrastructure type: Physical (default)"
            fi
        fi
    fi

    if [ "$INFRA_TYPE" = "Unknown" ]; then
        warn_log "Could not determine infrastructure type, defaulting to Unknown"
    fi
}

#######################################
# Detect specific cloud provider from environment
#######################################
function detect_cloud_provider_env() {
    # Check environment variables
    if env | grep -qi "^aws"; then
        return 0  # AWS
    elif env | grep -qi "^azure"; then
        return 1  # Azure
    elif env | grep -qi "^gcp\|^google"; then
        return 2  # GCP
    fi
    return -1  # Unknown
}

# ===========================
# HARDWARE INFORMATION
# ===========================

#######################################
# Collect HW information
#######################################
function collect_hw_info() {
    local result="OK"
    local hw_model="Unknown"
    local serial_number="Unknown"
    
    debug_log "Collecting hardware information"

    # For containers, return Container
    if [ "$IS_CONTAINER" = "1" ]; then
        print_json "HW_MODEL" "$result" "Container"
        print_json "SERIAL_NUMBER" "$result" "N/A"
        debug_log "Hardware: Container environment"
        return 0
    fi

    # Try dmidecode first
    if [ "$HAS_DMIDECODE" = "1" ] && [ "$PERMISSION_LEVEL" = "root" ]; then
        hw_model=$(dmidecode -s system-product-name 2>/dev/null | grep -v "^#" | head -1)
        [ -z "$hw_model" ] && hw_model="Unknown"

        # For cloud VMs, prefer UUID over serial number
        if [ "$INFRA_TYPE" != "Physical" ]; then
            local uuid
            uuid=$(dmidecode -s system-uuid 2>/dev/null | grep -v "^#" | head -1)
            if [ -n "$uuid" ] && [ "$uuid" != "Unknown" ]; then
                serial_number="$uuid"
            else
                serial_number=$(dmidecode -s system-serial-number 2>/dev/null | grep -v "^#" | head -1)
            fi
        else
            # Physical server: use serial number
            serial_number=$(dmidecode -s system-serial-number 2>/dev/null | grep -v "^#" | head -1)
        fi
        
        [ -z "$serial_number" ] && serial_number="Unknown"
        debug_log "Hardware via dmidecode: model=$hw_model, serial=$serial_number"
    fi

    # Fallback for HW model from sysfs
    if [ -z "$hw_model" ] || [ "$hw_model" = "Unknown" ]; then
        if [ -f /sys/class/dmi/id/product_name ]; then
            hw_model=$(cat /sys/class/dmi/id/product_name 2>/dev/null | head -1)
            debug_log "Hardware model from sysfs: $hw_model"
        fi
    fi

    # Fallback for serial number from sysfs
    if [ -z "$serial_number" ] || [ "$serial_number" = "Unknown" ]; then
        if [ -f /sys/class/dmi/id/product_serial ]; then
            serial_number=$(cat /sys/class/dmi/id/product_serial 2>/dev/null | head -1)
            debug_log "Serial number from sysfs (product_serial): $serial_number"
        elif [ -f /sys/class/dmi/id/product_uuid ]; then
            serial_number=$(cat /sys/class/dmi/id/product_uuid 2>/dev/null | head -1)
            debug_log "Serial number from sysfs (product_uuid): $serial_number"
        fi
    fi

    # Final validation
    [ -z "$hw_model" ] && hw_model="Unknown"
    [ -z "$serial_number" ] && serial_number="Unknown"

    print_json "HW_MODEL" "$result" "$hw_model"
    print_json "SERIAL_NUMBER" "$result" "$serial_number"
}

# ===========================
# OS INFORMATION
# ===========================

#######################################
# Parse OS version safely
# Arguments:
#   $1 - raw version string
# Returns: cleaned version string (e.g., "22.04" from "22.04.1 LTS")
#######################################
function parse_os_version() {
    local raw_version="${1}"
    local version=""

    # Extract major.minor version only
    version=$(echo "$raw_version" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/' 2>/dev/null)
    
    # If pattern matching failed, try alternative
    if [ -z "$version" ]; then
        version=$(echo "$raw_version" | awk -F'[^0-9.]' '{print $1}' 2>/dev/null)
    fi

    # If still empty, return raw version
    if [ -z "$version" ]; then
        version="$raw_version"
    fi

    echo "$version"
}

#######################################
# Collect OS information
#######################################
function collect_os_info() {
    local result="OK"
    local os_name="Unknown"
    local os_version="Unknown"
    local kernel_version="Unknown"

    debug_log "Collecting OS information"

    # Kernel version (always available)
    kernel_version=$(uname -r 2>/dev/null || echo "Unknown")
    debug_log "Kernel version: $kernel_version"

    # Try /etc/os-release (modern standard, available in all modern distros)
    if [ -f /etc/os-release ]; then
        debug_log "Using /etc/os-release"
        # Source the file safely
        . /etc/os-release 2>/dev/null || true

        [ -n "$NAME" ] && os_name="$NAME"
        
        # Try VERSION_ID first (more reliable for version comparison)
        if [ -n "$VERSION_ID" ]; then
            os_version=$(parse_os_version "$VERSION_ID")
        elif [ -n "$VERSION" ]; then
            os_version=$(parse_os_version "$VERSION")
        fi
    fi

    # Fallback: Red Hat family (/etc/redhat-release)
    if [ "$os_name" = "Unknown" ] && [ -f /etc/redhat-release ]; then
        debug_log "Using /etc/redhat-release"
        local redhat_content
        redhat_content=$(cat /etc/redhat-release 2>/dev/null)
        os_name=$(echo "$redhat_content" | sed 's/ release.*//' 2>/dev/null)
        os_version=$(echo "$redhat_content" | sed -n 's/.*release \([0-9]*\(\.[ 0-9]*\)?\).*/\1/p' 2>/dev/null)
    fi

    # Fallback: Debian family (/etc/debian_version)
    if [ "$os_name" = "Unknown" ] && [ -f /etc/debian_version ]; then
        debug_log "Using /etc/debian_version"
        os_name="Debian"
        os_version=$(cat /etc/debian_version 2>/dev/null)
    fi

    # Fallback: lsb_release (older Ubuntu/Debian systems)
    if [ "$os_name" = "Unknown" ] && [ "$HAS_LSB_RELEASE" = "1" ]; then
        debug_log "Using lsb_release"
        os_name=$(lsb_release -is 2>/dev/null)
        os_version=$(lsb_release -rs 2>/dev/null)
    fi

    # Final fallback to uname
    if [ "$os_name" = "Unknown" ]; then
        debug_log "Final fallback to uname"
        os_name=$(uname -s 2>/dev/null || echo "Linux")
        os_version=$(uname -r 2>/dev/null || echo "Unknown")
    fi

    # Validate versions are not empty
    [ -z "$os_version" ] && os_version="Unknown"
    [ -z "$os_name" ] && os_name="Unknown"

    debug_log "OS: name=$os_name, version=$os_version"
    print_json "OS_NAME" "$result" "$os_name"
    print_json "OS_VERSION" "$result" "$os_version"
    print_json "KERNEL_VERSION" "$result" "$kernel_version"
}

# ===========================
# CPU INFORMATION
# ===========================

#######################################
# Extract logical CPU count safely
# Returns: number of logical CPUs
#######################################
function get_logical_cpu_count() {
    if [ -f /proc/cpuinfo ]; then
        grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "0"
    else
        nproc 2>/dev/null || echo "0"
    fi
}

#######################################
# Extract CPU count (sockets) safely
# Returns: number of physical CPUs
#######################################
function get_physical_cpu_count() {
    if [ -f /proc/cpuinfo ]; then
        local count
        count=$(grep "physical id" /proc/cpuinfo 2>/dev/null | sort -u | wc -l)
        if [ "$count" -gt 0 ]; then
            echo "$count"
        else
            echo "1"
        fi
    else
        echo "1"
    fi
}

#######################################
# Extract cores per socket safely
# Returns: number of cores per CPU
#######################################
function get_cores_per_cpu() {
    if [ -f /proc/cpuinfo ]; then
        local cores
        cores=$(grep "cpu cores" /proc/cpuinfo 2>/dev/null | head -1 | awk '{print $4}')
        if [ -n "$cores" ] && [ "$cores" -gt 0 ]; then
            echo "$cores"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

#######################################
# Extract CPU model safely
# Returns: CPU model string
#######################################
function get_cpu_model() {
    if [ -f /proc/cpuinfo ]; then
        grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | sed 's/^[ \t]*//' | head -c 100
    fi
}

#######################################
# Collect CPU information
#######################################
function collect_cpu_info() {
    local result="OK"
    local cpu_count=0
    local cpu_total_cores=0
    local cpu_model="Unknown"

    debug_log "Collecting CPU information (INFRA_TYPE=$INFRA_TYPE)"

    # Physical server: use dmidecode if available
    if [ "$INFRA_TYPE" = "Physical" ] && [ "$HAS_DMIDECODE" = "1" ] && [ "$PERMISSION_LEVEL" = "root" ]; then
        debug_log "Physical server: using dmidecode"
        local dmi_output
        dmi_output=$(dmidecode -t processor 2>/dev/null)

        if [ -n "$dmi_output" ]; then
            # Get CPU model from dmidecode
            cpu_model=$(echo "$dmi_output" | grep "Version:" | grep -v "Not Specified" | head -1 | cut -d: -f2 | sed 's/^[ \t]*//' | head -c 100)

            # Count physical CPUs (sockets)
            cpu_count=$(echo "$dmi_output" | grep -c "Socket Designation:" 2>/dev/null)
            [ "$cpu_count" -eq 0 ] && cpu_count=1

            # Get cores per CPU and calculate total
            local cores_per_cpu
            cores_per_cpu=$(echo "$dmi_output" | grep "Core Count:" | head -1 | awk '{print $3}')
            if [ -n "$cores_per_cpu" ] && [ "$cores_per_cpu" -gt 0 ]; then
                cpu_total_cores=$((cores_per_cpu * cpu_count))
            fi

            debug_log "CPU via dmidecode: count=$cpu_count, cores=$cpu_total_cores, model=$cpu_model"
        fi
    fi

    # Fallback or for all other infrastructure types: use /proc/cpuinfo
    if [ "$cpu_count" -eq 0 ] || [ "$cpu_total_cores" -eq 0 ]; then
        debug_log "Fallback to /proc/cpuinfo"
        
        if [ -f /proc/cpuinfo ]; then
            # Get CPU model
            cpu_model=$(get_cpu_model)
            [ -z "$cpu_model" ] && cpu_model="Unknown"

            if [ "$INFRA_TYPE" = "Physical" ] || [ "$INFRA_TYPE" = "VM" ]; then
                # Physical or VM: count sockets and cores properly
                cpu_count=$(get_physical_cpu_count)
                local cores_per_socket
                cores_per_socket=$(get_cores_per_cpu)
                
                if [ "$cores_per_socket" -gt 0 ]; then
                    cpu_total_cores=$((cores_per_socket * cpu_count))
                else
                    # Fallback: assume equal cores per socket
                    local logical_cores
                    logical_cores=$(get_logical_cpu_count)
                    cpu_total_cores=$((logical_cores))
                fi
            else
                # Cloud instances and containers: 1 socket, count logical CPUs as vCPU
                cpu_count=1
                cpu_total_cores=$(get_logical_cpu_count)
            fi

            debug_log "CPU via /proc/cpuinfo: count=$cpu_count, cores=$cpu_total_cores, model=$cpu_model"
        fi
    fi

    # Final validation
    if [ "$cpu_count" -eq 0 ] || [ -z "$cpu_count" ]; then
        cpu_count=1
        warn_log "Could not determine CPU count, defaulting to 1"
    fi
    if [ "$cpu_total_cores" -eq 0 ] || [ -z "$cpu_total_cores" ]; then
        cpu_total_cores=1
        warn_log "Could not determine CPU cores, defaulting to 1"
    fi
    [ -z "$cpu_model" ] && cpu_model="Unknown"

    debug_log "Final CPU: count=$cpu_count, cores=$cpu_total_cores, model=$cpu_model"
    print_json "CPU_COUNT" "$result" "$cpu_count"
    print_json "CPU_TOTAL_CORES" "$result" "$cpu_total_cores"
    print_json "CPU_MODEL" "$result" "$cpu_model"
}

# ===========================
# MEMORY INFORMATION
# ===========================

#######################################
# Convert /proc/meminfo KiB to decimal GB
# /proc/meminfo reports in KiB (1024-based) despite label "kB"
# 1 GB (decimal) = 976,562.5 KiB
#
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
    
    echo "$kib" | awk '{printf "%.2f", $1 / 976562.5}'
}

#######################################
# Estimate kernel memory overhead from /proc/meminfo
# Uses DirectMap entries to estimate actual physical memory
#
# Returns: overhead estimate in KiB
#######################################
function estimate_kernel_overhead_kib() {
    if [ ! -f /proc/meminfo ]; then
        echo "0"
        return 1
    fi
    
    local memtotal_kib
    memtotal_kib=$(grep "^MemTotal:" /proc/meminfo 2>/dev/null | awk '{print $2}')
    
    # Sum all DirectMap entries (actual memory mapped)
    local directmap_kib
    directmap_kib=$(grep "^DirectMap" /proc/meminfo 2>/dev/null | awk '{sum += $2} END {print sum}')
    
    if [ -z "$directmap_kib" ] || [ "$directmap_kib" = "0" ]; then
        # Fallback: estimate 1.5-2% as kernel overhead
        echo "$memtotal_kib" | awk '{printf "%.0f", $1 * 0.015}'
        return 0
    fi
    
    # Calculate difference (kernel + BIOS reserved)
    echo "$memtotal_kib $directmap_kib" | awk '{print $1 - $2}' | awk '{printf "%.0f", $1}'
}

#######################################
# Get estimated physical memory
# Adds kernel overhead to MemTotal to approximate installed memory
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
    overhead_kib=$(estimate_kernel_overhead_kib)
    
    echo "$((memtotal_kib + overhead_kib))"
}

#######################################
# Normalize memory to standard sizes
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
        size = $1 + 0
        
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
            echo "$((limit / 1024))"
            return 0
        fi
    fi
    
    # cgroup v1
    if [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
        local limit
        limit=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null)
        # 9223372036854771712 is the "unlimited" sentinel value
        if [ "$limit" != "9223372036854771712" ] && [ -n "$limit" ] && [ "$limit" -gt 0 ]; then
            echo "$((limit / 1024))"
            return 0
        fi
    fi
    
    echo "0"
}

#######################################
# Collect Memory information v3.0
# Handles: physical servers, VMs, cloud instances, containers
#######################################
function collect_memory_info() {
    local result="OK"
    local memory_count=0
    local memory_total_gb=0
    local memory_individual_gb=""
    local ddr_info="Unknown"

    debug_log "Collecting memory information (INFRA_TYPE=$INFRA_TYPE)"

    # Step 1: Try dmidecode first (most accurate for physical servers)
    if [ "$INFRA_TYPE" = "Physical" ] && [ "$HAS_DMIDECODE" = "1" ] && [ "$PERMISSION_LEVEL" = "root" ]; then
        debug_log "Physical server: attempting dmidecode"
        local dmi_output
        dmi_output=$(dmidecode -t memory 2>/dev/null)

        if [ -n "$dmi_output" ]; then
            # Count memory modules (excluding empty slots)
            memory_count=$(echo "$dmi_output" | sed 's/^\t*//' | grep "^Size:" | grep -v "No Module Installed" | wc -l)

            if [ "$memory_count" -gt 0 ]; then
                # Parse each module and sum in decimal GB (dmidecode uses decimal)
                local mem_result
                mem_result=$(echo "$dmi_output" | sed 's/^\t*//' | grep "^Size:" | grep -v "No Module Installed" | awk '
                BEGIN {
                    sum = 0
                    individual = ""
                    count = 0
                }
                {
                    size = $2
                    unit = tolower($3)
                    gb_size = 0

                    # dmidecode reports in decimal GB/MB/TB
                    if (unit == "gb") gb_size = size
                    else if (unit == "mb") gb_size = size / 1000
                    else if (unit == "tb") gb_size = size * 1000
                    else gb_size = size

                    sum += gb_size
                    count++

                    # Round individual module size to nearest integer
                    gb_size_int = sprintf("%.0f", gb_size)

                    if (individual == "") {
                        individual = gb_size_int
                    } else {
                        individual = individual " " gb_size_int
                    }
                }
                END {
                    printf "%.2f|%s|%d", sum, individual, count
                }')

                memory_total_gb=$(echo "$mem_result" | cut -d'|' -f1)
                memory_individual_gb=$(echo "$mem_result" | cut -d'|' -f2)
                memory_count=$(echo "$mem_result" | cut -d'|' -f3)

                # Get DDR type
                ddr_info=$(echo "$dmi_output" | sed 's/^\t*//' | grep "^Type:" | grep -v "Unknown" | grep -v "Error Correction Type" | head -1 | cut -d: -f2 | sed 's/^[ \t]*//')
                
                if [ -z "$ddr_info" ] || [ "$ddr_info" = "Unknown" ]; then
                    ddr_info=$(echo "$dmi_output" | sed 's/^\t*//' | grep "Type Detail:" | head -1 | cut -d: -f2 | sed 's/^[ \t]*//')
                fi

                [ -z "$ddr_info" ] && ddr_info="Unknown"

                debug_log "✓ Memory from dmidecode: count=$memory_count, total_gb=$memory_total_gb, ddr=$ddr_info"
                
                # Validate dmidecode result
                if [ -n "$memory_total_gb" ] && [ "$memory_total_gb" != "0" ]; then
                    print_json "MEMORY_COUNT" "$result" "$memory_count"
                    print_json "MEMORY_INDIVIDUAL_GB" "$result" "$memory_individual_gb"
                    print_json "MEMORY_TOTAL_GB" "$result" "$memory_total_gb"
                    print_json "DDR_INFO" "$result" "$ddr_info"
                    return 0
                fi
            fi
        fi
    fi

    # Step 2: Try cgroup limits for containers
    local cgroup_limit_kib
    cgroup_limit_kib=$(get_cgroup_memory_limit_kib)
    if [ "$cgroup_limit_kib" -gt 0 ]; then
        debug_log "Container environment: using cgroup memory limit"
        memory_total_gb=$(kib_to_decimal_gb "$cgroup_limit_kib")
        memory_total_gb=$(normalize_memory_size "$memory_total_gb")
        memory_individual_gb="$memory_total_gb"
        memory_count=1
        ddr_info="N/A"
        
        debug_log "✓ Memory from cgroup: total_gb=$memory_total_gb"
        print_json "MEMORY_COUNT" "$result" "$memory_count"
        print_json "MEMORY_INDIVIDUAL_GB" "$result" "$memory_individual_gb"
        print_json "MEMORY_TOTAL_GB" "$result" "$memory_total_gb"
        print_json "DDR_INFO" "$result" "$ddr_info"
        return 0
    fi

    # Step 3: Fallback to /proc/meminfo with calibration (all systems)
    debug_log "Using /proc/meminfo with calibration"
    
    if [ -f /proc/meminfo ]; then
        local total_memory_kib
        total_memory_kib=$(grep "^MemTotal:" /proc/meminfo 2>/dev/null | awk '{print $2}')
        
        if [ -n "$total_memory_kib" ] && [ "$total_memory_kib" -gt 0 ]; then
            # Convert /proc/meminfo KiB to decimal GB
            # /proc reports KiB (1024-based) despite "kB" label
            memory_total_gb=$(kib_to_decimal_gb "$total_memory_kib")
            
            # Apply calibration: estimate physical memory by adding kernel overhead
            local estimated_physical_kib
            estimated_physical_kib=$(get_estimated_physical_memory_kib)
            local calibrated_gb
            calibrated_gb=$(kib_to_decimal_gb "$estimated_physical_kib")
            
            # Use calibrated value if significantly different from MemTotal
            local diff
            diff=$(echo "$calibrated_gb $memory_total_gb" | awk '{printf "%.2f", $1 - $2}')
            debug_log "MemTotal: $memory_total_gb GB, Calibrated: $calibrated_gb GB, Diff: $diff GB"
            
            if [ "$(echo "$diff > 1" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
                memory_total_gb="$calibrated_gb"
                debug_log "Using calibrated value (kernel overhead detected)"
            fi
            
            # Normalize to standard size
            memory_total_gb=$(normalize_memory_size "$memory_total_gb")
            memory_individual_gb="$memory_total_gb"
            memory_count=1
            ddr_info="N/A"
            
            debug_log "✓ Memory from /proc/meminfo (calibrated): total_gb=$memory_total_gb"
            print_json "MEMORY_COUNT" "$result" "$memory_count"
            print_json "MEMORY_INDIVIDUAL_GB" "$result" "$memory_individual_gb"
            print_json "MEMORY_TOTAL_GB" "$result" "$memory_total_gb"
            print_json "DDR_INFO" "$result" "$ddr_info"
            return 0
        fi
    fi

    # Step 4: Complete failure - return zeros
    warn_log "Could not determine memory information"
    memory_count=0
    memory_total_gb=0
    memory_individual_gb="0"
    ddr_info="Unknown"
    
    print_json "MEMORY_COUNT" "$result" "$memory_count"
    print_json "MEMORY_INDIVIDUAL_GB" "$result" "$memory_individual_gb"
    print_json "MEMORY_TOTAL_GB" "$result" "$memory_total_gb"
    print_json "DDR_INFO" "$result" "$ddr_info"
}

# ===========================
# ADDITIONAL SYSTEM INFO
# ===========================

#######################################
# Collect additional system information
#######################################
function collect_additional_info() {
    local result="OK"
    
    debug_log "Collecting additional system information"

    # System uptime
    local uptime_seconds
    uptime_seconds=$(cat /proc/uptime 2>/dev/null | awk '{print int($1)}')
    if [ -n "$uptime_seconds" ] && [ "$uptime_seconds" -gt 0 ]; then
        print_json "UPTIME_SECONDS" "$result" "$uptime_seconds"
    fi

    # Permission level
    print_json "PERMISSION_LEVEL" "$result" "$PERMISSION_LEVEL"

    # Infrastructure type
    print_json "INFRA_TYPE" "$result" "$INFRA_TYPE"

    # Container indicator
    local is_container_str="No"
    [ "$IS_CONTAINER" = "1" ] && is_container_str="Yes"
    print_json "IS_CONTAINER" "$result" "$is_container_str"
}

# ===========================
# MAIN FUNCTION
# ===========================

#######################################
# Main function
#######################################
function main() {
    # Parse command-line arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --json)
                JSON_OUTPUT=1
                ;;
            --verbose)
                VERBOSE_MODE=1
                ;;
            --debug)
                DEBUG_MODE=1
                VERBOSE_MODE=1
                ;;
            *)
                echo "Unknown option: $1" >&2
                echo "Usage: $0 [--json] [--verbose] [--debug]" >&2
                exit 1
                ;;
        esac
        shift
    done

    # Initialize environment
    init_environment
    detect_infra_type

    # Output JSON header
    echo '{'
    echo '  "kind" : "server_info",'
    echo '  "version" : "2.0",'
    echo '  "items" : ['
    echo '    {'
    echo '      "data" : ['

    # Collect all information
    collect_hw_info
    collect_os_info
    collect_cpu_info
    collect_memory_info
    collect_additional_info

    # Output JSON footer
    echo '        {}'
    echo '      ],'
    echo '      "status" : "OK"'
    echo '    }'
    echo '  ]'
    echo '}'
}

# Execute main function
main "$@"
