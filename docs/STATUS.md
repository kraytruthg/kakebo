# Kakebo 系統開發狀態

最後更新：2026-03-01

## 已完成

- 認證：登入 / 登出 / 註冊（REGISTRATION_OPEN 開關）
- 帳戶管理：新增 / 編輯（預算帳戶 / 追蹤帳戶）
- 預算分配：BudgetEntry 編輯、Ready to Assign、複製上月
- 月份切換：URL 參數 ?year=&month=，邊界保護
- 自動結轉：首次瀏覽某月自動從上月 available 建立 carried_over
- 交易記錄：從帳戶頁新增 / 刪除 / 編輯
- 類別管理：CategoryGroup / Category CRUD，刪除保護
- Onboarding：新用戶首次登入引導建立第一個帳戶

## 進行中

- 類別交易明細頁：從預算頁進入某類別的跨帳戶月份交易列表（feature/category-transactions）

## 待開發

-（尚無）

## 維護說明

完成功能開發或重要修正後，AI Agent 提議更新此文件，由開發者確認後 commit。
