# 환경 설정 가이드

## pyenv 설정

```bash
# 자동 설정 (저장소 루트에서)
../scripts/setup-env.sh

# 또는 수동 설정
pyenv virtualenv 3.11 ansible-onpremise   # 1. 가상환경 생성 (최초 1회)
cd ansible-onpremise
pyenv local ansible-onpremise             # 2. 디렉토리 진입 시 자동 활성화
pip install -r ../requirements.txt        # 3. Ansible 등 의존성 설치
```

## 인증 설정 (최초 1회)

접속 비밀번호는 `group_vars/all/vault.yml`에 Vault 암호화되어 있고,
`.vault_pass` 파일로 자동 복호화된다 (둘 다 gitignore — 새 장비에서는 별도 전달 필요).

```bash
# Vault 복호화 키 배치 (팀 내 안전한 경로로 전달받아 생성)
echo '<vault 비밀번호>' > .vault_pass
chmod 600 .vault_pass
```

## 실행 방법

```bash
# 드라이런 (미리보기) — 비밀번호 프롬프트 없음, Vault 가 인증 처리
ansible-playbook -i inventory/hosts playbook.yml -l test-node1 --check --diff

# 실제 실행
ansible-playbook -i inventory/hosts playbook.yml -l test-node1 -v

# 비상용: vault 없이 프롬프트로 인증해야 할 때만
ansible-playbook -i inventory/hosts playbook.yml -k -K
```

## 필요 도구

- pyenv
- sshpass (`brew install hudochenkov/sshpass/sshpass`)
  — Ansible 이 비밀번호 SSH 접속에 내부적으로 사용 (Vault 변수 인증에도 필요)
