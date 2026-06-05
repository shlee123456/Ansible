#!/bin/bash
# 호스트 시스템 정보 수집 스크립트
#
# 사용법: ./scripts/facts.sh [환경] [필터] [추가옵션]
#   환경: onpremise (기본값), aws
#   필터: ansible_distribution* (기본값)
#
# 예시:
#   ./scripts/facts.sh                           # 온프레미스 배포판 정보
#   ./scripts/facts.sh aws                       # AWS 배포판 정보
#   ./scripts/facts.sh onpremise ansible_memory* # 메모리 정보
#   ./scripts/facts.sh aws ansible_processor*   # CPU 정보

set -e

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ENV=${1:-onpremise}
FILTER=${2:-ansible_distribution*}
shift 2 2>/dev/null || shift 1 2>/dev/null || true

# 작업 디렉토리 이동
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../ansible-$ENV"

echo -e "${GREEN}=== 호스트 시스템 정보 ($ENV) ===${NC}"
echo -e "필터: ${YELLOW}$FILTER${NC}"
echo ""

# 환경별 옵션 설정
if [[ "$ENV" == "onpremise" ]]; then
    DEFAULT_OPTS="-k"
else
    DEFAULT_OPTS=""
fi

ansible -i inventory/hosts all -m setup -a "filter=$FILTER" $DEFAULT_OPTS "$@"
