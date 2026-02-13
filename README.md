# Linux Server Collector

Linux 서버 구성정보 수집 스크립트 v2.0

## 개요
서버의 하드웨어/소프트웨어 구성정보를 자동으로 수집하여 JSON 형태로 출력하는 쉘 스크립트.

## 주요 특징
- 20개 모듈화된 함수 (800+ 줄)
- 20+ 배포판 호환 (RHEL/CentOS/Rocky/AlmaLinux/Debian/Ubuntu 등)
- 컨테이너/클라우드/물리서버 자동 감지
- Non-root 실행 지원 (graceful degradation)
- 메모리 보정 알고리즘 (±0.1~0.2GB 정확도)

## 사용법

```bash
# 기본 실행
sudo ./improved_script.sh > server_info.json

# 상세 로깅
sudo ./improved_script.sh --verbose > server_info.json 2> warn.log

# 디버그 모드
sudo ./improved_script.sh --debug 2> debug.log > server_info.json
```

## 파일 구조
| 파일 | 설명 |
|------|------|
| `improved_script.sh` | 메인 스크립트 (프로덕션용) |
| `updated_improved_script.sh` | 메모리 모듈 통합 버전 |
| `improved_memory_module.sh` | 메모리 보정 모듈 |
| `TEST_CASES.md` | 배포판별 테스트 케이스 (20+개) |
| `EDGE_CASES.md` | 엣지 케이스 분석 (40+개) |
| `VALIDATION_REPORT.md` | 종합 검증 리포트 |
| `MEMORY_CALIBRATION.md` | 메모리 보정 방법론 |
| `MEMORY_TEST_RESULTS.md` | 25개 환경 검증 결과 |

## 검증 결과
- 배포판 호환성: 20/20 ✅
- 기능 검증: 15/15 ✅
- 엣지 케이스: 40/40 ✅
- 환경 감지: 8/8 ✅
