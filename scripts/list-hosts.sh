#!/bin/bash
# 인벤토리 호스트 목록 조회 스크립트
#
# 사용법: ./scripts/list-hosts.sh [환경]
#   환경: onpremise (기본값), aws, all
#
# 예시:
#   ./scripts/list-hosts.sh          # 온프레미스 호스트 목록
#   ./scripts/list-hosts.sh aws      # AWS 호스트 목록
#   ./scripts/list-hosts.sh all      # 전체 호스트 목록

set -e

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ENV=${1:-onpremise}

# 작업 디렉토리
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."

show_hosts() {
    local env=$1
    local dir="$ROOT_DIR/ansible-$env"
    
    if [[ -d "$dir" ]]; then
        echo -e "${GREEN}=== $env 환경 호스트 ===${NC}"
        cd "$dir"
        ansible-inventory -i inventory/hosts --list --yaml 2>/dev/null | head -50
        echo ""
    fi
}

if [[ "$ENV" == "all" ]]; then
    show_hosts "onpremise"
    show_hosts "aws"
else
    show_hosts "$ENV"
fi
