#!/usr/bin/env bash
# =============================================================
#  大團廣告 — 循環 GIF 封裝自動化（2-SV 的 320x100 / 320x50 等系列）
# =============================================================
#  用途：把同尺寸的「編號影格」（如 320x100-1.jpg ~ 320x100-4.jpg）
#         合成無限循環 GIF（每張 1.25 秒），原始靜態影格送廢紙簍。
#         自動處理該資料夾本身與其 2x/ 子夾。
#
#  用法：
#    1) Finder 雙擊本檔 → 跳視窗選「2-SV」資料夾（預設 ~/Downloads）
#    2) 終端機：./大團廣告GIF封裝.command "<2-SV 資料夾>"
#
#  可調整（環境變數）：
#    FRAME_MS   每張影格毫秒數（預設 1250 = 1.25 秒）
#    NO_TRASH   設為 1 則「不」把原影格送廢紙簍（預設會送，可還原）
#
#  自動化評估：
#    [自動] 偵測編號影格系列（prefix-1 / prefix-2 …）
#    [自動] 合成循環 GIF（base 夾＋2x 夾）
#    [自動] 原影格送 Finder 廢紙簍（可還原）
# =============================================================
set -euo pipefail
export LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}"
FRAME_MS="${FRAME_MS:-1250}"

echo "===== 大團廣告 GIF 封裝 ====="

# 1) 取得 2-SV 資料夾
SV_DIR="${1:-}"
if [ -z "$SV_DIR" ]; then
  SV_DIR="$(osascript -e 'POSIX path of (choose folder with prompt "請選擇「2-SV」資料夾（內含編號影格）" default location (path to downloads folder))' 2>/dev/null || true)"
fi
[ -z "$SV_DIR" ] && { echo "✗ 未選擇資料夾，結束。"; exit 1; }
SV_DIR="${SV_DIR%/}"
[ -d "$SV_DIR" ] || { echo "✗ 資料夾不存在：$SV_DIR"; exit 1; }

# 2) Python 偵測系列並合成 GIF；回傳要送廢紙簍的原影格清單到暫存檔
TRASH_LIST="$(mktemp /tmp/gif_trash_XXXXXX.txt)"
python3 - "$SV_DIR" "$FRAME_MS" "$TRASH_LIST" <<'PY'
import sys, os, re, glob
from PIL import Image
sv_dir, frame_ms, trash_list = sys.argv[1], int(sys.argv[2]), sys.argv[3]

def is2x(folder):
    return os.path.basename(folder.rstrip("/")) == "2x"

def double_dims(prefix):
    m = re.fullmatch(r"(\d+)x(\d+)", prefix)
    if m:
        return f"{int(m.group(1))*2}x{int(m.group(2))*2}"
    return None

def process(folder):
    if not os.path.isdir(folder):
        return []
    # 找出「prefix-<整數>.jpg」系列
    series = {}
    for p in glob.glob(os.path.join(folder, "*-*.jpg")):
        name = os.path.basename(p)
        m = re.fullmatch(r"(.+)-(\d+)\.jpg", name)
        if not m:
            continue
        series.setdefault(m.group(1), []).append((int(m.group(2)), p))
    trashed = []
    for prefix, items in sorted(series.items()):
        if len(items) < 2:
            continue
        items.sort()
        frames = [Image.open(p).convert("RGB") for _, p in items]
        if is2x(folder):
            dd = double_dims(prefix)
            out_name = f"Banner_{dd}_loop@2x.gif" if dd else f"Banner_{prefix}_loop@2x.gif"
        else:
            out_name = f"Banner_{prefix}_loop.gif"
        out = os.path.join(folder, out_name)
        frames[0].save(out, save_all=True, append_images=frames[1:],
                       duration=frame_ms, loop=0, optimize=True)
        print(f"  ✓ {out_name}  ({len(frames)} 影格)")
        trashed += [p for _, p in items]
    return trashed

all_trash = []
all_trash += process(sv_dir)
all_trash += process(os.path.join(sv_dir, "2x"))
with open(trash_list, "w") as f:
    f.write("".join(p + "\n" for p in all_trash))  # 每行含結尾換行，避免 while-read 吞掉最後一筆
print(f"  待清原影格：{len(all_trash)} 張")
PY

# 3) 原影格送廢紙簍（可還原），除非 NO_TRASH=1
if [ "${NO_TRASH:-0}" = "1" ]; then
  echo "（NO_TRASH=1，保留原影格不清）"
else
  # 逐一刪除（Finder 批次 delete 偶爾會漏清單裡的一個，逐一才可靠）
  TRASHED=0
  while IFS= read -r f || [ -n "$f" ]; do
    [ -n "$f" ] && [ -f "$f" ] || continue
    if osascript -e "tell application \"Finder\" to delete (POSIX file \"$f\")" >/dev/null 2>&1; then
      TRASHED=$((TRASHED+1))
    else
      echo "⚠ 無法送廢紙簍：$f"
    fi
  done < "$TRASH_LIST"
  echo "✓ 原始靜態影格已送廢紙簍 $TRASHED 張（可還原）"
fi
rm -f "$TRASH_LIST"

echo ""
echo "===== 完成 ====="
echo "資料夾：$SV_DIR"