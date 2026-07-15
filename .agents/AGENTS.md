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
1. **討論開發計畫**: Confirm with the developer what feature/task they are about to implement.
2. **建議分支名稱**: Generate a clean branch name following the format `feature/username-featurename` (e.g., `feature/lobo-login-ui` or `feature/beast-db-sync`).
3. **提供分支指令/介面操作對照**: Present step-by-step instructions for:
   - **GitHub Desktop**: How to switch to `main`, pull, create a new branch, and publish it.
   - **Git CLI**: The exact shell commands (`git checkout main`, `git pull`, `git checkout -b ...`, `git push -u ...`).


---

## 「收工」Automation (End-of-Session Command)

### Trigger
- **Rule**: When the user says **「收工」**, you **MUST** automatically perform the following actions in order:

### Actions
1. **撰寫開發日誌**: Create a new development log in `docs/03_開發日誌/` following the established specification, documenting all technical changes made during the current session.
2. **更新進度表**: Review and update [進度.md](file:///c:/Users/brain/OneDrive/文件/GitHub/project67/docs/進度.md) — check off (`[x]`) any completed items, and add any new items that were discovered during the session.
3. **產出 Git Commit 訊息**: Generate a ready-to-paste **Summary** and **Description** for GitHub Desktop, strictly following the conventions defined in [Git提交訊息規範.md](file:///c:/Users/brain/OneDrive/文件/GitHub/project67/docs/00_公共規格/Git提交訊息規範.md).
4. **提示上傳與 GitHub 合併步驟**: Provide a clear step-by-step guidance on how to:
   - Push the local branch to remote (via GitHub Desktop or CLI).
   - Create a Pull Request (PR) on GitHub.
   - Perform the merge (Merge Pull Request) on GitHub.
   - Switch back to `main` locally, pull the merged code, and delete the temporary feature branch.

## Git Commit Message Convention

### Rule
- **Rule**: Whenever you generate Git commit messages (whether triggered by 「收工」 or by user request), you **MUST** follow the format and type labels defined in [Git提交訊息規範.md](file:///c:/Users/brain/OneDrive/文件/GitHub/project67/docs/00_公共規格/Git提交訊息規範.md).

