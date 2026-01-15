# CLAUDE.md

## 프로젝트 개요

이 프로젝트는 Ansible을 사용하여 온프레미스 환경과 AWS 클라우드 환경에서 서버 인프라를 자동으로 구성하고 관리하는 IaC(Infrastructure as Code) 솔루션입니다.

## 기술 스택

### 핵심 기술
- **Ansible**: 인프라 자동화 및 구성 관리 도구
- **Python 3**: Ansible 인터프리터 (`/usr/bin/python3`)
- **YAML**: 모든 플레이북 및 설정 파일 형식
- **Bash**: 실행 스크립트

### 인프라 구성 요소
- **Docker**: 컨테이너화 플랫폼 (Docker CE)
- **Docker Compose**: v2.23.3
- **OpenSSH**: Ed25519 키 쌍 기반 인증
- **시스템 패키지**: vim, git, curl, htop, tree, net-tools, unzip, wget

### 타겟 환경
- **온프레미스**: Ubuntu 기반 서버
  - work-node1: 192.168.45.54 (사무실 mini-pc)
  - test-node1: 192.168.45.231 (테스트 서버)
- **AWS EC2**: Ubuntu 인스턴스
  - western: 54.193.60.59

## 프로젝트 구조

```
ansible/
├── ansible-onpremise/          # 온프레미스 환경 설정
│   ├── ansible.cfg             # Ansible 구성 파일
│   ├── playbook.yml            # 메인 플레이북
│   ├── playbook.old.yml        # 백업 플레이북
│   ├── start.sh                # 실행 스크립트
│   ├── SETUP.md                # 로컬 개발환경 설정 가이드
│   ├── .python-version         # pyenv 버전 설정
│   ├── inventory/
│   │   └── hosts               # 호스트 목록 및 연결 정보
│   ├── group_vars/
│   │   └── all.yml             # 공통 변수 정의
│   └── roles/                  # Ansible 역할들
│       ├── common/             # 기본 시스템 설정
│       │   └── tasks/main.yml
│       ├── docker/             # Docker 설치 및 구성
│       │   └── tasks/main.yml
│       ├── jenkins-user/       # Jenkins 배포 사용자 설정
│       │   ├── tasks/main.yml
│       │   ├── handlers/main.yml
│       │   ├── defaults/main.yml
│       │   ├── meta/main.yml
│       │   ├── README.md       # 역할 문서
│       │   └── templates/
│       │       └── jenkins-sudoers.j2  # sudoers 템플릿
│       └── ssh-keys/           # SSH 키 관리
│           └── tasks/main.yml
│
├── ansible-aws/                # AWS 환경 설정
│   ├── playbook.yml            # AWS 플레이북
│   ├── inventory/
│   │   └── hosts               # AWS 호스트 목록
│   ├── group_vars/
│   │   └── all.yml             # 공통 변수 정의
│   └── roles/                  # Ansible 역할들
│       ├── common/             # 기본 시스템 설정
│       ├── docker/             # Docker 설치 및 구성
│       └── ssh-keys/           # SSH 키 관리
│
├── .gitignore                  # Git 설정
├── CLAUDE.md                   # 이 파일
└── README.md                   # 프로젝트 문서
```

## 주요 컴포넌트

### 1. Common Role (기본 시스템 설정)
- apt 패키지 캐시 업데이트
- 필수 시스템 패키지 설치 (vim, git, curl, htop, tree 등)
- 시간대 설정 (Asia/Seoul)
- Python 의존성 설치 (Ansible 모듈용)

**위치:**
- 온프레미스: `ansible-onpremise/roles/common/tasks/main.yml`
- AWS: `ansible-aws/roles/common/tasks/main.yml`

### 2. Docker Role (컨테이너 환경 구성)
- Docker 공식 GPG 키 및 Repository 추가
- Docker Engine 설치 (docker-ce, docker-ce-cli, containerd.io)
- Docker Compose v2.23.3 설치
- Docker 서비스 시작 및 자동 활성화
- 사용자를 docker 그룹에 추가

**위치:**
- 온프레미스: `ansible-onpremise/roles/docker/tasks/main.yml`
- AWS: `ansible-aws/roles/docker/tasks/main.yml`

### 3. Jenkins User Role (Jenkins 배포 환경)
**온프레미스 전용**

- jenkins 그룹/사용자 생성 (UID/GID: 900)
- SSH 디렉토리 및 authorized_keys 설정
- sudo 비밀번호 없이 접근 권한 설정
- docker 그룹에 jenkins 사용자 추가
- SSH 클라이언트 설정 (StrictHostKeyChecking 비활성화)

**위치:** `ansible-onpremise/roles/jenkins-user/tasks/main.yml`

### 4. SSH Keys Role (SSH 키 관리)
- .ssh 디렉토리 생성 (권한: 0700)
- Ed25519 SSH 키 쌍 자동 생성
- 공개 키 내용 출력

**위치:**
- 온프레미스: `ansible-onpremise/roles/ssh-keys/tasks/main.yml`
- AWS: `ansible-aws/roles/ssh-keys/tasks/main.yml`

## 코딩 컨벤션

### YAML 스타일
```yaml
# ✅ Good: 2칸 스페이스 들여쓰기
- name: Install basic packages
  apt:
    name: "{{ item }}"
    state: present
  loop:
    - vim
    - git
```

### 주석 스타일
- 한글 주석 사용
- 역할/태스크 설명은 `name` 필드에 명시
- 섹션 구분 주석 사용

```yaml
# ✅ Good: 명확한 한글 주석
# 시스템 기본 패키지 설치
- name: Install basic packages
  raw: apt-get install -y vim git curl

# ✅ Good: 인라인 주석으로 역할 설명
roles:
  - common    # 기본 시스템 설정
  - docker    # Docker 설치 및 구성
```

### Ansible 모듈 사용 가이드

**온프레미스 환경:**
- 초기 부트스트랩 단계에서는 `raw` 모듈 사용 (Python 미설치 환경 대응)
- Python 의존성 설치 후 정규 모듈 사용 가능

```yaml
# ✅ 부트스트랩 단계
- name: Update apt cache
  raw: apt-get update

# ✅ Python 설치 후
- name: Install Python dependencies
  raw: apt-get install -y python3-six python3-jmespath
```

**AWS 환경:**
- Python이 사전 설치된 환경이므로 Ansible 네이티브 모듈 사용
- `loop`를 활용한 반복 작업

```yaml
# ✅ 네이티브 모듈 사용
- name: Update apt cache
  apt:
    update_cache: yes
    cache_valid_time: 3600

- name: Install basic packages
  apt:
    name: "{{ item }}"
    state: present
  loop:
    - vim
    - git
    - curl
```

### 변수 관리
- 공통 변수는 `group_vars/all.yml`에 정의
- 역할별 기본값은 `roles/[role_name]/defaults/main.yml`에 정의
- 환경별 차이는 각 디렉토리의 inventory에서 관리

```yaml
# ✅ group_vars/all.yml
timezone: Asia/Seoul
system_packages:
  - vim
  - git
  - curl
```

### Playbook 구조
```yaml
# ✅ 표준 플레이북 구조
---
- name: Configure Server
  hosts: servers
  gather_facts: yes  # facts 수집 (네이티브 모듈 사용 시 필요)
  become: yes        # sudo 권한 사용

  roles:
    - common
    - docker
    #- jenkins-user  # 필요 시 활성화
```

### 멱등성(Idempotency) 보장
- `changed_when: false`로 상태 변경 추적 제어
- 조건부 실행(`when`)으로 중복 작업 방지
- 적절한 Ansible 모듈 사용으로 자동 멱등성 확보

```yaml
# ✅ 멱등성 보장
- name: Check if file exists
  stat:
    path: /path/to/file
  register: file_check

- name: Create file
  file:
    path: /path/to/file
    state: touch
  when: not file_check.stat.exists
```

### 권한 관리
```yaml
# ✅ 명시적 권한 설정
- name: Create .ssh directory
  file:
    path: "{{ ansible_env.HOME }}/.ssh"
    state: directory
    mode: '0700'
    owner: jenkins
    group: jenkins
```

## 실행 방법

### 온프레미스 환경
```bash
cd ansible-onpremise
./start.sh

# 또는 직접 실행
ansible-playbook -i inventory/hosts playbook.yml -k -K -v
```

**옵션 설명:**
- `-i inventory/hosts`: 인벤토리 파일 지정
- `-k`: SSH 비밀번호 프롬프트
- `-K`: sudo 비밀번호 프롬프트
- `-v`: Verbose 모드
- `--check`: 드라이런 모드 (실제 변경 없음)
- `--diff`: 변경사항 미리보기

### AWS 환경
```bash
cd ansible-aws
ansible-playbook -i inventory/hosts playbook.yml
```

**참고:** AWS는 SSH 키 기반 인증 사용 (`~/.ssh/western.pem`)

## 로컬 개발환경 설정

### 필요 도구
- **pyenv**: Python 버전 관리
- **sshpass**: 비밀번호 기반 SSH 자동화 (`brew install hudochenkov/sshpass/sshpass`)

### pyenv 가상환경 설정
```bash
# 1. 가상환경 생성 (최초 1회)
pyenv virtualenv 3.11.0 ansible-onpremise

# 2. 프로젝트 디렉토리에서 자동 활성화 설정
cd ansible-onpremise
pyenv local ansible-onpremise

# 3. Ansible 설치
pip install ansible
```

### 환경변수 설정
```bash
# SSH 비밀번호 설정 (sshpass 사용 시)
export SSHPASS='your_password'

# 드라이런 (미리보기)
sshpass -e ansible-playbook -i inventory/hosts playbook.yml -l test-node1 -k -K --check --diff

# 실제 실행
sshpass -e ansible-playbook -i inventory/hosts playbook.yml -l test-node1 -k -K -v
```

## 환경별 설정 차이

| 항목 | 온프레미스 | AWS |
|------|-----------|-----|
| 호스트 | work-node1 (192.168.45.54), test-node1 (192.168.45.231) | western (54.193.60.59) |
| 사용자 | puzzle | ubuntu |
| 인증 방식 | 비밀번호 | SSH 키 (western.pem) |
| Python 인터프리터 | /usr/bin/python3 | /usr/bin/python3 |
| gather_facts | yes | yes (기본값) |
| 활성 역할 | common, docker | common, docker |
| 비활성 역할 | jenkins-user (주석처리) | ssh-keys (주석처리) |
| 모듈 스타일 | raw 모듈 (부트스트랩) → 네이티브 | 네이티브 모듈 |

## 보안 고려사항

1. **SSH 설정**
   - 온프레미스: 비밀번호 기반 인증
   - AWS: 키 기반 인증 (권장)
   - `host_key_checking = False` 설정 (개발 환경용)

2. **Sudo 권한**
   - jenkins 사용자: NOPASSWD 설정 (배포 자동화용)
   - 프로덕션 환경에서는 제한적 sudo 권한 고려

3. **SSH 키 관리**
   - Ed25519 알고리즘 사용
   - 비공개 키 파일 권한: 0600
   - .ssh 디렉토리 권한: 0700

## 확장 가능성

### 새로운 역할 추가
```bash
# 역할 디렉토리 구조 생성
mkdir -p roles/new-role/{tasks,handlers,defaults,meta}

# main.yml 파일 생성
touch roles/new-role/tasks/main.yml
```

### 새로운 환경 추가
```bash
# 새 환경 디렉토리 복사
cp -r ansible-onpremise ansible-new-env

# inventory 및 group_vars 수정
vim ansible-new-env/inventory/hosts
vim ansible-new-env/group_vars/all.yml
```

## Git 커밋 컨벤션

### 커밋 메시지 규칙
- **언어**: 한글로 작성
- **Co-Authored-By**: 사용하지 않음
- **형식**: 제목 + 빈 줄 + 본문 (선택)

### 커밋 메시지 예시
```
CLAUDE.md 문서 업데이트 및 개발환경 설정 추가

- 프로젝트 구조 섹션에 누락된 파일 추가
- 로컬 개발환경 설정 가이드 추가
- 환경별 설정 차이 테이블 업데이트
```

### PR 제목/본문
- 제목: 한글로 간결하게
- 본문: 변경 사항 요약 (한글)

## 참고 문서

- [Ansible 공식 문서](https://docs.ansible.com/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Docker 설치 가이드](https://docs.docker.com/engine/install/ubuntu/)
