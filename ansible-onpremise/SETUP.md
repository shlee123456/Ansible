# 환경 설정 가이드

## pyenv 설정

```bash
# 1. 가상환경 생성 (최초 1회)
pyenv virtualenv 3.11.0 ansible-onpremise

# 2. 프로젝트 디렉토리에서 자동 활성화 설정
cd ansible-onpremise
pyenv local ansible-onpremise

# 3. Ansible 설치
pip install ansible
```

## 실행 방법

```bash
# 비밀번호 설정
export SSHPASS='your_password'

# 드라이런 (미리보기)
sshpass -e ansible-playbook -i inventory/hosts playbook.yml -l test-node1 -k -K --check --diff

# 실제 실행
sshpass -e ansible-playbook -i inventory/hosts playbook.yml -l test-node1 -k -K -v
```

## 필요 도구

- pyenv
- sshpass (`brew install hudochenkov/sshpass/sshpass`)
