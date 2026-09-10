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

section "PostgreSQL Replication Test"

info "Detecting primary..."

PRIMARY=""

for NODE in db1 db2 db3; do
    echo "[DEBUG] Checking $NODE..."

    if ansible "$NODE" -b -m shell \
        -a "curl -sf http://{{ ansible_host }}:8008/primary >/dev/null"; then
        PRIMARY="$NODE"
        break
    fi
done

if [ -z "$PRIMARY" ]; then
    fail "Could not detect primary"
    exit 1
fi

info "Primary: $PRIMARY"

TEST_ID="replication_$(date +%s)"

info "Creating test record: $TEST_ID"

CREATE_CMD="sudo -u postgres psql -d postgres -v ON_ERROR_STOP=1 -c \"CREATE TABLE IF NOT EXISTS ha_replication_test (id text PRIMARY KEY, created_at timestamptz DEFAULT now()); INSERT INTO ha_replication_test(id) VALUES ('$TEST_ID');\""

echo "[DEBUG] Running on $PRIMARY:"
echo "[DEBUG] $CREATE_CMD"

if ! ansible "$PRIMARY" -b -m shell -a "$CREATE_CMD"; then
    fail "Failed to create test record on $PRIMARY"
    exit 1
fi

pass "Test record created on $PRIMARY"

section "Replica Verification"

for REPLICA in db1 db2 db3; do

    if [ "$REPLICA" = "$PRIMARY" ]; then
        continue
    fi

    info "Checking $REPLICA..."

    QUERY="sudo -u postgres psql -d postgres -tAc \"SELECT count(*) FROM ha_replication_test WHERE id='$TEST_ID';\""

    echo "[DEBUG] Query on $REPLICA:"
    echo "[DEBUG] $QUERY"

    RESULT=$(ansible "$REPLICA" -b -m shell -a "$QUERY")

    if [ $? -ne 0 ]; then
        fail "Query failed on $REPLICA"
        echo "$RESULT"
        continue
    fi

    echo "[DEBUG] Result from $REPLICA:"
    echo "$RESULT"

    if echo "$RESULT" | grep -q "1"; then
        pass "$REPLICA received replicated record"
    else
        fail "$REPLICA did not receive replicated record"
    fi

done

section "Result"

echo -e "${GREEN}Replication test completed.${NC}"
