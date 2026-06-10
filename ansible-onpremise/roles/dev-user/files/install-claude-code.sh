#!/usr/bin/env bash
#
# install-claude-code.sh — 새 서버에 Claude Code를 설치하는 스크립트
#
# 사용법:
#   ./install-claude-code.sh            # 최신 stable 버전 설치
#   ./install-claude-code.sh latest     # latest 채널 설치
#   ./install-claude-code.sh 2.0.1      # 특정 버전 설치
#
# 동작:
#   1. 이미 설치되어 있으면 버전 출력 후 종료 (FORCE=1 로 재설치 가능)
#   2. 공식 네이티브 인스톨러(curl | bash) 시도
#   3. 실패 시 npm 글로벌 설치로 폴백 (Node.js 18+ 필요)
#   4. PATH 에 ~/.local/bin 등록 (bash/zsh rc 파일)
#   5. 설치 확인 (claude --version)

set -euo pipefail

VERSION="${1:-stable}"
INSTALL_DIR="$HOME/.local/bin"

log()  { printf '\033[1;32m[INFO]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; }

# ── 0. root 로 실행 시 경고 ─────────────────────────────────────────
if [ "$(id -u)" -eq 0 ]; then
  warn "root 로 실행 중입니다. 일반 사용자 계정으로 설치하는 것을 권장합니다."
fi

# ── 1. 이미 설치되어 있는지 확인 ────────────────────────────────────
if command -v claude >/dev/null 2>&1 && [ "${FORCE:-0}" != "1" ]; then
  log "Claude Code 가 이미 설치되어 있습니다: $(claude --version)"
  log "재설치하려면 FORCE=1 $0 으로 실행하세요."
  exit 0
fi

# ── 2. 필수 도구 확인 ───────────────────────────────────────────────
if ! command -v curl >/dev/null 2>&1; then
  err "curl 이 필요합니다. 먼저 설치하세요. (예: apt-get install -y curl)"
  exit 1
fi

OS="$(uname -s)"
case "$OS" in
  Linux|Darwin) ;;
  *) err "지원하지 않는 OS 입니다: $OS (Windows 는 WSL 에서 실행하세요)"; exit 1 ;;
esac

# ── 3. 네이티브 인스톨러 시도 ───────────────────────────────────────
install_native() {
  log "공식 네이티브 인스톨러로 설치를 시도합니다 (버전: $VERSION)..."
  curl -fsSL https://claude.ai/install.sh | bash -s -- "$VERSION"
}

# ── 4. npm 폴백 ─────────────────────────────────────────────────────
install_npm() {
  if ! command -v npm >/dev/null 2>&1; then
    err "네이티브 설치가 실패했고 npm 도 없습니다."
    err "Node.js 18+ 를 설치한 뒤 다시 실행하세요. (예: https://nodejs.org 또는 nvm)"
    exit 1
  fi
  local node_major
  node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  if [ "$node_major" -lt 18 ]; then
    err "Node.js 18 이상이 필요합니다. 현재: $(node --version 2>/dev/null || echo '없음')"
    exit 1
  fi
  log "npm 으로 설치합니다..."
  if [ "$VERSION" = "stable" ] || [ "$VERSION" = "latest" ]; then
    npm install -g @anthropic-ai/claude-code
  else
    npm install -g "@anthropic-ai/claude-code@$VERSION"
  fi
}

if ! install_native; then
  warn "네이티브 인스톨러 설치에 실패했습니다. npm 폴백을 시도합니다."
  install_npm
fi

# ── 5. PATH 등록 ────────────────────────────────────────────────────
add_path_to_rc() {
  local rc="$1"
  local line="export PATH=\"\$HOME/.local/bin:\$PATH\""
  if [ -f "$rc" ] && ! grep -qF '.local/bin' "$rc"; then
    printf '\n# Claude Code\n%s\n' "$line" >> "$rc"
    log "PATH 설정을 $rc 에 추가했습니다."
  fi
}

if [ -x "$INSTALL_DIR/claude" ]; then
  add_path_to_rc "$HOME/.bashrc"
  add_path_to_rc "$HOME/.zshrc"
  export PATH="$INSTALL_DIR:$PATH"
fi

# ── 6. 설치 확인 ────────────────────────────────────────────────────
if command -v claude >/dev/null 2>&1; then
  log "설치 완료: $(claude --version)"
  log "새 셸을 열거나 'source ~/.bashrc' 후 'claude' 를 실행하세요."
  log "첫 실행 시 로그인이 필요합니다. headless 서버는 ANTHROPIC_API_KEY 환경변수 또는"
  log "'claude setup-token' 으로 발급한 토큰을 사용할 수 있습니다."
else
  err "설치가 끝났지만 'claude' 명령을 찾을 수 없습니다. PATH 를 확인하세요: $INSTALL_DIR"
  exit 1
fi
