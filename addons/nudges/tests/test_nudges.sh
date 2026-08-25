#!/bin/bash
set -euo pipefail

ADDON=$(cd "$(dirname "$0")/.." && pwd)
RUN="$ADDON/bin/run"
PASSED=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  [[ "$1" == *"$2"* ]] || fail "expected output to contain: $2"
}

setup_case() {
  CASE_DIR=$(mktemp -d)
  export HOME="$CASE_DIR/home"
  export JUGNU_HELPER_CLOCK="$CASE_DIR/clock-helper"
  export CLOCK_LIST_FILE="$CASE_DIR/clock-list.json"
  CLOCK_LOG="$CASE_DIR/clock.log"
  mkdir -p "$HOME" "$JUGNU_HELPER_CLOCK/bin"
  cat > "$JUGNU_HELPER_CLOCK/bin/clock" <<EOF
#!/bin/bash
request=\$(cat)
printf '%s\n' "\$request" >> "$CLOCK_LOG"
if [[ "\$request" == *'"op":"list"'* ]]; then
  if [[ -f "$CLOCK_LIST_FILE" ]]; then
    cat "$CLOCK_LIST_FILE"
  else
    printf '{"ok":true,"timers":[]}\n'
  fi
else
  printf '{"ok":true}\n'
fi
EOF
  chmod +x "$JUGNU_HELPER_CLOCK/bin/clock"
}

teardown_case() {
  rm -rf "$CASE_DIR"
}

write_state() {
  mkdir -p "$HOME/.local/share/jugnu/state/nudges"
  cat > "$HOME/.local/share/jugnu/state/nudges/nudges.yaml"
}

write_current_timers() {
  local include_water=${1:-yes}
  local water=""
  if [[ "$include_water" == "yes" ]]; then
    water=',{"id":"nudges:water","kind":"interval","interval_seconds":2700,"enabled":true,"paused":false,"next_fire":"2030-01-01T00:45:00Z","group":"nudges","target":{"addon":"nudges","command":"show-card"}}'
  fi
  cat > "$CLOCK_LIST_FILE" <<EOF
{"ok":true,"timers":[{"id":"nudges:eye-rest","kind":"interval","interval_seconds":1200,"enabled":true,"paused":false,"next_fire":"2030-01-01T00:20:00Z","group":"nudges","target":{"addon":"nudges","command":"show-card"}}${water},{"id":"nudges:stretch","kind":"interval","interval_seconds":3600,"enabled":true,"paused":false,"next_fire":"2030-01-01T01:00:00Z","group":"nudges","target":{"addon":"nudges","command":"show-card"}}]}
EOF
}

full_state() {
  cat <<'EOF'
template:
  emoji: "✨"
  title: "New nudge"
  message: "A small reminder."
  interval_minutes: 30
  accent: null
rows:
  - id: "eye-rest"
    emoji: "👀"
    title: "Eyes"
    message: "Glow somewhere farther away for a bit."
    interval_minutes: 20
    accent: null
    enabled: true
  - id: "water"
    emoji: "💧"
    title: "Water"
    message: "Your cells called. They’re thirsty."
    interval_minutes: 45
    accent: null
    enabled: true
  - id: "stretch"
    emoji: "🧘"
    title: "Stretch"
    message: "Uncurl. The chair will survive."
    interval_minutes: 60
    accent: null
    enabled: true
EOF
}

test_first_run_writes_yaml_and_schedules_presets() {
  setup_case
  output=$(printf '{"api":1,"op":"run","command":"manage","args":{}}\n' | "$RUN")
  state=$(cat "$HOME/.local/share/jugnu/state/nudges/nudges.yaml")
  assert_contains "$output" '"ok":true'
  assert_contains "$state" $'template:\n'
  assert_contains "$state" $'rows:\n'
  [[ "$state" != \{* ]] || fail "state must be YAML, not JSON"
  [[ $(rg -c '"op":"upsert"' "$CLOCK_LOG") == 3 ]] || fail "expected three preset upserts"
  ! rg -q '/usr/bin/python3' "$RUN" || fail "runtime must not use Python"
  teardown_case
  PASSED=$((PASSED + 1))
}

test_show_card_accepts_generic_timer_id() {
  setup_case
  full_state | write_state
  write_current_timers
  output=$(printf '{"api":1,"op":"run","command":"show-card","args":{"timerId":"nudges:water"}}\n' | "$RUN")
  assert_contains "$output" '"title":"Water"'
  assert_contains "$output" '"emoji":"💧"'
  teardown_case
  PASSED=$((PASSED + 1))
}

test_show_card_still_accepts_row_id() {
  setup_case
  full_state | write_state
  write_current_timers
  output=$(printf '{"api":1,"op":"run","command":"show-card","args":{"rowId":"eye-rest"}}\n' | "$RUN")
  assert_contains "$output" '"title":"Eyes"'
  teardown_case
  PASSED=$((PASSED + 1))
}

test_load_reconciles_only_missing_timer() {
  setup_case
  full_state | write_state
  write_current_timers no
  printf '{"api":1,"op":"run","command":"manage","args":{}}\n' | "$RUN" >/dev/null
  [[ $(rg -c '"op":"upsert"' "$CLOCK_LOG") == 1 ]] || fail "expected one missing timer upsert"
  assert_contains "$(cat "$CLOCK_LOG")" '"id":"nudges:water"'
  teardown_case
  PASSED=$((PASSED + 1))
}

test_reconcile_preserves_pause_and_next_fire() {
  setup_case
  full_state | write_state
  cat > "$CLOCK_LIST_FILE" <<'EOF'
{"ok":true,"timers":[{"id":"nudges:eye-rest","kind":"interval","interval_seconds":1200,"enabled":true,"paused":false,"next_fire":"2030-01-01T00:20:00Z","group":"nudges","target":{"addon":"nudges","command":"show-card"}},{"id":"nudges:water","kind":"interval","interval_seconds":60,"enabled":true,"paused":true,"next_fire":"2030-02-03T04:05:06Z","group":"nudges","target":{"addon":"nudges","command":"show-card"}},{"id":"nudges:stretch","kind":"interval","interval_seconds":3600,"enabled":true,"paused":false,"next_fire":"2030-01-01T01:00:00Z","group":"nudges","target":{"addon":"nudges","command":"show-card"}}]}
EOF
  printf '{"api":1,"op":"run","command":"manage","args":{}}\n' | "$RUN" >/dev/null
  request=$(rg '"op":"upsert"' "$CLOCK_LOG")
  assert_contains "$request" '"paused":true'
  assert_contains "$request" '"next_fire":"2030-02-03T04:05:06Z"'
  teardown_case
  PASSED=$((PASSED + 1))
}

test_restore_only_upserts_missing_preset() {
  setup_case
  full_state | write_state
  perl -0777 -pi -e 's/  - id: "water".*?(?=  - id: "stretch")//s' "$HOME/.local/share/jugnu/state/nudges/nudges.yaml"
  write_current_timers no
  printf '{"api":1,"op":"run","command":"restore-presets","args":{}}\n' | "$RUN" >/dev/null
  [[ $(rg -c '"op":"upsert"' "$CLOCK_LOG") == 1 ]] || fail "restore must upsert only the missing preset"
  assert_contains "$(cat "$CLOCK_LOG")" '"id":"nudges:water"'
  teardown_case
  PASSED=$((PASSED + 1))
}

test_restore_preserves_existing_orphan_timer() {
  setup_case
  full_state | write_state
  perl -0777 -pi -e 's/  - id: "water".*?(?=  - id: "stretch")//s' "$HOME/.local/share/jugnu/state/nudges/nudges.yaml"
  ! rg -q 'id: "water"' "$HOME/.local/share/jugnu/state/nudges/nudges.yaml" || fail "water fixture row was not removed"
  cat > "$CLOCK_LIST_FILE" <<'EOF'
{"ok":true,"timers":[{"id":"nudges:eye-rest","kind":"interval","interval_seconds":1200,"enabled":true,"paused":true,"next_fire":"2030-01-01T00:20:00Z","group":"nudges","target":{"addon":"nudges","command":"show-card"}},{"id":"nudges:water","kind":"interval","interval_seconds":2700,"enabled":true,"paused":true,"next_fire":"2030-02-03T04:05:06Z","group":"nudges","target":{"addon":"nudges","command":"show-card"}},{"id":"nudges:stretch","kind":"interval","interval_seconds":3600,"enabled":true,"paused":true,"next_fire":"2030-01-01T01:00:00Z","group":"nudges","target":{"addon":"nudges","command":"show-card"}}]}
EOF
  output=$(printf '{"api":1,"op":"run","command":"restore-presets","args":{}}\n' | "$RUN")
  assert_contains "$output" '"ok":true'
  assert_contains "$(cat "$HOME/.local/share/jugnu/state/nudges/nudges.yaml")" '  - id: "water"'
  ! rg -q '"op":"upsert"' "$CLOCK_LOG" || fail "restore must not replace an existing orphan timer"
  assert_contains "$(cat "$CLOCK_LIST_FILE")" '"paused":true'
  assert_contains "$(cat "$CLOCK_LIST_FILE")" '"next_fire":"2030-02-03T04:05:06Z"'
  teardown_case
  PASSED=$((PASSED + 1))
}

test_pause_and_resume_use_nudges_group() {
  setup_case
  full_state | write_state
  write_current_timers
  printf '{"api":1,"op":"run","command":"pause","args":{}}\n' | "$RUN" >/dev/null
  printf '{"api":1,"op":"run","command":"resume","args":{}}\n' | "$RUN" >/dev/null
  assert_contains "$(cat "$CLOCK_LOG")" '"op":"pause","group":"nudges"'
  assert_contains "$(cat "$CLOCK_LOG")" '"op":"resume","group":"nudges"'
  teardown_case
  PASSED=$((PASSED + 1))
}

test_manage_lists_selectable_rows_and_add() {
  setup_case
  full_state | write_state
  write_current_timers
  output=$(printf '{"api":1,"op":"run","command":"manage","args":{}}\n' | "$RUN")
  assert_contains "$output" '"id":"water","title":"💧 Water","subtitle":"Enabled · Every 45 min","actions":["select"]'
  assert_contains "$output" '"id":"add","title":"➕ Add nudge","subtitle":"Create a new nudge","actions":["select"]'
  [[ "$output" != *'"actions":["toggle","edit","delete"]'* ]] || fail "manage exposed unreachable multi-action rows"
  actions=$(printf '{"api":1,"op":"run","command":"manage","args":{"itemId":"water","action":"select"}}\n' | "$RUN")
  assert_contains "$actions" '"id":"toggle:water","title":"🔁 Toggle","actions":["select"]'
  assert_contains "$actions" '"id":"edit:water","title":"✏️ Edit","actions":["select"]'
  assert_contains "$actions" '"id":"delete:water","title":"🗑️ Delete","actions":["select"]'
  teardown_case
  PASSED=$((PASSED + 1))
}

test_manage_add_form_uses_template_and_saves_row() {
  setup_case
  full_state | write_state
  write_current_timers
  form=$(printf '{"api":1,"op":"run","command":"manage","args":{"itemId":"add","action":"select"}}\n' | "$RUN")
  assert_contains "$form" '"pattern":"form"'
  assert_contains "$form" '"id":"emoji","label":"Emoji","kind":"text","value":"✨"'
  assert_contains "$form" '"id":"interval_minutes","label":"Interval (minutes)","kind":"text","value":30'
  output=$(printf '{"api":1,"op":"run","command":"manage","args":{"id":"breathe","emoji":"🌬️","title":"Breathe","message":"Slow down.","interval_minutes":"15","accent":"","enabled":true}}\n' | "$RUN")
  assert_contains "$output" '"message":"Nudge added."'
  state=$(cat "$HOME/.local/share/jugnu/state/nudges/nudges.yaml")
  assert_contains "$state" '  - id: "breathe"'
  assert_contains "$state" '    interval_minutes: 15'
  assert_contains "$(cat "$CLOCK_LOG")" '"id":"nudges:breathe"'
  teardown_case
  PASSED=$((PASSED + 1))
}

test_manage_edit_keeps_identity_and_syncs_clock() {
  setup_case
  full_state | write_state
  write_current_timers
  form=$(printf '{"api":1,"op":"run","command":"manage","args":{"itemId":"edit:water","action":"select"}}\n' | "$RUN")
  assert_contains "$form" '"id":"title","label":"Title","kind":"text","value":"Water"'
  [[ "$form" != *'"id":"id","label":"ID"'* ]] || fail "edit form exposed editable identity"
  assert_contains "$form" '"id":"edit:water:message"'
  output=$(printf '{"api":1,"op":"run","command":"manage","args":{"id":"stretch","emoji":"💧","title":"Hydrate","edit:water:message":"Drink.","interval_minutes":"50","accent":"","enabled":true}}\n' | "$RUN")
  assert_contains "$output" '"message":"Nudge saved."'
  state=$(cat "$HOME/.local/share/jugnu/state/nudges/nudges.yaml")
  assert_contains "$state" $'  - id: "water"\n    emoji: "💧"\n    title: "Hydrate"'
  assert_contains "$state" $'  - id: "stretch"\n    emoji: "🧘"\n    title: "Stretch"'
  assert_contains "$(cat "$CLOCK_LOG")" '"interval_seconds":3000'
  teardown_case
  PASSED=$((PASSED + 1))
}

test_manage_toggle_and_confirmed_delete_sync_clock() {
  setup_case
  full_state | write_state
  write_current_timers
  output=$(printf '{"api":1,"op":"run","command":"manage","args":{"itemId":"toggle:water","action":"select"}}\n' | "$RUN")
  assert_contains "$output" '"message":"Nudge disabled."'
  assert_contains "$(cat "$CLOCK_LOG")" '"op":"cancel","id":"nudges:water"'
  assert_contains "$(cat "$HOME/.local/share/jugnu/state/nudges/nudges.yaml")" '    enabled: false'

  : > "$CLOCK_LOG"
  confirm=$(printf '{"api":1,"op":"run","command":"manage","args":{"itemId":"delete:water","action":"select"}}\n' | "$RUN")
  assert_contains "$confirm" '"pattern":"confirm"'
  assert_contains "$(cat "$HOME/.local/share/jugnu/state/nudges/nudges.yaml")" 'id: "water"'
  ! rg -q '"op":"cancel"' "$CLOCK_LOG" || fail "delete cancelled clock before confirmation"
  output=$(printf '{"api":1,"op":"run","command":"manage","args":{"confirmed":true}}\n' | "$RUN")
  assert_contains "$output" '"message":"Nudge deleted."'
  assert_contains "$(cat "$CLOCK_LOG")" '"op":"cancel","id":"nudges:water"'
  ! rg -q 'id: "water"' "$HOME/.local/share/jugnu/state/nudges/nudges.yaml" || fail "deleted row remained in state"
  teardown_case
  PASSED=$((PASSED + 1))
}

test_manage_rejects_invalid_form_values() {
  setup_case
  full_state | write_state
  write_current_timers
  output=$(printf '{"api":1,"op":"run","command":"manage","args":{"id":"bad","emoji":"⚠️","title":"Bad","message":"","interval_minutes":"0","accent":"","enabled":true}}\n' | "$RUN")
  assert_contains "$output" '"ok":false'
  assert_contains "$output" '"error":"Message is required."'
  ! rg -q 'id: "bad"' "$HOME/.local/share/jugnu/state/nudges/nudges.yaml" || fail "invalid row was saved"
  teardown_case
  PASSED=$((PASSED + 1))
}

test_advanced_saves_and_resets_template() {
  setup_case
  full_state | write_state
  write_current_timers
  form=$(printf '{"api":1,"op":"run","command":"advanced","args":{}}\n' | "$RUN")
  assert_contains "$form" '"id":"emoji","label":"Emoji","kind":"text","value":"✨"'
  assert_contains "$form" '"id":"reset","label":"Reset to factory template","kind":"toggle","value":false'
  output=$(printf '{"api":1,"op":"run","command":"advanced","args":{"emoji":"🌱","title":"Fresh","message":"Begin again.","interval_minutes":"12","accent":"#66CCFF","reset":false}}\n' | "$RUN")
  assert_contains "$output" '"message":"Template saved."'
  assert_contains "$(cat "$HOME/.local/share/jugnu/state/nudges/nudges.yaml")" '  title: "Fresh"'

  confirm=$(printf '{"api":1,"op":"run","command":"advanced","args":{"emoji":"🌱","title":"Fresh","message":"Begin again.","interval_minutes":"12","accent":"#66CCFF","reset":true}}\n' | "$RUN")
  assert_contains "$confirm" '"pattern":"confirm"'
  output=$(printf '{"api":1,"op":"run","command":"advanced","args":{"confirmed":true}}\n' | "$RUN")
  assert_contains "$output" '"message":"Template reset."'
  assert_contains "$(cat "$HOME/.local/share/jugnu/state/nudges/nudges.yaml")" '  title: "New nudge"'
  teardown_case
  PASSED=$((PASSED + 1))
}

test_nudge_now_selection_returns_card() {
  setup_case
  full_state | write_state
  write_current_timers
  list=$(printf '{"api":1,"op":"run","command":"nudge-now","args":{}}\n' | "$RUN")
  assert_contains "$list" '"id":"water","title":"💧 Water"'
  output=$(printf '{"api":1,"op":"run","command":"nudge-now","args":{"itemId":"water","action":"select"}}\n' | "$RUN")
  assert_contains "$output" '"pattern":"card"'
  assert_contains "$output" '"message":"Your cells called. They’re thirsty."'
  teardown_case
  PASSED=$((PASSED + 1))
}

test_nudge_now_hides_disabled_rows() {
  setup_case
  full_state | write_state
  perl -pi -e '$seen ||= /id: "water"/; if ($seen && /enabled: true/) { s/enabled: true/enabled: false/; $seen = 0 }' "$HOME/.local/share/jugnu/state/nudges/nudges.yaml"
  write_current_timers
  list=$(printf '{"api":1,"op":"run","command":"nudge-now","args":{}}\n' | "$RUN")
  [[ "$list" != *'"id":"water"'* ]] || fail "nudge-now listed a disabled row"
  assert_contains "$list" '"id":"eye-rest"'
  teardown_case
  PASSED=$((PASSED + 1))
}

test_first_run_writes_yaml_and_schedules_presets
test_show_card_accepts_generic_timer_id
test_show_card_still_accepts_row_id
test_load_reconciles_only_missing_timer
test_reconcile_preserves_pause_and_next_fire
test_restore_only_upserts_missing_preset
test_restore_preserves_existing_orphan_timer
test_pause_and_resume_use_nudges_group
test_manage_lists_selectable_rows_and_add
test_manage_add_form_uses_template_and_saves_row
test_manage_edit_keeps_identity_and_syncs_clock
test_manage_toggle_and_confirmed_delete_sync_clock
test_manage_rejects_invalid_form_values
test_advanced_saves_and_resets_template
test_nudge_now_selection_returns_card
test_nudge_now_hides_disabled_rows
printf '%s nudges tests passed\n' "$PASSED"
