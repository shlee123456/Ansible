# Docker 기반 로컬 테스트 하니스

실제 온프레미스/AWS 서버 없이, macOS(Docker Desktop)에서 **일회용 Ubuntu/Debian
컨테이너**에 실제 플레이북을 적용하고 **멱등성(2회차 changed=0)** 을 검증한다.

## 무엇을 검증하나

- raw 부트스트랩(Python 미설치 → python3/python3-apt 설치)이 동작하는지
- common / docker / ssh-keys 역할이 Ubuntu 22.04, Ubuntu 24.04, Debian 12 에서 동작하는지
- 2회 연속 실행 시 모든 호스트가 `changed=0` 인지 (멱등성)

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
   따라서 프로덕션의 **비밀번호 SSH(-k)/sudo(-K)/SSH 키** 인증 경로 자체는 검증하지
   않는다. 검증 대상은 *역할 로직과 멱등성*이다. (SSH 충실도가 필요하면 베이스에
   sshd 가 이미 포함되어 있으므로, 컨테이너 22번 포트를 매핑하고
   `ansible_connection=ssh` 인벤토리를 추가해 확장할 수 있다.)
2. **docker-in-docker 의 불안정성**: 커널/Desktop 버전에 따라 dockerd 기동이 실패할 수
   있다. 이때는 `--no-docker-daemon` 으로 데몬 검증(hello-world)만 건너뛰고 나머지
   (패키지 설치, repo 추가, 그룹 추가, 멱등성)는 그대로 검증한다.
   > 데몬 검증을 var 로 끄려면 역할이 `docker_verify`/`docker_run_smoke_test` 같은
   > 게이트 변수를 지원해야 한다(역할 수정본 전제). 현재 원본 역할의 hello-world 는
   > `ignore_errors: yes` 라 실패해도 플레이는 멈추지 않지만, 멱등성 소음을 줄이기 위해
   > var 게이트 적용을 권장한다.
3. **아키텍처**: 본 개발 호스트는 Intel Mac(amd64)이라 컨테이너가 amd64 로 뜨고
   Docker apt repo 의 `arch=amd64` 가 맞는다. Apple Silicon 에서는 arm64 컨테이너가
   되어 `arch=amd64` 하드코딩이 깨지므로, docker 역할의 arch 동적화(수정본)가 필요하다.
4. **부트스트랩 충실도**: 베이스 이미지에 python3 를 의도적으로 넣지 않아 raw
   부트스트랩이 실제로 실행된다. 단, `ca-certificates`/`sudo`/`systemd`/`openssh-server`/`tzdata`
   는 빌드시 설치되어 있다(이들은 raw 단계 이전 인프라 전제이며 부트스트랩 대상 아님).
   - **tzdata 주의**: docker 의 최소 `ubuntu:22.04` base 에는 `tzdata` 가 없어
     `timezone: Asia/Seoul` 태스크가 `given timezone "Asia/Seoul" is not available`
     로 실패한다(실제 하니스 실행 중 발견됨). 실제 클라우드/서버 이미지에는 tzdata 가
     기본 포함되므로 base 이미지에 미리 설치해 둔다. **다만 common role 이 직접
     tzdata(또는 시간대 DB)를 설치하면 최소 환경에서도 견고해지므로 role 보강을 권장한다.**

## 트러블슈팅

- `community.docker 컬렉션이 없습니다` → 위 컬렉션 설치 명령 실행.
- `Docker 데몬에 연결할 수 없습니다` → Docker Desktop 실행 확인.
- 컨테이너가 `is-system-running` 에서 멈춤 → `--privileged`/cgroup 마운트가 막혔는지
  확인. `docker logs <컨테이너>` 로 systemd 부팅 로그 확인.
- 멱등성 실패(changed!=0) → 2회차 로그(`.context/terminal/<env>_<distro>_idempotency_*.log`)
  에서 `changed:` 로 표시된 태스크를 찾는다. 흔한 원인: `state: latest`,
  `get_url force: yes`, changed_when 누락 raw, `ignore_errors` 로 매번 재실행되는 purge.
