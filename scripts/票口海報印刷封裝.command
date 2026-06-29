#!/usr/bin/env bash
# =============================================================
#  票口海報 — 印刷封裝自動化
# =============================================================
#  用途：把設計師手動放進 Links/ 的主圖，一鍵封裝成印刷交付物
#         （複製 .ai 範本 → 重新嵌入主圖 → 產 K100 黑底版）。
#
#  用法：
#    1) Finder 直接雙擊本檔 → 跳視窗選「印刷」資料夾
#    2) 終端機：./票口海報印刷封裝.command "<印刷資料夾路徑>"
#
#  自動化評估（哪些自動、哪些手動）：
#    [手動] Figma 匯出主圖 @4x：設計師自行調好底色/解析度後，
#           存進  <印刷>/Links/ （命名含 @4x）。本腳本不碰、不覆蓋。
#    [自動] 偵測 Links/ 主圖
#    [自動] 複製範本 .ai 進印刷夾
#    [自動] 產 K100 黑底版（自動判斷：透明底→疊黑、灰底→重底）
#    [半自動] Illustrator 重新嵌入主圖（需 Illustrator 可被驅動；僅 macOS）
#
#  可調整（環境變數，不設就用預設）：
#    TEMPLATE_AI   範本 .ai 路徑（預設：本腳本同層 票口templete/ 內）
# =============================================================
set -euo pipefail
# 強制 UTF-8 locale：否則變數後緊接中文全形字會被黏成變數名（unbound variable）
export LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}"

# --- 路徑全部相對解析，不寫死，可整夾搬給別人用 ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_AI="${TEMPLATE_AI:-$SCRIPT_DIR/../templete/Print-票口海報-範本.ai}"

echo "===== 票口海報 印刷封裝 ====="

# 1) 取得印刷資料夾（參數優先；沒給就跳選取視窗）
PRINT_DIR="${1:-}"
if [ -z "$PRINT_DIR" ]; then
  PRINT_DIR="$(osascript -e 'POSIX path of (choose folder with prompt "請選擇「印刷」資料夾（內含 Links/ 主圖）" default location (path to downloads folder))' 2>/dev/null || true)"
fi
[ -z "$PRINT_DIR" ] && { echo "✗ 未選擇資料夾，結束。"; exit 1; }
PRINT_DIR="${PRINT_DIR%/}"
[ -d "$PRINT_DIR" ] || { echo "✗ 資料夾不存在：$PRINT_DIR"; exit 1; }

# 2) 找 Links 主圖（優先檔名含 @4x，否則取第一張 png）
LINKS_DIR="$PRINT_DIR/Links"
[ -d "$LINKS_DIR" ] || mkdir -p "$LINKS_DIR"

# 2a) 自動等待：主圖還沒放就輪詢偵測（設計師手動存進 Links/ 後自動繼續，不需口頭回報）
#     WAIT_SECS=0 可關閉等待；預設等 1800 秒（30 分）
WAIT_SECS="${WAIT_SECS:-1800}"
if ! ls "$LINKS_DIR"/*@4x*.png "$LINKS_DIR"/*.png >/dev/null 2>&1 && [ "$WAIT_SECS" -gt 0 ]; then
  echo "⏳ 尚未偵測到主圖。請把『印刷-票口海報_67x108mm@4x.png』存進："
  echo "   $LINKS_DIR"
  echo "   （偵測到就自動繼續，最多等 ${WAIT_SECS} 秒，無需回報）"
  waited=0
  while ! ls "$LINKS_DIR"/*@4x*.png "$LINKS_DIR"/*.png >/dev/null 2>&1 && [ "$waited" -lt "$WAIT_SECS" ]; do
    sleep 5; waited=$((waited+5))
  done
fi

SRC_PNG="$(ls "$LINKS_DIR"/*@4x*.png 2>/dev/null | head -n1 || true)"
[ -z "$SRC_PNG" ] && SRC_PNG="$(ls "$LINKS_DIR"/*.png 2>/dev/null | head -n1 || true)"
[ -z "$SRC_PNG" ] && { echo "✗ 等待逾時仍未在 Links/ 找到主圖 PNG。請放好後重跑。"; exit 1; }
echo "✓ 偵測到主圖：$SRC_PNG"

# 3) 確認範本
[ -f "$TEMPLATE_AI" ] || { echo "✗ 找不到範本 .ai：$TEMPLATE_AI（可用環境變數 TEMPLATE_AI 指定）"; exit 1; }

# 4) 複製範本 .ai 進印刷夾
AI_NAME="$(basename "$TEMPLATE_AI")"
DEST_AI="$PRINT_DIR/$AI_NAME"
cp "$TEMPLATE_AI" "$DEST_AI"
echo "✓ 已複製範本 → $DEST_AI"

# 5) 產 K100 黑底版（自動判斷透明/灰底；不動原檔，另存副本）
K100_OUT="$PRINT_DIR/票口海報_67x108mm.png"
python3 - "$SRC_PNG" "$K100_OUT" <<'PY'
import sys
from PIL import Image, ImageChops
Image.MAX_IMAGE_PIXELS = None
src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGBA")
W, H = im.size
px = im.load()
corners = [px[0, 0], px[W-1, 0], px[0, H-1], px[W-1, H-1]]
transparent = any(c[3] == 0 for c in corners)
if transparent:
    bg = Image.new("RGBA", im.size, (0, 0, 0, 255))
    bg.alpha_composite(im)
    bg.save(out); method = "透明疊黑（零毛邊）"
else:
    r, g, b, a = im.split()
    def le(ch, t): return ch.point(lambda v: 255 if v <= t else 0).convert("1")
    neutral = ImageChops.logical_and(
        ImageChops.logical_and(le(ImageChops.difference(r, g), 12),
                               le(ImageChops.difference(g, b), 12)),
        le(ImageChops.difference(r, b), 12))
    inrange = r.point(lambda v: 255 if 30 <= v <= 110 else 0).convert("1")
    mask = ImageChops.logical_and(neutral, inrange)
    im.paste((0, 0, 0, 255), None, mask)
    im.save(out); method = "灰底重底"
print(f"  K100 方法：{method}，尺寸 {im.size}")
PY
echo "✓ 已產 K100 → $K100_OUT"

# 6) Illustrator 重新嵌入主圖並存檔（換 Links 檔不會生效，必須 embed）
JSX="$(mktemp /tmp/embed_XXXXXX.jsx)"
cat > "$JSX" <<JSXEOF
var f = new File("$DEST_AI");
var doc = app.open(f);
var oldR = doc.rasterItems[0];
var gb = oldR.geometricBounds;
var L = gb[0], T = gb[1], W = gb[2]-gb[0], H = gb[1]-gb[3];
var p = doc.placedItems.add();
p.file = new File("$SRC_PNG");
p.width = W; p.height = H; p.position = [L, T];
p.embed();
oldR.remove();
doc.save();
JSXEOF

echo "👉 即將開啟 Illustrator 嵌入主圖；若畫面沒反應，請點一下 Illustrator 視窗再切回來，以便繼續！"
if osascript >/dev/null 2>&1 <<APPLESCRIPT
set jsxFile to POSIX file "$JSX"
tell application "Adobe Illustrator"
  activate
  do javascript jsxFile
end tell
APPLESCRIPT
then
  echo "✓ Illustrator 已重新嵌入主圖並存檔：$DEST_AI"
else
  echo "⚠ Illustrator 嵌入失敗（請確認已安裝/開啟 Illustrator），其餘步驟已完成，可手動置換嵌入圖。"
fi
rm -f "$JSX"

echo ""
echo "===== 完成 ====="
echo "印刷夾：$PRINT_DIR"
echo "  ├─ ${AI_NAME}（已嵌入主圖）"
echo "  ├─ 票口海報_67x108mm.png（K100 黑底版）"
echo "  └─ Links/$(basename "$SRC_PNG")（你的原檔，未更動）"
