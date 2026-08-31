# 📅 [2026-09-01] - 【模組五：數據戰情與條款知識中樞】數據戰情室與SafeCheck條款CRM精算整合

> **執行狀態**：🟢 特徵分支 (`feature/lobo-policy-clauses-crm`)

## 🎯 實作成果摘要
落實專案人員「零假資料、全量實體資料庫連線、借鏡 SafeCheck 與臨床真實需求」之核心指導原則，完成「數據戰情室」全面重構與條款精算中樞升級：
1. **100% 資料庫即時動態連線**：拔除寫死之「11,722 款」、「VIP 4 位」與「85% 健診率」，改由 SQL 動態計數為全台官方條款庫 **`12,090 款`**，並實時聚合名下客戶為 **3 大業務生命週期**（🎯 未開發 Leads、💬 跟進中 Prospects、🌟 已簽單保戶 Clients）與當月拜訪達成率。
2. **SafeCheck 規格條款檢索矩陣**：實作 15 大險種智慧擴展（`expandCategoryFilter` 映射 33 種底層條款，修復手術險等關鍵字檢索）、伺服器端高效 Range 原生分頁與動態計數 Badge。
3. **SafeCheck 規格 2~8 款商品橫向並排比較表 (`PolicyComparisonScreen`)**：支援底部亮橘色浮動列（`已選 X/8 款商品`）、橫向並排規格對照、只看差異開關與原廠 PDF 直開。
4. **業界標準全方位理賠精算中樞**：
   - 雙模式輸入：6 大臨床情境標準範本一鍵載入 + 自由單據明細編輯器（自訂病房天數/單價、手術自費、標靶藥品/醫材雜費）。
   - 健保 2-2-7 處置陷阱即時檢核與紅框警示（非 2-2-7 處置自動除外）。
   - 🔥 跨保單/雙實支多層次瀑布精算（正本核銷 $\rightarrow$ 副本補足 $\rightarrow$ 正本衝突預警 $\rightarrow$ 最終缺口精算）。
5. **CRM 業務實體閉環**：比較表內可直接一鍵將商品掛載至名下客戶，寫入 `customer_policies` 實體資料表。
6. **全站測試驗證**：36/36 單元與整合測試 100% 綠燈通過。

---

## 💻 技術變更明細 (Actual Technical Changes)

- **[NEW] [`lib/screens/policy_comparison_screen.dart`](file:///c:/GitHub/project67/lib/screens/policy_comparison_screen.dart)**：
  - 實作 SafeCheck 風格 2~8 款商品橫向並排比較表。
  - 支援「只看差異 (Diff View)」開關、原廠 PDF 條款直開。
  - 整合「全真醫療單據試算」彈窗（支援範本載入 + 自由單據編輯器 + 2-2-7 處置陷阱檢核）。
  - 整合「🔥 跨保單組合包聯合精算」瀑布流向彈窗（支援雙實支正副本核銷與收據衝突檢核）。
  - 整合「為名下客戶規劃」彈窗，一鍵寫入 Supabase `customer_policies` 實體保單表。
- **[MODIFY] [`lib/screens/data_dashboard_tab.dart`](file:///c:/GitHub/project67/lib/screens/data_dashboard_tab.dart)**：
  - 徹底移除寫死之假陣列（`_catalogProducts`、`CAT-01`）與假線性保費公式。
  - 頂部接入真實業務漏斗指標卡（名下客戶總量、未開發/跟進中/已簽單保戶、本月拜訪戰況、推動中專案數）。
  - 接入 12,090 筆官方條款實時檢索矩陣與 15 大險種 ChoiceChips。
  - 實作 SafeCheck 風格底部亮橘色浮動選取列（`已選 X/8 款商品`）。
- **[MODIFY] [`lib/services/customer_policy_service.dart`](file:///c:/GitHub/project67/lib/services/customer_policy_service.dart)**：
  - 新增 `CustomerFunnelSummary`、`ClinicalScenario`、`ClinicalScenarioResult`、`MultiPolicyClaimItem`、`MultiPolicyClaimSummary` 數據模型。
  - 實作 `fetchRealSalesFunnelMetrics()`：100% 透過 Supabase 查詢計算客戶漏斗與拜訪達成率。
  - 建立 6 大真實臨床情境資料庫（達文西、標靶、膝關節、支架、闌尾炎、骨折鋼釘）。
  - 實作 `calculateCustomItemizedClaim()`：支援自訂單據與 2-2-7 處置陷阱檢核。
  - 實作 `calculateMultiPolicyWaterfallClaim()`：支援跨保單/雙實支多層次瀑布核銷精算。
- **[MODIFY] [`lib/services/policy_crawler_service.dart`](file:///c:/GitHub/project67/lib/services/policy_crawler_service.dart)**：
  - 新增 `expandCategoryFilter()`：自動將前台 15 大分類映射至資料庫 33 種底層實體分類。
  - 升級 `searchPolicyClausesPaged()`：採用 Supabase `.range(from, to).count(CountOption.exact)` 原生伺服器端分頁，突破 1,000 筆截斷限制。
- **[MODIFY] [`lib/screens/home_screen.dart`](file:///c:/GitHub/project67/lib/screens/home_screen.dart)**：
  - 移除未使用的不存在 import，加入離線預覽模式 Supabase Auth 監聽防護。
- **[NEW] [`test/data_dashboard_real_data_test.dart`](file:///c:/GitHub/project67/test/data_dashboard_real_data_test.dart)**：
  - 建立專屬單元測試套件（漏斗指標計算、6 大臨床情境試算、類別擴展映射、自訂單據 2-2-7 陷阱、雙實支瀑布核銷），全站 36/36 測試全數通過。

---

## ⚠️ 環境異動與破壞性變更 (Environment & Breaking Changes)
- **資料庫欄位/資料表**：無結構變更，完全沿用已具備嚴格 RLS 策略之 `policy_clauses` 與 `customer_policies` 實體表。
- **套件/Skill 異動**：未引入額外第三方套件。
- **假資料清除狀態**：**100% 徹底清除**。數據戰情室中已無任何寫死之假商品或假算式。

---

## 🚦 Quality Gate 4 項品質稽核檢驗
- [x] **Supabase RLS 安全**：`customer_policies` 具備使用者等級之安全隔離存取控制。
- [x] **UI/UX 規範**：符合 Anti-Slop 美學、深色/淺色主題自適應與 SafeCheck 現代化設計標準。
- [x] **工具包同步**：檢查確認未引入額外第三方套件。
- [x] **Null-Safety 防護**：全站 36/36 單元與整合測試 100% 綠燈通過。

---

## 🤝 [Handoff 狀態條言] (Session Cross-Handover State)

- **會話脈絡 (Session Context)**：
  本次會話聚焦於「數據戰情室」與「條款知識庫」的去假求真重構。專案人員明確指示「100% 拒絕假資料、條款數量真實化、解決名下未開發客戶漏斗歸屬、借鏡 SafeCheck 與真實臨床需求」。AI 團隊首先盤點實體資料庫（12,090 筆條款、5 位名下客戶），依據業務現實建立了 3 大客戶生命週期漏斗；接著借鏡 SafeCheck 實作二維檢索矩陣、底部浮動列與 2~8 款商品橫向並排比較表；進一步將理賠試算升級為「自由單據細項編輯器 + 健保 2-2-7 地雷預警 + 雙實支瀑布精算」，並完成一鍵 CRM 投保閉環。
- **當前軟體狀態 (Current Software State)**：
  - 目前位於特徵分支：`feature/lobo-policy-clauses-crm`。
  - 本地 Web 伺服器運作於：`http://localhost:8080`（`python -m http.server 8080 --directory build/web`）。
  - 自動化測試狀態：**36/36 Passed (100% 綠燈)**。
- **核心決策 (Key Architectural Decisions)**：
  1. **零假資料原則**：戰情室條款筆數隨資料庫增刪即時連動，搜尋與篩選完全由 Supabase 原生 Range 分頁計算。
  2. **客戶漏斗判定**：有保單為「🌟 保戶」、有拜訪行程/標籤為「💬 跟進中」、其餘為「🎯 未開發」。
  3. **理賠精算架構**：提供「臨床標準範本 + 自由單據明細自訂 + 2-2-7 處置陷阱檢核 + 跨保單雙實支瀑布流向」，符合頂尖 InsurTech / 保經系統標準。
  4. **CRM 閉環**：比較後的商品可一鍵選取名下客戶寫入 `customer_policies`，將該客戶自動升級為已簽單保戶。
- **後續接續推薦 (Recommended Next Steps)**：
  1. **Phase 2 條款 PK 圖卡匯出**：於客戶管理詳情彈窗整合「名下保單 vs 推薦新保單」一鍵 PK 圖卡生成。
  2. **頁面狀態快取優化**：採用 `IndexedStack` 減少側邊欄切換時的重複查詢。
  3. **Google 日曆雙向同步 (Phase 2)**：接續推進 `google_event_id` 與次日曆 API 授權。
