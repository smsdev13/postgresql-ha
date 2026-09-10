#!/usr/bin/env bash

set -u

export ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

section() {
    echo
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW} $1${NC}"
    echo -e "${YELLOW}========================================${NC}"
}

section "PostgreSQL HA Validation"

info "Checking Ansible connectivity..."

if ansible all -m ping >/dev/null 2>&1; then
    pass "Ansible connectivity"
else
    fail "Ansible connectivity"
    exit 1
fi


section "PostgreSQL Nodes"

info "Checking db1, db2, db3..."

if ansible postgres -m ping >/dev/null 2>&1; then
    pass "PostgreSQL nodes: db1 db2 db3"
else
    fail "PostgreSQL nodes"
    exit 1
fi


section "Load Balancers"

info "Checking lb1, lb2..."

if ansible loadbalancers -m ping >/dev/null 2>&1; then
    pass "Load balancers: lb1 lb2"
else
    fail "Load balancers"
    exit 1
fi


section "Backup"

info "Checking backup1..."

if ansible backup -m ping >/dev/null 2>&1; then
    pass "Backup node: backup1"
else
    fail "Backup node"
    exit 1
fi


section "Monitoring"

info "Checking monitoring node..."

if ansible monitoring -m ping >/dev/null 2>&1; then
    pass "Monitoring node: db1"
else
    fail "Monitoring node"
    exit 1
fi


section "Result"

echo -e "${GREEN}All basic connectivity checks passed.${NC}"
echo

#!/usr/bin/env bash

set -u

export ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

section() {
    echo
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW} $1${NC}"
    echo -e "${YELLOW}========================================${NC}"
}

section "PostgreSQL HA Validation"

# --------------------------------------------------
# Ansible connectivity
# --------------------------------------------------

section "Connectivity"

if ansible postgres -m ping >/dev/null 2>&1; then
    pass "PostgreSQL nodes reachable"
else
    fail "PostgreSQL nodes unreachable"
    exit 1
fi

# --------------------------------------------------
# Patroni service
# --------------------------------------------------

section "Patroni"

if ansible postgres -b -m shell \
    -a "systemctl is-active --quiet patroni"; then
    pass "Patroni is active on all PostgreSQL nodes"
else
    fail "Patroni is not active on one or more nodes"
fi

# --------------------------------------------------
# Patroni API
# --------------------------------------------------

info "Checking Patroni API..."

if ansible postgres -b -m shell \
    -a "curl -sf http://{{ ansible_host }}:8008/patroni >/dev/null"; then
    pass "Patroni API is healthy"
else
    fail "Patroni API check failed"
fi

# --------------------------------------------------
# Cluster membership
# --------------------------------------------------

section "Cluster State"

info "Checking Patroni cluster membership..."

CLUSTER_OUTPUT=$(ansible db1 -b -m shell \
    -a "patronictl -c /etc/patroni.yml list" 2>/dev/null)

echo "$CLUSTER_OUTPUT"

PRIMARY_COUNT=$(echo "$CLUSTER_OUTPUT" | grep -cE '\| Primary \|')
REPLICA_COUNT=$(echo "$CLUSTER_OUTPUT" | grep -cE '\| Replica \|')

if [ "$PRIMARY_COUNT" -eq 1 ]; then
    pass "Exactly one PostgreSQL primary"
else
    fail "Expected exactly one primary, found $PRIMARY_COUNT"
fi

if [ "$REPLICA_COUNT" -eq 2 ]; then
    pass "Two PostgreSQL replicas"
else
    fail "Expected two replicas, found $REPLICA_COUNT"
fi

# --------------------------------------------------
# Replication
# --------------------------------------------------

section "Replication"

REPLICATION_OUTPUT=$(ansible db1 -b -m shell \
    -a "sudo -u postgres psql -tAc \"SELECT application_name || '|' || state || '|' || sync_state FROM pg_stat_replication ORDER BY application_name\"" \
    2>/dev/null)

echo "$REPLICATION_OUTPUT"

REPLICATION_COUNT=$(echo "$REPLICATION_OUTPUT" | grep -c '|streaming|')

if [ "$REPLICATION_COUNT" -eq 2 ]; then
    pass "Both replicas are streaming"
else
    fail "Expected 2 streaming replicas, found $REPLICATION_COUNT"
fi

# --------------------------------------------------
# Timeline
# --------------------------------------------------

section "Timeline"

TIMELINES=$(ansible postgres -b -m shell \
    -a "curl -sf http://{{ ansible_host }}:8008/patroni | python3 -c 'import sys,json; print(json.load(sys.stdin)[\"timeline\"])'" \
    2>/dev/null | grep -E '^[^ ]+ \| [0-9]+$' | awk -F'\\| ' '{print $2}' | sort -u)

TIMELINE_COUNT=$(echo "$TIMELINES" | sed '/^$/d' | wc -l)

if [ "$TIMELINE_COUNT" -eq 1 ]; then
    pass "All PostgreSQL nodes are on the same timeline"
else
    fail "PostgreSQL nodes are on different timelines"
fi

# --------------------------------------------------
# etcd
# --------------------------------------------------

section "etcd / DCS"

if ansible etcd -b -m shell \
    -a "etcdctl endpoint health" >/dev/null 2>&1; then
    pass "etcd cluster is healthy"
else
    fail "etcd cluster health check failed"
fi

if ansible db1 -b -m shell \
    -a "etcdctl get /service/postgres-ha/leader" >/dev/null 2>&1; then
    pass "Patroni DCS leader key exists"
else
    fail "Patroni DCS leader key not found"
fi

# --------------------------------------------------
# Result
# --------------------------------------------------

section "Result"

echo -e "${GREEN}PostgreSQL HA validation completed.${NC}"
