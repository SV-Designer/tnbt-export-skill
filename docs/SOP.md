# TNBT 存圖 SOP（Figma → 本地資料夾）

> 用途：每一場「開發場次」（開發三、開發四、開發五…）從 Figma 把素材匯出到本地、整理成交付資料夾的標準流程。
> 來源檔：Figma `2026-TNBT`（fileKey **見 `config.json`**），每場一個 session（page）。
> 範例依據：05-開發四（session node-id = `241-732`）。
>
> ⚠️ **本文所有 node-id 都是「05-開發四」的範例**。每個新場次 node-id 都不同——實跑前**務必先 `get_metadata` 重抓**該場次結構，不可直接照抄表內 node-id。

---

## 0-0. 開始前：確認輸出根路徑（⛔ 必停下來問）

**每次開跑前，一定要停下來向使用者確認「存到哪裡」**——先講出預設值 `~/Downloads`（即 `/Users/<你>/Downloads`，建議用場次名子夾如 `~/Downloads/05-開發四/`），**等使用者回覆確認或改路徑後才往下**，不可自己假設就開跑。確定後在該根路徑下建立第 1 節的資料夾骨架。

> 收尾對應：**全部完成後，要明確告知使用者「成品存放路徑」**（見 §5 第 8 項）。

---

## 0. 名詞說明（一句話）

- **session / page**：Figma 一個分頁，裡面放一整場的所有素材。
- **section**：分頁裡的分區（例：`1-Legacy`、`2-SV`），對應一類交付物。
- **frame / artboard**：實際要輸出的單張圖（命名多為尺寸，如 `1250x160`）。
- **node-id**：Figma 每個物件的編號（如 `346:12860`），匯出要用它指定。
- **1x / 2x / 4x**：輸出解析度倍率；2x = 兩倍像素（高解析）。
- **K100**：印刷的純黑（CMYK 只有黑版 100%）。

---

## 1. Session → 本地資料夾 對應總表

Figma session 內有 5 個 section；本地最終整理成 3 個交付夾（`1-主視覺`、`2-Banner`、`3-票口海報`）。

| 本地交付夾 | 來源 Figma section | 內容 |
|---|---|---|
| `1-主視覺/` | 取自 `3-心交+電子報` 的 **心交-1240x1754**（node `346:13209`） | hero 主視覺，1x JPG（從 2-Banner 複製一份過來） |
| `2-Banner/1-Legacy/` | section **1-Legacy**（node `346:13001`） | 11 張，1x JPG ＋ `2x/` 子夾 2x JPG |
| `2-Banner/2-SV/` | section **2-SV**（node `346:12362`） | 17 張，1x JPG ＋ `2x/` 子夾；其中 320x100／320x50 系列做成循環 GIF |
| `2-Banner/3-心交+電子報/` | section **3-心交+電子報**（node `346:13208`） | 2 張，1x JPG |
| `2-Banner/4-福利社/` | section **4-福利社**（node `346:12597`） | 3 張，1x JPG（CB 那張特例 PNG） |
| `3-票口海報/` | section **票口海報**（node `346:12717`） | 社群版 1x JPG ＋ `印刷/` 封裝夾 |

---

## 2. 各 section 輸出規則

### 預設規則
- **每個 frame → 1x JPG**（檔名沿用 Figma frame 名）。
- **`1-Legacy`、`2-SV` 這兩個 section → 額外再存 2x JPG**，放在該夾的 **`2x/` 子資料夾**。
- 其他 section（3、4、票口海報）只存 1x。

### 特例（覆蓋預設）
| Frame | node-id | 特例輸出 |
|---|---|---|
| `福利社-CB_1340x400` | `346:12647` | **1x PNG**（含透明，不是 JPG） |
| `印刷-票口海報_67x108mm@4x` | `346:12860` | **4x PNG**（高解析印刷用） |

### 命名注意（已知坑）
- **同名 frame 要加後綴**避免覆蓋：
  - 1-Legacy 有兩張 `1080x1350` → 存成 `1080x1350(1)`（上，node `385:8918`）、`1080x1350(2)`（下，node `385:9048`）。
  - 2-SV 有兩張 `336x280` → `336x280`（node `382:19250`）、`336x280_2`（node `382:19374`，**實際尺寸 300×250**，名稱沿用旁圖）。
- 檔名含 `()`、中文皆可，mac 檔案系統 OK。

---

## 3. 標準匯出流程（每張 frame）

工具：Figma MCP `download_assets` → 回傳臨時 URL → `curl` 下載到本地。

**步驟一**：呼叫 `mcp__plugin_figma_figma__download_assets`
- `fileKey`: `<見 config.json 的 fileKey>`
- `nodeId`: 該 frame 的 node-id
- `defaultFormat`: `jpg`（或特例 `png`）
- `defaultScale`: `1` / `2` / `4`
- 回傳 JSON 的 `export.url` 即下載連結（**臨時連結，要馬上下載**）。

**步驟二**：立即下載並驗證
```bash
curl -sL "<export.url>" -o "<目標路徑>"
file "<目標路徑>"   # 確認是 JPEG / PNG、尺寸正確
```

**效率做法**：一次並行呼叫多個 `download_assets`（5–6 個），收到全部 URL 後用一個 `curl` 批次下載。量大時（如整個 session 50+ 檔）可分 section 派給子代理（subagent）並行處理。

**取得 session 結構**：先用 `mcp__plugin_figma_figma__get_metadata`（帶 `fileKey`＋ session `nodeId`），解析各 section 下的直接子 frame 與 node-id。

---

## 4. 衍生交付物

### 4-1. 循環 GIF（2-SV 的 320x100 / 320x50 系列）
- 規格：**每張影格 1.25 秒、無限循環**，順序 1→2→3→4。
- 工具：Python PIL。
```python
from PIL import Image
frames=[Image.open(f'320x100-{i}.jpg').convert('RGB') for i in [1,2,3,4]]
frames[0].save('Banner_320x100_loop.gif', save_all=True,
               append_images=frames[1:], duration=1250, loop=0, optimize=True)
```
- 命名：`Banner_<尺寸>_loop.gif`；2x 版加 `@2x`（如 `Banner_640x200_loop@2x.gif`）。
- **收尾**：GIF 做好後放回「來源影格所在資料夾」，原始靜態影格（4 張）送**廢紙簍**（用 Finder 刪除可還原，勿硬刪）。
- **腳本**：`scripts/大團廣告GIF封裝.command`（自動偵測編號影格系列、合成 1x/2x GIF、原影格送廢紙簍）。
- ⚠️ **已知坑（送廢紙簍漏清最後一張）**：把要刪的路徑寫進清單再用 `while read` 逐行刪時，**清單最後一行若沒有換行符，`while read` 會吞掉最後一筆**，導致每次剛好漏清「最後系列的最後一張」（實測為 `2x/320x50-4.jpg`）。修法：寫清單時**每行都補 `\n`**，迴圈用 `while IFS= read -r f || [ -n "$f" ]`；另 Finder 批次 `delete { 多個 }` 偶爾也會漏單筆，**改逐一 `delete` 並回報實際刪除數**較可靠。

### 4-2. 印刷封裝（`3-票口海報/印刷/`）　★半自動「手動存 4x → 偵測 → 一鍵封裝」（2026-06-29 起）

**分工總則**：`印刷-票口海報_67x108mm@4x.png` 這張 4x 主圖**自動化不主動匯出**（底色／解析度由設計師決定），由設計師**手動**從 Figma 存進 `Links/`。其餘（複製 .ai、重嵌主圖、產 K100）由腳本一鍵完成。

**標準流程**
1. **先建好空殼**：即使不存 4x，`3-票口海報/印刷/Links/` 子夾**仍要先建立**（給設計師放檔）。
2. 自動存好**社群版** `社群-票口海報_1080x1350.jpg`（1x JPG）到 `3-票口海報/`。
3. **提示一次**（不必等口頭回報）：
   > 「切回 Figma 儲存『印刷-票口海報_67x108mm@4x』至 `3-票口海報/印刷/Links/`。」
4. **直接跑封裝腳本（建議背景執行）**：腳本內建**自動輪詢等待**——Links/ 還沒有 4x 就持續偵測，**一存進去就自動繼續，不需使用者說「存了」**（最多等 `WAIT_SECS` 秒，預設 1800；設 0 關閉等待）。
5. **跑封裝腳本**：`scripts/票口海報印刷封裝.command`（路徑不寫死，見下）。腳本會：
   - (a) 複製範本 `票口templete/Print-票口海報-開發X.ai` → `印刷/`
   - (b) Illustrator 重新嵌入主圖並存檔（**此時印出提示「點一下 Illustrator 並切回這裡，以便繼續！」**並 `activate`）
   - (c) 產 K100 黑底版 `票口海報_67x108mm.png`（自動判斷：透明底→疊黑、灰底→重底，見 4-3）

**腳本用法**（macOS）
- Finder 雙擊 `票口海報印刷封裝.command` → 跳選取視窗（**預設位置 `~/Downloads`**）選「印刷」資料夾。
- 或終端機：`票口海報印刷封裝.command "<印刷資料夾>"`。
- 範本走「腳本同層 `票口templete/`」，整個 `出圖自動化` 夾複製給別人即可用；要換範本設環境變數 `TEMPLATE_AI`。

最終資料夾結構：
```
印刷/
├── Print-票口海報-開發X.ai          ← Illustrator 排版檔（已重嵌入主圖）
├── 票口海報_67x108mm.png            ← K100 黑底版（由 4x 改底而來）
└── Links/
    └── 印刷-票口海報_67x108mm@4x.png  ← 4x 主圖（設計師手動放，自動化不碰）
```
**關鍵坑**：這份 `.ai` 是把圖**嵌入（embed）**、不是連結。所以**換 `Links/` 檔不會生效**，必須在 Illustrator 內置換嵌入圖（腳本已自動處理）。底層 ExtendScript 邏輯：
```javascript
var doc=app.activeDocument;
var oldR=doc.rasterItems[0];
var gb=oldR.geometricBounds; var L=gb[0],T=gb[1],W=gb[2]-gb[0],H=gb[1]-gb[3];
var p=doc.placedItems.add();
p.file=new File("<新圖完整路徑>");
p.width=W; p.height=H; p.position=[L,T];
p.embed();            // 嵌入（變成 rasterItem）
oldR.remove();        // 移除舊嵌入圖
doc.save();
```
**寫獨立 .jsx 給 osascript 的兩個坑**：① `.jsx` **不可加 UTF-8 BOM**（ExtendScript 會解析失敗）；② 驅動腳本的 shell 要設 `LC_ALL/LANG=UTF-8`，否則變數後接中文全形字會被黏成變數名而報 `unbound variable`。

### 4-3. K100 純黑底 —— 正解：在 Figma 調色，直接輸出
> 教訓（2026-06-26）：**不要用 Python 後製改底色**（改寫像素會毛邊；去背疊黑也只是在補 Figma 該做的事）。
> 海報的灰底是 **frame 自己的填色**（如 `#444444`），不是 section 或匯出設定造成的。

**正確做法（零後製、零毛邊）：**
1. 在 Figma 把該 frame 的填色改成目標色：
   - 要純黑 K100 → 填 `#000000`
   - 要透明 → 設「**無填色 / 移除填色**」（注意：改成更深的灰如 `#1E1E1E` 仍是不透明，不是透明）
2. 直接選這個 frame 用 `download_assets` 輸出（＝「選取 frame 直接輸出」），匯出就是你要的底色。
- 驗證：匯出 PNG 後看四角像素（`alpha=0` 才是真透明；`(0,0,0,255)` 才是純黑）。
- **送印 K100 提醒**：RGB `#000000` 經 RIP 可能轉成四色黑；要保證單色 K100，請在 Illustrator 置入圖下方鋪 K100 矩形或轉 CMYK 指定 K100。

---

## 5. 重複執行檢查清單（新場次）

0. [ ] **⛔ 停下來向使用者確認輸出根路徑**（講出預設 `~/Downloads`／建議場次名子夾，等對方回覆才往下，不可自己假設）。
1. [ ] 拿到新場次 Figma session node-id；`get_metadata` 取結構，列出各 section 的 frame＋node-id。
2. [ ] 建立資料夾：`1-主視覺/`、`2-Banner/{1-Legacy,2-SV,3-心交+電子報,4-福利社}`（Legacy/SV 加 `2x/`）、`3-票口海報/印刷/Links/`（**`Links/` 即使不存 4x 也要先建好**）。
3. [ ] 依規則批次匯出：預設 1x JPG；Legacy/SV 加 2x；套用特例（CB→PNG）。**票口印刷 4x 不主動匯出**（見第 7 項）。
4. [ ] 同名 frame 加後綴；驗證每檔 `file` 格式與尺寸正確。
5. [ ] 主視覺：把 `心交-1240x1754` 複製一份到 `1-主視覺/`。
6. [ ] 2-SV 的 320x100／320x50 做循環 GIF，原影格送廢紙簍。
7. [ ] 票口海報：社群版 1x JPG **自動**輸出 → 提示一次請設計師手動存 `印刷-票口海報_67x108mm@4x.png` 至 `印刷/Links/` → 跑 `票口海報印刷封裝.command`（**自動輪詢偵測，存進去就接著跑，不需口頭回報**；複製 .ai＋重嵌主圖＋產 K100；Illustrator 啟動時提示「點一下 Illustrator 並切回」）。
8. [ ] 全部對照本表清點數量，並**明確告知使用者成品存放路徑**（輸出根路徑）。

---

## 6. 常用參數速查

- **fileKey**：`<見 config.json 的 fileKey>`
- **印刷尺寸**：67×108mm；@4x = 7597×12246、1x ≈ 1900×3062
- **GIF**：`duration=1250`、`loop=0`
- **大圖 PIL**：先 `Image.MAX_IMAGE_PIXELS=None`（避免 DecompressionBomb 警告中斷）
- **Illustrator 腳本**：換行用 `String.fromCharCode(10)`

---

_最後更新：2026-06-26（依 05-開發四 實作整理）_
