# -l 특정 호스트 또는 그룹만 대상으로 실행
# -k 옵션은 ssh 비밀번호 입력
# -K sudo 비밀번호 입력 추가
# -v, -vvv 디버깅 용도

ansible-playbook -i inventory/hosts playbook.yml -k -K -v --check --diff

#특정 호스트 또는 그룹만 대상으로 실행
ansible-playbook -i inventory/hosts playbook.yml -l work-node1 --check --diff