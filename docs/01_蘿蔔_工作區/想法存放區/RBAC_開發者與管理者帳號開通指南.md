# 🛡️ RBAC 開發者 (`dev`) 與管理者 (`admin`) 帳號開通與升級指南

本指南紀錄如何在 Supabase 資料庫與系統中，將指定的業務員帳號升級為 **`dev` (核心開發者)** 或 **`admin` (團隊管理者)**，供後續 Demo 展示或團隊測試時安全啟用。

---

## 📌 預設機制與安全防護
1. **預設權限**：所有新註冊的帳號（無論透過 Email 註冊或 Google OAuth 登入），在 Supabase `public.profiles` 表中的 `role` 預設皆為 `'agent'`（一般業務員）。
2. **權限隔離**：一般業務員前端 **無法** 任意修改自己的 `role` 欄位。只有具有 Supabase 管理存取權限者才能變更。

---

## 🛠️ 方式 A：透過 Supabase SQL Editor 一鍵升級（最推薦）

當您在前端註冊好特定測試帳號後（例如 `lobo@example.com`），直接開啟 [Supabase Dashboard](https://supabase.com/dashboard) $\rightarrow$ **SQL Editor**，貼上並執行以下 SQL 指令：

```sql
-- 1. 將指定 Email 帳號升級為 dev (核心開發者)
UPDATE public.profiles 
SET role = 'dev' 
WHERE email = '您的Email@gmail.com';

-- 2. 將指定 Email 帳號升級為 admin (團隊主管)
UPDATE public.profiles 
SET role = 'admin' 
WHERE email = '主管Email@gmail.com';

-- 3. 查詢目前所有帳號的角色清單
SELECT id, email, full_name, role, is_google_connected, updated_at 
FROM public.profiles 
ORDER BY created_at DESC;
```

---

## 🛠️ 方式 B：離線測試模式 (Local SharedPreferences) 手動寫入

若在未連線網路/離線模擬測試時，可以在瀏覽器控制台或本地 LocalStorage 清除後，執行以下 Key 寫入：
- `profile_role` $\rightarrow$ `'dev'` 或 `'admin'`

---

## 👑 成果說明
* 升級為 `'dev'` 後：登入系統將自動獲得「上帝視角 (View-As Mode)」導覽列，可在 `業務員視圖`、`主管視圖` 與 `開發者除錯控制台` 之間一秒無縫切換，極度方便展示與 Demo！
* 升級為 `'admin'` 後：登入系統直接切換為「團隊總攬戰情室與成員派單管理面板」。
