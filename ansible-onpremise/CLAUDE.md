# ansible-onpremise CLAUDE.md

> **상위 문서**: [루트 CLAUDE.md](../CLAUDE.md)를 먼저 참조하세요.
> 이 문서는 루트 규칙을 따르며, 온프레미스 환경에 특화된 규칙만 정의합니다.

## 목적

Ubuntu 기반 온프레미스 서버의 인프라 자동화 구성

## 타겟 호스트

| 호스트 | IP | 설명 |
|--------|-----|------|
| work-node1 | 192.168.45.54 | 사무실 mini-pc |
| test-node1 | 192.168.45.231 | 테스트 서버 |
| work-node2 | 192.168.45.114 | LLM 서빙 서버 (Ubuntu 24.04, RTX PRO 6000 Blackwell x2) |

### 서버 그룹

| 그룹 | 호스트 | 용도 |
|------|--------|------|
| servers | 전체 | 공통 기반 (bootstrap, common, docker, nvidia) |
| llm | work-node2 | LLM 모델 다운로드·서빙 (단일 3.5TB LVM, /media/llm-models 표준 경로) |
| stt | (입고 예정) | 음성인식 서버·서비스 (docker compose) |

## 인증 방식

- **기본**: Ansible Vault — `group_vars/all/vault.yml` 의 비밀번호를 `.vault_pass` 로 자동 복호화 (프롬프트 없음)
- **비상용**: `-k`(SSH) / `-K`(sudo) 프롬프트 — vault 변수가 우선이므로 평소엔 불필요
- **사용자**: puzzle (사내 공용) / 개인 작업·git clone 은 **shlee** 계정 (dev-user 역할이 생성)

### 비대화식 실행 (검증된 패턴 — 매번 재확인 불필요)

**Ansible Vault 가 기본 경로다.** 접속/승격 비밀번호는 `group_vars/all/vault.yml`(암호화, 커밋 가능)의
`vault_ansible_password` 에 있고, `group_vars/all/main.yml` 이 `ansible_password`/`ansible_become_pass` 로 참조한다.
복호화 키는 `.vault_pass`(gitignore, 0600) — `ansible.cfg` 의 `vault_password_file` 이 자동 사용한다.

```bash
# 프롬프트 없이 바로 실행 (.vault_pass 가 있으면 끝)
./start.sh -l work-node2
ansible-playbook -i inventory/hosts playbook.yml      # 직접 실행도 동일

# vault 값 수정
ansible-vault edit group_vars/all/vault.yml
```

- `.vault_pass` 가 없는 새 머신: 기존 머신에서 `.vault_pass` 파일만 복사 (또는 `--ask-vault-pass`)
- `start.sh` 인증 우선순위: `SSHPASS` 환경변수(임시 덮어쓰기) → `.vault_pass` → `--ask-vault-pass` 프롬프트
- 실행은 **ansible-onpremise 디렉토리에서** (vault_password_file 이 상대경로)
- 실행기 경로(셸 PATH 에 shim 없을 때): `$HOME/.pyenv/versions/ansible-onpremise/bin/ansible-playbook`
- venv 이름은 **`ansible-onpremise`** (문서 예시의 `ansible` 아님)
- `--check` 드라이런은 docker/nvidia 역할에서 실패가 정상 (저장소 추가 전 패키지 조회 한계)

## 디렉토리 구조

```
ansible-onpremise/
├── .python-version      # pyenv 가상환경 (ansible)
├── ansible.cfg          # Ansible 설정 (host_key_checking=False)
├── playbook.yml         # 메인 플레이북
├── start.sh             # 실행 스크립트 (옵션 지원)
├── SETUP.md             # 상세 개발환경 가이드
├── inventory/hosts      # 호스트 목록
├── group_vars/all/      # 공통 변수 (main.yml) + 암호화 비밀변수 (vault.yml)
├── .vault_pass          # Vault 복호화 키 (gitignore, 커밋 금지)
└── roles/
    ├── common/          # 기본 시스템 설정 (네이티브 모듈, 멱등)
    ├── docker/          # Docker CE, Compose 설치
    ├── nvidia/          # NVIDIA 드라이버 + Container Toolkit (GPU 자동 감지)
    ├── llm/             # HF 모델 다운로드 (llm 그룹 전용, /media/llm-models)
    ├── stt/             # 음성인식 서버 (골격 — 서버 입고 후 구체화)
    ├── git-credentials/ # GitHub HTTPS 자격증명 (puzzle 계정)
    ├── dev-user/        # 개인 계정(shlee) + 공유 git 배포 키 + 유틸 스크립트
    └── ssh-keys/        # SSH 키 관리 (옵트인: manage_ssh_keys=true)
```

> 부트스트랩은 저장소 루트의 **공유 `roles/bootstrap`** 역할이 담당합니다
> (`ansible.cfg` 의 `roles_path = roles:../roles` 로 탐색).

## 로컬 코딩 컨벤션

### 부트스트랩 (Python 미설치 환경) — 공유 역할 사용
playbook 은 `gather_facts: no` 로 시작하고 공유 `bootstrap` 역할을 **첫 역할**로 둡니다.
이 역할이 `raw` 로 `python3`/`python3-apt` 만 설치한 뒤 `setup` 으로 facts 를 수집하므로,
이후 역할은 네이티브 모듈을 그대로 사용할 수 있습니다.

```yaml
- name: Configure Server
  hosts: servers
  gather_facts: no
  become: yes
  roles:
    - bootstrap   # python3/python3-apt 설치 + facts 수집 (공유 역할)
    - common      # 이후 네이티브 모듈 역할
    - docker
```

### Python 설치 후
```yaml
# ✅ 네이티브 모듈 사용 가능
- name: Install packages
  apt:
    name: "{{ item }}"
    state: present
  loop:
    - vim
    - git
```

### 사용자 변수화 (하드코딩 금지)
```yaml
# ✅ 올바른 예시
- name: Add user to docker group
  user:
    name: "{{ ansible_user }}"
    groups: docker

# ❌ 잘못된 예시
- name: Add user to docker group
  user:
    name: puzzle  # 하드코딩 금지
    groups: docker
```

## 역할(Role) 설명

| 역할 | 상태 | 설명 |
|------|------|------|
| bootstrap | 활성 | (공유) python3/python3-apt 설치 + facts 수집 |
| common | 활성 | 기본 패키지, 한글 로케일, 시간대 설정 (네이티브·멱등) |
| docker | 활성 | Docker CE, Compose Plugin 설치 |
| nvidia | 활성 | NVIDIA 드라이버 + Container Toolkit (GPU 자동 감지, 미감지 시 스킵) |
| llm | 활성 | HF 모델 다운로드 환경(venv)·모델 동기화 (llm 그룹 전용, 토큰은 vault) |
| git-credentials | 활성 | GitHub HTTPS 자격증명 배포 (puzzle 계정용, 토큰은 vault) |
| dev-user | 활성 | 개인 작업 계정(shlee) 생성 + 공유 git 배포 키 설치 → 초기 세팅 후 즉시 SSH clone 가능 |
| stt | 골격 | 음성인식 서버·서비스 (서버 입고·소스 확정 후 구체화) |
| ssh-keys | 옵트인 | Ed25519 키 쌍 생성 (`-e manage_ssh_keys=true` 또는 `-t ssh-keys`) |

> **docker 역할 검증 변수**: `docker_verify`(데몬 hello-world 검증)와
> `docker_manage_service`(서비스 시작)는 기본값이 안전하게 설정돼 있어 컨테이너
> 테스트에서 자동으로 꺼집니다. 실서버에서는 `-e docker_verify=true` 로 데몬 검증을 켜세요.

## 실행 명령어

### start.sh 스크립트 (권장)
```bash
./start.sh              # 기본 실행
./start.sh -c           # 드라이런 (--check --diff)
./start.sh -l work-node1  # 특정 호스트만 실행
./start.sh -t docker    # 특정 태그만 실행
./start.sh -v           # 상세 출력 (-vvv)
./start.sh -h           # 도움말
```

### 직접 실행 (인증은 Vault 자동)
```bash
# 기본 실행
ansible-playbook -i inventory/hosts playbook.yml -v

# 특정 노드/태그만 실행
ansible-playbook -i inventory/hosts playbook.yml -l work-node2 -t llm -v

# 드라이런 (docker/nvidia/llm 역할은 신규 저장소 한계로 실패가 정상)
ansible-playbook -i inventory/hosts playbook.yml --check --diff
```

### 신규 서버 온보딩 절차 (검증된 런북)
1. `inventory/hosts` 에 호스트 추가 (GPU·LLM 서버면 `[llm]` 그룹에도 추가)
2. 연결 확인: `../scripts/ping.sh onpremise` (또는 `ansible -i inventory/hosts <호스트> -m ping`)
3. 적용: `./start.sh -l <호스트>` — 끝. (GPU 드라이버는 자동 감지, shlee 계정·git SSH clone 즉시 가능)
4. 멱등성 확인: 한 번 더 실행해 `changed=0` 확인

### Makefile (루트 디렉토리에서)
```bash
make ping-onprem    # 연결 테스트
make check-onprem   # 드라이런
make run-onprem     # 실행
```

## 개발환경 설정

### pyenv 가상환경 (권장)
```bash
# 프로젝트 루트에서 자동 설정
cd ..
./scripts/setup-env.sh

# 또는 수동 설정
pyenv virtualenv 3.11 ansible
pyenv local ansible
pip install ansible jmespath
```

### sshpass 설치 (macOS)
```bash
brew install hudochenkov/sshpass/sshpass
```

### 환경변수로 비밀번호 설정
```bash
export SSHPASS='your_password'
sshpass -e ansible-playbook -i inventory/hosts playbook.yml -k -K -v
```

## 주요 파일

| 파일 | 설명 |
|------|------|
| `playbook.yml` | 메인 플레이북 (역할 실행 순서 정의) |
| `inventory/hosts` | 호스트 IP, 사용자, Python 경로 설정 |
| `group_vars/all.yml` | timezone, 패키지 목록 등 공통 변수 |
| `ansible.cfg` | host_key_checking, Python 인터프리터 설정 |
| `SETUP.md` | 상세 개발환경 설정 가이드 |
