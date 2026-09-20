# 🏷️ 分類標籤系統與 AI 提取規範 (Categorized Tag System & AI Extraction Spec)

本文件整理並規劃了保險助手系統中「標籤 (Tags)」的分類體系、資料庫三層建模、AI 對齊機制，以及標籤合併管理功能，以避免自由文字輸入造成的標籤混亂。

---

## 1. 標籤分類體系 (Predefined Categories)

為確保資料統計的精準度與一致性，系統預先定義好 5 個核心大分類。所有子標籤必須隸屬於這 5 大分類中的其中一個，使用者與 AI 無法自創新的大分類。

### 📊 1. 客戶身分 (Identity)
*   **預設標籤**：`青年(18-35)`、`中年(36-60)`、`高齡(60+)`、`單身`、`已婚`、`有小孩`、`頂客族`、`高資產`、`小資族`、`退休族`。
*   *業務價值*：統計客群基本畫像。

### 🛡️ 2. 已購保險 (Insurance Types)
*   **預設標籤**：`醫療險`、`意外險`、`防癌險`、`重大傷病`、`壽險`、`儲蓄險`、`投資型保單`、`年金險`、`車險`、`火險`、`旅平險`、`寵物險`。
*   *業務價值*：分析業務主力產品與主流銷售趨勢。

### 🎨 3. 生活興趣 (Interests)
*   **預設標籤**：`露營`、`高爾夫`、`美食`、`健身`、`出國旅遊`、`吃素`。
*   *業務價值*：尋找拜訪的共同話題與非正式關懷。

### 🏥 4. 健康體況 (Health Status)
*   **預設標籤**：`健康`、`有體況`、`高血壓`、`糖尿病`。
*   *業務價值*：核保前的核保條件預篩選。

### 📅 5. 跟進狀態 (Follow-up Status)
*   **預設標籤**：`定期聯繫`、`節日問候`、`高意願`、`觀望中`、`已簽約`、`已拒絕`。
*   *業務價值*：輔助漏斗轉換統計。

---

## 2. 系統運作與限制規則

1.  **大分類固定**：`tag_categories` 僅限系統管理員修改，使用者與 AI **絕對不能自創新的大分類**。
2.  **開放式子標籤**：使用者與 AI 可以動態新增子標籤，但**必須在新增時指定它隸屬的既有大分類**。
3.  **無標準/自訂區分**：系統不再區分「標準標籤」與「自訂標籤」，所有子標籤在地位上完全平等，均屬於其分類下的可用標籤。

---

## 3. AI 語意提取與分類對齊機制

### 🤖 Gemini API 的分類限制 (Category Mapping)
在呼叫 Gemini API 的 System Prompt 中，我們會將 5 個大分類的 `id` 與 `name` 傳給 AI，並規範以下規則：
1.  **分類強制歸屬**：AI 從語音逐字稿中提取新標籤時，**必須回傳其所屬的大分類 `category_id`**。如果該概念無法歸類於 5 大分類中的任何一個，則視為一般文字備註處理，不得輸出為標籤。
2.  **語意自動對齊**：AI 會對語意進行模糊匹配。如果已有相同的子標籤則直接使用；若為全新標籤（例如：`愛爬山`），則在 `suggested_tags` 中回傳 `{"name": "愛爬山", "category_id": [生活興趣的ID]}`。
3.  **漏填與灰色地帶處理**：若語意未明說，則該欄位輸出 `null`，不進行無依據的猜測。

---

## 4. 前端 UI 呈現與標籤管理器

### 🎨 前端 UI 多維度渲染
*   **顏色區隔顯示**：在客戶卡片與詳情彈窗上，標籤不再是單一顏色，而是**依據大分類進行顏色區隔**。例如：
    *   `客戶身分` 標籤 $\rightarrow$ **科技藍**
    *   `已購保險` 標籤 $\rightarrow$ **翡翠綠**
    *   `生活興趣` 標籤 $\rightarrow$ **活力橘**
*   這能讓業務在查看客戶卡片時，視覺結構極其清晰。

### 🛠️ 標籤管理器 (Tag Manager) - 補救與清理機制
為防使用者或 AI 建立語意重複的標籤，我們在設定頁面提供「標籤管理器」：
*   **一鍵合併功能**：業務代表可勾選多個子標籤（例如：`汽機車險`、`保車`、`車子險`），一鍵將它們合併至大分類 `已購保險` 下的標準 `車險` 標籤中。
*   **自動批次更新**：資料庫會自動執行 RPC 函數，將所有關聯這些被合併標籤的客戶，替換為合併後的標準標籤，並刪除舊標籤，保持資料庫乾淨。

---

## 🗄️ 資料庫三層建模設計 (Database Schema)

在 Supabase 中，將原本扁平的標籤設計重構為以下三層結構：

```sql
-- 1. 大分類表 (唯讀)
CREATE TABLE public.tag_categories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

-- 2. 子標籤表
CREATE TABLE public.tags (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    category_id UUID REFERENCES public.tag_categories(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(category_id, name) -- 同一分類下不能有重複標籤名
);

-- 3. 客戶標籤關聯表 (Junction Table)
CREATE TABLE public.customer_tags (
    customer_id UUID REFERENCES public.customers(id) ON DELETE CASCADE NOT NULL,
    tag_id UUID REFERENCES public.tags(id) ON DELETE CASCADE NOT NULL,
    PRIMARY KEY (customer_id, tag_id)
);
```
