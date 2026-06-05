# bootstrap 역할 (공유)

> **상위 문서**: 저장소 루트 [CLAUDE.md](../../CLAUDE.md)를 먼저 참조하세요.
> 이 역할은 `ansible-onpremise`와 `ansible-aws` 양쪽 playbook이 공유합니다.
> 복사본을 만들지 말고, 각 환경의 `ansible.cfg` `roles_path`가 이 디렉토리를 가리키게 하세요.

## 목적

Python이 전혀 설치되지 않은 깨끗한 Ubuntu/Debian 서버를 Ansible 네이티브 모듈이
동작 가능한 상태로 만드는 **최소 부트스트랩**.

- `raw` 모듈만 사용해 `python3`, `python3-apt`를 설치 (apt 모듈은 python3-apt 필요)
- 설치 후 `setup` 모듈로 facts를 명시 수집하여
  `ansible_user`, `ansible_distribution`, `ansible_distribution_release`,
  `ansible_architecture` 등을 이후 역할에서 사용 가능하게 함
- 멱등: 이미 python3/python3-apt가 있으면 설치를 건너뛰고 `changed=0`

## 사용법

play는 반드시 `gather_facts: no`로 시작하고, `roles:` 목록의 **맨 앞**에 둡니다.

```yaml
- name: Configure Server
  hosts: servers
  gather_facts: no   # bootstrap이 raw로 시작하고 끝에서 setup을 직접 호출
  become: yes
  roles:
    - bootstrap   # 1) python3/python3-apt 설치 + facts 수집
    - common      # 2) 이후 네이티브 모듈 역할
    - docker
```

## 멱등성 보장 방식

| task | 멱등 보장 방법 |
|------|----------------|
| 존재 여부 검사 | `changed_when: false` (읽기 전용 검사) |
| python3 설치 | `when: 'PY_OK' not in ...` 으로 이미 있으면 skip + 'Setting up ' 마커 기반 `changed_when` |
| facts 수집 | `setup` 모듈은 본질적으로 changed를 보고하지 않음 |

## OS 범위

Ubuntu 22.04/24.04, Debian 11/12 (apt 계열). RHEL/dnf 미지원.
`apt-get`만 사용하므로 두 배포판 모두에서 동일하게 동작합니다.
