#!/bin/bash
# SSH 연결 테스트 스크립트
#
# 사용법: ./scripts/ping.sh [환경] [추가옵션]
#   환경: onpremise (기본값), aws
#
# 예시:
#   ./scripts/ping.sh              # 온프레미스 연결 테스트
#   ./scripts/ping.sh aws          # AWS 연결 테스트
#   ./scripts/ping.sh onpremise -k # 비밀번호 입력 모드

set -e

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ENV=${1:-onpremise}
shift 2>/dev/null || true

# 작업 디렉토리 이동
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../ansible-$ENV"

echo -e "${GREEN}=== SSH 연결 테스트 ($ENV) ===${NC}"

# 환경별 옵션 설정
if [[ "$ENV" == "onpremise" ]]; then
    DEFAULT_OPTS="-k"
else
    DEFAULT_OPTS=""
fi

ansible -i inventory/hosts all -m ping $DEFAULT_OPTS "$@"
