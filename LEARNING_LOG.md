# Learning Log

> 每週心得獨立於程式碼提交。請補上自己的觀察，不要在公開 repo 放個資、密碼或真實教務資料。

## W5 — 關聯式資料設計

### 本週完成
- 在 Notes API 加入分類與標籤。
- `categories` 對 `notes` 使用一對多外鍵。
- `notes` 對 `tags` 使用 `note_tags` 關聯表表示多對多。
- 筆記 API 回傳關聯物件，並支援依分類或標籤篩選。

### 我自己的心得

這週把分類和標籤加進 Notes API 後，我發現一對多和多對多不是只有畫在關係圖上的差別，也會影響資料要怎麼存。分類和筆記是一對多，所以把 `category_id` 放在 `notes`；筆記和標籤是多對多，則需要 `note_tags` 把兩邊的 ID 配起來。同一篇筆記可以有好幾個標籤，同一個標籤也能給不同筆記使用，關聯表的複合主鍵還能避免同一組關係重複出現。我也注意到分類刪除時不一定要把筆記一起刪掉，使用 `ON DELETE SET NULL` 可以保留筆記，只把分類關聯清掉。這樣的設計比較能保護原本的內容；以後如果資料有重要的從屬關係，我會先想清楚刪除一邊時另一邊應該怎麼處理。

## W5 PostgreSQL — View 與 Function

### 本週完成
- 建立 `class`、`inheritance`、`object`、`co` 資料表與外鍵關係。
- 使用 `insertclass` function 在同一交易中新增分類並更新階層路徑。
- 建立 `vd_subclass` view，並由 FastAPI 提供查詢與新增分類 API。
- 對 API 資料庫帳號授予 view 的唯讀權限及 function 執行權限。

### 我自己的心得

這週我學到，資料表主要保存資料，View 則是把常用的查詢整理成一個可以重複使用的入口；讀取 View 時看到的是查詢結果，不是另外複製一份資料。專案用 `vd_subclass` 整理父分類和子分類，API 就不必在每個地方重寫相同的 JOIN。新增分類時，`insertclass` 會一起檢查父分類、建立關係並更新路徑；把這些步驟放在資料庫 function 和同一個交易裡，比較能避免只完成一半的狀況。我也理解到，API 帳號不一定需要直接修改所有資料表，只開放讀取 View 和執行指定 function，就能完成需要的功能，也比較不會因為程式出錯而改到不相關的資料。這讓我開始把權限也當成資料庫設計的一部分，而不只是「讓程式連得上」就好。

## W5 Web — JavaScript DOM 與事件處理

### 本週完成
- 導覽選單、卡片與說明由前端 JSON 範例資料 render。
- 加入側欄開關與 Escape 關閉、導覽 hover/focus 預覽、卡片選取及 detail panel。
- 加入帳戶選單、深色模式和提示文字更新等 Event → Function → DOM 練習。
- FastAPI 只公開首頁所需的靜態檔案白名單。

### 我自己的心得

這週做前端互動時，我比較能把畫面上的操作拆成「使用者做了什麼、哪個 function 接到事件、畫面哪裡改變」。例如按下側邊欄按鈕後，程式會切換側欄和遮罩的狀態，也會更新按鈕的 `aria-expanded`；卡片則可以用滑鼠點選，也能用鍵盤的 Enter 或 Space 操作。以前我可能只注意畫面有沒有變，現在也會留意按鈕狀態和 DOM 是否一起更新，讓鍵盤操作的人也能知道目前狀態。瀏覽器開發者工具的 Network 面板可以確認 JavaScript 和 JSON 是否成功載入；如果資料載入失敗，頁面應該顯示錯誤而不是假裝一切正常。這讓我知道前端互動不只是加動畫或按鈕，還要讓操作方式清楚、載入狀況看得見。

## W6 — Google OIDC 與 App JWT

### 本週完成
- 以 Google OIDC 驗證帳號，第一次登入新增會員，再次登入更新 profile。
- 使用本系統簽發的短效 JWT，透過 HttpOnly cookie 或 Bearer token 傳送。
- 以會員資料庫狀態保護 Notes 與 class/subclass API。
- 前端可登入、顯示 profile，並呼叫登出 API 清除 cookie。

### 我自己的心得

這週做登入功能後，我比較能分清楚 Authentication 和 Authorization：前者是確認「使用者是誰」，後者是決定「這個使用者可以做什麼」。Google OIDC 負責確認 Google 帳號身分，系統再用穩定的 Google `sub` 找到或建立自己的會員，並簽發本系統使用的短效 JWT。受保護的 API 不只檢查 token，也會確認會員仍存在且帳號啟用，所以停用會員後，舊 token 也不應繼續取得資料。JWT 放在 HttpOnly cookie 時，前端 JavaScript 不能直接讀取它，降低被腳本偷走的風險；但瀏覽器會自動附上 cookie，因此正式環境仍要使用 HTTPS，並了解 SameSite 和 CSRF 防護。這週讓我明白，登入成功不代表所有 API 都可以任意使用，身分確認、權限檢查和安全保存 token 是不同但都重要的步驟。

## W7 — EER 分類模型與虛構資料

### 本週完成
- 用 `class` 和 `inheritance` 表示分類節點及父子關係。
- 用 `object` 和 `co` 表示一般物件及物件與分類的關聯。
- 使用 `insertclass` 建立分類，並透過 `vd_subclass` 查詢直接的父子關係。
- 用虛構資料練習主鍵、外鍵、複合主鍵和資料庫限制。

### 我自己的心得

這週我用分類目錄來理解 EER：`class` 保存分類節點，`inheritance` 保存哪個分類是另一個分類的父節點，`object` 保存一般內容，而 `co` 把內容連到分類。看到四張表一起合作後，我比較能理解為什麼關係本身也需要一張表保存；例如同一個物件可以放在不同分類，而同一個分類也能有很多物件。我也學到本專案的 `inheritance` 代表分類的父子關係，不是學生或教師那種資料表繼承，名稱相似不代表意思相同。主鍵和外鍵可以防止重複關係或指向不存在的資料，但它們不會自動檢查所有規則，例如分類是否形成循環、路徑欄位是否一直和關係一致。這讓我知道畫好資料模型後，還要確認資料庫真正設定了哪些限制，以及哪些規則仍需要程式或 function 處理。

## W8 — PostgreSQL Schema、View 與資料重用

### 本週完成
- 分辨 Database、Schema、Table 和 View 的用途。
- 使用 `public.vd_subclass` 重用父分類與子分類的查詢。
- 從 FastAPI endpoint 追蹤到 repository，再看到 PostgreSQL View 回傳資料。
- 認識 Schema `USAGE`、View `SELECT` 和 Function `EXECUTE` 是不同權限。

### 我自己的心得

這週我學到 Database 和 Schema 不是同一層：連線時先選擇 Database，Schema 則是在 Database 裡整理資料表、View 和其他物件的命名空間。查詢時寫出 `public.class` 這種完整名稱，比只寫 `class` 清楚，因為省略 Schema 時 PostgreSQL 會依 `search_path` 尋找，可能找到不同位置的同名物件。專案裡的 `vd_subclass` 把分類父子關係整理成固定欄位，API repository 用它查詢時，就能重用相同的結果格式，不需要每個 endpoint 都重新拼 JOIN。我也從 API 一路看到 SQL 查詢，了解使用參數傳入 ID 和直接把輸入拼進 SQL 不一樣。權限方面，能使用 Schema 不等於能讀取裡面的資料；API 帳號應只拿到實際需要的 View、欄位或 Function 權限。這讓我理解，資料重用和最小權限可以一起設計，讓 API 比較簡單，也減少不必要的資料存取。
