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
- **Rule**: Whenever the user requests you to write a development log, you **MUST** create a new file in [docs/03_開發日誌/](docs/03_開發日誌/) named in the format `YYYYMMDD_Title.md` (e.g., `20260713_登入介面更新.md`), using short, concise titles.
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
2. **確認開發者身分與工作區**：主動詢問開發者為 **蘿蔔 (lobo)** 還是 **巨獸 (beast)**，以鎖定對應的分支前綴與沙盒路徑。
3. **巡檢個人工作區新靈感 (Read-Only Scan)**：唯讀巡檢 `docs/01_蘿蔔_工作區/想法存放區/` 與 `docs/02_巨獸_工作區/想法存放區/`，若發現全新未討論靈感，詢問是否提報摘要至 `docs/進度.md` 萬能收件匣。（注意：AI 嚴禁修改或刪除人類工作區原始筆記）。
4. **對齊進度表任務**：讀取 [進度.md](docs/進度.md) 並展示當前未完成的大模組任務列表，請開發者選擇本次要進行的任務。
5. **建議分支名稱**：若為程式碼開發，生成格式為 `feature/username-featurename` 的分支名稱（例如：`feature/lobo-customer-list-ui`）。
6. **提供分支指令/介面操作指引**：引導 GitHub Desktop 建立特徵分支（純文件類修改除外）。

---

## 「收工」Automation (End-of-Session Command)

### Trigger
- **Rule**: When the user says **「收工」**, you **MUST** automatically perform the following actions in order:

### Actions
1. **撰寫開發日誌**: Create a new development log in [docs/03_開發日誌/](docs/03_開發日誌/) following the established specification, documenting all technical changes made during the current session.
2. **更新進度表**: Review and update [進度.md](docs/進度.md) — check off (`[x]`) any completed items, and process the Incubator/Backlog promotion if applicable.
3. **產出 Git Commit 訊息**: Generate a ready-to-paste **Summary** and **Description** for GitHub Desktop, strictly following the conventions defined in [Git提交訊息規範.md](docs/00_公共規格/Git提交訊息規範.md).
4. **智慧提交分流引導 (Fast-Track vs Standard PR)**：
   - **純文件修訂 (Fast-Track 快速通道)**：若本次變更僅包含 `docs/` 或 `.md` 文件（未修改 `lib/` 或程式碼），直接引導在 GitHub Desktop 提交並推送至 `main` 主線分支。
   - **程式碼修訂 (Standard PR 流程)**：若本次包含程式碼變更，引導透過 GitHub Desktop 將特徵分支推送至遠端、建立 PR 並進行 Merge。

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
