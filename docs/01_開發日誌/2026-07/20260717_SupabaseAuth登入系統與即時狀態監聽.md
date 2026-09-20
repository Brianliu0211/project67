# 📅 2026-07-17 - 【Phase 2：Supabase Auth 登入系統】登入系統實作與即時狀態監聽

> **執行狀態**：🟢 已併入主線 (src)

## 🎯 實作成果摘要
- 實作完整業務員註冊與登入功能，新增姓名輸入欄位，並透過資料庫 Trigger 自動生成對應的 `public.profiles` 使用者檔案。
- 實作反應式會話狀態（Session）監聽，網頁重整時能保持登入狀態（會話保存），登入或登出時能即時無縫重繪 UI。
- 優化主畫面側邊欄，由硬編碼「王大同 業務代表」改為動態拉取登入使用者的真實姓名與電子信箱，並將字首呈現於圓形頭像上。
- 修復 Material 3 的 `CardTheme` 類型錯誤，並重構 `run_local_web.bat` 改以編譯後靜態啟動本地伺服器方式，繞過了 Puro 版本管理器在 Windows 上的軟連結路徑 Bug。

## 💻 技術變更明細 (Actual Technical Changes)

- **[MODIFY] `lib/main.dart`**：
  - 將 `AuthGateway` 改為反應式監聽元件，使用 `StreamBuilder<AuthState>` 訂閱 `Supabase.instance.client.auth.onAuthStateChange`。
  - 將 `ThemeData` 中的 `cardTheme` 類型從 `CardTheme` 修復為 `CardThemeData`。
  ```dart
  // AuthGateway 核心變更
  return StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (context, snapshot) {
      // 監聽 session 並自動切換 HomeScreen 或 LoginScreen
    }
  );
  ```

- **[MODIFY] `lib/screens/login_screen.dart`**：
  - 新增 `_nameController` 控制器，在註冊介面中顯示「姓名」輸入欄位。
  - 在 `signUp` 中以 `data: {'full_name': _nameController.text.trim()}` 將姓名傳遞至 Auth metadata。
  - 新增離線安全保護，阻擋在離線模式下點擊註冊按鈕調用 `Supabase.instance` 導致的崩潰。

- **[MODIFY] `lib/screens/home_screen.dart`**：
  - 新增 `_userName` 與 `_userEmail` 變數，並於 `initState` 中調用 `_loadUserProfile()`。
  - 線上模式下從 `profiles` 資料表查詢登入者的真實姓名與信箱，並將姓名第一個字動態呈現在側邊欄頭像。
  - 簡化 `_handleSignOut`，僅需呼叫 `auth.signOut()` 即可由 `AuthGateway` 自動處理回退。

- **[MODIFY] `run_local_web.bat`**：
  - 重寫為 ASCII 編碼格式，改以先執行 `puro flutter build web --debug`，再利用 `python -m http.server 8080 --directory build/web`（或 Node.js `npx http-server`）啟動，解決路徑解析失敗問題。

## ⚠️ 環境異動與破壞性變更 (Environment & Breaking Changes)
- 新增 `.env` 環境變數設定需求：需填寫 `SUPABASE_URL` 與 `SUPABASE_ANON_KEY` 以啟用線上模式。
- 無新增第三方套件包。

## 🚦 團隊協作與驗證指南 (Verification Plan)
- **工程師驗證**：
  - 執行 `flutter analyze` 確保無 Errors。
  - 執行 `run_local_web.bat` 能順利編譯並在 `localhost:8080` 開啟。
- **PM/夥伴預覽**：
  - 無金鑰狀態下，點擊頂部黃色橫幅「直接跳過登入」測試離線客戶 CRUD 功能。
  - 填寫金鑰狀態下，註冊新帳號，並在 Supabase 控制台的 `profiles` 表中檢查姓名是否寫入成功。
