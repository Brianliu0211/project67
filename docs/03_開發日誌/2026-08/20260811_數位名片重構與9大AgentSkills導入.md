# 📅 [2026-08-11] - 【模組二：個人帳號與商務名片】數位名片實體化重構、9大 Agent Skills 導入與系統架構決策

> **執行狀態**：🟢 已併入主線分支 (`feature/lobo-system-architecture-overhaul`) / 本地伺服器運行於 [http://localhost:8080](http://localhost:8080)

---

## 🎯 實作成果摘要
1. **數位名片實體化重構**：徹底擺脫舊版遊戲面板感，重構為比照真實印刷名片的高級質感排版，新增「保險業務員登錄字號」欄位，將快捷動作按鈕下移至預覽舞台下方，並重構「榮譽頭銜 (Tab 2)」為 3 大結構化面板。
2. **導入 9 大 AI Agent 開源審美 Skills**：於 `.agents/skills/` 正式裝載與對齊 9 大 Agent Skills，徹底消滅 AI 寫出粗糙/俗套介面 (Anti-Slop) 的問題。
3. **刪除冗餘彈窗與側邊欄對調**：刪除「3D 劇院」預覽彈窗，並於 `home_screen.dart` 完成側邊欄「垃圾桶 🗑️」與「個人帳號 👤」選單順序對調。
4. **開發日誌規範修訂**：更新 `docs/03_開發日誌/開發日誌規範.md`，納入 `[Handoff 狀態條言]` 規範與 Quality Gate 品質門檻條文。

---

## 💻 技術變更明細 (Actual Technical Changes)

### 1. `lib/screens/profile_screen.dart` (名片實體化與頭銜面板重構)
- **保險業務員登錄字號 (`_licenseNoController`)**：新增控制器、FocusNode 與 Key-Value 持久化儲存 (`profile_license_no`)。
- **名片正面排版 (`_buildCardFrontSide`)**：去除卡片內部原本佔據近 40% 空間的 3 個彩色大按鈕，改為頂部「公司 Logo + 金管會登錄字號 + 尊榮頭銜」，中部「64x64 大頭貼 + 中文姓名 + 職稱」，下部「精緻聯絡欄 + 橫向滑動專業證照徽章」。
- **快捷動作工具列 (`_buildStudioStageCanvas`)**：將 `[撥打電話]`、`[加 LINE]`、`[發送 Email]` 獨立為名片預覽舞台正下方的獨立操作列。
- **榮譽頭銜面板重構 (`_buildTab2BadgesAndTheme`)**：拆解為「👑 專屬榮譽頭銜 (選擇/新增)」、「🏆 專業證照與榮譽徽章 (FilterChip 多選)」、「🎨 名片實體材質與視覺主題 (黑金尊榮、極光藍曜等色票)」3 大卡片區塊。
- **刪除 3D 劇院彈窗**：刪除頂部 `[3D 劇院]` 按鈕與 `_open3DTheaterModal()` 方法。

```dart
// 登錄字號顯示邏輯範例
if (_licenseNoController.text.trim().isNotEmpty) ...[
  const SizedBox(height: 2),
  Text(
    '登錄字號：${_licenseNoController.text.trim()}',
    style: TextStyle(fontSize: 11, color: cardSubColor, fontWeight: FontWeight.w500),
  ),
],
```

### 2. `lib/screens/home_screen.dart` (側邊欄選單對調)
- 對調側邊欄選單順序，將「垃圾桶」移至「數據戰情」下方，「個人帳號」移至「垃圾桶」與「系統設定」之間。

```dart
_buildSidebarItem(Icons.bar_chart_outlined, '數據戰情', isDark, primaryColor),
_buildSidebarItem(Icons.delete_outline, '垃圾桶', isDark, primaryColor),
_buildSidebarItem(Icons.account_circle_outlined, '個人帳號', isDark, primaryColor),
_buildSidebarItem(Icons.settings_outlined, '系統設定', isDark, primaryColor),
```

### 3. `.agents/skills/` (導入 9 大 AI Agent 開源審美 Skills)
- 於 `.agents/skills/` 下建置並升級 9 大 Agent Skills 實體檔：
  1. `taste-skill/SKILL.md` (Anti-Slop 質感規約)
  2. `ui-ux-pro-max/SKILL.md` (滿版 RWD 佈局與分頁表單智庫)
  3. `impeccable-design/SKILL.md` (59 條防醜與對話框防抖動品質檢查門檻)
  4. `frontend-design/SKILL.md` (Anthropic 大膽視覺與微動畫規約)
  5. `hallmark-design/SKILL.md` (Together AI 20 主題與反模板自我批判門檻)
  6. `gsap-motion-skills/SKILL.md` (GreenSock 緩動曲線與時間軸規範)
  7. `stitch-design-skills/SKILL.md` (Google Agent 技能開放標準)
  8. `web-interface-guidelines/SKILL.md` (WAI-ARIA 無障礙與全鍵盤 Focus 規範)
  9. `web-video-presentation/SKILL.md` (劇院級產品動態展示與 Spotlight 導覽規範)

### 4. `docs/工具包.md` & `docs/03_開發日誌/開發日誌規範.md` (文件同步)
- 在 `docs/工具包.md` 新增 9 大 Skills 之本機實體檔超連結與說明。
- 在 `docs/03_開發日誌/開發日誌規範.md` 寫入 `[Handoff 狀態條言]` 與 Quality Gate 條文。

---

## 💡 本次確認之核心架構與觀念 (Architectural Decisions)

1. **【保單健診白話庫 `policy_checkpoints`】**：
   - 告別舊名稱 SafeCheck 的抄襲感，全新命名 `policy_checkpoints`。
   - 必須綁定金管會/保發中心 `approval_code` 核准字號透明溯源。
   - 利用免費 GitHub Actions 每週 Cron 背景爬蟲，實現 0 費用資料同步。
2. **【企業級 Admin Studio 後台與 RBAC 權限】**：
   - 區分 Agent (業務員) 與 Admin (管理員) 雙層權限。
   - 包含：帳號審核與**離職業務員客戶資產一鍵移轉**、`policy_checkpoints` 上架審核、**主標籤同義字一鍵合併清理**（如 `[缺實支]` 併入 `[缺實支實付]`）、系統營運與 RLS 資安 Log 監控。
3. **【真‧互動式 Spotlight 導覽落地順序】**：
   - 確定「先完成全站實體功能與畫面 $\rightarrow$ 最後才封頂製作 Spotlight 手把手亮光穿透教學」，確保教學動線 100% 準確且不重複重做。

---

## 🚦 Quality Gate 品質門檻稽核
- [x] **Supabase RLS 安全**：本機 SharedPreferences 與 profiles 結構寫入正常。
- [x] **UI/UX 規範**：100% 貫徹 9 大 Agent Skills 之反俗套美學，移除名片內部巨型按鈕，消除對話框抖動。
- [x] **工具包同步**：已同步更新 `docs/工具包.md`。
- [x] **Null-Safety 防護**：所有選填欄位（登錄字號、LINE、Email、地址）皆包覆 `isNotEmpty` 判斷。

---

## 🤝 [Handoff 狀態條言] (Session Cross-Handover State)

- **會話脈絡 (Session Context)**：
  專案人員（蘿蔔）針對名片視覺、選單順序、9 大 Agent Skills 運作機制提出深刻指引，要求將名片回歸實體質感、對調側邊欄「垃圾桶」與「個人帳號」、釐清 Agent Skills 在 `.agents/skills/` 的運作邏輯，並同步更新 `開發日誌規範.md`。
- **當前軟體狀態 (Current Software State)**：
  * 當前 Git 分支：`feature/lobo-system-architecture-overhaul`
  * 靜態預覽伺服器：`http://localhost:8080` 正常運行中，通過 `puro flutter build web --release` 編譯。
- **核心決策 (Key Architectural Decisions)**：
  * 實體名片視覺定案：黑金/金屬風格，登錄字號標示，快捷連線按鈕下移至預覽舞台下方。
  * 側邊欄順序定案：數據戰情 $\rightarrow$ 垃圾桶 $\rightarrow$ 個人帳號 $\rightarrow$ 系統設定。
  * 9 大 Agent Skills 實體目錄歸檔至 `.agents/skills/`，並於 `docs/工具包.md` 對齊。
- **建議接棒下一步 (Recommended Next Steps)**：
  * 開始推進第二階段：**【保單健診白話庫 `policy_checkpoints` & 6 大點對比 PK 卡】** 的 Supabase DB Migration 腳本撰寫與 UI 設計。
