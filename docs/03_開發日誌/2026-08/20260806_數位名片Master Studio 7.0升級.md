# 📅 [2026-08-06] - 【模組五：系統個性化】數位名片 Master Studio 7.0 全面升級

> **執行狀態**：🟢 已併入主線 (src)

## 🎯 實作成果摘要

將 `profile_screen.dart` 的 3D 數位名片從視覺展示框架升級至具備完整互動體驗的 Master Studio 7.0：統一名片字體大小（14px 清晰標準）、完整標籤 CRUD 管理（證照/頭銜均可新增刪除）、支援「不顯示頭銜」選項、7 色自訂色盤選色器、以及廢除舊版光錐改為參考 todo-tcg 實作之「游移閃卡光斑 (Foil Shimmer Spotlight)」三段式切換模式。

---

## 💻 技術變更明細 (Actual Technical Changes)

- **[MODIFY] `lib/screens/profile_screen.dart`**：
  - **字體大小統一放大 (Unified & Enlarged Fonts)**：
    - 頭銜標籤 (Honor Title) chip：`10px → 12px` (w900)
    - 職稱 (Job Title)：`12px → 14px` (bold)
    - 專業證照徽章 (Badges)：`10px → 12px` (bold)
    - 按鈕 Hub (撥打/加LINE/Email)：`10px → 12px` (bold)
    - 聯絡資訊列：`11px → 13px` (w500)
  - **Section 2 「專業證照」獨立新增按鈕**：新增 `_customBadgeController` + `TextField` + `[ ＋ 新增證照 ]` 按鈕，與 Section 1 (榮譽頭銜) 結構完全對稱。
  - **「🚫 不顯示頭銜 (空白)」選項**：在 Honor Title `Wrap` 最前置放 `ChoiceChip`，選中後 `_honorTitle = ''`，名片右上角的標籤 Container 以 `if (_honorTitle.isNotEmpty)` 條件完全隱藏。
  - **7 色自訂色盤 (`_buildColorSwatch`)**：在主題選單新增 `🎨 自訂自由色盤` 按鈕，點選後展開紫羅蘭/玫瑰粉紅/皇家寶藍/活力珊瑚橘/極光靛青/高雅石墨灰/湖水碧綠等 7 大色票。
  - **3D 光澤模式三段式切換 (`_glareMode`)**：
    - 廢除舊版 `RadialGradient` 光錐。
    - 新增 `String _glareMode = 'none'` 狀態變數，預設「🚫 無光澤 (純淨質感)」。
    - `'tcg_rainbow'`：改用 **RadialGradient Spotlight** 以 `(_glareX * 2.0 - 1.0, _glareY * 2.0 - 1.0)` 為中心，半徑 1.1，由 `0x66FFFFFF → 0x55FF0055 → 0x5500E5FF → 0x55FFD700 → 0x4400FF66 → 透明` 擴散，精確跟隨滑鼠游移位置。
    - `'metallic_tint'`：`RadialGradient` 以相同游移座標為中心，`Colors.white.withOpacity(0.6) → cardAccentColor.withOpacity(0.25) → 透明`，與名片主色連動。
    ```dart
    if (_glareMode == 'tcg_rainbow')
      Positioned.fill(
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(_glareX * 2.0 - 1.0, _glareY * 2.0 - 1.0),
                radius: 1.1,
                colors: const [
                  Color(0x66FFFFFF), Color(0x55FF0055), Color(0x5500E5FF),
                  Color(0x55FFD700), Color(0x4400FF66), Color(0x00000000),
                ],
              ),
            ),
          ),
        ),
      )
    ```
  - **WCAG AAA 全 Chip 高對比抗吃字修正**：所有 `ChoiceChip` / `InputChip` 選中時，以 `color.computeLuminance() > 0.45` 動態切換 `activeFontColor` 為 `#0F172A` 深藍黑字或 `Colors.white`，`checkmarkColor` 同步套用，`FontWeight.w900`，徹底消除吃字問題。

---

## ⚠️ 環境異動與破壞性變更

- **無**：本次為純 UI/UX 迭代，無 pubspec.yaml / DB Schema / .env 異動。

---

## 🚦 團隊協作與驗證指南

- **工程師驗飾**：
  ```bash
  flutter build web --release
  npx -y http-server build/web -p 8080
  ```
  於 `http://localhost:8080` → 「個人帳號」 → 測試頭銜不顯示、色盤選色、三段光澤模式切換。

- **PM/夥伴預覽**：前往 Vercel 部署版本，點選「個人帳號」頁面即可直接體驗。

---

## 📋 今日未完成事項 (請同步至 Discord)

> 以下為今日計劃內但本次 session 尚未完成的項目，建議下次 session 優先跟進：

1. **🟡 QR Code 上傳顯示與回退邏輯驗證**：已實作 `_pickQrCodeImage` 但尚未在瀏覽器端測試 QR Code 上傳後在名片背面是否正確渲染與 fallback 至 LINE ID 文字。

2. **🟡 3D 閃卡光斑在實機效果確認**：`tcg_rainbow` 目前使用 `RadialGradient` Spotlight 方式，但實際滑鼠追蹤流暢度與光澤強度尚待用戶在瀏覽器實機中確認是否達到 todo-tcg 參考效果。若不滿意可進一步調整 `radius`、透明度梯度與色彩組合。

3. **🟡 名片背面 (Card Back) 資訊欄位完整性審查**：名片正面已完成字體統一升級，但名片背面各資訊列（QR Code 區塊、掃一掃文字、聯絡資訊）的字體大小尚未對齊正面統一標準。

4. **🟡 HD 名片下載 (RepaintBoundary PNG Export) 功能測試**：已實作下載按鈕，但尚未在最新版本(7.0 重構後)確認下載的 PNG 圖檔是否正確輸出與渲染。
