# Linux 배포판별 테스트 케이스 및 예상 출력값

## 목차
1. [RHEL Family](#rhel-family)
2. [CentOS](#centos)
3. [Ubuntu / Debian](#ubuntu--debian)
4. [Rocky Linux / AlmaLinux](#rocky-linux--almalinux)
5. [Special Environments](#special-environments)

---

## RHEL Family

### RHEL 7.x

**테스트 환경 정보:**
- 이름: Red Hat Enterprise Linux 7.x
- OS 파일: `/etc/redhat-release`, `/etc/os-release`
- 특징: systemd 미지원 (RHEL 7.0-7.2)부터 일부 지원

**환경 파일 구성:**

```
/etc/redhat-release:
Red Hat Enterprise Linux Server release 7.9 (Maipo)

/etc/os-release:
NAME="Red Hat Enterprise Linux Server"
VERSION="7.9 (Maipo)"
ID="rhel"
ID_LIKE="fedora"
VERSION_ID="7.9"
PRETTY_NAME="Red Hat Enterprise Linux Server 7.9 (Maipo)"
```

**예상 출력값:**

```json
{
  "OS_NAME": "Red Hat Enterprise Linux Server",
  "OS_VERSION": "7.9",
  "KERNEL_VERSION": "3.10.0-1160.36.2.el7.x86_64",
  "INFRA_TYPE": "Physical|VM|AWS|Azure|GCP",
  "HW_MODEL": "Dell Inc. PowerEdge R640|VMware Virtual Platform",
  "SERIAL_NUMBER": "ABCD123456|vpc-xxxxx",
  "CPU_COUNT": 2,
  "CPU_TOTAL_CORES": 16,
  "CPU_MODEL": "Intel(R) Xeon(R) CPU E5-2680 v4 @ 2.40GHz",
  "MEMORY_COUNT": 4,
  "MEMORY_INDIVIDUAL_GB": "8 8 8 8",
  "MEMORY_TOTAL_GB": "32",
  "DDR_INFO": "DDR4"
}
```

**특이사항:**
- `/proc/cpuinfo` 형식: `processor`, `physical id`, `cpu cores` 필드 모두 존재
- dmidecode 설치 여부: Red Hat에서는 일반적으로 설치되어 있음
- `/etc/os-release`에서 `VERSION_ID`에 포인트 릴리스 포함 (7.9)

---

### RHEL 8.x

**테스트 환경 정보:**
- 이름: Red Hat Enterprise Linux 8.x
- OS 파일: `/etc/os-release` (주), `/etc/redhat-release` (보조)
- 특징: systemd 완전 지원, dnf 패키지 관리자

**환경 파일 구성:**

```
/etc/redhat-release:
Red Hat Enterprise Linux release 8.8 (Ootpa)

/etc/os-release:
NAME="Red Hat Enterprise Linux"
VERSION="8.8 (Ootpa)"
ID="rhel"
ID_LIKE="fedora"
VERSION_ID="8.8"
PRETTY_NAME="Red Hat Enterprise Linux 8.8 (Ootpa)"
```

**예상 출력값:**

```json
{
  "OS_NAME": "Red Hat Enterprise Linux",
  "OS_VERSION": "8.8",
  "KERNEL_VERSION": "4.18.0-477.21.1.el8_8.x86_64",
  "INFRA_TYPE": "Physical|VM|AWS|Azure|GCP",
  "HW_MODEL": "Dell Inc. PowerEdge R750|QEMU Standard PC",
  "SERIAL_NUMBER": "SERIAL123|i-0123456789abcdef",
  "CPU_COUNT": 4,
  "CPU_TOTAL_CORES": 32,
  "CPU_MODEL": "Intel(R) Xeon(R) Platinum 8180 CPU @ 2.50GHz",
  "MEMORY_COUNT": 8,
  "MEMORY_INDIVIDUAL_GB": "16 16 16 16 16 16 16 16",
  "MEMORY_TOTAL_GB": "128",
  "DDR_INFO": "DDR4"
}
```

**특이사항:**
- RHEL 7과 유사하지만 더 최신 커널 (4.18.0)
- `VERSION_ID`에 포인트 릴리스 포함 (8.8)

---

### RHEL 9.x

**테스트 환경 정보:**
- 이름: Red Hat Enterprise Linux 9.x
- 특징: 최신 기술 스택, SELinux 기본 활성화

**환경 파일 구성:**

```
/etc/redhat-release:
Red Hat Enterprise Linux release 9.2 (Plow)

/etc/os-release:
NAME="Red Hat Enterprise Linux"
VERSION="9.2 (Plow)"
ID="rhel"
ID_LIKE="fedora"
VERSION_ID="9.2"
```

**예상 출력값:**

```json
{
  "OS_NAME": "Red Hat Enterprise Linux",
  "OS_VERSION": "9.2",
  "KERNEL_VERSION": "5.14.0-284.11.1.el9_2.x86_64",
  "INFRA_TYPE": "Physical|VM|AWS|Azure|GCP",
  "HW_MODEL": "HP ProLiant DL380 Gen10 Plus|Google Compute Engine",
  "SERIAL_NUMBER": "SGH123ABC|GoogleCloud-XXXXX",
  "CPU_COUNT": 8,
  "CPU_TOTAL_CORES": 64,
  "CPU_MODEL": "Intel(R) Xeon(R) Platinum 8375C CPU @ 2.90GHz",
  "MEMORY_COUNT": 16,
  "MEMORY_INDIVIDUAL_GB": "8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8",
  "MEMORY_TOTAL_GB": "128",
  "DDR_INFO": "DDR4"
}
```

**특이사항:**
- 최신 커널 버전 (5.14.0)
- `VERSION_ID`에 포인트 릴리스 포함 (9.2)

---

## CentOS

### CentOS 7

**테스트 환경 정보:**
- 이름: CentOS Linux 7 (Core)
- 배포 종료: 2024-06-30

**환경 파일 구성:**

```
/etc/redhat-release:
CentOS Linux release 7.9.2009 (Core)

/etc/os-release:
NAME="CentOS Linux"
VERSION="7 (Core)"
ID="centos"
ID_LIKE="rhel fedora"
VERSION_ID="7"
```

**예상 출력값:**

```json
{
  "OS_NAME": "CentOS Linux",
  "OS_VERSION": "7",
  "KERNEL_VERSION": "3.10.0-1160.90.1.el7.x86_64",
  "CPU_COUNT": 2,
  "CPU_TOTAL_CORES": 8,
  "CPU_MODEL": "Intel(R) Core(TM) i7-9700K CPU @ 3.60GHz",
  "MEMORY_COUNT": 2,
  "MEMORY_INDIVIDUAL_GB": "8 8",
  "MEMORY_TOTAL_GB": "16",
  "DDR_INFO": "DDR4"
}
```

---

### CentOS 8

**테스트 환경 정보:**
- 이름: CentOS Linux 8 (Core)
- 배포 종료: 2021-12-31 (Red Hat에 의해 지원 중단)

**환경 파일 구성:**

```
/etc/redhat-release:
CentOS Linux release 8.5.2111 (Core)

/etc/os-release:
NAME="CentOS Linux"
VERSION="8"
ID="centos"
ID_LIKE="rhel fedora"
VERSION_ID="8"
PLATFORM_ID="platform:el8"
```

**예상 출력값:**

```json
{
  "OS_NAME": "CentOS Linux",
  "OS_VERSION": "8",
  "KERNEL_VERSION": "4.18.0-348.12.2.el8_5.x86_64",
  "CPU_COUNT": 4,
  "CPU_TOTAL_CORES": 16,
  "CPU_MODEL": "AMD EPYC 7301 16-Core Processor",
  "MEMORY_COUNT": 4,
  "MEMORY_INDIVIDUAL_GB": "8 8 8 8",
  "MEMORY_TOTAL_GB": "32",
  "DDR_INFO": "DDR4"
}
```

---

### CentOS Stream

**테스트 환경 정보:**
- 이름: CentOS Stream 9
- 특징: 새로운 모델, RHEL의 상류 개발 버전

**환경 파일 구성:**

```
/etc/redhat-release:
CentOS Stream release 9

/etc/os-release:
NAME="CentOS Stream"
VERSION="9"
ID="centos"
ID_LIKE="rhel fedora"
VERSION_ID="9"
PLATFORM_ID="platform:el9"
```

**예상 출력값:**

```json
{
  "OS_NAME": "CentOS Stream",
  "OS_VERSION": "9",
  "KERNEL_VERSION": "5.14.0-284.el9.x86_64",
  "CPU_COUNT": 4,
  "CPU_TOTAL_CORES": 32,
  "CPU_MODEL": "Intel(R) Xeon(R) Gold 6326 CPU @ 2.90GHz",
  "MEMORY_COUNT": 8,
  "MEMORY_INDIVIDUAL_GB": "8 8 8 8 8 8 8 8",
  "MEMORY_TOTAL_GB": "64",
  "DDR_INFO": "DDR4"
}
```

---

## Ubuntu / Debian

### Ubuntu 18.04 LTS

**테스트 환경 정보:**
- 코드명: Bionic Beaver
- 지원 종료: 2023-04-30
- 특징: systemd, `/proc/cpuinfo`에 `core_id` 필드 포함

**환경 파일 구성:**

```
/etc/os-release:
NAME="Ubuntu"
VERSION="18.04.6 LTS (Bionic Beaver)"
ID=ubuntu
ID_LIKE=debian
VERSION_ID="18.04"
PRETTY_NAME="Ubuntu 18.04.6 LTS"
```

**예상 출력값:**

```json
{
  "OS_NAME": "Ubuntu",
  "OS_VERSION": "18.04",
  "KERNEL_VERSION": "5.4.0-150-generic",
  "INFRA_TYPE": "VM|AWS|Azure",
  "HW_MODEL": "VMware Virtual Platform|t2.xlarge (AWS)",
  "SERIAL_NUMBER": "uuid-123-456|i-abcdef1234567",
  "CPU_COUNT": 2,
  "CPU_TOTAL_CORES": 4,
  "CPU_MODEL": "Intel(R) Xeon(R) CPU E5-2686 v4 @ 2.30GHz",
  "MEMORY_COUNT": 0,
  "MEMORY_INDIVIDUAL_GB": "8",
  "MEMORY_TOTAL_GB": "8",
  "DDR_INFO": "N/A"
}
```

**특이사항:**
- `/proc/cpuinfo`에 `core_id` 필드 있음
- dmidecode 설치되지 않을 수 있음
- `/proc/meminfo` 기반 메모리 계산

---

### Ubuntu 20.04 LTS

**테스트 환경 정보:**
- 코드명: Focal Fossa
- 지원 기간: 2025-04 (표준), 2030-04 (Pro)
- 특징: systemd, AppArmor, modern tooling

**환경 파일 구성:**

```
/etc/os-release:
NAME="Ubuntu"
VERSION="20.04.6 LTS (Focal Fossa)"
ID=ubuntu
ID_LIKE=debian
VERSION_ID="20.04"
PRETTY_NAME="Ubuntu 20.04.6 LTS"
```

**예상 출력값:**

```json
{
  "OS_NAME": "Ubuntu",
  "OS_VERSION": "20.04",
  "KERNEL_VERSION": "5.15.0-84-generic",
  "INFRA_TYPE": "VM|AWS|Container",
  "HW_MODEL": "QEMU Standard PC|t3.2xlarge",
  "SERIAL_NUMBER": "standard-pc|i-1234567890abcdef",
  "CPU_COUNT": 4,
  "CPU_TOTAL_CORES": 8,
  "CPU_MODEL": "Intel(R) Xeon(R) Platinum 8375C CPU @ 2.90GHz",
  "MEMORY_COUNT": 0,
  "MEMORY_INDIVIDUAL_GB": "16",
  "MEMORY_TOTAL_GB": "16",
  "DDR_INFO": "N/A"
}
```

---

### Ubuntu 22.04 LTS

**테스트 환경 정보:**
- 코드명: Jammy Jellyfish
- 지원 기간: 2027-04 (표준), 2032-04 (Pro)
- 특징: Python 3.10, modern container support

**환경 파일 구성:**

```
/etc/os-release:
NAME="Ubuntu"
VERSION="22.04.3 LTS (Jammy Jellyfish)"
ID=ubuntu
ID_LIKE=debian
VERSION_ID="22.04"
PRETTY_NAME="Ubuntu 22.04.3 LTS"
```

**예상 출력값:**

```json
{
  "OS_NAME": "Ubuntu",
  "OS_VERSION": "22.04",
  "KERNEL_VERSION": "6.2.0-39-generic",
  "INFRA_TYPE": "VM|AWS|Azure|GCP",
  "HW_MODEL": "VMware Virtual Platform|c5.4xlarge|Standard_D16s_v3|n2-highmem-8",
  "SERIAL_NUMBER": "vmware-uuid|i-098765432abcdef|Azure-UUID|gce-instance-uuid",
  "CPU_COUNT": 4,
  "CPU_TOTAL_CORES": 16,
  "CPU_MODEL": "Intel(R) Xeon(R) Platinum 8375C CPU @ 2.90GHz",
  "MEMORY_COUNT": 0,
  "MEMORY_INDIVIDUAL_GB": "32",
  "MEMORY_TOTAL_GB": "32",
  "DDR_INFO": "N/A"
}
```

---

### Ubuntu 24.04 LTS

**테스트 환경 정보:**
- 코드명: Noble Numbat
- 지원 기간: 2029-04 (표준), 2034-04 (Pro)
- 특징: Latest stable, modern tooling, improved cloud support

**환경 파일 구성:**

```
/etc/os-release:
NAME="Ubuntu"
VERSION="24.04 LTS (Noble Numbat)"
ID=ubuntu
ID_LIKE=debian
VERSION_ID="24.04"
PRETTY_NAME="Ubuntu 24.04 LTS"
```

**예상 출력값:**

```json
{
  "OS_NAME": "Ubuntu",
  "OS_VERSION": "24.04",
  "KERNEL_VERSION": "6.8.0-35-generic",
  "INFRA_TYPE": "VM|AWS|Azure|GCP|Container",
  "HW_MODEL": "KVM Virtual Machine|r7i.4xlarge|Standard_E16s_v5|m2-ultramem-416",
  "SERIAL_NUMBER": "kvm-uuid|i-fedcba9876543210|Azure-UUID-2024|gce-uuid-2024",
  "CPU_COUNT": 8,
  "CPU_TOTAL_CORES": 32,
  "CPU_MODEL": "Intel(R) Xeon(R) Platinum 8490H CPU @ 3.00GHz",
  "MEMORY_COUNT": 0,
  "MEMORY_INDIVIDUAL_GB": "64",
  "MEMORY_TOTAL_GB": "64",
  "DDR_INFO": "N/A"
}
```

---

### Debian 10 (Buster)

**테스트 환경 정보:**
- 릴리스 날짜: 2019-07-06
- 지원 종료: 2024-06-30
- 특징: Python 3.7, modern systemd

**환경 파일 구성:**

```
/etc/os-release:
NAME="Debian GNU/Linux"
VERSION="10 (Buster)"
ID=debian
VERSION_ID="10"
PRETTY_NAME="Debian GNU/Linux 10 (Buster)"

/etc/debian_version:
10.13
```

**예상 출력값:**

```json
{
  "OS_NAME": "Debian GNU/Linux",
  "OS_VERSION": "10",
  "KERNEL_VERSION": "4.19.0-26-amd64",
  "CPU_COUNT": 2,
  "CPU_TOTAL_CORES": 4,
  "CPU_MODEL": "Intel(R) Core(TM) i5-8400 CPU @ 2.80GHz",
  "MEMORY_COUNT": 0,
  "MEMORY_INDIVIDUAL_GB": "8",
  "MEMORY_TOTAL_GB": "8",
  "DDR_INFO": "N/A"
}
```

---

### Debian 11 (Bullseye)

**테스트 환경 정보:**
- 릴리스 날짜: 2021-08-14
- 지원 종료: 2026-08-31
- 특징: Python 3.9, systemd 248

**환경 파일 구성:**

```
/etc/os-release:
NAME="Debian GNU/Linux"
VERSION="11 (Bullseye)"
ID=debian
VERSION_ID="11"
PRETTY_NAME="Debian GNU/Linux 11 (Bullseye)"
```

**예상 출력값:**

```json
{
  "OS_NAME": "Debian GNU/Linux",
  "OS_VERSION": "11",
  "KERNEL_VERSION": "5.10.0-27-amd64",
  "CPU_COUNT": 4,
  "CPU_TOTAL_CORES": 8,
  "CPU_MODEL": "AMD Ryzen 7 3700X 8-Core Processor",
  "MEMORY_COUNT": 0,
  "MEMORY_INDIVIDUAL_GB": "16",
  "MEMORY_TOTAL_GB": "16",
  "DDR_INFO": "N/A"
}
```

---

### Debian 12 (Bookworm)

**테스트 환경 정보:**
- 릴리스 날짜: 2023-06-10
- 지원 기간: 2028-06-30 (표준), 2033-06-30 (LTS)
- 특징: Python 3.11, latest tooling

**환경 파일 구성:**

```
/etc/os-release:
NAME="Debian GNU/Linux"
VERSION="12 (Bookworm)"
ID=debian
VERSION_ID="12"
PRETTY_NAME="Debian GNU/Linux 12 (Bookworm)"
```

**예상 출력값:**

```json
{
  "OS_NAME": "Debian GNU/Linux",
  "OS_VERSION": "12",
  "KERNEL_VERSION": "6.1.0-17-amd64",
  "CPU_COUNT": 8,
  "CPU_TOTAL_CORES": 16,
  "CPU_MODEL": "Intel(R) Xeon(R) W9-3595X CPU @ 2.00GHz",
  "MEMORY_COUNT": 0,
  "MEMORY_INDIVIDUAL_GB": "32",
  "MEMORY_TOTAL_GB": "32",
  "DDR_INFO": "N/A"
}
```

---

## Rocky Linux / AlmaLinux

### Rocky Linux 8.x

**테스트 환경 정보:**
- 프로젝트: RHEL 8 호환 대체
- 릴리스: 2021년 이후
- 특징: 높은 RHEL 호환성, Enterprise 사용자 지향

**환경 파일 구성:**

```
/etc/redhat-release:
Rocky Linux release 8.8 (Green Obsidian)

/etc/os-release:
NAME="Rocky Linux"
VERSION="8.8 (Green Obsidian)"
ID="rocky"
ID_LIKE="rhel fedora"
VERSION_ID="8.8"
```

**예상 출력값:**

```json
{
  "OS_NAME": "Rocky Linux",
  "OS_VERSION": "8.8",
  "KERNEL_VERSION": "4.18.0-477.21.1.el8_8.x86_64",
  "INFRA_TYPE": "Physical|VM",
  "HW_MODEL": "Dell Inc. PowerEdge R750",
  "SERIAL_NUMBER": "SERIAL456",
  "CPU_COUNT": 4,
  "CPU_TOTAL_CORES": 32,
  "CPU_MODEL": "Intel(R) Xeon(R) Platinum 8375C CPU @ 2.90GHz",
  "MEMORY_COUNT": 8,
  "MEMORY_INDIVIDUAL_GB": "16 16 16 16 16 16 16 16",
  "MEMORY_TOTAL_GB": "128",
  "DDR_INFO": "DDR4"
}
```

---

### Rocky Linux 9.x

**테스트 환경 정보:**
- 프로젝트: RHEL 9 호환 대체
- 최신 안정 버전

**환경 파일 구성:**

```
/etc/redhat-release:
Rocky Linux release 9.2 (Blue Onyx)

/etc/os-release:
NAME="Rocky Linux"
VERSION="9.2 (Blue Onyx)"
ID="rocky"
ID_LIKE="rhel fedora"
VERSION_ID="9.2"
```

**예상 출력값:**

```json
{
  "OS_NAME": "Rocky Linux",
  "OS_VERSION": "9.2",
  "KERNEL_VERSION": "5.14.0-284.11.1.el9_2.x86_64",
  "CPU_COUNT": 8,
  "CPU_TOTAL_CORES": 64,
  "CPU_MODEL": "Intel(R) Xeon(R) Platinum 8490H CPU @ 3.00GHz",
  "MEMORY_COUNT": 16,
  "MEMORY_INDIVIDUAL_GB": "8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8",
  "MEMORY_TOTAL_GB": "128",
  "DDR_INFO": "DDR4"
}
```

---

### AlmaLinux 8.x

**테스트 환경 정보:**
- 프로젝트: RHEL 8 호환 대체
- 후원사: CloudLinux Inc.

**환경 파일 구성:**

```
/etc/redhat-release:
AlmaLinux release 8.8 (Sapphire Caracal)

/etc/os-release:
NAME="AlmaLinux"
VERSION="8.8 (Sapphire Caracal)"
ID="almalinux"
ID_LIKE="rhel fedora"
VERSION_ID="8.8"
```

**예상 출력값:**

```json
{
  "OS_NAME": "AlmaLinux",
  "OS_VERSION": "8.8",
  "KERNEL_VERSION": "4.18.0-477.21.1.el8_8.x86_64",
  "CPU_COUNT": 4,
  "CPU_TOTAL_CORES": 16,
  "CPU_MODEL": "Intel(R) Xeon(R) Gold 6326 CPU @ 2.90GHz",
  "MEMORY_COUNT": 4,
  "MEMORY_INDIVIDUAL_GB": "16 16 16 16",
  "MEMORY_TOTAL_GB": "64",
  "DDR_INFO": "DDR4"
}
```

---

### AlmaLinux 9.x

**테스트 환경 정보:**
- 프로젝트: RHEL 9 호환 대체
- 최신 버전

**환경 파일 구성:**

```
/etc/redhat-release:
AlmaLinux release 9.2 (Caracara)

/etc/os-release:
NAME="AlmaLinux"
VERSION="9.2 (Caracara)"
ID="almalinux"
ID_LIKE="rhel fedora"
VERSION_ID="9.2"
```

**예상 출력값:**

```json
{
  "OS_NAME": "AlmaLinux",
  "OS_VERSION": "9.2",
  "KERNEL_VERSION": "5.14.0-284.11.1.el9_2.x86_64",
  "CPU_COUNT": 8,
  "CPU_TOTAL_CORES": 32,
  "CPU_MODEL": "AMD EPYC 7513 32-Core Processor",
  "MEMORY_COUNT": 8,
  "MEMORY_INDIVIDUAL_GB": "16 16 16 16 16 16 16 16",
  "MEMORY_TOTAL_GB": "128",
  "DDR_INFO": "DDR4"
}
```

---

## Special Environments

### Docker Container (Ubuntu 22.04 기반)

**테스트 환경 정보:**
- 이름: Docker Container
- 기반: ubuntu:22.04
- 특징: 호스트 커널 공유, 리소스 제한 가능

**환경 특성:**

```
/proc/1/cgroup: 
11:perf_event:/docker/abc123def456...
10:pids:/docker/abc123def456...
...

/run/.containerenv: (존재)
/.dockerenv: (존재)

/proc/cpuinfo: 호스트와 동일 (전체 CPU 표시)
/proc/meminfo: cgroup 제한이 적용될 수 있음
```

**예상 출력값:**

```json
{
  "OS_NAME": "Ubuntu",
  "OS_VERSION": "22.04",
  "KERNEL_VERSION": "5.15.0-84-generic",
  "INFRA_TYPE": "Container",
  "HW_MODEL": "Container",
  "SERIAL_NUMBER": "N/A",
  "CPU_COUNT": 1,
  "CPU_TOTAL_CORES": 4,  # 호스트 또는 cgroup 제한
  "CPU_MODEL": "Intel(R) Xeon(R) CPU @ 2.40GHz",
  "MEMORY_COUNT": 0,
  "MEMORY_INDIVIDUAL_GB": "2",
  "MEMORY_TOTAL_GB": "2",  # cgroup 제한이 2GB인 경우
  "DDR_INFO": "N/A",
  "IS_CONTAINER": "Yes"
}
```

---

### Kubernetes Pod (Ubuntu 22.04 기반)

**테스트 환경 정보:**
- 이름: Kubernetes Pod
- 기반: ubuntu:22.04
- 특징: Docker보다 더 많은 제약

**환경 특성:**

```
/proc/1/cgroup:
10:cpuset:/kubepods.slice/kubepods-pod12345678.slice/cri-containerd-...
...

/etc/os-release: 호스트와 동일
```

**예상 출력값:**

```json
{
  "OS_NAME": "Ubuntu",
  "OS_VERSION": "22.04",
  "KERNEL_VERSION": "5.15.0-84-generic",
  "INFRA_TYPE": "Container",
  "HW_MODEL": "Container",
  "SERIAL_NUMBER": "N/A",
  "CPU_COUNT": 1,
  "CPU_TOTAL_CORES": 2,  # Pod 요청 CPU
  "CPU_MODEL": "Intel(R) Xeon(R) CPU @ 2.40GHz",
  "MEMORY_COUNT": 0,
  "MEMORY_INDIVIDUAL_GB": "4",
  "MEMORY_TOTAL_GB": "4",  # Pod 메모리 제한
  "DDR_INFO": "N/A",
  "IS_CONTAINER": "Yes"
}
```

---

### AWS EC2 (Ubuntu 22.04)

**테스트 환경 정보:**
- 인스턴스 유형: t3.2xlarge
- 베이스 이미지: ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*
- 특징: cloud-init, AWS 특화 도구

**환경 파일 구성:**

```
/etc/cloud/cloud.cfg:
datasource_list: [AWS]
cloud_init_modules:
  - ec2-handle-user-data
  ...

/proc/cpuinfo: AWS Nitro 하이퍼바이저의 CPU 정보
```

**예상 출력값:**

```json
{
  "OS_NAME": "Ubuntu",
  "OS_VERSION": "22.04",
  "KERNEL_VERSION": "6.2.0-39-generic",
  "INFRA_TYPE": "AWS",
  "HW_MODEL": "t3.2xlarge",
  "SERIAL_NUMBER": "i-0123456789abcdef0",
  "CPU_COUNT": 1,
  "CPU_TOTAL_CORES": 8,  # t3.2xlarge의 vCPU
  "CPU_MODEL": "Intel(R) Xeon(R) Platinum 8259CL CPU @ 2.50GHz",
  "MEMORY_COUNT": 0,
  "MEMORY_INDIVIDUAL_GB": "32",
  "MEMORY_TOTAL_GB": "32",
  "DDR_INFO": "N/A",
  "PERMISSION_LEVEL": "ec2-user|ubuntu"
}
```

---

### Azure VM (RHEL 9)

**테스트 환경 정보:**
- VM 크기: Standard_D8s_v3
- 이미지: RHEL 9.2
- 특징: Azure 에이전트, cloud-init

**환경 파일 구성:**

```
/var/lib/waagent/: Azure 에이전트 디렉토리 존재
/etc/cloud/cloud.cfg: Azure datasource 설정
```

**예상 출력값:**

```json
{
  "OS_NAME": "Red Hat Enterprise Linux",
  "OS_VERSION": "9.2",
  "KERNEL_VERSION": "5.14.0-284.el9.x86_64",
  "INFRA_TYPE": "Azure",
  "HW_MODEL": "Standard_D8s_v3",
  "SERIAL_NUMBER": "Azure-UUID-format",
  "CPU_COUNT": 1,
  "CPU_TOTAL_CORES": 8,
  "CPU_MODEL": "Intel(R) Xeon(R) Platinum 8272CL CPU @ 2.60GHz",
  "MEMORY_COUNT": 0,
  "MEMORY_INDIVIDUAL_GB": "32",
  "MEMORY_TOTAL_GB": "32",
  "DDR_INFO": "N/A"
}
```

---

### GCP Compute Engine (Debian 12)

**테스트 환경 정보:**
- 머신 유형: n2-highmem-8
- 이미지: debian-12
- 특징: gcloud CLI, cloud-init

**환경 파일 구성:**

```
/etc/cloud/cloud.cfg: GCP datasource 설정
/usr/bin/gcloud: GCP 도구 설치됨
```

**예상 출력값:**

```json
{
  "OS_NAME": "Debian GNU/Linux",
  "OS_VERSION": "12",
  "KERNEL_VERSION": "6.1.0-17-amd64",
  "INFRA_TYPE": "GCP",
  "HW_MODEL": "n2-highmem-8",
  "SERIAL_NUMBER": "gce-instance-uuid-format",
  "CPU_COUNT": 1,
  "CPU_TOTAL_CORES": 8,
  "CPU_MODEL": "Intel(R) Xeon(R) CPU @ 2.80GHz",
  "MEMORY_COUNT": 0,
  "MEMORY_INDIVIDUAL_GB": "64",
  "MEMORY_TOTAL_GB": "64",
  "DDR_INFO": "N/A"
}
```

---

### Non-Root 사용자 실행

**테스트 환경 정보:**
- 권한: 일반 사용자 (sudo 없음)
- 결과: 일부 정보 제한

**예상 출력값:**

```json
{
  "OS_NAME": "Ubuntu",
  "OS_VERSION": "22.04",
  "KERNEL_VERSION": "6.2.0-39-generic",
  "INFRA_TYPE": "Unknown",  # dmidecode 접근 불가
  "HW_MODEL": "Unknown",     # dmidecode 접근 불가
  "SERIAL_NUMBER": "Unknown", # dmidecode 접근 불가
  "CPU_COUNT": 4,            # /proc/cpuinfo에서 읽음
  "CPU_TOTAL_CORES": 8,      # /proc/cpuinfo에서 읽음
  "CPU_MODEL": "Intel(R) Xeon(R) CPU @ 2.40GHz",
  "MEMORY_COUNT": 0,         # dmidecode 접근 불가
  "MEMORY_INDIVIDUAL_GB": "16",
  "MEMORY_TOTAL_GB": "16",   # /proc/meminfo에서 읽음
  "DDR_INFO": "Unknown",      # dmidecode 접근 불가
  "PERMISSION_LEVEL": "user"
}
```

---

## 테스트 케이스 검증 체크리스트

### ✓ 각 배포판별 확인사항

- [ ] `/etc/os-release` 파일 존재 및 형식
- [ ] `/etc/redhat-release` 또는 `/etc/debian_version` 형식
- [ ] `uname -r` 커널 버전 출력
- [ ] `/proc/cpuinfo` 형식 (필드: processor, physical id, cpu cores, core_id)
- [ ] `/proc/meminfo` MemTotal 항목 존재 여부
- [ ] dmidecode 설치 여부 및 권한
- [ ] cloud-init 설정 파일 존재 여부
- [ ] 컨테이너 환경 마커 파일 (/.dockerenv, /run/.containerenv)

### ✓ 기능별 검증

- [ ] OS 이름 파싱 정확성
- [ ] OS 버전 파싱 (부 버전 제거 확인)
- [ ] CPU 개수 (소켓 vs vCPU) 올바른 감지
- [ ] 메모리 크기 올바른 반올림
- [ ] 인프라 유형 정확한 감지
- [ ] Non-root 실행 시 graceful fallback
- [ ] 컨테이너 환경 감지
- [ ] 클라우드 공급자 감지 (AWS/Azure/GCP)

