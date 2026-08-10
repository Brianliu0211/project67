# Workspace Rules - insurance_helper

This file defines guidelines and constraints specific to the `insurance_helper` workspace.

## Automated Document Synchronization

### Tooling Guide Update (`docs/工具包.md`)
- **Rule**: Whenever you (the AI Agent) install, configure, or recommend a new tool, SDK, CLI tool, or Dart package (added to `pubspec.yaml`), you **MUST** automatically update the [工具包.md](docs/工具包.md) file.
- **Content Requirements**:
  - For new SDKs/CLI tools: add under the "開發環境與 SDK" section, including a name, version details, short purpose, and official download links.
  - For new Dart/Flutter packages: add under the "專案相依套件" section, describing its exact role in the project.
- **Timing**: Perform this update immediately after modifying configuration files (like `pubspec.yaml`) or running install commands.

### Developer Log Update (`docs/03_開發日誌/`)
- **Rule**: Whenever the user requests you to write a development log, you **MUST** create a new file in [docs/03_開發日誌/YYYY-MM/](docs/03_開發日誌/) (e.g. `docs/03_開發日誌/2026-08/`) named in the format `YYYYMMDD_Title.md` (e.g., `20260802_進度表大模組重構.md`), using short, concise titles.
- **Specification Compliance**: You **MUST** strictly follow all rules and templates defined in [開發日誌規範.md](docs/03_開發日誌/開發日誌規範.md).
- **Multiple Logs Per Day**: If multiple dev logs are written on the same day, each log should use a distinct functional title (e.g., `20260714_客戶卡片UI刻劃.md` and `20260714_Supabase串接與RLS測試.md`). Do NOT use sequential numbering.

### Shortcut Guide Update (`docs/00_公共規格/開發人員快捷指令.md`)
- **Rule**: Whenever you (the AI Agent) modify or update the trigger conditions or actions of the developer shortcut commands (such as 「開工」, 「收工」, 「讓我看看」, or 「確認狀況」) in this file, you **MUST** automatically synchronize the changes to [開發人員快捷指令.md](docs/00_公共規格/開發人員快捷指令.md).
- **Timing**: Perform this update immediately after updating the respective automation sections in this file.

---

## 「開工」Automation (Start-of-Session Command)

### Trigger
- **Rule**: When the user says **「開工」**, or when you (the AI Agent) and the user agree on a development plan, you **MUST** automatically perform the following actions:

### Actions
1. **前置安全檢查 (Check Previous Closing Status)**：在執行任何開工動作前，**必須**先檢查本地 Git 倉庫狀態（如執行 `git status`）。若偵測到當前工作目錄有未提交的變更，或前次開發分支尚未執行收工與合併流程，**必須**主動發出黃色/橙色警示，提醒專案人員先進行「收工」或合併，待確認安全後始得繼續開工。
2. **確認開發者身分與工作區 (強制常駐點選彈窗)**：**必須【強制呼叫 `ask_question` 互動選單工具】**，彈出互動選項讓專案人員直接點選身分（`我是 蘿蔔 (lobo)` 或 `我是 巨獸 (beast)`），以鎖定對應的分支前綴與沙盒路徑，徹底免去手動打字負擔。
3. **巡檢個人工作區新靈感 (Read-Only Scan)**：唯讀巡檢 `docs/01_蘿蔔_工作區/想法存放區/` 與 `docs/02_巨獸_工作區/想法存放區/`，若發現全新未討論靈感，詢問是否提報摘要至 `docs/進度.md` 萬能收件匣。（注意：AI 嚴禁修改或刪除人類工作區原始筆記）。
4. **對齊進度表任務 (強制常駐點選彈窗)**：讀取 [進度.md](docs/進度.md) 並**透過 `ask_question` 彈窗**展示當前未完成的大模組任務列表，讓開發者能直接點選本次要進行的任務。
5. **大任務微型拆解協定 (Task Decomposition Protocol)**：當開發者選定特定大模組任務時，AI **必須**自動進行 4 階段微型拆解（`(1) Schema/RLS` $\rightarrow$ `(2) Service/邏輯層` $\rightarrow$ `(3) UI組件` $\rightarrow$ `(4) 驗證`），將大任務拆為微型 Tickets 並展示於對話與 sub-task 脈絡中，避免一次變更規模過大。
6. **建議分支名稱**：若為程式碼開發，生成格式為 `feature/username-featurename` 的分支名稱（例如：`feature/lobo-customer-list-ui`）。
7. **提供分支指令/介面操作指引**：引導 GitHub Desktop 建立特徵分支（純文件類修改除外）。

---

## 「收工」Automation (End-of-Session Command)

### Trigger
- **Rule**: When the user says **「收工」**, you **MUST** automatically perform the following actions in order:

### Actions
1. **檢查與自動修復 Git 分支狀態 (Branch Safeguard & Auto-Switch)**：
   - 檢查當前本機 Git 分支與變更檔案：
     - **純文件修訂 (Fast-Track 快速通道)**：若本次變更 100% 僅包含 `docs/` 或 `.md` 文件（未修改 `lib/` 或程式碼），**目標分支一律為 `main` 主線**。若當前本機處於特徵分支，AI **必須直接在背景執行 `git checkout main`** 自動切換回 `main` 主線，並明確輸出 **「已自動幫您切換至目標分支: main」**。
     - **程式碼修訂 (Standard PR 流程)**：若包含程式碼變更，且發現未部位於標準特徵分支（例如位於 `main` 主線，或位於非標準名稱），AI **必須直接在背景執行 `git checkout -b feature/username-featurename`（或 `git branch -m`）** 自動幫開發者建好並切換至標準特徵分支，徹底免去手動手動建立/切換分支的負擔！
2. **Quality Gate 4 項品質稽核檢驗**：在產出 Commit 與日誌前，強制審查以下 4 項品質門檻：
   - **Supabase RLS 安全**：若涉 SQL/Table 改動，確認已配置安全性政策。
   - **UI 規範驗證**：若改動 UI，確認符合 `main_spec.md` 之 Toast / 彈窗與主題標準。
   - **工具包同步**：若新增 Package/SDK，確認已同步更新至 `docs/工具包.md`。
   - **Null-Safety 防護**：確認核心流程具備 Exception 捕獲與防空值處理。
3. **撰寫開發日誌與 Handoff 條文**: Create a new development log in [docs/03_開發日誌/](docs/03_開發日誌/) following the established specification. **MUST** include a dedicated `[Handoff 狀態條言]` section at the end of the log documenting exact session context, current state, key decisions, and recommended next steps for seamless cross-developer/agent handoff.
4. **更新進度表**: Review and update [進度.md](docs/進度.md) — check off (`[x]`) any completed items, and process the Incubator/Backlog promotion if applicable.
5. **產出 Git Commit 訊息與分支指引**: Generate a ready-to-paste **Summary** and **Description** for GitHub Desktop, strictly following the conventions defined in [Git提交訊息規範.md](docs/00_公共規格/Git提交訊息規範.md)，並**明確輸出對應的特徵分支名稱（若為純文件則明確輸出 `main` 分支）**。
6. **智慧提交分流引導 (Fast-Track vs Standard PR)**：
   - **純文件修訂 (Fast-Track 快速通道)**：直接引導在 GitHub Desktop 將分支切換至 `main`，提交並推送至 `main` 主線分支（免發起 PR）。
   - **程式碼修訂 (Standard PR 流程)**：若本次包含程式碼變更，引導透過 GitHub Desktop 將該特徵分支推送至遠端、建立 PR 並進行 Merge。

---

## 「精簡模式」與「詳細模式」Automation (Token-Efficiency Protocol Command)

### Trigger
- **Rule**: When the user says **「精簡模式」** (or `caveman`) or **「詳細模式」**, you **MUST** update your response style accordingly:

### Actions
1. **「精簡模式」 (Caveman Mode)**：
   - 去除所有禮貌客套語與贅字，僅輸出高密度的技術關鍵、邏輯變更、代碼與檔案超連結。
   - 用於密集 Debug、批量重構或連續執行技術任務，極大化節省 Token 消耗與讀取耗時。
2. **「詳細模式」 (Standard Detailed Mode)**：
   - 恢復完整的背景說明、步驟拆解與關懷指引，適用於架構討論、教學或綜合專案規劃。

---

## 「讓我看看」Automation (Local Web Preview Command)

### Trigger
- **Rule**: When the user says **「讓我看看」**, or requests to see/run the local preview, you **MUST** automatically perform the following actions:

### Actions
1. **提供說明**：說明專案人員可以前往專案根目錄，點擊兩下執行 **`run_local_web.bat`** 檔案來一鍵啟動本地預覽。
2. **自動背景啟動**：主動在背景啟動預覽伺服器，啟動指令為：
   `$env:FLUTTER_ROOT="C:\Users\USER\.puro\envs\stable\flutter"; C:\Users\USER\.puro\envs\stable\flutter\bin\cache\dart-sdk\bin\dart.exe --packages="C:\Users\USER\.puro\envs\stable\flutter\packages\flutter_tools\.dart_tool\package_config.json" C:\Users\USER\.puro\shared\flutter_tools\ee80f08bbf97172ec030b8751ceab557177a34a6\flutter_tools.snapshot run -d web-server --web-port=8080`
3. **引導前往連結**：啟動後，請提供點擊連結 **[http://localhost:8080](http://localhost:8080)** 以便進行網頁測試版預覽。

---

## 「確認狀況」Automation (Status Check & Interrupt Command)

### Trigger
- **Rule**: When the user says **「確認狀況」**, you **MUST** automatically perform the following actions:

### Actions
1. **進入「安全凍結狀態 (Safety Freeze)」**：
   - 承諾在此輪對話中，**絕對不修改任何檔案、不建立/刪除程式碼，也不執行任何具有變更性的系統指令**。
   - 若有任何正在跑的非同步背景任務或子代理，主動列出並說明其狀態。
2. **彙整當前進度與脈絡 (Status Audit)**：
   - **目前任務進度**：讀取 `docs/進度.md` 與 `task.md`，摘要目前正進行的任務與進度。
   - **目前已修改的檔案清單與變更摘要**：列出本機目前已被修改或新增的檔案，並摘要已改動了哪些核心邏輯。
   - **接下來預期的變化**：說明 AI 接下來預計會修改或建立哪些檔案、會有哪些功能或行為邏輯上的變化。
3. **引導確認**：
   - 清晰且專注地請專案人員評估當下狀況，等待其提問或指示，在專案人員明確指示下一步前，不可主動恢復代碼開發。

---

## 「對齊」Automation (Align Master System Specification Command)

### Trigger
- **Rule**: When the user says **「對齊」**, or requests to align/synchronize the main system specification, you **MUST** automatically perform the following actions:

### Actions
1. **全面巡檢現有程式碼與資料庫結構**：對比 `lib/` 原始碼、`docs/進度.md` 與 Supabase Schema。
2. **廢棄與陳舊資訊清掃 (Deprecation Sweep Step)**：
   - 檢查規格書中記載但實體程式碼/SQL 中已刪除或已被新邏輯取代的廢棄欄位、舊 SOP 或舊規範。
   - 將已廢棄之項目予以更新移除，或移至廢棄歷史區加註 `[Deprecated / 已廢棄]`，防止規格書膨脹為歷史堆疊垃圾場。
3. **對齊補全全套公共規格文件 (SSOT & Full Specs Synchronization)**：
   - 以 `.agents/AGENTS.md`（規則 SSOT）與 `docs/00_公共規格/main_spec.md`（架構 SSOT）為單一真理來源。
   - 更新 [docs/00_公共規格/main_spec.md](docs/00_公共規格/main_spec.md)（補充最新資料庫表、UI Toast 標準、維運防護 SOP 與快捷指令體系）。
   - **強制同步修訂** [docs/00_公共規格/開發人員快捷指令.md](docs/00_公共規格/開發人員快捷指令.md) 與 [docs/00_公共規格/開發人員手冊.md](docs/00_公共規格/開發人員手冊.md)，採用精簡表格與 SSOT 條文超連結引用，徹底防止多檔案重複寫入產生的版本漂移 (Version Drift)。
4. **報告對齊結果**：向專案人員摘要說明本次 `main_spec.md`、`開發人員快捷指令.md` 與 `開發人員手冊.md` 補全與清掃了哪些欄位與核心架構。

---

## 「book」Automation (System Document Relationship Map Command)

### Trigger
- **Rule**: When the user says **「book」** (or `Book`), you **MUST** automatically perform the following actions:

### Actions
1. **渲染全專案文檔關係地圖 (Mermaid Diagram)**：輸出專案核心文件 (AGENTS, 快捷指令, 主規格書, 進度表, 個人工作區, 專題報告) 的完整架構圖。
2. **說明 4 種連動型態對照表**：
   - **Type A (雙向自動對齊)**：`AGENTS.md` $\Leftrightarrow$ `開發人員快捷指令.md` / `手冊.md`
   - **Type B (單向唯讀巡檢 - 人類領地)**：`個人工作區` $\rightarrow$ `進度.md` (AI 僅讀取，不改動人類筆記)
   - **Type C (按需實體對齊)**：`lib/` + `*.sql` + `開發日誌` $\rightarrow$ `main_spec.md` (輸入 `對齊` 時觸發)
   - **Type D (里程碑自動備份)**：`lib/` $\rightarrow$ `04_專題報告/` (有改 Code 時收工自動備份 Mermaid/ERD)

---

## 「自我修復」Automation (Self-Correction & Rule Repair Command)

### Trigger
- **Rule**: When the user says **「自我修復」**, or when a logical contradiction/edge-case inconsistency with original system design is detected, you **MUST** automatically perform the following actions:

### Actions
1. **剖析矛盾與根因 (Root Cause Analysis)**：
   - 清楚條列出「原本設計意圖 (Original Design)」、「發生的實際矛盾/邏輯漏洞 (Actual Contradiction)」與「造成該問題的根因 (Root Cause)」。
2. **修復底層運作規則 (`.agents/AGENTS.md`)**：
   - 即刻修改本檔案（`AGENTS.md`）對應的指令、自動化防護或驗證條件，確保邏輯閉環無死角。
3. **單一真理來源 (SSOT) 防漂移對齊**：
   - 確保 `.agents/AGENTS.md`（運作 SSOT）與 `main_spec.md`（架構 SSOT）為核心源頭，所有手冊以連結與簡明對照表引用，避免重複文義產生的版本漂移。
4. **廢棄與陳舊資訊清掃 (Deprecation Sweep)**：
   - 巡檢並廢除舊版矛盾邏輯，清理舊招式與舊 SOP，移至歷史區或更換為新版標準。
5. **雙向自動對齊全套手冊與規格書**：
   - 嚴格落實 Type A 雙向自動對齊，同步更新 `開發人員快捷指令.md`、`開發人員手冊.md`、`main_spec.md` 與 `進度.md`。
6. **報告自我修復結果**：
   - 摘要說明修正了哪些底層規則條文、清掃了哪些廢棄資訊、同步對齊了哪些實體文檔，並說明全新的防呆運作邏輯。

---

## Obsidian Linking Specification

### Rule
- **Rule**: When creating bidirectional links in documentation, you **MUST** adhere to the following rules to maintain graph cleanliness:
  1. **No Concept Links**: Only link to physical files that exist (e.g. `[[進度.md]]` or `[Label](../path.md)`). Never link abstract concepts (e.g. `[[設計]]`) that do not have dedicated files.
  2. **Format Compatibility**: Prefer standard markdown relative paths with `.md` extensions (e.g., `[Label](../path.md)`) for absolute compatibility between GitHub and Obsidian.
  3. **Strict Case-Sensitivity**: Folder paths and filenames must match the filesystem case exactly (use lowercase `docs/`).

---

## Git Commit Message Convention

### Rule
- **Rule**: Whenever you generate Git commit messages (whether triggered by 「收工」 or by user request), you **MUST** follow the format and type labels defined in [Git提交訊息規範.md](docs/00_公共規格/Git提交訊息規範.md).
