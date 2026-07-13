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

