#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script="$root/config/airootfs/usr/local/lib/kova/check-battery"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export KOVA_POWER_SUPPLY_ROOT="$tmp/supply"
export KOVA_BATTERY_STATE_ROOT="$tmp/state"
export KOVA_NOTIFY_SEND="$tmp/notify-send"
export KOVA_TEST_NOTIFICATIONS="$tmp/notifications"
mkdir -p "$KOVA_POWER_SUPPLY_ROOT"
cat > "$KOVA_NOTIFY_SEND" <<'MOCK'
#!/usr/bin/env bash
if [[ "${KOVA_TEST_NOTIFY_FAIL:-0}" == 1 ]]; then exit 1; fi
printf '%s\n' "$*" >> "$KOVA_TEST_NOTIFICATIONS"
MOCK
chmod 0755 "$KOVA_NOTIFY_SEND"
bash -n "$script"
run() { bash "$script"; }
count() { if [[ -f "$KOVA_TEST_NOTIFICATIONS" ]]; then wc -l < "$KOVA_TEST_NOTIFICATIONS"; else echo 0; fi; }
expect() { [[ "$(count)" -eq "$1" ]] || { echo "Expected $1 notifications, got $(count)" >&2; exit 1; }; }
battery() {
  local dir="$KOVA_POWER_SUPPLY_ROOT/$1"
  mkdir -p "$dir"
  printf 'Battery\n' > "$dir/type"
  printf '%s\n' "$2" > "$dir/capacity"
  printf '%s\n' "$3" > "$dir/status"
}
run; expect 0
# A headless root/systemd service may not define HOME or XDG_STATE_HOME.
# That must not break a machine with no battery.
env -u HOME -u XDG_STATE_HOME -u KOVA_BATTERY_STATE_ROOT \
  KOVA_POWER_SUPPLY_ROOT="$tmp/no-such-supply" bash "$script"
expect 0
battery BAT0 40 Discharging
run; expect 0
battery BAT0 20 Discharging
run; expect 1
grep -Fq 'Battery low' "$KOVA_TEST_NOTIFICATIONS"
[[ "$(cat "$KOVA_BATTERY_STATE_ROOT/battery-warning")" == 20 ]]
battery BAT0 19 Discharging
run; expect 1
battery BAT0 10 Discharging
run; expect 2
grep -Fq 'Battery very low' "$KOVA_TEST_NOTIFICATIONS"
battery BAT0 5 Discharging
run; expect 3
grep -Fq -- '--urgency=critical' "$KOVA_TEST_NOTIFICATIONS"
run; expect 3
battery BAT0 100 Charging
run; expect 3
[[ ! -e "$KOVA_BATTERY_STATE_ROOT/battery-warning" ]]
battery BAT0 18 Discharging
run; expect 4
battery BAT0 100 Full
run
battery BAT0 20 Discharging
KOVA_TEST_NOTIFY_FAIL=1 run
expect 4
[[ ! -e "$KOVA_BATTERY_STATE_ROOT/battery-warning" ]]
run; expect 5
battery BAT0 90 Charging
run
battery BAT1 7 Discharging
run; expect 6
grep -Fq 'Only 7% remaining' "$KOVA_TEST_NOTIFICATIONS"
battery BAT1 70 Charging
run
battery BAT1 0 Discharging
run; expect 7
grep -Fq 'Only 0% remaining!' "$KOVA_TEST_NOTIFICATIONS"
battery BAT1 invalid Discharging
run; expect 7
printf 'NotBattery\n' > "$KOVA_POWER_SUPPLY_ROOT/BAT1/type"
run; expect 7
echo 'Kova low-battery notification tests passed'
