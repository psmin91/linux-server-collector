# 엣지 케이스 분석 및 처리 방법

## 목차
1. [권한 관련](#권한-관련-문제)
2. [파일 누락](#파일-누락-케이스)
3. [dmidecode 관련](#dmidecode-관련-이슈)
4. [CPU 정보 이상](#cpu-정보-이상-케이스)
5. [메모리 정보 이상](#메모리-정보-이상-케이스)
6. [환경 감지 문제](#환경-감지-문제)
7. [OS 버전 파싱](#os-버전-파싱-이슈)

---

## 권한 관련 문제

### Case 1.1: Non-Root 사용자 실행

**문제:**
```bash
$ ./improved_script.sh
# dmidecode 실행 거부, /sys/class/dmi/id/* 읽기 실패
```

**원인:**
- dmidecode는 root 권한 필요
- `/sys/class/dmi/id/` 파일들은 root 소유 (644 또는 400 권한)

**스크립트 처리:**

```bash
# init_environment()에서 권한 검사
if [ "$EUID" -eq 0 ]; then
    PERMISSION_LEVEL="root"
else
    PERMISSION_LEVEL="user"
    warn_log "Not running as root. Some information may be limited."
fi

# collect_hw_info()에서 권한 체크
if [ "$HAS_DMIDECODE" = "1" ] && [ "$PERMISSION_LEVEL" = "root" ]; then
    hw_model=$(dmidecode -s system-product-name 2>/dev/null ...)
fi

# Fallback: /proc/cpuinfo는 모든 사용자가 읽을 수 있음
if [ -f /proc/cpuinfo ]; then
    cpu_count=$(grep "physical id" /proc/cpuinfo ...)
fi
```

**예상 출력:**
```json
{
  "OS_NAME": "Ubuntu",
  "OS_VERSION": "22.04",
  "HW_MODEL": "Unknown",  # 접근 권한 부족
  "SERIAL_NUMBER": "Unknown",
  "CPU_COUNT": 4,  # /proc/cpuinfo에서 읽음
  "MEMORY_TOTAL_GB": "16",  # /proc/meminfo에서 읽음
  "PERMISSION_LEVEL": "user"
}
```

**권장사항:**
- 스크립트는 non-root에서도 동작하도록 설계
- 로그에 "PERMISSION_LEVEL: user" 기록
- dmidecode 결과 불가능할 경우 `/proc` 및 `/sys` 폴백 사용

---

### Case 1.2: Sudo 권한 불완전 설정

**문제:**
```bash
# sudoers에서 특정 명령만 허용된 경우
$ sudo ./improved_script.sh
# dmidecode 실행 가능하나, 다른 명령 불가
```

**스크립트 처리:**

```bash
function collect_hw_info() {
    # sudo로 실행하면 EUID가 0 (root)
    if [ "$PERMISSION_LEVEL" = "root" ]; then
        if [ "$HAS_DMIDECODE" = "1" ]; then
            hw_model=$(dmidecode -s system-product-name 2>/dev/null || echo "Unknown")
        fi
    fi
    
    # 실패 시 fallback
    if [ -z "$hw_model" ] || [ "$hw_model" = "Unknown" ]; then
        if [ -f /sys/class/dmi/id/product_name ]; then
            hw_model=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
        fi
    fi
}
```

---

## 파일 누락 케이스

### Case 2.1: `/etc/os-release` 누락 (매우 구 배포판)

**문제:**
```bash
# RHEL 6 이전, 매우 구 Ubuntu 등
ls -la /etc/os-release
# 파일 없음
```

**원인:**
- `/etc/os-release`는 systemd 도입 이후 표준화됨
- RHEL 6 이전 버전에서는 미지원

**스크립트 처리:**

```bash
function collect_os_info() {
    local os_name="Unknown"
    local os_version="Unknown"

    # 1단계: /etc/os-release 시도
    if [ -f /etc/os-release ]; then
        . /etc/os-release 2>/dev/null || true
        [ -n "$NAME" ] && os_name="$NAME"
        [ -n "$VERSION_ID" ] && os_version="$VERSION_ID"
    fi

    # 2단계: /etc/redhat-release (Red Hat 계열)
    if [ "$os_name" = "Unknown" ] && [ -f /etc/redhat-release ]; then
        os_name=$(cat /etc/redhat-release | sed 's/ release.*//')
        os_version=$(sed -n 's/.*release \([0-9.]*\).*/\1/p' /etc/redhat-release)
    fi

    # 3단계: /etc/debian_version (Debian 계열)
    if [ "$os_name" = "Unknown" ] && [ -f /etc/debian_version ]; then
        os_name="Debian"
        os_version=$(cat /etc/debian_version)
    fi

    # 4단계: lsb_release (구 Ubuntu/Debian)
    if [ "$os_name" = "Unknown" ] && command -v lsb_release >/dev/null 2>&1; then
        os_name=$(lsb_release -is 2>/dev/null)
        os_version=$(lsb_release -rs 2>/dev/null)
    fi

    # 최종 fallback
    if [ "$os_name" = "Unknown" ]; then
        os_name=$(uname -s 2>/dev/null || echo "Linux")
    fi
}
```

**예상 출력:**
```json
{
  "OS_NAME": "CentOS Linux",  # /etc/redhat-release에서
  "OS_VERSION": "6.10",        # 파싱
  "KERNEL_VERSION": "2.6.32-754.35.1.el6.x86_64"
}
```

---

### Case 2.2: `/proc/cpuinfo` 누락 (컨테이너, seccomp 제약)

**문제:**
```bash
# 일부 hardened 컨테이너, procfs 마운트 안됨
cat /proc/cpuinfo
# No such file or directory
```

**스크립트 처리:**

```bash
function get_logical_cpu_count() {
    # 1단계: /proc/cpuinfo 시도
    if [ -f /proc/cpuinfo ]; then
        grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "0"
    else
        # 2단계: nproc 명령 사용
        nproc 2>/dev/null || echo "0"
    fi
}

function collect_cpu_info() {
    # fallback 체인 구성
    if [ -f /proc/cpuinfo ]; then
        cpu_count=$(grep "physical id" /proc/cpuinfo | sort -u | wc -l)
        cpu_total_cores=$(grep "cpu cores" /proc/cpuinfo | head -1 | awk '{print $4}')
        cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2)
    else
        # nproc은 /proc 없어도 작동 가능
        cpu_count=1
        cpu_total_cores=$(nproc 2>/dev/null || echo "1")
        cpu_model="Unknown"
    fi
}
```

**예상 출력:**
```json
{
  "CPU_COUNT": 1,
  "CPU_TOTAL_CORES": 8,  # nproc에서 읽음
  "CPU_MODEL": "Unknown"
}
```

---

### Case 2.3: `/proc/meminfo` 누락

**문제:**
```bash
# seccomp 제약, 특수 컨테이너
cat /proc/meminfo
# No such file or directory
```

**스크립트 처리:**

```bash
function collect_memory_info() {
    # dmidecode 첫 시도 (가능한 경우)
    if [ "$HAS_DMIDECODE" = "1" ]; then
        dmi_output=$(dmidecode -t memory 2>/dev/null)
        # 메모리 정보 파싱
    fi

    # /proc/meminfo fallback
    if [ -f /proc/meminfo ]; then
        total_memory_kib=$(grep "^MemTotal:" /proc/meminfo | awk '{print $2}')
        memory_total_gb=$(echo "$total_memory_kib" | awk '{printf "%.0f", $1 / 1024 / 1024}')
    else
        # 최종 fallback: "Unknown" 또는 기본값
        memory_total_gb="Unknown"
    fi
}
```

---

## dmidecode 관련 이슈

### Case 3.1: dmidecode 미설치

**문제:**
```bash
$ which dmidecode
# (empty output)

$ dmidecode
# command not found
```

**스크립트 처리:**

```bash
function init_environment() {
    if command -v dmidecode >/dev/null 2>&1; then
        HAS_DMIDECODE=1
        debug_log "dmidecode found"
    else
        HAS_DMIDECODE=0
        debug_log "dmidecode not found, using fallback methods"
    fi
}

function collect_hw_info() {
    # HAS_DMIDECODE 체크로 불필요한 호출 방지
    if [ "$HAS_DMIDECODE" = "1" ]; then
        hw_model=$(dmidecode -s system-product-name 2>/dev/null)
    fi

    # Fallback 체인
    if [ -z "$hw_model" ] || [ "$hw_model" = "Unknown" ]; then
        if [ -f /sys/class/dmi/id/product_name ]; then
            hw_model=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
        fi
    fi
}
```

**설치 방법:**

```bash
# Ubuntu/Debian
sudo apt-get install dmidecode

# RHEL/CentOS
sudo yum install dmidecode

# Alpine
apk add dmidecode
```

---

### Case 3.2: dmidecode 실행 실패 (권한)

**문제:**
```bash
$ dmidecode
# DMI data not found
# Device busy
```

**원인:**
- 비루트 사용자
- `/dev/mem` 접근 거부
- SecureBoot 활성화
- 가상 환경에서 미지원

**스크립트 처리:**

```bash
function collect_hw_info() {
    if [ "$HAS_DMIDECODE" = "1" ] && [ "$PERMISSION_LEVEL" = "root" ]; then
        hw_model=$(dmidecode -s system-product-name 2>/dev/null)
        if [ -z "$hw_model" ]; then
            debug_log "dmidecode failed or returned empty"
            # Fallback to sysfs
            if [ -f /sys/class/dmi/id/product_name ]; then
                hw_model=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
            fi
        fi
    fi
}
```

---

### Case 3.3: dmidecode 비정상 출력

**문제:**
```bash
$ dmidecode
# Version: Not Specified
# Manufacturer: Unknown

# 또는 공백이나 null 문자 포함
```

**스크립트 처리:**

```bash
function collect_hw_info() {
    local hw_model
    hw_model=$(dmidecode -s system-product-name 2>/dev/null | grep -v "^#" | head -1)
    
    # "Unknown" 또는 공백 체크
    if [ -z "$hw_model" ] || [ "$hw_model" = "Unknown" ] || [ "$hw_model" = "Not Specified" ]; then
        warn_log "dmidecode returned non-standard value: '$hw_model'"
        hw_model="Unknown"
    fi
    
    # sanitize
    hw_model=$(echo "$hw_model" | sed 's/^ *//; s/ *$//')
    [ -z "$hw_model" ] && hw_model="Unknown"
}
```

---

## CPU 정보 이상 케이스

### Case 4.1: 물리 CPU를 감지할 수 없음

**문제:**
```bash
$ cat /proc/cpuinfo | grep "physical id"
# (empty output)

# 또는 모든 processor가 동일한 physical id를 가짐
# physical id : 0
# physical id : 0
# ...
```

**원인:**
- 일부 가상화 플랫폼에서 NUMA 정보 미제공
- 컨테이너 환경
- 매우 구 커널

**스크립트 처리:**

```bash
function get_physical_cpu_count() {
    if [ -f /proc/cpuinfo ]; then
        local count
        count=$(grep "physical id" /proc/cpuinfo 2>/dev/null | sort -u | wc -l)
        
        # "physical id" 필드가 없으면 0 반환
        if [ "$count" -eq 0 ]; then
            # Cloud/Container 환경: 소켓 1개로 가정
            echo "1"
        else
            echo "$count"
        fi
    else
        echo "1"
    fi
}

function collect_cpu_info() {
    cpu_count=$(get_physical_cpu_count)
    
    # CPU 개수가 1이면, 논리 CPU를 코어 수로 사용
    if [ "$cpu_count" -eq 1 ]; then
        cpu_total_cores=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null)
        [ "$cpu_total_cores" -eq 0 ] && cpu_total_cores=1
    fi
}
```

**예상 시나리오:**

```
/proc/cpuinfo (AWS EC2):
processor       : 0
...
processor       : 7
# physical id 필드 없음

결과:
CPU_COUNT = 1 (기본값)
CPU_TOTAL_CORES = 8 (프로세서 개수)
```

---

### Case 4.2: CPU 코어 정보 모순

**문제:**
```bash
$ grep "cpu cores" /proc/cpuinfo
# (empty - 필드 없음)

# 또는
$ grep "cpu cores" /proc/cpuinfo
cpu cores       : 0
```

**원인:**
- ARM 아키텍처
- 구 프로세서 정보 제공 미지원
- CPU 핫플러그 상황

**스크립트 처리:**

```bash
function get_cores_per_cpu() {
    if [ -f /proc/cpuinfo ]; then
        local cores
        cores=$(grep "cpu cores" /proc/cpuinfo 2>/dev/null | head -1 | awk '{print $4}')
        
        if [ -n "$cores" ] && [ "$cores" -gt 0 ]; then
            echo "$cores"
        else
            # cpu cores 필드 없으면 0 반환 (호출자가 fallback)
            echo "0"
        fi
    else
        echo "0"
    fi
}

function collect_cpu_info() {
    cpu_count=$(get_physical_cpu_count)
    local cores_per_socket
    cores_per_socket=$(get_cores_per_cpu)
    
    if [ "$cores_per_socket" -gt 0 ]; then
        cpu_total_cores=$((cores_per_socket * cpu_count))
    else
        # Fallback: 논리 CPU 개수 사용
        cpu_total_cores=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null)
        [ "$cpu_total_cores" -eq 0 ] && cpu_total_cores=1
        warn_log "Could not determine cores per socket, using logical CPU count"
    fi
}
```

---

### Case 4.3: CPU 모델 정보 누락

**문제:**
```bash
$ grep "model name" /proc/cpuinfo
# (empty output)

# 또는 ARM 시스템
$ grep "model name" /proc/cpuinfo
# (empty)

$ grep "Processor" /proc/cpuinfo
Processor       : ARMv7 Processor rev 4 (v7l)
```

**스크립트 처리:**

```bash
function get_cpu_model() {
    if [ -f /proc/cpuinfo ]; then
        local model
        model=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | sed 's/^[ \t]*//;')
        
        if [ -z "$model" ]; then
            # ARM 또는 다른 아키텍처
            model=$(grep "Processor" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | sed 's/^[ \t]*//;')
        fi
        
        echo "$model"
    fi
}

function collect_cpu_info() {
    cpu_model=$(get_cpu_model)
    [ -z "$cpu_model" ] && cpu_model="Unknown"
}
```

---

## 메모리 정보 이상 케이스

### Case 5.1: 메모리 크기 반올림 불정확

**문제:**
```
/proc/meminfo:
MemTotal:       16345672 kB

계산:
16345672 KiB / 1024 / 1024 = 15.58 GB

반올림 결과: 16 GB (정확함)

그러나:
다른 시스템: 15.85 GB → 16 GB (맞음)
                 16.15 GB → 16 GB (틀림: 17로 해야함)
```

**원인:**
- 시스템 OS 오버헤드로 실제 메모리보다 3-5% 적게 표시됨
- 메모리 모듈 스펙과 실제 가용 메모리의 차이

**스크립트 처리:**

```bash
function round_memory_size() {
    local gb_size="${1}"
    
    # 표준 메모리 크기와의 범위 비교
    # 예: 2GB = 1.85~2.2GB 범위로 간주
    echo "$gb_size" | awk '{
        size = $1
        
        # 범위 정의 (허용 오차 ±10%)
        if (size >= 1.8 && size < 2.2) print "2"
        else if (size >= 3.5 && size < 4.5) print "4"
        else if (size >= 7.5 && size < 8.5) print "8"
        else if (size >= 15 && size < 17) print "16"
        else if (size >= 30 && size < 34) print "32"
        else if (size >= 62 && size < 66) print "64"
        else if (size >= 124 && size < 132) print "128"
        else if (size >= 250 && size < 262) print "256"
        else if (size >= 506 && size < 518) print "512"
        else printf "%.0f", size + 0.5  # 표준값 아님: 가장 가까운 정수로
    }'
}
```

**테스트 케이스:**

```bash
# 테스트
round_memory_size "1.85"   # → 2
round_memory_size "2.1"    # → 2
round_memory_size "3.7"    # → 4
round_memory_size "8.2"    # → 8
round_memory_size "16.1"   # → 16
round_memory_size "24.5"   # → 24 (비표준)
```

---

### Case 5.2: dmidecode 메모리 정보 이상

**문제:**
```
dmidecode -t memory:
Size: No Module Installed
Type: DRAM
Size: 16384 MB
Type: DDR4
Size: 16384 MB
Type: DRAM
```

**스크립트 처리:**

```bash
function collect_memory_info() {
    if [ "$HAS_DMIDECODE" = "1" ]; then
        local dmi_output
        dmi_output=$(dmidecode -t memory 2>/dev/null)
        
        # "No Module Installed" 라인 제거
        memory_count=$(echo "$dmi_output" | sed 's/^\t*//' | \
                       grep "^Size:" | grep -v "No Module Installed" | wc -l)
        
        # 실제 설치된 모듈만 계산
        local mem_result
        mem_result=$(echo "$dmi_output" | sed 's/^\t*//' | \
                     grep "^Size:" | grep -v "No Module Installed" | \
                     awk '... 계산로직 ...')
    fi
}
```

---

### Case 5.3: NUMA 시스템 메모리 계산

**문제:**
```
NUMA 시스템에서:
Node 0: 64 GB
Node 1: 64 GB
Total: 128 GB

그러나 dmidecode에서는 다른 결과 가능
```

**스크립트 처리:**

```bash
function collect_memory_info() {
    # dmidecode 결과 먼저 시도
    local dmidecode_result
    dmidecode_result=$(dmidecode -t memory 2>/dev/null | ...)
    
    # /proc/meminfo 검증
    local procmem
    procmem=$(grep "^MemTotal:" /proc/meminfo | awk '{print int($2 / 1024 / 1024)}')
    
    # 두 값이 크게 다르면 /proc/meminfo 우선
    if [ -n "$dmidecode_result" ] && [ -n "$procmem" ]; then
        local diff=$((dmidecode_result - procmem))
        if [ "$diff" -lt -5 ] || [ "$diff" -gt 5 ]; then
            warn_log "dmidecode and /proc/meminfo differ: dmidecode=$dmidecode_result, procmem=$procmem"
            memory_total_gb="$procmem"  # /proc/meminfo 우선
        fi
    fi
}
```

---

### Case 5.4: cgroup 메모리 제한 (컨테이너)

**문제:**
```
호스트: 64 GB
컨테이너 제한: 2 GB

/proc/meminfo in container:
MemTotal: 64 GB (호스트 값)

그러나 실제 가용 메모리: 2 GB (cgroup 제한)
```

**스크립트 처리:**

```bash
function collect_memory_info() {
    if [ "$IS_CONTAINER" = "1" ]; then
        # cgroup 메모리 제한 확인
        local cgroup_limit
        if [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
            cgroup_limit=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null)
            if [ "$cgroup_limit" -gt 0 ] && [ "$cgroup_limit" -ne 9223372036854771712 ]; then
                # 실제 제한된 값 사용
                memory_total_gb=$((cgroup_limit / 1024 / 1024 / 1024))
                debug_log "Container memory limited by cgroup: ${memory_total_gb}GB"
            fi
        fi
    fi
}
```

---

## 환경 감지 문제

### Case 6.1: 컨테이너 미감지

**문제:**
```bash
# 일부 경량 컨테이너나 특수 구성
cat /proc/1/cgroup
# (docker/lxc 마커 없음)

ls -la /.dockerenv
# 파일 없음
```

**스크립트 처리:**

```bash
function init_environment() {
    # 다중 검사 방식
    if [ -f /proc/1/cgroup ] && grep -qaE 'docker|lxc|kubepods|cri-o|containerd' /proc/1/cgroup 2>/dev/null; then
        IS_CONTAINER=1
    elif [ -f /run/.containerenv ] || [ -f /.dockerenv ]; then
        IS_CONTAINER=1
    elif [ -f /etc/containers/containers.conf ]; then
        # Podman
        IS_CONTAINER=1
    elif [ -f /.dockerenv ] || [ -d /docker ]; then
        IS_CONTAINER=1
    fi
}
```

---

### Case 6.2: Cloud Provider 감지 실패

**문제:**
```bash
# AWS 환경이나 cloud-init 미설정
cat /etc/cloud/cloud.cfg
# (파일 없음)

dmidecode -s system-manufacturer
# "QEMU" (AWS 특성 미반영)
```

**스크립트 처리:**

```bash
function detect_infra_type() {
    # 다단계 감지
    
    # 1. dmidecode (가장 신뢰도 높음)
    if [ "$HAS_DMIDECODE" = "1" ]; then
        local mfg=$(dmidecode -s system-manufacturer 2>/dev/null | tr '[:upper:]' '[:lower:]')
        if echo "$mfg" | grep -qE "amazon|ec2"; then
            INFRA_TYPE="AWS"
            return
        fi
    fi
    
    # 2. cloud-init 설정
    if [ -f /etc/cloud/cloud.cfg ]; then
        if grep -qEi "ec2|aws" /etc/cloud/cloud.cfg 2>/dev/null; then
            INFRA_TYPE="AWS"
            return
        fi
    fi
    
    # 3. 클라우드 도구 디렉토리
    if [ -d /opt/aws ] || [ -f /usr/bin/aws ]; then
        INFRA_TYPE="AWS"
        return
    fi
    
    # 4. 환경변수 (마지막 수단)
    if env | grep -qEi "^AWS_"; then
        INFRA_TYPE="AWS"
        return
    fi
}
```

---

### Case 6.3: 로컬 시스템이 클라우드로 감지됨

**문제:**
```bash
# 로컬 물리 서버이나 dmidecode가 클라우드로 인식
dmidecode -s system-product-name
# "Google Compute Engine" (실제로는 로컬 서버)
```

**스크립트 처리:**

```bash
function detect_infra_type() {
    # 신뢰도 순위 정의
    # 1. /proc/1/cgroup (컨테이너) - 가장 확실
    # 2. dmidecode + 다른 지표 (클라우드) - 중간
    # 3. cloud-init (클라우드) - 중간
    # 4. CPU 특성 (VM 여부) - 낮음
    
    # 컨테이너 우선 (가장 확실)
    if [ "$IS_CONTAINER" = "1" ]; then
        INFRA_TYPE="Container"
        return
    fi
    
    # dmidecode + cloud-init 결합 검증
    local dmi_result="unknown"
    if [ "$HAS_DMIDECODE" = "1" ]; then
        dmi_result=$(dmidecode -s system-manufacturer 2>/dev/null | tr '[:upper:]' '[:lower:]')
    fi
    
    # cloud-init와 dmidecode 일치 확인
    if [ -f /etc/cloud/cloud.cfg ]; then
        if grep -qEi "aws|ec2" /etc/cloud/cloud.cfg && \
           echo "$dmi_result" | grep -qE "amazon|ec2"; then
            INFRA_TYPE="AWS"  # 두 지표 일치
            return
        fi
    fi
}
```

---

## OS 버전 파싱 이슈

### Case 7.1: 부 버전 분리 실패

**문제:**
```
/etc/os-release:
VERSION="22.04.1 LTS"
VERSION_ID="22.04.1"

파싱 결과: "22.04.1" (원하는: "22.04")
```

**스크립트 처리:**

```bash
function parse_os_version() {
    local raw_version="${1}"
    local version=""
    
    # 정규식: major.minor만 추출
    version=$(echo "$raw_version" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')
    
    # sed 실패 시 awk 대체
    if [ -z "$version" ]; then
        version=$(echo "$raw_version" | awk -F'[^0-9.]' '{print $1}')
    fi
    
    echo "$version"
}

# 테스트
parse_os_version "22.04.1 LTS"  # → "22.04"
parse_os_version "9.2 (Plow)"   # → "9.2"
parse_os_version "20.04.6 LTS"  # → "20.04"
```

---

### Case 7.2: 포인트 릴리스 완전 누락

**문제:**
```
VERSION_ID="7"
# 포인트 릴리스 정보 없음

실제: RHEL 7.9
파싱 결과: "7"
```

**스크립트 처리:**

```bash
function collect_os_info() {
    local os_version="Unknown"
    
    # 우선순위 순서
    if [ -n "$VERSION_ID" ]; then
        os_version=$(parse_os_version "$VERSION_ID")
    elif [ -n "$VERSION" ]; then
        os_version=$(parse_os_version "$VERSION")
    elif [ -f /etc/redhat-release ]; then
        os_version=$(sed -n 's/.*release \([0-9.]*\).*/\1/p' /etc/redhat-release)
    fi
    
    # 보충: lsb_release로 확인 (Debian/Ubuntu)
    if [ -z "$os_version" ] || [ "$os_version" = "Unknown" ]; then
        if command -v lsb_release >/dev/null 2>&1; then
            os_version=$(lsb_release -rs 2>/dev/null)
        fi
    fi
}
```

---

### Case 7.3: 이상한 버전 형식

**문제:**
```
/etc/os-release:
VERSION="Bionic Beaver (no number)"

또는
VERSION_ID="bionic"

파싱 실패
```

**스크립트 처리:**

```bash
function parse_os_version() {
    local raw_version="${1}"
    local version=""
    
    # 1단계: x.y 형식 추출
    version=$(echo "$raw_version" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')
    
    # 2단계: 숫자만 추출
    if [ -z "$version" ]; then
        version=$(echo "$raw_version" | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)
    fi
    
    # 3단계: 코드명 사용 (숫자 불가)
    if [ -z "$version" ]; then
        version="$raw_version"
        warn_log "Could not parse numeric version, using: $version"
    fi
    
    echo "$version"
}

# 테스트
parse_os_version "Bionic Beaver"  # → "Bionic Beaver"
parse_os_version "jammy"          # → "jammy"
parse_os_version "bionic"         # → "bionic"
```

---

## 엣지 케이스 처리 체크리스트

### ✓ 권한 관련
- [x] Non-root 실행 감지 및 처리
- [x] Sudo 권한 불완전 설정
- [x] dmidecode 권한 거부 시 fallback
- [x] /sys/class/dmi 접근 실패 처리

### ✓ 파일 누락
- [x] `/etc/os-release` 없을 때 fallback 체인
- [x] `/proc/cpuinfo` 없을 때 대안 (nproc)
- [x] `/proc/meminfo` 없을 때 dmidecode 우선
- [x] 모든 파일 없을 때 안전한 기본값

### ✓ dmidecode
- [x] 미설치 감지
- [x] 실행 실패 처리
- [x] 비정상 출력 (Unknown, 공백) 필터링
- [x] 결과 검증

### ✓ CPU
- [x] "physical id" 필드 미존재 처리
- [x] "cpu cores" 0 또는 미존재 처리
- [x] "model name" 미존재 (ARM 등)
- [x] 논리/물리 코어 혼동 방지

### ✓ 메모리
- [x] 표준 크기 범위 기반 반올림
- [x] dmidecode/meminfo 상충 처리
- [x] NUMA 시스템 지원
- [x] cgroup 메모리 제한 감지

### ✓ 환경
- [x] 컨테이너 감지 (다중 마커)
- [x] Cloud Provider 감지 (다단계)
- [x] 오감지 방지 (신뢰도 검증)

### ✓ 버전 파싱
- [x] 부 버전 정리 (22.04.1 → 22.04)
- [x] 포인트 릴리스 누락 시 대체
- [x] 이상한 형식 (코드명) 처리

