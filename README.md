# Ansible Infrastructure Automation

Ansible 기반 IaC(Infrastructure as Code) 프로젝트로, 온프레미스 및 AWS 환경의 서버 인프라를 자동 구성합니다.

## 주요 기능

- 기본 시스템 패키지 설치 및 한글 로케일 설정
- Docker CE 및 Docker Compose v2 설치
- NVIDIA 드라이버 + Container Toolkit 설치 (GPU 자동 감지, 미장착 호스트는 스킵)
- LLM 서빙 서버 구성 (Hugging Face 모델 자동 다운로드)
- 서버 git 접근 자동화 (GitHub 자격증명 배포 + 개인 작업 계정·배포 키)
- Ansible Vault 기반 접속 비밀번호 암호화 관리 (프롬프트 없는 비대화식 실행)
- 시간대 설정 (Asia/Seoul)
- SSH 키 관리 (옵트인)

## 사전 요구사항

- **로컬 환경**
  - Python 3.11+
  - Ansible (ansible-core 2.16+)
  - Galaxy 컬렉션: `ansible-galaxy collection install -r requirements.yml`
  - sshpass (온프레미스용): `brew install hudochenkov/sshpass/sshpass`

- **타겟 서버**
  - Ubuntu 22.04/24.04 LTS, Debian 11/12
  - SSH 접속 가능 (Python 미설치도 가능 — bootstrap 역할이 자동 설치)
  - sudo 권한

## 빠른 시작

### 온프레미스 환경

```bash
cd ansible-onpremise

# 방법 1: 스크립트 실행
./start.sh

# 방법 2: 직접 실행 (인증은 Vault가 자동 처리 — 비밀번호 프롬프트 없음)
ansible-playbook -i inventory/hosts playbook.yml -v
```

**옵션 설명:**
- `-v`: 상세 로그 출력
- `-l <호스트>`: 특정 호스트만 실행
- `-t <태그>`: 특정 태그만 실행 (예: `-t llm`)
- `--check --diff`: 드라이런 (미리보기)
- `-k` / `-K`: SSH·sudo 비밀번호 프롬프트 (비상용 — 평소엔 Vault가 처리)

> 접속 비밀번호는 `group_vars/all/vault.yml`에 Vault 암호화되어 있으며,
> `.vault_pass` 파일로 자동 복호화됩니다 (둘 다 gitignore 대상).

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
├── roles/bootstrap/      # 공유 부트스트랩 역할 (python3 설치 + facts 수집)
├── ansible-onpremise/    # 온프레미스 환경
│   ├── playbook.yml      # 메인 플레이북 (servers + llm/stt 그룹별 플레이)
│   ├── inventory/hosts   # 호스트 목록 (servers / llm / stt 그룹)
│   ├── group_vars/       # 공통 변수 (all/main.yml) + Vault 비밀값 (all/vault.yml)
│   └── roles/            # common, docker, nvidia, llm, stt,
│                         # git-credentials, dev-user, ssh-keys
├── ansible-aws/          # AWS 환경
│   ├── playbook.yml
│   ├── inventory/hosts
│   └── roles/            # common, docker, ssh-keys
├── test/                 # Docker 기반 로컬 테스트 하니스
└── claude-docs/          # CLAUDE.md 가이드라인 (서브모듈)
```

### 온프레미스 역할 구성

| 역할 | 설명 | 실행 조건 |
|------|------|----------|
| bootstrap | python3/python3-apt 설치 + facts 수집 | 항상 |
| common | 기본 패키지, 로케일, 시간대 | 항상 |
| docker | Docker CE + Compose v2 | 항상 |
| nvidia | NVIDIA 드라이버 + Container Toolkit | GPU 감지 시 (미감지 자동 스킵) |
| git-credentials | GitHub HTTPS 자격증명 배포 (토큰은 Vault) | 항상 |
| dev-user | 개인 작업 계정(shlee) + 공유 git 배포 키 | 항상 |
| llm | Hugging Face 모델 자동 다운로드·동기화 | `[llm]` 그룹 호스트만 |
| stt | 음성인식 서버 (골격 — 서버 입고 후 구체화) | `[stt]` 그룹 호스트만 |
| ssh-keys | SSH 키 관리 | 옵트인 (`manage_ssh_keys=true`) |

## 설치되는 구성 요소

| 구성 요소 | 버전 | 설명 |
|----------|------|------|
| Docker CE | latest | 컨테이너 엔진 |
| Docker Compose | v2 (plugin) | 다중 컨테이너 관리 |
| NVIDIA 드라이버 | 자동 선택 | GPU 서버 한정, Container Toolkit 포함 |
| 시스템 패키지 | - | vim, git, curl, htop, tree, net-tools |
| 로케일 | 온프레미스 ko_KR / AWS en_US | group_vars 의 `locale` 변수로 설정 |
| Python | bootstrap | 미설치 서버에 python3/python3-apt 자동 설치 |

## 환경별 설정

| 항목 | 온프레미스 | AWS |
|------|-----------|-----|
| 사용자 | puzzle (개인 작업은 shlee) | ubuntu |
| 인증 | 비밀번호 (Vault 암호화, 자동 복호화) | SSH 키 |
| 호스트 | 192.168.45.x | EC2 Public IP |

## 신규 서버 온보딩

1. `ansible-onpremise/inventory/hosts`에 호스트 추가 (GPU·LLM 서버면 `[llm]` 그룹에도 추가)
2. 연결 확인: `./scripts/ping.sh onpremise`
3. 적용: `cd ansible-onpremise && ./start.sh -l <호스트>`
4. 멱등성 확인: 한 번 더 실행해 `changed=0` 확인

## 로컬 테스트 (Docker 하니스)

실제 서버 없이 일회용 Ubuntu/Debian 컨테이너에 플레이북을 2회 적용해
멱등성(changed=0)을 검증합니다.

```bash
make test                                      # 전체 (onprem+aws × ubuntu22.04/24.04 + debian12)
cd test && ./run-tests.sh -e aws -d debian12   # 특정 시나리오만
cd test && ./run-tests.sh --no-docker-daemon   # 데몬 의존 작업 제외 (DinD 불안정 시)
```

자세한 사용법과 한계(연결 방식·docker-in-docker 등)는 [test/README.md](test/README.md) 참조.

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
- [Docker 설치 가이드](https://docs.docker.com/engine/install/)
- [ansible-onpremise/SETUP.md](ansible-onpremise/SETUP.md) - 로컬 개발환경 상세 설정

## 라이선스

MIT License
