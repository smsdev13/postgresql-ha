# etcd test

ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg ansible etcd -m shell -a "systemctl is-active etcd"

ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg ansible db1 -m shell -a \
'etcdctl --endpoints=http://10.10.10.11:2379,http://10.10.10.12:2379,http://10.10.10.13:2379 endpoint status --write-out=table'



# postgres test

ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg ansible postgres -b -m shell -a "pg_lsclusters"

ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg ansible postgres -b -m shell -a "psql --version"

ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg ansible postgres -b -m shell -a "systemctl is-active postgresql"


# patroni test

ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg ansible postgres -m shell -a "systemctl is-active patroni"

ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg ansible postgres -m shell -a "patronictl -c /etc/patroni.yml list"


# haproxy test

ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg ansible loadbalancers -b -m shell -a "systemctl is-active haproxy"

ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg ansible loadbalancers -m shell -a "ip addr show enp0s8"

ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg ansible lb1 -b -m systemd -a "name=keepalived state=stopped"

ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg ansible loadbalancers -m shell -a "ip addr show enp0s8"

ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg ansible lb1 -b -m systemd -a "name=keepalived state=started"

ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg ansible loadbalancers -m shell -a "ip addr show enp0s8"

# application test

ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg ansible loadbalancers -m shell -a \
"nc -zv 10.10.10.100 5432"


ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg ansible lb1 -m shell -a \
"curl -s http://10.10.10.11:8008/primary"


ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg ansible db1 -m shell -a \
"PGPASSWORD=postgres123 psql -h 10.10.10.100 -U postgres -d postgres -c 'select inet_server_addr(), pg_is_in_recovery();'"


ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg ansible db3 -b -m systemd -a "name=patroni state=stopped"


ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg ansible db1 -m shell -a \
"patronictl -c /etc/patroni.yml list"


ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg ansible db1 -m shell -a \
"PGPASSWORD=postgres123 psql -h 10.10.10.100 -U postgres -d postgres -c 'select inet_server_addr(), pg_is_in_recovery();'"


ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg ansible db3 -b -m systemd -a "name=patroni state=started"


ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg ansible db1 -m shell -a \
"patronictl -c /etc/patroni.yml list"
