#!/usr/bin/env bash
set -euo pipefail

database_container="${SUPABASE_DB_CONTAINER:-supabase_db_serp}"
agent_command_id="$(uuidgen | tr '[:upper:]' '[:lower:]')"
presentation_command_id="$(uuidgen | tr '[:upper:]' '[:lower:]')"
agent_name="Agente concurrente ${agent_command_id:0:8}"
presentation_name="Presentacion concurrente ${presentation_command_id:0:8}"
agent_output_one="$(mktemp)"
agent_output_two="$(mktemp)"
presentation_output_one="$(mktemp)"
presentation_output_two="$(mktemp)"

cleanup() {
  rm -f "$agent_output_one" "$agent_output_two"
  rm -f "$presentation_output_one" "$presentation_output_two"
}
trap cleanup EXIT

run_sql() {
  docker exec "$database_container" \
    psql -X -v ON_ERROR_STOP=1 -U postgres -d postgres -Atqc "$1"
}

agent_sql="select (public.create_sales_agent(
  '$agent_command_id', '$agent_name', '', 'concurrency-test', 'pgTAP', 'local'
)).id;"

run_sql "$agent_sql" >"$agent_output_one" &
agent_pid_one=$!
run_sql "$agent_sql" >"$agent_output_two" &
agent_pid_two=$!
wait "$agent_pid_one"
wait "$agent_pid_two"

agent_id_one="$(tr -d '[:space:]' <"$agent_output_one")"
agent_id_two="$(tr -d '[:space:]' <"$agent_output_two")"

if [[ -z "$agent_id_one" || "$agent_id_one" != "$agent_id_two" ]]; then
  echo "FAIL: concurrent agent retries returned different entities" >&2
  exit 1
fi

agent_count="$(run_sql "select count(*) from public.sales_agents where name='$agent_name';")"
agent_receipt_count="$(run_sql "select count(*) from public.sales_agent_create_commands where command_id='$agent_command_id' and entity_id='$agent_id_one' and result_version=1;")"

if [[ "$agent_count" != "1" || "$agent_receipt_count" != "1" ]]; then
  echo "FAIL: concurrent agent command did not persist one entity and one completed receipt" >&2
  exit 1
fi

presentation_sql="select (public.create_packaging_presentation(
  '$presentation_command_id', '$presentation_name', 'concurrency-test', 'pgTAP', 'local'
)).id;"

run_sql "$presentation_sql" >"$presentation_output_one" &
presentation_pid_one=$!
run_sql "$presentation_sql" >"$presentation_output_two" &
presentation_pid_two=$!
wait "$presentation_pid_one"
wait "$presentation_pid_two"

presentation_id_one="$(tr -d '[:space:]' <"$presentation_output_one")"
presentation_id_two="$(tr -d '[:space:]' <"$presentation_output_two")"

if [[ -z "$presentation_id_one" || "$presentation_id_one" != "$presentation_id_two" ]]; then
  echo "FAIL: concurrent presentation retries returned different entities" >&2
  exit 1
fi

presentation_count="$(run_sql "select count(*) from public.packaging_presentations where name='$presentation_name';")"
presentation_receipt_count="$(run_sql "select count(*) from public.packaging_presentation_create_commands where command_id='$presentation_command_id' and entity_id='$presentation_id_one' and result_version=1;")"

if [[ "$presentation_count" != "1" || "$presentation_receipt_count" != "1" ]]; then
  echo "FAIL: concurrent presentation command did not persist one entity and one completed receipt" >&2
  exit 1
fi

echo "PASS: concurrent retries returned one agent and one presentation with completed receipts"
