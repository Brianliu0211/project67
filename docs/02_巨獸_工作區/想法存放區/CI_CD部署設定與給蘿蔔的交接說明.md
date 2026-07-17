# 🚀 Phase 0.95 CI/CD 部署設定與給蘿蔔的交接說明

這份說明存放在巨獸的想法存放區，方便您直接複製並傳給專案夥伴「蘿蔔」進行 GitHub Secrets 設定與 PR 合併。

---

## 📋 給蘿蔔的交接訊息 (請直接複製傳送)

蘿蔔，我已經在 `feature/beast-cicd` 分支中把 Phase 0.95 CI/CD 自動部署的設定與清理工作完成了！在合併這個分支之前，需要你協助在 GitHub 上配置 Vercel 部署的金鑰：

### 1. 設定 GitHub Secrets
請前往我們的 GitHub 專案網頁 ➔ 點選 **Settings** ➔ **Secrets and variables** ➔ **Actions** ➔ 點選 **New repository secret** 新增以下三個加密憑證：

*   **`VERCEL_TOKEN`**（Vercel 個人授權 Token）：
    *   **取得路徑**：到你的 [Vercel 帳號設定 > Tokens](https://vercel.com/account/tokens) 頁面，點擊 **Create** 建立一個新 Token 貼進來。
*   **`VERCEL_ORG_ID`**（你的 Vercel 帳號或團隊 ID）：
    *   **取得路徑**：到你的 Vercel 帳號設定頁面 [Account Settings > General](https://vercel.com/account/settings)，複製帳號名稱下方的 **ID**（例如：`user_xxxx...` 或 `team_xxxx...`）。
*   **`VERCEL_PROJECT_ID`**（本專案在 Vercel 上的 ID）：
    *   **取得路徑**：到 Vercel 的本專案頁面 ➔ 點選 **Settings > General**，複製 **Project ID**（例如：`prj_xxxx...`）。

### 2. 審查並合併 PR
*   設定好 Secrets 後，請至 GitHub 審查我的 Pull Request（將 `feature/beast-cicd` 合併入 `main`）並點選 **Merge pull request**。

### 3. 驗證自動化部署
*   合併完成後，GitHub Actions 會被自動喚醒。你可以到 GitHub 的 **Actions** 分頁，觀察 `Deploy Flutter Web to Vercel` 工作流是否順利編譯完畢並顯示綠燈，隨後打開 Vercel 網頁確認最新版程式碼已成功發布！
