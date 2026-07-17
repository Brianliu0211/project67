# 🌐 Supabase 線上部署金鑰配置與給蘿蔔的交接說明

為了讓發布到 Vercel 的網頁版正式脫離「離線預覽模式」並成功連接 Supabase 資料庫，需要請專案管理員「蘿蔔」在 GitHub 上進行金鑰配置。

---

## 📋 給蘿蔔的交接訊息 (請直接複製傳送)

蘿蔔，我已經更新了我們的 GitHub Actions CI/CD 設定檔，現在只要在 GitHub 上多設定兩個 Supabase 金鑰，發布到 Vercel 的網站就能自動轉為「線上模式」並正常連接資料庫了！

請協助在我們專案的 GitHub 倉庫執行以下設定：

### 1. 新增 Supabase Secrets
請前往專案的 GitHub 網頁 ➔ 點選 **Settings** ➔ **Secrets and variables** ➔ **Actions** ➔ 點選 **New repository secret** 新增以下兩個憑證：

*   **`SUPABASE_URL`**：
    *   **取得路徑**：到我們的 Supabase Project Dashboard ➔ 點選左下角的 **Project Settings** ➔ **API**。
    *   複製 **Project URL** 貼進來。
*   **`SUPABASE_ANON_KEY`**：
    *   **取得路徑**：同在 Supabase **API** 設定頁面中。
    *   複製 **Project API keys** 下方的 `anon` `public` key 貼進來。

### 2. 合併 PR 或推送至 main
*   Secrets 設定好後，請將我最新提交的分支代碼合併或推送至 `main`。
*   GitHub Actions 就會在背景自動讀取這兩個金鑰，將它們打包進網頁，並完成部署。這時再次打開 Vercel 網址，頂部的橘色離線橫幅就會消失，且註冊/登入功能就能正常對接 Supabase 資料庫了！
