#!/usr/bin/env bash
#
# ============================================================================
#  Docker 기반 로컬 테스트 하니스
#  - 일회용 Ubuntu/Debian 컨테이너에서 실제 플레이북을 실행
#  - 2회 실행하여 멱등성(changed=0)을 검증
#  - 실제 서버 없이 macOS(Docker Desktop)에서 동작
# ============================================================================
#
# 사용법:
#   ./run-tests.sh                      # 전체(onprem+aws) × 전체 배포판, 멱등성까지
#   ./run-tests.sh -e onprem            # 온프레미스만
#   ./run-tests.sh -e aws -d debian12   # AWS × debian12 만
#   ./run-tests.sh --no-docker-daemon   # docker 데몬 의존 작업(서비스 시작 + hello-world) 건너뜀 (DinD 불안정 시)
#   ./run-tests.sh --keep               # 실패/성공 후 컨테이너 보존(디버깅)
#   ./run-tests.sh --converge-only      # 1회만 실행(멱등성 검증 생략)
#   ./run-tests.sh -h
#
# 종료 코드: 0 = 모든 시나리오 통과, 1 = 하나라도 실패
#
# ── 멱등성 판정 방식 ──
#   2회차 실행의 PLAY RECAP 을 파싱하여 모든 호스트가 changed=0 이면 통과.
#   changed!=0 또는 failed!=0 이면 실패로 처리합니다.
#
# ── systemd-in-docker (Docker Desktop for Mac) 필수 플래그 ──
#   --privileged        : systemd 가 cgroup/마운트를 제어하려면 필요
#   --cgroupns=host     : 호스트 cgroup 네임스페이스 공유 (cgroup v2)
#   -v /sys/fs/cgroup:/sys/fs/cgroup:rw : systemd 가 cgroup 계층에 접근
#   --tmpfs /run --tmpfs /run/lock      : 런타임 디렉터리
#   이 플래그들이 있어야 역할의 service/systemctl 호출과 dockerd 기동이 가능합니다.
# ============================================================================

set -euo pipefail

# ── 경로 ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOCKERFILE="${SCRIPT_DIR}/docker/Dockerfile.systemd"
INVENTORY="${SCRIPT_DIR}/inventory/hosts.yml"

# ── 색상 ──
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[FAIL]${NC} $*" >&2; }

# ── 기본 옵션 ──
ENVS="onprem aws"                 # 검증할 환경
DISTROS="ubuntu2204 ubuntu2404 debian12"   # 검증할 배포판
RUN_DOCKER_DAEMON=1              # docker 역할의 데몬 검증(hello-world) 수행 여부
KEEP=0                          # 컨테이너 보존 여부
CONVERGE_ONLY=0                 # 멱등성 검증 생략 여부
CONTAINER_PREFIX="ans-test"
IMAGE_PREFIX="ansible-harness"

# 배포판 → 베이스 이미지 매핑
# macOS 기본 bash 는 3.2 라 연관배열(declare -A)을 못 쓰므로 case 함수로 구현.
base_image_for() {
  case "$1" in
    ubuntu2204) echo "ubuntu:22.04" ;;
    ubuntu2404) echo "ubuntu:24.04" ;;
    debian12)   echo "debian:12" ;;
    *) echo "" ;;
  esac
}

# ── 도움말 ──
show_help() {
  sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
}

# ── 옵션 파싱 ──
while [[ $# -gt 0 ]]; do
  case "$1" in
    -e|--env)     ENVS="$2"; shift 2 ;;
    -d|--distro)  DISTROS="$2"; shift 2 ;;
    --no-docker-daemon) RUN_DOCKER_DAEMON=0; shift ;;
    --keep)       KEEP=1; shift ;;
    --converge-only) CONVERGE_ONLY=1; shift ;;
    -h|--help)    show_help ;;
    *) err "알 수 없는 옵션: $1"; echo "도움말: $0 -h"; exit 1 ;;
  esac
done

# ============================================================================
#  1) ansible 실행기 확인 (호스트 pyenv venv 문제 해결)
# ============================================================================
# 프로젝트의 ansible 은 pyenv 가상환경 안에만 있고, 평범한 셸의 shim 은
# 'pyenv: ansible-playbook: command not found' 로 실패합니다.
# 아래 순서로 신뢰성 있게 실행기를 찾습니다.
#   1. 이미 PATH 에서 실제로 실행 가능한 ansible-playbook
#   2. ANSIBLE_VENV 환경변수로 지정된 venv 의 bin
#   3. pyenv versions/ 아래에서 ansible-playbook 을 가진 venv 자동 탐색
#      (CLAUDE.md 는 'ansible' 이라 하지만 실제 디스크는 'ansible-onpremise'.
#       이름에 의존하지 않고 ansible-playbook 존재 여부로 탐색)
resolve_ansible() {
  # 1. PATH 에서 진짜 동작하는지 확인 (pyenv shim 의 가짜 성공 배제)
  if command -v ansible-playbook >/dev/null 2>&1; then
    if ansible-playbook --version >/dev/null 2>&1; then
      ANSIBLE_PLAYBOOK="$(command -v ansible-playbook)"
      return 0
    fi
  fi

  # 2. 명시적 지정
  if [[ -n "${ANSIBLE_VENV:-}" && -x "${ANSIBLE_VENV}/bin/ansible-playbook" ]]; then
    ANSIBLE_PLAYBOOK="${ANSIBLE_VENV}/bin/ansible-playbook"
    return 0
  fi

  # 3. pyenv 가상환경 자동 탐색
  local pyenv_root="${PYENV_ROOT:-$HOME/.pyenv}"
  if [[ -d "${pyenv_root}/versions" ]]; then
    # 'ansible' 우선, 없으면 'ansible*' 패턴, 그래도 없으면 첫 매치
    local candidates=()
    [[ -x "${pyenv_root}/versions/ansible/bin/ansible-playbook" ]] && candidates+=("${pyenv_root}/versions/ansible")
    local d
    for d in "${pyenv_root}"/versions/ansible*; do
      [[ -x "${d}/bin/ansible-playbook" ]] && candidates+=("${d}")
    done
    if [[ ${#candidates[@]} -gt 0 ]]; then
      ANSIBLE_PLAYBOOK="${candidates[0]}/bin/ansible-playbook"
      return 0
    fi
  fi

  return 1
}

if ! resolve_ansible; then
  err "ansible-playbook 을 찾을 수 없습니다."
  err "pyenv 가상환경을 활성화하거나(ANSIBLE_VENV 로 경로 지정) requirements 를 설치하세요:"
  err "  pyenv activate ansible-onpremise   # 또는 해당 venv"
  err "  또는  ANSIBLE_VENV=\$HOME/.pyenv/versions/ansible-onpremise $0"
  exit 1
fi
log "ansible-playbook: ${ANSIBLE_PLAYBOOK}"
"${ANSIBLE_PLAYBOOK}" --version | head -1

# community.docker 연결 플러그인 존재 확인 (없으면 컨테이너에 닿을 수 없음)
ANSIBLE_BIN_DIR="$(dirname "${ANSIBLE_PLAYBOOK}")"
if ! "${ANSIBLE_BIN_DIR}/ansible-galaxy" collection list 2>/dev/null | grep -qi 'community.docker'; then
  err "community.docker 컬렉션이 없습니다. 설치:"
  err "  ${ANSIBLE_BIN_DIR}/ansible-galaxy collection install community.docker community.general"
  exit 1
fi

# Docker 데몬 확인
if ! docker info >/dev/null 2>&1; then
  err "Docker 데몬에 연결할 수 없습니다. Docker Desktop 이 실행 중인지 확인하세요."
  exit 1
fi

# ── 로그 디렉터리 (CLAUDE.md: .context/terminal/ 는 gitignore) ──
LOG_DIR="${REPO_ROOT}/.context/terminal"
mkdir -p "${LOG_DIR}"
TS="$(date +%Y%m%d_%H%M%S)"

# ── 환경 변수: ansible 이 본 디렉터리의 ansible.cfg 와 컬렉션을 쓰도록 ──
export ANSIBLE_CONFIG="${SCRIPT_DIR}/ansible.cfg"
# 주의: ANSIBLE_FORCE_COLOR 는 설정하지 않는다.
#       색상 ANSI 코드가 PLAY RECAP 의 'changed=N' 토큰에 섞이면 parse_recap 이
#       changed 수를 0 으로 오판하여 비멱등 실행을 거짓 PASS 시킨다.
# 모듈을 도커 컨테이너로 보낼 때 호스트 키 검사 등 비활성 (cfg 에도 있으나 명시)
export ANSIBLE_HOST_KEY_CHECKING=False

# ── 정리 대상 컨테이너 추적 ──
STARTED_CONTAINERS=()

cleanup() {
  if [[ ${KEEP} -eq 1 ]]; then
    warn "--keep 지정: 컨테이너를 보존합니다. 수동 정리:"
    warn "  docker rm -f ${STARTED_CONTAINERS[*]:-<none>}"
    return
  fi
  if [[ ${#STARTED_CONTAINERS[@]} -gt 0 ]]; then
    log "컨테이너 정리 중..."
    docker rm -f "${STARTED_CONTAINERS[@]}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# ============================================================================
#  2) 이미지 빌드
# ============================================================================
build_image() {
  local distro="$1"
  local base; base="$(base_image_for "${distro}")"
  local image="${IMAGE_PREFIX}:${distro}"
  log "이미지 빌드: ${image}  (base=${base})"
  # amd64 호스트(Intel Mac)에서는 기본 플랫폼이 linux/amd64.
  # Apple Silicon 이라면 BASE 가 arm64 로 풀되며, 역할의 arch 처리(수정본)가 필요.
  docker build \
    --build-arg "BASE_IMAGE=${base}" \
    -t "${image}" \
    -f "${DOCKERFILE}" \
    "${SCRIPT_DIR}/docker" \
    >"${LOG_DIR}/build_${distro}_${TS}.log" 2>&1 \
    || { err "이미지 빌드 실패: ${image} (로그: ${LOG_DIR}/build_${distro}_${TS}.log)"; tail -20 "${LOG_DIR}/build_${distro}_${TS}.log"; return 1; }
  ok "이미지 준비 완료: ${image}"
}

# ============================================================================
#  3) 컨테이너 기동 (systemd + DinD 가능하도록 privileged)
# ============================================================================
start_container() {
  local env="$1" distro="$2"
  local image="${IMAGE_PREFIX}:${distro}"
  local cname="${CONTAINER_PREFIX}-${env}-${distro}"

  # 기존 동명 컨테이너 제거
  docker rm -f "${cname}" >/dev/null 2>&1 || true

  log "컨테이너 기동: ${cname}"
  # systemd-in-docker 필수 플래그 (Docker Desktop for Mac, cgroup v2)
  docker run -d \
    --name "${cname}" \
    --hostname "${cname}" \
    --privileged \
    --cgroupns=host \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    --tmpfs /run \
    --tmpfs /run/lock \
    "${image}" \
    >/dev/null

  STARTED_CONTAINERS+=("${cname}")

  # systemd 가 부팅을 마칠 때까지 대기 (running 상태가 될 때까지 폴링)
  local i
  for i in $(seq 1 30); do
    if docker exec "${cname}" systemctl is-system-running >/dev/null 2>&1; then
      break
    fi
    # degraded 도 허용 (컨테이너에서는 일부 유닛이 실패할 수 있음)
    if docker exec "${cname}" systemctl is-system-running 2>/dev/null | grep -qE 'running|degraded'; then
      break
    fi
    sleep 1
  done
  ok "컨테이너 부팅 완료: ${cname} ($(docker exec "${cname}" systemctl is-system-running 2>/dev/null || echo unknown))"
}

# ============================================================================
#  4) 플레이북 실행 (+ 멱등성 판정)
# ============================================================================
# PLAY RECAP 에서 changed/failed 합계를 추출 (마지막 RECAP 블록만)
parse_recap() {
  # 입력: 실행 로그 파일 / 출력: "changed_total failed_total"
  local logfile="$1"
  # ANSI 색상 이스케이프를 먼저 제거한 뒤 파싱 (color 가 섞이면 changed 오판).
  # RECAP 자체가 없으면 '-1 -1' 을 출력해 호출부에서 실패로 처리하게 한다.
  sed $'s/\x1b\\[[0-9;]*m//g' "${logfile}" | awk '
    /PLAY RECAP/ {recap=1; ch=0; fa=0; found=0; next}
    recap==1 && /changed=/ {
      found=1
      for (i=1;i<=NF;i++) {
        if ($i ~ /^changed=/) { split($i,a,"="); ch+=a[2] }
        if ($i ~ /^failed=/)  { split($i,a,"="); fa+=a[2] }
      }
    }
    END { if (found==0) print "-1 -1"; else print ch" "fa }
  '
}

run_playbook() {
  local env="$1" distro="$2" pass="$3"   # pass: converge | idempotency
  local playbook="${SCRIPT_DIR}/playbooks/${env}.yml"
  local host="${env}-${distro}"          # 인벤토리상 호스트명
  local logfile="${LOG_DIR}/${env}_${distro}_${pass}_${TS}.log"

  # docker 역할의 데몬 검증(hello-world)은 var/태그로 제어.
  # 기본은 --skip-tags 로 끄지 않되, --no-docker-daemon 이면 docker 데몬 검증만 스킵.
  local extra_args=()
  if [[ ${RUN_DOCKER_DAEMON} -eq 0 ]]; then
    # 데몬 의존 작업을 모두 끈다:
    #   docker_verify=false        → hello-world / server 버전 검증 스킵
    #   docker_manage_service=false → service(docker/containerd) 시작 스킵
    # (둘 다 systemd PID1 + --privileged 가 없는 컨테이너에서 실패하는 작업)
    extra_args+=(-e "docker_verify=false" -e "docker_manage_service=false")
  else
    extra_args+=(-e "docker_verify=true" -e "docker_manage_service=true")
  fi

  log "[${env}/${distro}] ${pass} 실행..."
  set +e
  "${ANSIBLE_PLAYBOOK}" \
    -i "${INVENTORY}" \
    -l "${host}" \
    "${playbook}" \
    "${extra_args[@]}" \
    2>&1 | tee "${logfile}"
  local rc=${PIPESTATUS[0]}
  set -e

  if [[ ${rc} -ne 0 ]]; then
    err "[${env}/${distro}] ${pass} 플레이북 실패 (rc=${rc}). 로그: ${logfile}"
    return 1
  fi

  if [[ "${pass}" == "idempotency" ]]; then
    read -r changed failed < <(parse_recap "${logfile}")
    log "[${env}/${distro}] 2회차 RECAP: changed=${changed} failed=${failed}"
    if [[ "${changed}" == "0" && "${failed}" == "0" ]]; then
      ok "[${env}/${distro}] 멱등성 통과 (changed=0)"
      return 0
    else
      err "[${env}/${distro}] 멱등성 실패: changed=${changed} failed=${failed}"
      err "  → 2회차에 변경을 보고한 태스크가 있습니다. 로그에서 'changed:' 항목 확인: ${logfile}"
      return 1
    fi
  fi
  return 0
}

# ============================================================================
#  5) 메인 루프
# ============================================================================
declare -a RESULTS=()
OVERALL_RC=0

# 필요한 배포판 이미지를 먼저 한 번씩 빌드
for distro in ${DISTROS}; do
  [[ -n "$(base_image_for "${distro}")" ]] || { err "알 수 없는 배포판: ${distro}"; exit 1; }
  build_image "${distro}" || { OVERALL_RC=1; RESULTS+=("BUILD ${distro}: FAIL"); continue; }
done

for env in ${ENVS}; do
  case "${env}" in onprem|aws) ;; *) err "알 수 없는 환경: ${env}"; exit 1 ;; esac
  for distro in ${DISTROS}; do
    [[ -n "$(base_image_for "${distro}")" ]] || continue
    scenario="${env}/${distro}"
    echo ""
    echo -e "${YELLOW}========================================================${NC}"
    echo -e "${YELLOW} 시나리오: ${scenario}${NC}"
    echo -e "${YELLOW}========================================================${NC}"

    if ! start_container "${env}" "${distro}"; then
      RESULTS+=("${scenario}: 컨테이너 기동 실패"); OVERALL_RC=1; continue
    fi

    # 1회차: converge
    if ! run_playbook "${env}" "${distro}" "converge"; then
      RESULTS+=("${scenario}: converge 실패"); OVERALL_RC=1
      [[ ${KEEP} -eq 0 ]] && docker rm -f "${CONTAINER_PREFIX}-${env}-${distro}" >/dev/null 2>&1 || true
      continue
    fi

    # 2회차: 멱등성
    if [[ ${CONVERGE_ONLY} -eq 0 ]]; then
      if ! run_playbook "${env}" "${distro}" "idempotency"; then
        RESULTS+=("${scenario}: 멱등성 실패"); OVERALL_RC=1
      else
        RESULTS+=("${scenario}: PASS (converge + idempotency)")
      fi
    else
      RESULTS+=("${scenario}: PASS (converge only)")
    fi

    # 시나리오별 컨테이너 즉시 정리(보존 옵션 아니면)
    if [[ ${KEEP} -eq 0 ]]; then
      docker rm -f "${CONTAINER_PREFIX}-${env}-${distro}" >/dev/null 2>&1 || true
      # 정리된 컨테이너를 추적 목록에서 제거 (요소 자체를 빼서 빈 문자열 잔여 방지).
      # macOS 기본 bash 3.2 + set -u 에서 빈 배열 확장이 죽지 않도록 개수로 가드.
      _kept=()
      for _c in "${STARTED_CONTAINERS[@]}"; do
        [[ "${_c}" != "${CONTAINER_PREFIX}-${env}-${distro}" ]] && _kept+=("${_c}")
      done
      if [[ ${#_kept[@]} -gt 0 ]]; then STARTED_CONTAINERS=("${_kept[@]}"); else STARTED_CONTAINERS=(); fi
    fi
  done
done

# ============================================================================
#  6) 요약
# ============================================================================
echo ""
echo -e "${YELLOW}==================== 결과 요약 ====================${NC}"
for r in "${RESULTS[@]}"; do
  if [[ "${r}" == *PASS* ]]; then ok "${r}"; else err "${r}"; fi
done
echo -e "${YELLOW}==================================================${NC}"
echo "로그: ${LOG_DIR}/*_${TS}.log"

if [[ ${OVERALL_RC} -eq 0 ]]; then
  ok "모든 시나리오 통과"
else
  err "일부 시나리오 실패"
fi
exit ${OVERALL_RC}
