#!/bin/bash
# pyenv 가상환경 설정 스크립트
#
# 사용법: ./scripts/setup-env.sh
#
# 이 스크립트는 다음을 수행합니다:
# 1. pyenv가 설치되어 있는지 확인
# 2. Python 3.11 설치 (없는 경우)
# 3. 'ansible' 가상환경 생성
# 4. Ansible 및 필수 패키지 설치

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PYTHON_VERSION="3.11"
VENV_NAME="ansible-onpremise"

echo -e "${CYAN}=== Ansible 개발환경 설정 ===${NC}"
echo ""

# 1. pyenv 확인
echo -e "${YELLOW}[1/5] pyenv 확인 중...${NC}"
if ! command -v pyenv &> /dev/null; then
    echo -e "${RED}오류: pyenv가 설치되어 있지 않습니다.${NC}"
    echo ""
    echo "pyenv 설치 방법:"
    echo "  macOS:  brew install pyenv pyenv-virtualenv"
    echo "  Linux:  curl https://pyenv.run | bash"
    echo ""
    echo "설치 후 쉘 설정 파일에 다음 추가:"
    echo '  export PYENV_ROOT="$HOME/.pyenv"'
    echo '  export PATH="$PYENV_ROOT/bin:$PATH"'
    echo '  eval "$(pyenv init -)"'
    echo '  eval "$(pyenv virtualenv-init -)"'
    exit 1
fi
echo -e "${GREEN}✓ pyenv 발견: $(pyenv --version)${NC}"

# 2. pyenv-virtualenv 확인
echo -e "${YELLOW}[2/5] pyenv-virtualenv 확인 중...${NC}"
if ! pyenv commands | grep -q virtualenv; then
    echo -e "${RED}오류: pyenv-virtualenv가 설치되어 있지 않습니다.${NC}"
    echo ""
    echo "설치 방법:"
    echo "  macOS:  brew install pyenv-virtualenv"
    echo "  Linux:  git clone https://github.com/pyenv/pyenv-virtualenv.git \$(pyenv root)/plugins/pyenv-virtualenv"
    exit 1
fi
echo -e "${GREEN}✓ pyenv-virtualenv 사용 가능${NC}"

# 3. Python 버전 설치
echo -e "${YELLOW}[3/5] Python ${PYTHON_VERSION} 확인 중...${NC}"
INSTALLED_VERSION=$(pyenv versions --bare | grep "^${PYTHON_VERSION}" | head -1 || true)

if [[ -z "$INSTALLED_VERSION" ]]; then
    echo -e "${YELLOW}Python ${PYTHON_VERSION} 설치 중... (몇 분 소요될 수 있습니다)${NC}"
    pyenv install ${PYTHON_VERSION}
    INSTALLED_VERSION=$(pyenv versions --bare | grep "^${PYTHON_VERSION}" | head -1)
fi
echo -e "${GREEN}✓ Python ${INSTALLED_VERSION} 설치됨${NC}"

# 4. 가상환경 생성
echo -e "${YELLOW}[4/5] 가상환경 '${VENV_NAME}' 확인 중...${NC}"
if pyenv versions --bare | grep -q "^${VENV_NAME}$"; then
    echo -e "${GREEN}✓ 가상환경 '${VENV_NAME}' 이미 존재${NC}"
else
    echo -e "${YELLOW}가상환경 '${VENV_NAME}' 생성 중...${NC}"
    pyenv virtualenv ${INSTALLED_VERSION} ${VENV_NAME}
    echo -e "${GREEN}✓ 가상환경 생성 완료${NC}"
fi

# 5. 패키지 설치
echo -e "${YELLOW}[5/5] Ansible 패키지 설치 중...${NC}"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
pyenv activate ${VENV_NAME}

pip install --upgrade pip
pip install ansible jmespath

echo ""
echo -e "${GREEN}=== 설정 완료 ===${NC}"
echo ""
echo "설치된 패키지:"
pip list | grep -E "^(ansible|jmespath)"
echo ""
echo -e "${CYAN}사용 방법:${NC}"
echo "  프로젝트 디렉토리로 이동하면 자동으로 가상환경이 활성화됩니다."
echo "  수동 활성화: pyenv activate ${VENV_NAME}"
echo ""
echo -e "${CYAN}다음 단계:${NC}"
echo "  온프레미스: cd ansible-onpremise && ./start.sh -h"
echo "  AWS:        cd ansible-aws && ./start.sh -h"
