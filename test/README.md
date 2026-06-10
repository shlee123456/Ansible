# Docker 기반 로컬 테스트 하니스

실제 온프레미스/AWS 서버 없이, macOS(Docker Desktop)에서 **일회용 Ubuntu/Debian
컨테이너**에 실제 플레이북을 적용하고 **멱등성(2회차 changed=0)** 을 검증한다.

## 무엇을 검증하나

- raw 부트스트랩(Python 미설치 → python3/python3-apt 설치)이 동작하는지
- 역할들이 Ubuntu 22.04, Ubuntu 24.04, Debian 12 에서 동작하는지
- 2회 연속 실행 시 모든 호스트가 `changed=0` 인지 (멱등성)

### 역할 커버리지 (onprem)

| 역할 | 검증 범위 |
|------|----------|
| bootstrap, common, docker, ssh-keys | 전체 (데몬 검증은 `--no-docker-daemon` 시 제외) |
| nvidia | GPU 미감지 자동 스킵 경로 (사전 패키지 + lspci 감지) — 실제 드라이버 설치는 실서버 전용 |
| llm | venv·디렉토리·디스크 가드 (`llm_models: []`) — 모델 다운로드는 실서버 전용 |
| git-credentials, dev-user | **미커버** — 실제 vault 비밀(GitHub 토큰·배포 키)과 외부 서비스 필요 → 실서버 검증 전용 |

## 사전 준비

1. Docker Desktop 실행 중일 것 (`docker info` 성공)
2. 호스트에 ansible 가 설치된 pyenv 가상환경이 있을 것
   (이 저장소는 `ansible-onpremise` venv 사용. 이름에 의존하지 않고 자동 탐색)
3. `community.docker`, `community.general` 컬렉션 설치 (이미 설치되어 있으면 생략)
   ```bash
   <venv>/bin/ansible-galaxy collection install community.docker community.general
   ```

> **pyenv venv 문제**: 평범한 셸에서 `ansible-playbook` 은
> `pyenv: ansible-playbook: command not found` 로 실패한다.
> `run-tests.sh` 는 (1) PATH 의 실제 실행가능 여부 → (2) `ANSIBLE_VENV` 환경변수 →
> (3) `~/.pyenv/versions/ansible*` 자동 탐색 순으로 실행기를 찾으므로,
> venv 를 활성화하지 않아도 동작한다. 필요 시 명시적으로 지정:
> ```bash
> ANSIBLE_VENV="$HOME/.pyenv/versions/ansible-onpremise" ./run-tests.sh
> ```

## 사용법

```bash
cd test

./run-tests.sh                      # 전체: (onprem,aws) × (u2204,u2404,deb12), 멱등성까지
./run-tests.sh -e onprem            # 온프레미스 환경만
./run-tests.sh -e aws -d debian12   # AWS × Debian 12 만
./run-tests.sh --converge-only      # 1회만(멱등성 검증 생략, 빠른 스모크)
./run-tests.sh --no-docker-daemon   # docker 역할의 hello-world 데몬 검증 건너뜀
./run-tests.sh --keep               # 디버깅용: 컨테이너 보존
./run-tests.sh -h
```

종료 코드: 모든 시나리오 통과 시 `0`, 하나라도 실패 시 `1` (CI 연동 가능).

로그는 `../.context/terminal/` 에 저장된다(루트 CLAUDE.md 규칙, gitignore 대상).

## 멱등성 판정 방식

2회차 실행의 `PLAY RECAP` 을 파싱하여 모든 호스트의 `changed=` 합과 `failed=` 합이
0 이면 통과. 0 이 아니면 어떤 태스크가 2회차에 다시 변경을 보고한 것이므로
(예: `state: latest`, `force: yes`, changed_when 누락 raw) 실패로 처리한다.

## systemd-in-docker 가 필요한 이유와 플래그

역할이 `service` / `systemctl` 로 docker·containerd 서비스를 기동하고, docker 역할은
`docker run hello-world` 로 데몬을 검증한다. 컨테이너 안에서 이를 재현하려면
**systemd 가 PID 1 로** 떠야 하고, **docker 데몬(dockerd)** 이 컨테이너 내부에서
실행되어야 한다(docker-in-docker). Docker Desktop for Mac(cgroup v2)에서는 다음
플래그가 필수다 — `run-tests.sh` 가 자동으로 적용한다:

```bash
docker run -d \
  --privileged \                              # systemd 가 cgroup/마운트 제어
  --cgroupns=host \                           # 호스트 cgroup 네임스페이스 공유 (cgroup v2)
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \       # systemd 의 cgroup 계층 접근
  --tmpfs /run --tmpfs /run/lock \            # 런타임 디렉터리
  ansible-harness:<distro>
```

| 플래그 | 역할 |
|--------|------|
| `--privileged` | systemd 가 cgroup/장치/마운트를 제어. dockerd 의 overlayfs·iptables·cgroup 도 필요 |
| `--cgroupns=host` | Docker Desktop(cgroup v2 단일 계층)에서 systemd 가 자기 cgroup 을 쓰도록 함. 없으면 systemd 부팅 실패 |
| `-v /sys/fs/cgroup:...:rw` | systemd 가 cgroup 트리에 쓰기. (cgroup v2 에서는 `:rw`, 과거 v1 의 `:ro` + 하위 마운트 불필요) |
| `--tmpfs /run`,`/run/lock` | systemd/sshd 런타임 디렉터리. 디스크 오염 방지 |

Compose 로 띄울 때는 `privileged: true`, `cgroup: host`, 같은 cgroup 볼륨/ tmpfs 가
`docker-compose.yml` 에 anchor 로 정의되어 있다.

## 한계 (정직한 경계)

1. **연결 방식**: `community.docker.docker` 플러그인(=docker exec)을 쓴다.
   따라서 프로덕션의 **SSH 인증 경로(Vault 비밀번호/sudo/SSH 키)** 자체는 검증하지
   않는다. 검증 대상은 *역할 로직과 멱등성*이다. (SSH 충실도가 필요하면 베이스에
   sshd 가 이미 포함되어 있으므로, 컨테이너 22번 포트를 매핑하고
   `ansible_connection=ssh` 인벤토리를 추가해 확장할 수 있다.)
2. **docker-in-docker 의 불안정성**: 커널/Desktop 버전에 따라 dockerd 기동이 실패할 수
   있다. 이때는 `--no-docker-daemon` 으로 데몬 의존 작업만 건너뛰고 나머지
   (패키지 설치, repo 추가, 그룹 추가, 멱등성)는 그대로 검증한다.
   > docker 역할이 게이트 변수를 내장한다: `docker_verify`(hello-world·서버 버전 검증,
   > 기본 false)와 `docker_manage_service`(서비스 시작). `run-tests.sh` 가 기본 실행에선
   > 둘 다 true 로 켜고, `--no-docker-daemon` 이면 둘 다 false 로 끈다.
3. **아키텍처**: docker 역할이 `dpkg --print-architecture` 로 apt repo 의 arch 를
   동적으로 결정하므로(amd64/arm64) Apple Silicon 에서도 깨지지 않는다.
   단, 실측 검증은 Intel Mac(amd64)에서만 수행했다.
4. **부트스트랩 충실도**: 베이스 이미지에 python3 를 의도적으로 넣지 않아 raw
   부트스트랩이 실제로 실행된다. 단, `ca-certificates`/`sudo`/`systemd`/`openssh-server`/`tzdata`
   는 빌드시 설치되어 있다(이들은 raw 단계 이전 인프라 전제이며 부트스트랩 대상 아님).
   - **tzdata**: common 역할이 tzdata 를 직접 설치하고 시간대를 심링크 방식으로
     설정하므로, tzdata 없는 최소 이미지에서도 견고하다 (과거 하니스에서 발견된
     `given timezone "Asia/Seoul" is not available` 이슈는 해결됨).

## 트러블슈팅

- `community.docker 컬렉션이 없습니다` → 위 컬렉션 설치 명령 실행.
- `Docker 데몬에 연결할 수 없습니다` → Docker Desktop 실행 확인.
- 컨테이너가 `is-system-running` 에서 멈춤 → `--privileged`/cgroup 마운트가 막혔는지
  확인. `docker logs <컨테이너>` 로 systemd 부팅 로그 확인.
- 멱등성 실패(changed!=0) → 2회차 로그(`.context/terminal/<env>_<distro>_idempotency_*.log`)
  에서 `changed:` 로 표시된 태스크를 찾는다. 흔한 원인: `state: latest`,
  `get_url force: yes`, changed_when 누락 raw, `ignore_errors` 로 매번 재실행되는 purge.
- **이미지 노후 → 멱등성 거짓 실패**: 이미지가 오래되면 converge 도중 apt 가 systemd 등을
  부수 업그레이드하고, 그 postinst 가 시스템 상태를 바꿔(예: systemd 255.4-8.16 의
  `/etc/default/locale` 심링크 전환, provision.conf 의 `/root/.ssh` 재소유) 2회차에
  changed 가 난다. 역할 버그처럼 보이면 먼저 이미지를 재빌드할 것:
  ```bash
  docker rmi ansible-harness:ubuntu2204 ansible-harness:ubuntu2404 ansible-harness:debian12
  # 빌드 캐시가 남아 있으면: docker builder prune
  ```
