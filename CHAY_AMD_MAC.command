#!/bin/zsh
set -eu
ROOT="$(cd "$(dirname "$0")" && pwd)"
RUNTIME="$ROOT/.amd-mac-runtime"
GODOT="${GODOT_EXE:-$HOME/Downloads/Godot_mono.app/Contents/MacOS/Godot}"
DOTNET="$(command -v dotnet || true)"
[[ -n "$DOTNET" ]] || DOTNET=/usr/local/share/dotnet/dotnet
DATA="$HOME/Library/Application Support/Dungeon Resonance AMD201 Mac"
mkdir -p "$DATA/launcher-logs"
LOG="$DATA/launcher-logs/$(date +%Y%m%d-%H%M%S)"
export AMD201_DATA_ROOT="$DATA" AMD201_API_URL=http://127.0.0.1:5086
export DUNGEON_AMD_QA_ROOT="$DATA" DOTNET_ROLL_FORWARD=Major
API_PID=""
cleanup() { if [[ -n "$API_PID" ]]; then kill "$API_PID" 2>/dev/null || true; fi; }
trap cleanup EXIT INT TERM
fail() { print "$1"; print "Logs: $LOG"; read '?Nhấn Enter để đóng...'; exit 1; }
[[ -x "$GODOT" ]] || fail 'Không tìm thấy Godot 4.7.2. Đặt GODOT_EXE tới executable Godot.'
VERSION="$("$GODOT" --headless --version)"
[[ "$VERSION" == 4.7.2.stable.* ]] || fail 'Cần Godot 4.7.2 stable.'
# A Mac-only runtime project keeps normal project settings and saves unchanged.
# Every resource directory points to the source checkout; only project/cache is local.
mkdir -p "$RUNTIME"
for item in addons assets data scenes scripts shaders tests tools docs icon.svg; do
  [[ -e "$ROOT/$item" ]] || continue
  if [[ -L "$RUNTIME/$item" ]]; then
    [[ "$(readlink "$RUNTIME/$item")" == "../$item" ]] || fail "Runtime link khác dự kiến: $item"
  elif [[ -e "$RUNTIME/$item" ]]; then
    fail "Runtime có file riêng cần giữ: $item"
  else
    ln -s "../$item" "$RUNTIME/$item"
  fi
done
sed 's/^config\/name="Dungeon Resonance"$/config\/name="Dungeon Resonance AMD201 Mac"/' "$ROOT/project.godot" | awk '{print} /^config\/name="Dungeon Resonance AMD201 Mac"$/ {print "config/use_custom_user_dir=true"}' > "$RUNTIME/project.godot"
[[ -f "$ROOT/online/tools/Dungeon.QaHost/bin/Release/net9.0/Dungeon.QaHost.dll" || "${1:-}" == --smoke-test ]] || fail 'Chưa build API. Xem HUONG_DAN_MAC.md.'

print 'Đang kiểm tra asset...'
"$GODOT" --headless --path "$RUNTIME" --editor --import > "$LOG-import.log" 2>&1 || fail 'Import thất bại.'
if grep -Eq '^[[:space:]]*(SCRIPT ERROR:|ERROR:)' "$LOG-import.log"; then fail 'Import có lỗi, xem log.'; fi
if [[ "${1:-}" == --smoke-test ]]; then
  "$GODOT" --headless --path "$RUNTIME" --script res://tests/test_amd_launcher.gd
  exit $?
fi
if lsof -nP -iTCP:5086 -sTCP:LISTEN >/dev/null 2>&1; then fail 'Cổng 5086 đang được dùng. Đóng phiên AMD/API trước; launcher không dùng chung server khác.'; fi
{
  "$DOTNET" "$ROOT/online/tools/Dungeon.QaHost/bin/Release/net9.0/Dungeon.QaHost.dll" --contentRoot "$ROOT/online/src/Dungeon.Api" > "$LOG-api.log" 2>&1 &
  API_PID=$!
  READY=0
  for i in {1..30}; do
    if lsof -nP -a -p "$API_PID" -iTCP:5086 -sTCP:LISTEN >/dev/null 2>&1 && curl --max-time 1 -fsS "$AMD201_API_URL/health/ready" >/dev/null 2>&1; then READY=1; break; fi
    sleep 1
  done
  [[ "$READY" == 1 ]] || fail 'API demo chưa khởi động được.'
  kill -0 "$API_PID" 2>/dev/null || fail 'Tiến trình API demo đã dừng, không dùng server khác.'
}
print 'Demo SQLite cục bộ. Web: http://127.0.0.1:5086/'
print 'Không phải PostgreSQL hoặc đồng bộ với PC. Đóng game sẽ dừng API do launcher này mở.'
"$GODOT" --path "$RUNTIME" res://scenes/amd201_boot.tscn > "$LOG-game.log" 2>&1 || fail 'Game thoát có lỗi, xem log.'
