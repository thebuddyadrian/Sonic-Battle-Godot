#!/bin/sh
# Plays a game's scripted local match headless (HeadlessCheck.tscn, next to
# this), without rollbacks and with forced rollbacks every tick, late packets,
# interpolation, logging, node reuse, rollback deferral, interpolation pauses
# and the forward load check (a replay's seek, before every tick), and fails
# unless all end in the same state, with the same trace (see HeadlessCheck.gd),
# with the same state on every tick both saved as the first run, and no errors. Run it from anywhere in the project; GODOT
# defaults to the macOS app's binary. Arguments after the ticks are passed on
# to every run, the scene and the input script among them:
#
#   sh addons/delta_rollback/headless_check/run_checks.sh [ticks] [HeadlessCheck options...]
#   sh addons/delta_rollback/headless_check/run_checks.sh 600 --scene=res://Main.tscn --inputs=res://tests/MyInputs.gd
#
# A game without logging_enabled on its scene: set NO_LOGGING=1 to skip the
# logging run.
dir="$(cd "$(dirname "$0")" && pwd)"
project="$dir"
while [ ! -f "$project/project.godot" ]; do
	[ "$project" = "/" ] && { echo "run_checks.sh: no project.godot above $dir"; exit 1; }
	project="$(dirname "$project")"
done
cd "$project" || exit 1
check="res://${dir#"$project"/}/HeadlessCheck.tscn"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
TICKS="${1:-600}"
[ $# -gt 0 ] && shift
status=0
reference=""
reference_states="$(mktemp)"
while read -r run; do
	[ -z "$run" ] && continue
	case "$run" in *--logging=1*) [ -n "$NO_LOGGING" ] && continue ;; esac
	output="$("$GODOT" --headless --fixed-fps 60 --path . "$check" -- $run --ticks=$TICKS "$@" 2>&1)"
	code=$?
	result="$(echo "$output" | grep '^RESULT' | sed 's/^RESULT //')"
	stats="$(echo "$output" | grep '^STATS' | sed 's/^STATS //')"
	errors="$(echo "$output" | grep -c 'ERROR')"
	echo "$run: $result ($errors errors; $stats)"
	if [ $code != 0 ]; then
		echo "  Godot exited with code $code"
		status=1
	fi
	if [ "$errors" != "0" ]; then
		echo "$output" | grep -A2 'ERROR' | head -20
		status=1
	fi
	if [ -z "$result" ]; then
		status=1
	elif [ -z "$reference" ]; then
		reference="$result"
		echo "$output" | grep '^STATE ' > "$reference_states"
	else
		if [ "$result" != "$reference" ]; then
			echo "  differs from the first run"
			status=1
		fi
		differing="$(echo "$output" | grep '^STATE ' | awk 'NR == FNR { h[$2] = $3; next } ($2 in h) && h[$2] != $3 { n++; if (!first) first = $2 } END { if (n) print n " ticks, from tick " first }' "$reference_states" -)"
		if [ -n "$differing" ]; then
			echo "  states differ from the first run's: $differing"
			status=1
		fi
	fi
done <<RUNS
--rollback=0
--rollback=1
--rollback=4
--rollback=7
--rollback=0 --interpolation=1
--rollback=4 --interpolation=1
--rollback=4 --logging=1
--late-packet=8:10:1
--late-packet=8:10:1 --interpolation=1
--rollback=4 --interpolation=1 --reuse=1
--rollback=4 --defer=2
--late-packet=2:1:2 --defer=2:cost:1 --interpolation=1
--rollback=4 --toggle-interpolation=7
--rollback=4 --interpolation=1 --reuse=1 --forward=1
--late-packet=8:10:1 --forward=1
RUNS
rm -f "$reference_states"
[ $status = 0 ] && echo "OK" || echo "FAILED"
exit $status
