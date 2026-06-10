# test/ CLAUDE.md

> **상위 문서**: [루트 CLAUDE.md](../CLAUDE.md)를 먼저 참조하세요.
> 이 문서는 루트 규칙을 따르며, Docker 기반 테스트 하니스에 특화된 규칙만 정의합니다.

## 목적

실제 온프레미스/AWS 서버 없이, 일회용 Ubuntu/Debian 컨테이너에서 실제 역할
(common, docker, ssh-keys, nvidia, llm)을 실행하고 **멱등성(changed=0)** 을 검증한다.

### 역할 커버리지 (onprem)

| 역할 | 검증 범위 |
|------|----------|
| bootstrap, common, docker, ssh-keys | 전체 (데몬 검증은 `--no-docker-daemon` 시 제외) |
| nvidia | GPU 미감지 자동 스킵 경로 (사전 패키지 + lspci 감지) — 실제 드라이버 설치는 실서버 전용 |
| llm | venv·디렉토리·디스크 가드 (`llm_models: []`) — 모델 다운로드는 실서버 전용 |
| git-credentials, dev-user | **미커버** — 실제 vault 비밀(GitHub 토큰·배포 키)과 외부 서비스 필요 → 실서버 검증 전용 |

## 디렉토리 구조

```
test/
├── CLAUDE.md                  # 본 문서
├── ansible.cfg                # 하니스 전용 설정 (roles_path 로 실제 역할 로드)
├── README.md                  # 사용법 / 한계 / systemd 플래그 설명
├── run-tests.sh               # 메인 실행기 (빌드→기동→2회 실행→멱등성→정리)
├── inventory/
│   └── hosts.yml              # community.docker.docker 연결, onprem/aws 그룹
├── playbooks/
│   ├── onprem.yml             # raw 부트스트랩 + 실제 온프레미스 역할
│   └── aws.yml                # raw 부트스트랩 + 실제 AWS 역할
└── docker/
    ├── Dockerfile.systemd     # systemd+sshd 베이스 (python3 미포함)
    └── docker-compose.yml     # (선택) 컨테이너 일괄 기동
```

## 핵심 설계 결정

| 항목 | 선택 | 이유 |
|------|------|------|
| 연결 방식 | `community.docker.docker` | sshd/비밀번호/키 주입 불필요, 가장 단순·안정. 실제 역할 로직과 멱등성은 그대로 검증됨 |
| 베이스 이미지 | python3 **미포함** | LOCKED #2 의 raw 부트스트랩을 실제로 검증 |
| init | systemd (PID 1) | 역할의 `service`/`systemctl` 호출 및 dockerd 기동 검증 |
| 실행 플래그 | `--privileged --cgroupns=host` + cgroup 마운트 | Docker Desktop for Mac(cgroup v2)에서 systemd 동작 |
| 역할 로드 | `roles_path` 로 원본 참조 | 검증 대상 코드를 복사하지 않음(드리프트 방지) |

## 한계 (정직하게 명시)

- **연결 방식이 프로덕션과 다름**: 본 하니스는 docker exec 기반이므로 비밀번호
  SSH(-k)/sudo(-K)/SSH 키 경로는 검증하지 않는다. 검증 범위는 "역할 로직 + 멱등성"이다.
- **docker-in-docker 데몬 검증**: `--privileged` + systemd 가 있어야 `docker run hello-world`
  가 가능하다. 환경이 불안정하면 `./run-tests.sh --no-docker-daemon` 으로 데몬 검증만 건너뛴다.
- **아키텍처**: 호스트가 Apple Silicon 이면 컨테이너가 arm64 로 뜨므로, docker 역할의
  apt repo `arch` 가 동적이어야 한다(역할 수정본 전제). Intel Mac(amd64)에서는 영향 없음.
- **이미지 노후 → 멱등성 거짓 실패**: 이미지가 오래되면 converge 도중 apt 가 systemd 등을
  부수 업그레이드하고, 그 postinst 가 시스템 상태를 바꿔(예: systemd 255.4-8.16 의
  /etc/default/locale 심링크 전환, provision.conf 의 /root/.ssh 재소유) 2회차에 changed 가
  난다. 역할 버그처럼 보이면 먼저 이미지를 재빌드할 것:
  `docker rmi ansible-harness:ubuntu2204 ansible-harness:ubuntu2404 ansible-harness:debian12`
  (빌드 캐시가 남아 있으면 `docker builder prune` 도 필요할 수 있음)

## 실행 (요약)

```bash
./run-tests.sh                 # 전체 검증 (onprem+aws × 3개 배포판, 멱등성 포함)
./run-tests.sh -e aws -d debian12
./run-tests.sh --no-docker-daemon
```

자세한 내용은 [README.md](./README.md) 참조.
