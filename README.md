# Ansible Infrastructure Automation

Ansible 기반 IaC(Infrastructure as Code) 프로젝트로, 온프레미스 및 AWS 환경의 서버 인프라를 자동 구성합니다.

## 주요 기능

- 기본 시스템 패키지 설치 및 한글 로케일 설정
- Docker CE 및 Docker Compose v2 설치
- 시간대 설정 (Asia/Seoul)
- SSH 키 관리
- Jenkins 배포 사용자 설정 (선택)

## 사전 요구사항

- **로컬 환경**
  - Python 3.11+
  - Ansible 2.9+
  - sshpass (온프레미스용): `brew install hudochenkov/sshpass/sshpass`

- **타겟 서버**
  - Ubuntu 20.04/22.04 LTS
  - SSH 접속 가능
  - sudo 권한

## 빠른 시작

### 온프레미스 환경

```bash
cd ansible-onpremise

# 방법 1: 스크립트 실행
./start.sh

# 방법 2: 직접 실행
ansible-playbook -i inventory/hosts playbook.yml -k -K -v
```

**옵션 설명:**
- `-k`: SSH 비밀번호 입력
- `-K`: sudo 비밀번호 입력
- `-v`: 상세 로그 출력
- `--check --diff`: 드라이런 (미리보기)

### AWS 환경

```bash
cd ansible-aws

# SSH 키 권한 설정 (최초 1회)
chmod 600 ~/.ssh/western.pem

# 실행
ansible-playbook -i inventory/hosts playbook.yml
```

## 프로젝트 구조

```
ansible/
├── ansible-onpremise/    # 온프레미스 환경
│   ├── playbook.yml      # 메인 플레이북
│   ├── inventory/hosts   # 호스트 목록
│   └── roles/            # 역할 (common, docker, jenkins-user, ssh-keys)
├── ansible-aws/          # AWS 환경
│   ├── playbook.yml
│   ├── inventory/hosts
│   └── roles/
└── claude-docs/          # CLAUDE.md 가이드라인 (서브모듈)
```

## 설치되는 구성 요소

| 구성 요소 | 버전 | 설명 |
|----------|------|------|
| Docker CE | latest | 컨테이너 엔진 |
| Docker Compose | v2 (plugin) | 다중 컨테이너 관리 |
| 시스템 패키지 | - | vim, git, curl, htop, tree, net-tools |
| 한글 로케일 | ko_KR.UTF-8 | 한글 깨짐 방지 |

## 환경별 설정

| 항목 | 온프레미스 | AWS |
|------|-----------|-----|
| 사용자 | puzzle | ubuntu |
| 인증 | 비밀번호 | SSH 키 |
| 호스트 | 192.168.45.x | EC2 Public IP |

## 문제 해결

### SSH 연결 실패
```bash
# 호스트 키 확인 비활성화 (개발 환경)
export ANSIBLE_HOST_KEY_CHECKING=False
```

### Docker 권한 오류
```bash
# 재로그인 또는 그룹 적용
newgrp docker
```

### 한글 깨짐
```bash
# 로케일 확인
locale
# LANG=ko_KR.UTF-8 이어야 함
```

## 참고 문서

- [Ansible 공식 문서](https://docs.ansible.com/)
- [Docker 설치 가이드](https://docs.docker.com/engine/install/ubuntu/)
- [ansible-onpremise/SETUP.md](ansible-onpremise/SETUP.md) - 로컬 개발환경 상세 설정

## 라이선스

MIT License
