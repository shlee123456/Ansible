# Ansible Infrastructure Automation - Makefile
#
# 사용법: make [target]
# 도움말: make help

.PHONY: help ping-onprem ping-aws run-onprem run-aws check-onprem check-aws \
        facts-onprem facts-aws list-hosts test test-onprem test-aws clean

# 기본 타겟
.DEFAULT_GOAL := help

# 도움말
help:
	@echo "Ansible 인프라 자동화 명령어"
	@echo ""
	@echo "연결 테스트:"
	@echo "  make ping-onprem     온프레미스 SSH 연결 테스트"
	@echo "  make ping-aws        AWS SSH 연결 테스트"
	@echo ""
	@echo "플레이북 실행:"
	@echo "  make run-onprem      온프레미스 플레이북 실행"
	@echo "  make run-aws         AWS 플레이북 실행"
	@echo "  make check-onprem    온프레미스 드라이런 (미리보기)"
	@echo "  make check-aws       AWS 드라이런 (미리보기)"
	@echo ""
	@echo "정보 조회:"
	@echo "  make facts-onprem    온프레미스 시스템 정보"
	@echo "  make facts-aws       AWS 시스템 정보"
	@echo "  make list-hosts      전체 호스트 목록"
	@echo ""
	@echo "테스트 (Docker 하니스):"
	@echo "  make test            전체 멱등성 검증 (onprem+aws × 3배포판)"
	@echo "  make test-onprem     온프레미스만 검증"
	@echo "  make test-aws        AWS만 검증"
	@echo ""
	@echo "유지보수:"
	@echo "  make clean           임시 파일 + 오래된 히스토리/로그 정리"
	@echo ""
	@echo "상세 옵션은 각 환경의 start.sh 참조:"
	@echo "  cd ansible-onpremise && ./start.sh -h"
	@echo "  cd ansible-aws && ./start.sh -h"

# 연결 테스트
ping-onprem:
	@./scripts/ping.sh onpremise

ping-aws:
	@./scripts/ping.sh aws

# 플레이북 실행 (온프레미스)
run-onprem:
	@cd ansible-onpremise && ./start.sh

check-onprem:
	@cd ansible-onpremise && ./start.sh -c

# 플레이북 실행 (AWS)
run-aws:
	@cd ansible-aws && ./start.sh

check-aws:
	@cd ansible-aws && ./start.sh -c

# 시스템 정보 조회
facts-onprem:
	@./scripts/facts.sh onpremise

facts-aws:
	@./scripts/facts.sh aws

# 호스트 목록
list-hosts:
	@./scripts/list-hosts.sh all

# Docker 기반 로컬 테스트 하니스 (멱등성 검증)
test:
	@cd test && ./run-tests.sh

test-onprem:
	@cd test && ./run-tests.sh -e onprem

test-aws:
	@cd test && ./run-tests.sh -e aws

# 임시 파일 정리 + 히스토리/로그 보존 정책 (루트 CLAUDE.md 참조)
clean:
	@echo "임시 파일 정리 중..."
	@find . -name "*.retry" -delete 2>/dev/null || true
	@find . -name "*.pyc" -delete 2>/dev/null || true
	@find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@find .context/history -name "*.md" -mtime +7 -delete 2>/dev/null || true
	@ls -t .context/terminal/*.log 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
	@echo "완료"
