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

## 인증 방식

- **SSH 인증**: 비밀번호 기반 (`-k` 옵션)
- **Sudo 인증**: 비밀번호 기반 (`-K` 옵션)
- **사용자**: puzzle

## 디렉토리 구조

```
ansible-onpremise/
├── ansible.cfg          # Ansible 설정 (host_key_checking=False)
├── playbook.yml         # 메인 플레이북
├── start.sh             # 실행 스크립트
├── inventory/hosts      # 호스트 목록
├── group_vars/all.yml   # 공통 변수
└── roles/
    ├── common/          # 기본 시스템 설정
    ├── docker/          # Docker 설치
    ├── jenkins-user/    # Jenkins 배포 사용자
    └── ssh-keys/        # SSH 키 관리
```

## 로컬 코딩 컨벤션

### 부트스트랩 단계 (Python 미설치 환경)
```yaml
# ✅ raw 모듈 사용 (Python 의존성 없음)
- name: Update apt cache
  raw: apt-get update

- name: Install Python dependencies
  raw: apt-get install -y python3-six python3-jmespath
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

## 역할(Role) 설명

| 역할 | 상태 | 설명 |
|------|------|------|
| common | 활성 | 기본 패키지, 시간대 설정 |
| docker | 활성 | Docker CE, Compose 설치 |
| jenkins-user | 비활성 | Jenkins 배포 사용자 설정 |
| ssh-keys | 비활성 | Ed25519 키 쌍 생성 |

## 실행 명령어

```bash
# 기본 실행
./start.sh

# 직접 실행
ansible-playbook -i inventory/hosts playbook.yml -k -K -v

# 특정 노드만 실행
ansible-playbook -i inventory/hosts playbook.yml -l test-node1 -k -K -v

# 드라이런
ansible-playbook -i inventory/hosts playbook.yml --check --diff -k -K
```

## 로컬 개발환경

```bash
# pyenv 가상환경 설정
pyenv virtualenv 3.11.0 ansible-onpremise
pyenv local ansible-onpremise
pip install ansible

# sshpass 설치 (macOS)
brew install hudochenkov/sshpass/sshpass

# 환경변수로 비밀번호 설정
export SSHPASS='your_password'
sshpass -e ansible-playbook -i inventory/hosts playbook.yml -k -K -v
```

## 주요 파일

| 파일 | 설명 |
|------|------|
| `playbook.yml` | 메인 플레이북 (역할 실행 순서 정의) |
| `inventory/hosts` | 호스트 IP, 사용자, Python 경로 설정 |
| `group_vars/all.yml` | timezone, 패키지 목록 등 공통 변수 |
| `SETUP.md` | 상세 개발환경 설정 가이드 |
