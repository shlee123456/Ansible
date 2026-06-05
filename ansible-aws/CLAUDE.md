# ansible-aws CLAUDE.md

> **상위 문서**: [루트 CLAUDE.md](../CLAUDE.md)를 먼저 참조하세요.
> 이 문서는 루트 규칙을 따르며, AWS 환경에 특화된 규칙만 정의합니다.

## 목적

AWS EC2 Ubuntu 인스턴스의 인프라 자동화 구성

## 타겟 호스트

| 호스트 | IP | 설명 |
|--------|-----|------|
| western | 54.193.60.59 | AWS EC2 인스턴스 |

## 인증 방식

- **SSH 인증**: 키 기반 (`~/.ssh/western.pem`)
- **Sudo 인증**: 비밀번호 없음 (ubuntu 사용자 기본 설정)
- **사용자**: ubuntu

## 디렉토리 구조

```
ansible-aws/
├── .python-version      # pyenv 가상환경 (ansible)
├── ansible.cfg          # Ansible 설정 (pipelining, timeout 등)
├── playbook.yml         # 메인 플레이북
├── start.sh             # 실행 스크립트 (옵션 지원)
├── inventory/hosts      # 호스트 목록 (SSH 키 경로 포함)
├── group_vars/all.yml   # 공통 변수
└── roles/
    ├── common/          # 기본 시스템 설정
    ├── docker/          # Docker CE, Compose Plugin 설치
    └── ssh-keys/        # SSH 키 관리 (비활성)
```

## 로컬 코딩 컨벤션

### 네이티브 모듈 사용 (Python 사전 설치됨)
```yaml
# ✅ apt 모듈 직접 사용
- name: Update apt cache
  apt:
    update_cache: yes
    cache_valid_time: 3600

# ✅ loop를 활용한 반복 작업
- name: Install basic packages
  apt:
    name: "{{ item }}"
    state: present
  loop:
    - vim
    - git
    - curl
```

### GPG 키 다운로드 (apt_key deprecated, Ubuntu/Debian 공통)
```yaml
# ✅ get_url + facts 기반 OS 경로 (Ubuntu/Debian 모두 정확)
- name: Download Docker GPG key
  get_url:
    url: "https://download.docker.com/linux/{{ ansible_distribution | lower }}/gpg"
    dest: /etc/apt/keyrings/docker.asc
    mode: '0644'

# ❌ apt_key (deprecated) / linux/ubuntu 하드코딩 (Debian 에서 깨짐)
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
    name: ubuntu  # 하드코딩 금지
    groups: docker
```

### 부트스트랩 + Facts 수집 (공유 bootstrap 역할)
```yaml
# ✅ gather_facts: no 로 시작하고 공유 bootstrap 역할이 facts 를 수집
- name: Configure AWS Server
  hosts: aws_servers
  gather_facts: no   # bootstrap 역할이 raw 로 시작 후 setup 으로 facts 수집
  become: yes
  roles:
    - bootstrap      # 공유 역할 (실서버엔 Python 이 있어 사실상 skip)
    - common
    - docker
```

## 역할(Role) 설명

| 역할 | 상태 | 설명 |
|------|------|------|
| bootstrap | 활성 | (공유) python3/python3-apt 설치 + facts 수집 |
| common | 활성 | 기본 패키지, 로케일(en_US.UTF-8), 시간대 설정 |
| docker | 활성 | Docker CE, Compose Plugin 설치 |
| ssh-keys | 옵트인 | Ed25519 키 쌍 생성 (`-e manage_ssh_keys=true`) |

## 실행 명령어

### start.sh 스크립트 (권장)
```bash
./start.sh              # 기본 실행 (SSH 키 인증)
./start.sh -c           # 드라이런 (--check --diff)
./start.sh -l western   # 특정 호스트만 실행
./start.sh -t docker    # 특정 태그만 실행
./start.sh -v           # 상세 출력 (-vvv)
./start.sh -h           # 도움말
```

### 직접 실행
```bash
# 기본 실행
ansible-playbook -i inventory/hosts playbook.yml

# Verbose 모드
ansible-playbook -i inventory/hosts playbook.yml -v

# 드라이런
ansible-playbook -i inventory/hosts playbook.yml --check --diff
```

### Makefile (루트 디렉토리에서)
```bash
make ping-aws    # 연결 테스트
make check-aws   # 드라이런
make run-aws     # 실행
```

## SSH 키 설정

```bash
# 키 파일 권한 설정 (최초 1회)
chmod 600 ~/.ssh/western.pem

# SSH 연결 테스트
ssh -i ~/.ssh/western.pem ubuntu@54.193.60.59
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

## 주요 파일

| 파일 | 설명 |
|------|------|
| `playbook.yml` | 메인 플레이북 |
| `inventory/hosts` | SSH 키 경로, 호스트 정보 |
| `group_vars/all.yml` | timezone, 패키지 목록 등 공통 변수 |
| `ansible.cfg` | pipelining, timeout, SSH 재사용 설정 |

## ansible.cfg 주요 설정

```ini
[defaults]
host_key_checking = False    # SSH 호스트 키 확인 비활성화
timeout = 30                 # 연결 타임아웃
forks = 10                   # 병렬 실행 수

[ssh_connection]
pipelining = True            # SSH 파이프라이닝 (성능 향상)
ssh_args = -o ControlMaster=auto -o ControlPersist=60s  # 연결 재사용
```

## 온프레미스와의 차이점

| 항목 | 온프레미스 | AWS |
|------|-----------|-----|
| 인증 | 비밀번호 (`-k -K`) | SSH 키 |
| 사용자 | puzzle | ubuntu |
| 모듈 | 공유 bootstrap(raw) + 네이티브 | 공유 bootstrap(raw) + 네이티브 |
| sudo | 비밀번호 필요 | 비밀번호 없음 |
| Python | bootstrap 자동 설치 | 사전 설치됨 (bootstrap skip) |
| 로케일 | ko_KR.UTF-8 | en_US.UTF-8 |
