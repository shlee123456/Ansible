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
├── playbook.yml         # 메인 플레이북
├── inventory/hosts      # 호스트 목록 (SSH 키 경로 포함)
├── group_vars/all.yml   # 공통 변수
└── roles/
    ├── common/          # 기본 시스템 설정
    ├── docker/          # Docker 설치
    └── ssh-keys/        # SSH 키 관리
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

### Facts 수집
```yaml
# ✅ gather_facts 활성화 (기본값)
- name: Configure AWS Server
  hosts: servers
  gather_facts: yes
  become: yes
```

## 역할(Role) 설명

| 역할 | 상태 | 설명 |
|------|------|------|
| common | 활성 | 기본 패키지, 시간대 설정 |
| docker | 활성 | Docker CE, Compose 설치 |
| ssh-keys | 비활성 | Ed25519 키 쌍 생성 |

## 실행 명령어

```bash
# 기본 실행 (SSH 키 인증)
ansible-playbook -i inventory/hosts playbook.yml

# Verbose 모드
ansible-playbook -i inventory/hosts playbook.yml -v

# 드라이런
ansible-playbook -i inventory/hosts playbook.yml --check --diff
```

## SSH 키 설정

```bash
# 키 파일 권한 설정
chmod 600 ~/.ssh/western.pem

# SSH 연결 테스트
ssh -i ~/.ssh/western.pem ubuntu@54.193.60.59
```

## 주요 파일

| 파일 | 설명 |
|------|------|
| `playbook.yml` | 메인 플레이북 |
| `inventory/hosts` | SSH 키 경로, 호스트 정보 |
| `group_vars/all.yml` | timezone, 패키지 목록 등 공통 변수 |

## 온프레미스와의 차이점

| 항목 | 온프레미스 | AWS |
|------|-----------|-----|
| 인증 | 비밀번호 | SSH 키 |
| 사용자 | puzzle | ubuntu |
| 모듈 | raw (부트스트랩) | 네이티브 |
| 옵션 | `-k -K` | 없음 |
