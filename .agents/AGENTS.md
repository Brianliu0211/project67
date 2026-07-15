# Workspace Rules - insurance_helper

This file defines guidelines and constraints specific to the `insurance_helper` workspace.

## Automated Document Synchronization

### Tooling Guide Update (`docs/工具包.md`)
- **Rule**: Whenever you (the AI Agent) install, configure, or recommend a new tool, SDK, CLI tool, or Dart package (added to `pubspec.yaml`), you **MUST** automatically update the [工具包.md](file:///c:/Users/haolu/OneDrive/文件/GitHub/project67/docs/工具包.md) file.
- **Content Requirements**:
  - For new SDKs/CLI tools: add under the "開發環境與 SDK" section, including a name, version details, short purpose, and official download links.
  - For new Dart/Flutter packages: add under the "專案相依套件" section, describing its exact role in the project.
- **Timing**: Perform this update immediately after modifying configuration files (like `pubspec.yaml`) or running install commands.

### Developer Log Update (`docs/03_開發日誌/`)
- **Rule**: Whenever the user requests you to write a development log, you **MUST** create a new file in [docs/03_開發日誌/](file:///c:/Users/haolu/OneDrive/文件/GitHub/project67/docs/03_開發日誌/) named in the format `YYYYMMDD_Title.md` (e.g., `20260713_登入介面更新.md`), using short, concise titles.
- **Specification Compliance**: You **MUST** strictly follow all rules and templates defined in [開發日誌規範.md](file:///c:/Users/haolu/OneDrive/文件/GitHub/project67/docs/03_開發日誌/開發日誌規範.md).
- **Multiple Logs Per Day**: If multiple dev logs are written on the same day, each log should use a distinct functional title (e.g., `20260714_客戶卡片UI刻劃.md` and `20260714_Supabase串接與RLS測試.md`). Do NOT use sequential numbering.

## 「開工」Automation (Start-of-Session Command)

### Trigger
- **Rule**: When the user says **「開工」**, or when you (the AI Agent) and the user agree on a development plan, you **MUST** automatically perform the following actions:

### Actions
1. **確認開發者身分與工作區**：主動詢問開發者為 **蘿蔔 (lobo)** 還是 **巨獸 (beast)**，以鎖定對應的分支前綴與沙盒路徑。
2. **對齊進度表任務**：讀取 `docs/進度.md` 並展示當前未完成的任務列表，請開發者選擇本次要進行的任務。
3. **建議分支名稱**：生成格式為 `feature/username-featurename` 的分支名稱（例如：`feature/lobo-customer-list-ui`）。
4. **提供分支指令/介面操作指引（主要提供 GitHub Desktop，Git CLI 僅作備用）**：
   - **GitHub Desktop**：主要引導切換至 `main`（提醒處理未提交變更）、Pull 並建立新特徵分支推送。
   - **Git CLI（備用，可置於 details 摺疊區塊或在要求時才提供）**：提供包含防呆與套件同步的完整指令。

---

## 「收工」Automation (End-of-Session Command)

### Trigger
- **Rule**: When the user says **「收工」**, you **MUST** automatically perform the following actions in order:

### Actions
1. **撰寫開發日誌**: Create a new development log in `docs/03_開發日誌/` following the established specification, documenting all technical changes made during the current session.
2. **更新進度表**: Review and update [進度.md](file:///c:/Users/brain/OneDrive/文件/GitHub/project67/docs/進度.md) — check off (`[x]`) any completed items, and add any new items that were discovered during the session.
3. **產出 Git Commit 訊息**: Generate a ready-to-paste **Summary** and **Description** for GitHub Desktop, strictly following the conventions defined in [Git提交訊息規範.md](file:///c:/Users/brain/OneDrive/文件/GitHub/project67/docs/00_公共規格/Git提交訊息規範.md).
4. **提示上傳與 GitHub 合併步驟**: Provide a clear step-by-step guidance focusing on GitHub Desktop (omit verbose CLI commands by default unless requested) on how to:
   - Push the local branch to remote (via GitHub Desktop).
   - Create a Pull Request (PR) on GitHub.
   - Perform the merge (Merge Pull Request) on GitHub.
   - Switch back to `main` locally, pull the merged code, and delete the temporary feature branch via GitHub Desktop.

## 「讓我看看」Automation (Local Web Preview Command)

### Trigger
- **Rule**: When the user says **「讓我看看」**, or requests to see/run the local preview, you **MUST** automatically perform the following actions:

### Actions
1. **提供說明**：說明專案人員可以前往專案根目錄，點擊兩下執行 **`run_local_web.bat`** 檔案來一鍵啟動本地預覽。
2. **自動背景啟動**：主動在背景啟動預覽伺服器，啟動指令為：
   `$env:FLUTTER_ROOT="C:\Users\USER\.puro\envs\stable\flutter"; C:\Users\USER\.puro\envs\stable\flutter\bin\cache\dart-sdk\bin\dart.exe --packages="C:\Users\USER\.puro\envs\stable\flutter\packages\flutter_tools\.dart_tool\package_config.json" C:\Users\USER\.puro\shared\flutter_tools\ee80f08bbf97172ec030b8751ceab557177a34a6\flutter_tools.snapshot run -d web-server --web-port=8080`
3. **引導前往連結**：啟動後，請提供點擊連結 **[http://localhost:8080](http://localhost:8080)** 以便進行網頁測試版預覽。

## Git Commit Message Convention

### Rule
- **Rule**: Whenever you generate Git commit messages (whether triggered by 「收工」 or by user request), you **MUST** follow the format and type labels defined in [Git提交訊息規範.md](file:///c:/Users/brain/OneDrive/文件/GitHub/project67/docs/00_公共規格/Git提交訊息規範.md).

