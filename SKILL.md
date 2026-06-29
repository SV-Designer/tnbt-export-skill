---
name: tnbt-export
description: >-
  TNBT 大團（開發場次）從 Figma 批次存圖到本地交付夾的標準流程。觸發詞：「TNBT出圖」「大團出圖」「TNBT輸出」。
  把一個 Figma session（page）內所有 section 的 frame 依規則匯出成 1x/2x JPG、特例 PNG，
  做循環 GIF，並半自動封裝票口海報印刷檔。需要 Figma MCP、Adobe Illustrator（macOS）、Python Pillow。
---

# TNBT 大團出圖 skill

把 Figma `2026-TNBT` 一個開發場次（session/page）的素材，批次匯出整理成本地交付夾。

## 先決條件（沒有就先補）
- **Figma MCP**：需 `download_assets`、`get_metadata`（本機 Figma 桌面版＋MCP 外掛）。
- **Adobe Illustrator**（macOS）：票口印刷封裝用 `osascript` 驅動。
- **Python 3 + Pillow**：GIF 與 K100 影像處理（`pip3 install pillow`）。
- **config.json**：複製 `config.example.json` → `config.json`，填入 `fileKey`（Figma 檔）與 `outputBase`（預設 `~/Downloads`）。`config.json` 已 gitignore，不進 repo。

## 啟動流程（Claude 照這個跑）

**Step 0 — 讀設定、確認路徑（⛔ 必停下來問）**
1. 讀 `config.json` 取 `fileKey`、`outputBase`。沒有就請使用者先複製 `config.example.json` 來填。
2. **⛔ 一定要停下來向使用者確認輸出根路徑**：先講出預設值（`outputBase`，通常 `~/Downloads`，建議用場次名子夾如 `~/Downloads/05-開發四/`），**等使用者回覆確認或改路徑後才往下**，不可自己假設就開跑。
3. 跟使用者拿「本場次 session node-id」。

**Step 1 — 抓結構**
- `get_metadata(fileKey, <session node-id>)`，解析 5 個 section 的直接子 frame 與 node-id。
- ⚠️ **node-id 每場都不同**，一定重抓，不可照抄 `docs/SOP.md` 範例值。

**Step 2 — 建資料夾骨架**（在輸出根路徑下）
```
1-主視覺/
2-Banner/{1-Legacy,2-SV,3-心交+電子報,4-福利社}   # Legacy、SV 各加 2x/
3-票口海報/印刷/Links/                              # Links 即使不存 4x 也要先建
```

**Step 3 — 批次匯出**（規則見 `docs/SOP.md` §2）
- 預設每 frame → 1x JPG；**Legacy、SV 另存 2x** 到 `2x/`。
- 特例：福利社-CB → 1x PNG（含透明）。
- **票口印刷 4x 不主動匯出**（見 Step 6）。
- 量大時分 section 派並行子代理（subagent）各自 `download_assets`＋`curl`。

**Step 4 — 主視覺**：把 `心交-1240x1754` 複製一份到 `1-主視覺/`。

**Step 5 — 循環 GIF**：2-SV 的編號影格系列（320x100-1~4、320x50-1~4…）
- 跑 `scripts/大團廣告GIF封裝.command "<2-SV 資料夾>"`：自動偵測系列、合成循環 GIF（1.25s、loop=0、含 2x）、原影格送廢紙簍。

**Step 6 — 票口海報印刷（半自動，自動偵測）**
1. 自動存好社群版 `社群-票口海報_1080x1350.jpg`。
2. **提示一次**：請設計師把『印刷-票口海報_67x108mm@4x』存進 `3-票口海報/印刷/Links/`（底色/解析度自行決定）。
3. **直接跑** `scripts/票口海報印刷封裝.command "<印刷資料夾>"`（**建議背景執行**）：腳本會**自動輪詢等待**，偵測到 Links/ 的 4x 主圖就自動往下——**不需使用者口頭回報「存了」**（最多等 `WAIT_SECS` 秒，預設 1800）。
4. 接續：複製範本 .ai → Illustrator 重嵌主圖（啟動時提示「點一下 Illustrator 並切回」）→ 產 K100 黑底版。

**Step 7 — 清點＋回報路徑**：對照 `docs/SOP.md` §1 數量表清查；**完成後一定要明確告訴使用者「成品存放路徑」**（輸出根路徑），方便他直接去開資料夾。

## 重要細節（坑）
- K100 底色**正解是在 Figma 調色直接輸出**（純黑填 `#000000`、透明設「無填色」），不要 Python 後製改底色。票口腳本的 K100 會自動判斷：透明→疊黑、灰底→重底。
- 票口 .ai 是**嵌入（embed）**不是連結，換 `Links/` 檔無效，必須在 Illustrator 內置換（腳本已處理）。
- 寫獨立 `.jsx` 給 osascript：**不可加 BOM**；驅動 shell 要 `LC_ALL/LANG=UTF-8`。
- 同名 frame 要加後綴避免覆蓋（如兩張 1080x1350 → `(1)`/`(2)`）。

完整規則、特例表、命名坑、參數速查 → 見 **`docs/SOP.md`**。
