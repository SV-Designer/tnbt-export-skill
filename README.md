# tnbt-export-skill

TNBT 大團（開發場次）從 **Figma 批次存圖到本地交付夾**的 Claude Code skill ＋ 輔助腳本。

把一個 Figma session（page）內所有 section 的 frame，依規則匯出成 1x/2x JPG、特例 PNG，做循環 GIF，並半自動封裝票口海報印刷檔。

> ⚠️ 這不是「一鍵 CLI」。批次下載要靠 **Claude Code＋Figma MCP** 驅動（`download_assets` 無法純腳本化）。本 repo＝**給 Claude 的操作手冊（SKILL.md / docs）＋兩支可獨立執行的封裝腳本**。

## 需求
- **Claude Code** ＋ **Figma MCP**（`download_assets`、`get_metadata`）
- **Adobe Illustrator**（macOS；票口印刷封裝用 `osascript` 驅動）
- **Python 3 + Pillow**：`pip3 install pillow`

## 安裝（當 Claude skill 用）
1. 把整個資料夾放到 `~/.claude/skills/tnbt-export/`（或你的 skills 目錄）。
2. 複製設定：`cp config.example.json config.json`，填入你的 Figma `fileKey` 與 `outputBase`。
   - `config.json` 已被 `.gitignore`，**不會進 repo**（fileKey 不外洩）。
3. 在 Claude Code 對話打 **「TNBT出圖」／「大團出圖」／「TNBT輸出」** 觸發。

## 兩支獨立腳本（macOS，雙擊即可跑）
| 腳本 | 做什麼 |
|---|---|
| `scripts/票口海報印刷封裝.command` | 偵測 `印刷/Links/` 的 4x 主圖 → 複製範本 .ai＋重嵌主圖＋產 K100 黑底版 |
| `scripts/大團廣告GIF封裝.command` | 偵測 2-SV 編號影格系列 → 合成循環 GIF（1.25s、loop=0、含 2x）→ 原影格送廢紙簍 |

兩支都：路徑不寫死（範本走相對路徑、目標夾用參數或選取視窗，預設開 `~/Downloads`）；可用環境變數覆蓋（`TEMPLATE_AI`、`FRAME_MS`、`NO_TRASH`）。

## 建議的 Claude Code 權限白名單（自行加，免每步問）
在你自己的 `~/.claude/settings.json` 的 `permissions.allow` 加入：
```
"Bash(<本 repo>/scripts/票口海報印刷封裝.command:*)",
"Bash(<本 repo>/scripts/大團廣告GIF封裝.command:*)",
"Bash(cp:*)", "Bash(find:*)", "Bash(python3:*)", "Bash(osascript:*)"
```

## 結構
```
SKILL.md                     ← 觸發詞＋給 Claude 的操作流程
docs/SOP.md                  ← 完整 SOP（規則、特例、命名坑、參數速查）
scripts/票口海報印刷封裝.command
scripts/大團廣告GIF封裝.command
templete/Print-票口海報-範本.ai
config.example.json          ← 複製成 config.json 填 fileKey
```

## 注意
- 本 repo 為 StreetVoice 設計團隊內部流程；範本 .ai 與流程屬內部素材。
- macOS 限定（用到 `osascript`／Finder 廢紙簍／choose folder）。
