#!/bin/bash
# Ansible 플레이북 실행 스크립트 (온프레미스 환경)
#
# 사용법: ./start.sh [옵션]
#   -c, --check    드라이런 모드 (변경 없이 미리보기)
#   -l, --limit    특정 호스트만 실행 (예: -l work-node1)
#   -t, --tags     특정 태그만 실행 (예: -t docker)
#   -v, --verbose  상세 출력 레벨 증가 (-vvv까지 가능)
#   -h, --help     도움말 출력
#
# 예시:
#   ./start.sh                    # 기본 실행 (전체 호스트)
#   ./start.sh -c                 # 드라이런 모드
#   ./start.sh -l work-node1      # work-node1만 실행
#   ./start.sh -c -l test-node1   # test-node1 드라이런
#   ./start.sh -t docker          # docker 태그만 실행

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 기본값
MODE=""
LIMIT=""
TAGS=""
VERBOSE="-v"

# 도움말 출력
show_help() {
    echo "사용법: ./start.sh [옵션]"
    echo ""
    echo "옵션:"
    echo "  -c, --check     드라이런 모드 (변경 없이 미리보기)"
    echo "  -l, --limit     특정 호스트만 실행 (예: -l work-node1)"
    echo "  -t, --tags      특정 태그만 실행 (예: -t docker)"
    echo "  -v, --verbose   상세 출력 레벨 증가 (최대 -vvv)"
    echo "  -h, --help      이 도움말 출력"
    echo ""
    echo "예시:"
    echo "  ./start.sh                    # 기본 실행"
    echo "  ./start.sh -c                 # 드라이런 모드"
    echo "  ./start.sh -l work-node1      # 특정 호스트만"
    echo "  ./start.sh -c -l test-node1   # 드라이런 + 특정 호스트"
    exit 0
}

# 옵션 파싱
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--check)
            MODE="--check --diff"
            shift
            ;;
        -l|--limit)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo -e "${RED}오류: -l 옵션에 호스트명이 필요합니다${NC}"
                exit 1
            fi
            LIMIT="-l $2"
            shift 2
            ;;
        -t|--tags)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo -e "${RED}오류: -t 옵션에 태그명이 필요합니다${NC}"
                exit 1
            fi
            TAGS="--tags $2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE="-vvv"
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}알 수 없는 옵션: $1${NC}"
            echo "도움말: ./start.sh -h"
            exit 1
            ;;
    esac
done

# 실행 정보 출력
echo -e "${GREEN}=== Ansible 플레이북 실행 (온프레미스) ===${NC}"
echo -e "모드: ${YELLOW}${MODE:-'실제 적용'}${NC}"
[[ -n "$LIMIT" ]] && echo -e "대상 호스트: ${YELLOW}${LIMIT#-l }${NC}"
[[ -n "$TAGS" ]] && echo -e "태그: ${YELLOW}${TAGS#--tags }${NC}"
echo ""

# 플레이북 실행 (인증 우선순위)
# 1) .vault_pass 존재     → Vault 가 비밀번호 복호화, 프롬프트 없음 (기본 경로)
# 2) SSHPASS 환경변수     → -e 변수 주입으로 비대화식 (vault 변수보다 우선)
# 3) 둘 다 없음           → Vault 비밀번호 프롬프트 (--ask-vault-pass)
#    (vault.yml 이 암호화돼 있어 -k -K 만으로는 변수 로딩이 불가)
if [[ -n "$SSHPASS" ]]; then
    echo -e "${GREEN}SSHPASS 감지 → 비대화식 실행${NC}"
    ansible-playbook -i inventory/hosts playbook.yml \
        -e 'ansible_password={{ lookup("env","SSHPASS") }}' \
        -e 'ansible_become_pass={{ lookup("env","SSHPASS") }}' \
        $VERBOSE $MODE $LIMIT $TAGS
elif [[ -f .vault_pass ]]; then
    echo -e "${GREEN}.vault_pass 감지 → Vault 비대화식 실행${NC}"
    ansible-playbook -i inventory/hosts playbook.yml $VERBOSE $MODE $LIMIT $TAGS
else
    echo -e "${YELLOW}.vault_pass 없음 → Vault 비밀번호 프롬프트${NC}"
    ansible-playbook -i inventory/hosts playbook.yml --ask-vault-pass $VERBOSE $MODE $LIMIT $TAGS
fi
