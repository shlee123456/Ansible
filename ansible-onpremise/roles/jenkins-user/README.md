# jenkins-user/README.md
# Ansible Role: jenkins-user

서버에 Jenkins 전용 계정을 생성하고 SSH 키 액세스 및 sudo 권한을 설정하는 Ansible 역할입니다.

## 요구 사항

- Ansible 2.9 이상

## 역할 변수

모든 변수는 `defaults/main.yml`에 정의되어 있습니다:

```yaml
jenkins_user: jenkins              # 생성할 사용자 이름
jenkins_group: jenkins             # 사용자의 기본 그룹
jenkins_sudo_access: true          # sudo 권한 부여 여부
jenkins_ssh_public_key: ""         # Jenkins 서버의 SSH 공개키
```

## 예제 Playbook

```yaml
- hosts: servers
  roles:
    - role: jenkins-user
      vars:
        jenkins_ssh_public_key: "ssh-ed25519 AAAAC3Nz... jenkins@deployment"
        jenkins_additional_groups:
          - docker
          - deploy
```

## 라이센스

MIT

# example-playbook.yml
---
- hosts: web_servers
  become: true
  roles:
    - role: jenkins-user
      vars:
        jenkins_ssh_public_key: "{{ lookup('file', '/path/to/jenkins_deploy_key.pub') }}"
        jenkins_additional_groups:
          - docker
          - webadmin