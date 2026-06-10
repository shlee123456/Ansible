# Ansible Infrastructure Automation

## ⚠️ 필수 실행 규칙 (모든 작업 전 확인)

> **이 규칙은 모든 작업에서 반드시 준수해야 합니다.**

### 1. 터미널 로그 기록
모든 Ansible 명령어 실행 시 `.context/terminal/`에 로그 저장:
```bash
ansible-playbook ... 2>&1 | tee .context/terminal/playbook_$(date +%s).log
```

### 2. 서브 CLAUDE.md 관리
- 새 환경/역할 생성 시 → 해당 디렉토리에 서브 CLAUDE.md 생성
- 기존 구조 변경 시 → 관련 서브 CLAUDE.md 업데이트
- 서브 CLAUDE.md는 반드시 루트 CLAUDE.md 참조

### 3. 세션 관리
- **세션 시작**: `.context/history/`에서 최근 기록 확인, 이전 TODO 파악
- **세션 종료**: `.context/history/session_YYYY-MM-DD_HH-MM.md`에 작업 내용 기록

### 4. Git 커밋 규칙
- 커밋 메시지는 **한글**로 작성
- `Co-Authored-By` 태그 **사용 금지**
- 형식: `<type>: <한글 설명>` (feat, fix, docs, refactor, chore 등)

### 5. 작업 완료 체크리스트
- [ ] 터미널 로그 저장했는가?
- [ ] 서브 CLAUDE.md 업데이트 필요한가?
- [ ] 세션 히스토리 기록했는가?
- [ ] Git 커밋 시 한글 메시지 사용했는가?

---

## 개요

Ansible 기반 IaC(Infrastructure as Code) 프로젝트로, 온프레미스 및 AWS 환경의 서버 인프라를 자동 구성합니다.

## 기술 스택

- **Ansible**: 인프라 자동화 도구
- **Python 3.11+**: Ansible 인터프리터
- **pyenv**: Python 버전 및 가상환경 관리
- **YAML**: 플레이북 및 설정 파일
- **Docker/Docker Compose**: 컨테이너 플랫폼
- **OpenSSH**: Ed25519 키 기반 인증

## 프로젝트 구조

```
ansible/
├── CLAUDE.md                   # 루트: 전역 규칙
├── Makefile                    # 편의 명령어 (make help)
├── requirements.txt            # Python 의존성
├── .python-version             # pyenv 가상환경 (ansible-onpremise)
├── .context/                   # 맥락 관리 (gitignore 대상)
│   ├── history/                # 세션 히스토리
│   └── terminal/               # 터미널 로그
├── scripts/                    # 유틸리티 스크립트
│   ├── setup-env.sh            # pyenv 환경 설정
│   ├── ping.sh                 # SSH 연결 테스트
│   ├── facts.sh                # 호스트 정보 수집
│   └── list-hosts.sh           # 인벤토리 조회
├── ansible-onpremise/          # 온프레미스 환경
│   ├── CLAUDE.md               # 서브: 온프레미스 규칙
│   ├── ansible.cfg
│   ├── start.sh
│   ├── playbook.yml
│   ├── inventory/hosts
│   └── roles/
├── ansible-aws/                # AWS 환경
│   ├── CLAUDE.md               # 서브: AWS 규칙
│   ├── ansible.cfg
│   ├── start.sh
│   ├── playbook.yml
│   ├── inventory/hosts
│   └── roles/
└── claude-docs/                # CLAUDE.md 가이드라인 (서브모듈)
```

## 서브 CLAUDE.md 목록

| 경로 | 설명 |
|------|------|
| `ansible-onpremise/CLAUDE.md` | 온프레미스 환경 규칙 (비밀번호 인증, raw 모듈) |
| `ansible-aws/CLAUDE.md` | AWS 환경 규칙 (SSH 키 인증, 네이티브 모듈) |

## 전역 코딩 컨벤션

### YAML 스타일
- 2칸 스페이스 들여쓰기
- 한글 주석 사용
- 역할/태스크 설명은 `name` 필드에 명시

### Ansible 규칙
- 공통 변수: `group_vars/all/main.yml` (비밀값은 `group_vars/all/vault.yml` 에 Vault 암호화)
- 역할별 기본값: `roles/[role]/defaults/main.yml`
- 멱등성 보장: `changed_when`, `when` 조건 활용
- 사용자 변수화: `{{ ansible_user }}` 사용 (하드코딩 금지)

### 권한 설정
- .ssh 디렉토리: `0700`
- 비공개 키: `0600`
- authorized_keys: `0644`

## 개발환경 설정

### pyenv 설치 (최초 1회)
```bash
# macOS
brew install pyenv pyenv-virtualenv

# 쉘 설정 (~/.zshrc 또는 ~/.bashrc)
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
```

### 프로젝트 환경 설정
```bash
# 자동 설정 스크립트 실행
./scripts/setup-env.sh

# 또는 수동 설정
pyenv virtualenv 3.11 ansible-onpremise
pyenv local ansible-onpremise
pip install -r requirements.txt
```

## 세션 관리 규칙

### 세션 시작 시
1. `.context/history/`에서 최근 세션 파일 확인
2. 이전 세션의 TODO와 진행상황 파악
3. 중단된 작업이 있으면 이어서 진행

### 세션 종료 시
1. `.context/history/session_YYYY-MM-DD_HH-MM.md` 파일 생성
2. 완료한 작업, 주요 결정사항, 다음 TODO 기록

## 자주 사용하는 명령어

### Makefile (권장)
```bash
make help           # 사용 가능한 명령어 목록
make ping-onprem    # 온프레미스 연결 테스트
make ping-aws       # AWS 연결 테스트
make check-onprem   # 온프레미스 드라이런
make check-aws      # AWS 드라이런
make run-onprem     # 온프레미스 실행
make run-aws        # AWS 실행
```

### start.sh 스크립트
```bash
# 온프레미스
cd ansible-onpremise
./start.sh              # 기본 실행
./start.sh -c           # 드라이런 (--check --diff)
./start.sh -l work-node1  # 특정 호스트만
./start.sh -t docker    # 특정 태그만
./start.sh -h           # 도움말

# AWS
cd ansible-aws
./start.sh              # 기본 실행 (SSH 키 인증)
./start.sh -c           # 드라이런
```

### 유틸리티 스크립트
```bash
./scripts/ping.sh onpremise   # 온프레미스 연결 테스트
./scripts/ping.sh aws         # AWS 연결 테스트
./scripts/facts.sh onpremise  # 시스템 정보 수집
./scripts/list-hosts.sh all   # 전체 호스트 목록
```

### 로그 기록
```bash
# 온프레미스 (인증은 Vault 가 자동 처리 — ansible-onpremise/CLAUDE.md 참조)
ansible-playbook -i inventory/hosts playbook.yml -v 2>&1 | tee .context/terminal/onprem_$(date +%s).log

# AWS
ansible-playbook -i inventory/hosts playbook.yml 2>&1 | tee .context/terminal/aws_$(date +%s).log
```

## 히스토리 관리

- `.context/history/`에 최근 5개 세션만 유지
- 7일 이상 된 히스토리는 삭제 또는 아카이브

```bash
# 7일 이상 된 히스토리 삭제
find .context/history -name "*.md" -mtime +7 -delete

# 최근 10개 터미널 로그만 유지
ls -t .context/terminal/*.log 2>/dev/null | tail -n +11 | xargs rm -f
```

## 참고 문서

- [Ansible 공식 문서](https://docs.ansible.com/)
- [Docker 설치 가이드](https://docs.docker.com/engine/install/ubuntu/)
- [pyenv 설치 가이드](https://github.com/pyenv/pyenv)
- `claude-docs/CLAUDE.md`: CLAUDE.md 작성 가이드라인
