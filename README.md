# Week 5: FastAPI + PostgreSQL 關聯式資料

這是一個使用 FastAPI 建立的後端 API 練習專案。

本專案從 W4 的 RESTful Notes API 延伸，使用 PostgreSQL 實作分類的一對多關係，以及筆記與標籤的多對多關係。

## 使用技術

- Python 3.14
- FastAPI
- Uvicorn
- Pydantic
- PostgreSQL
- Psycopg
- HTML/CSS
- Git
- GitHub

## 專案結構

```text
api/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── api/
│   │   ├── auth.py
│   │   ├── classes.py
│   │   ├── notes.py
│   │   └── taxonomy.py
│   ├── core/
│   │   ├── database.py
│   │   ├── db_test.py
│   │   └── security.py
│   ├── repositories/
│   │   ├── classes.py
│   │   ├── members.py
│   │   ├── notes.py
│   │   └── taxonomy.py
│   └── schemas/
│       ├── classes.py
│       ├── member.py
│       ├── note.py
│       └── taxonomy.py
├── public/
│   ├── index.html
│   ├── styles.css
│   ├── app.js
│   └── json/
│       ├── teacher_ops.json
│       └── dashboard_cards.json
├── psql/
│   ├── createdb.sql
│   ├── academic.sql
│   ├── w06_auth.sql
│   └── w05_relations.sql
├── run.bat
├── .env.example
├── .gitignore
├── README.md
├── requirements.txt
└── venv/
```

## 安裝與執行

### 1. 下載專案

```powershell
git clone https://github.com/s114213515-jessy/Week1.API.git
cd Week1.API
```

### 2. 建立虛擬環境

```powershell
py -m venv venv
```

### 3. 啟動虛擬環境

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\venv\Scripts\Activate.ps1
```

成功後，PowerShell 前面應該會出現：

```text
(venv)
```

### 4. 安裝套件

```powershell
python -m pip install -r requirements.txt
```

### 5. 啟動 FastAPI

使用預設設定啟動：

```powershell
.\run.bat
```

如需讓課程網路上的 IIS 反向代理連入，才依老師指示指定 host 與 port：

```powershell
.\run.bat 192.168.1.10 7777
```

本機直接測試時可使用 loopback 位址：

```powershell
uvicorn app.main:app --host 127.0.0.1 --port 7777 --reload
```

### 6. 開啟 Web App 與 API 文件

瀏覽器開啟：

```text
http://127.0.0.1:7777/
http://127.0.0.1:7777/docs
```

API 路由統一使用 `/api/` 前綴。網站只提供靜態檔案白名單中的首頁、CSS、JavaScript
和範例 JSON；其他靜態路徑會回傳 404。

### 7. 設定 PostgreSQL

先複製 `.env.example` 為 `.env`，再依本機 PostgreSQL 的帳號、密碼和連接埠修改
`DATABASE_URL`。使用 `psql` 執行 `psql/createdb.sql` 建立開發資料庫、
`dev_user` 和 W4 的 `notes` table。接著執行 W5 的 Notes 關聯結構與學術分類 view：

```powershell
psql -h localhost -U postgres -d fastapi_dev -f psql/w05_relations.sql
psql -h localhost -U postgres -d postgres -f psql/academic.sql
psql -h localhost -U postgres -d fastapi_dev -f psql/w06_auth.sql
```

此 migration 可重複執行；它會建立 `categories`、`tags`、`note_tags`，並為既有 `notes`
新增可為空的 `category_id`。`academic.sql` 則會在需要時建立 `fastapi_dev` 資料庫，
安裝 `class`、`inheritance`、`object`、`co`、`insertclass` function 與 `vd_subclass` view。
執行後，重新啟動 FastAPI。

確認 Python 可以連線：

```powershell
python -m app.core.db_test
```

## API 端點

| 方法 | 路徑 | 說明 |
|---|---|---|
| GET | `/api/health` | 檢查 API 是否正常 |
| GET | `/api/version` | 查看 API 版本 |
| POST | `/api/items` | 建立一個商品 |
| POST | `/api/notes` | 建立筆記 |
| GET | `/api/notes` | 列出所有筆記 |
| GET | `/api/notes/{id}` | 取得單筆筆記 |
| PUT | `/api/notes/{id}` | 完整更新筆記 |
| DELETE | `/api/notes/{id}` | 刪除筆記 |
| GET | `/api/categories` | 列出分類 |
| POST | `/api/categories` | 建立分類 |
| GET | `/api/tags` | 列出標籤與使用筆記數 |
| POST | `/api/tags` | 建立標籤 |
| POST | `/api/classes` | 透過 PostgreSQL function 建立或連結子分類 |
| GET | `/api/subclass/pcid/{parent_id}` | 透過 `vd_subclass` view 查詢子分類 |
| GET | `/api/auth/google/login` | 開始 Google OIDC 登入 |
| GET | `/api/auth/google/callback` | 完成登入並簽發 HttpOnly JWT cookie |
| GET | `/api/auth/me` | 取得目前登入的會員資料 |
| POST | `/api/auth/logout` | 清除登入 cookie |
| GET | `/api/note/{id}` | 舊版單筆查詢相容路徑 |

W6 Google OIDC、JWT、會員資料表和安全設定步驟見 [`OAUTH.md`](OAUTH.md)。執行
`psql/w06_auth.sql` 後，將 `.env.example` 複製為 `.env` 並填入自己的 Google OAuth
憑證與兩組不同的隨機 secret。Google 登入需要在 Google Cloud Console 設定精確一致的
redirect URI；不要將真實憑證提交到 GitHub。Notes 與 class/subclass API 需要有效登入。

## W5：關聯式設計

```text
categories 1 ─────< notes
                      >─────< tags
                         note_tags
```

- 一個分類可以有多篇筆記；每篇筆記最多屬於一個分類。`notes.category_id` 是 nullable foreign key。
- 一篇筆記可以有多個標籤，一個標籤也可以標記多篇筆記。`note_tags` 是關聯表，以 `(note_id, tag_id)` 複合主鍵避免重複關聯。
- 刪除分類時，所屬筆記保留但 `category_id` 變成 `NULL`；刪除筆記或標籤時，其 `note_tags` 關聯會由 foreign key cascade 清理。
- 完整教學、migration 與驗收步驟見 [`W05_RELATIONAL_DESIGN.md`](W05_RELATIONAL_DESIGN.md)。
- PostgreSQL 學術分類 function、view 與 API 練習見 [`W05_POSTGRES_VIEW.md`](W05_POSTGRES_VIEW.md)。
- 本專案首頁也包含 Web Programming W5 的 DOM 互動範例，見下方「W5 Web：JavaScript DOM」。

## W7–W8：EER、Schema 與 View

循序練習本專案的分類階層資料模型、PostgreSQL Schema 與 `vd_subclass` View，包含 SQL 驗證、最小權限及 FastAPI 端到端測試，見 [`W07_W08_EER_SCHEMA.md`](W07_W08_EER_SCHEMA.md)。

## W5 Web：JavaScript DOM 與事件

首頁讀取 `public/json/teacher_ops.json` 與 `public/json/dashboard_cards.json`，示範側邊欄
開關、Escape 關閉、導覽預覽、卡片選取、卡片說明展開、帳戶選單、深色模式與提示文字更新。
在瀏覽器開啟 `http://127.0.0.1:7777/` 測試，並從首頁進入 `/w05.html` 閱讀 W5 教材與
操作互動示範。Event → Function → DOM 對照、驗收步驟及 Code Review 檢查表見
[`W05_WEB_DOM.md`](W05_WEB_DOM.md)。

建立筆記時可同時設定分類與多個標籤：

```http
POST /api/notes
Content-Type: application/json
```

```json
{
  "title": "整理資料庫筆記",
  "content": "比較一對多與多對多",
  "category_id": 1,
  "tag_ids": [1, 2]
}
```

回應包含關聯物件：

```json
{
  "id": 1,
  "title": "整理資料庫筆記",
  "content": "比較一對多與多對多",
  "created_at": "2026-10-06T07:00:00Z",
  "category": { "id": 1, "name": "課程" },
  "tags": [
    { "id": 1, "name": "PostgreSQL" },
    { "id": 2, "name": "W5" }
  ]
}
```

`PUT /api/notes/{id}` 仍是完整取代更新：未提供 `category_id` 會清除分類，未提供 `tag_ids`
會清除標籤。列出筆記可用 `GET /api/notes?category_id=1&tag_id=2` 篩選。
不存在的分類或標籤回傳 404；重複分類/標籤名稱回傳 409；重複的 `tag_ids` 回傳 422。

## W5 測試

執行不需要 PostgreSQL 的 schema 驗證測試：

```powershell
python -m unittest discover -s tests -v
```

關聯查詢與 CRUD 的端對端驗收需先啟動 PostgreSQL、執行 migration 並設定 `.env`，
再透過 `/docs` 操作。

## API 測試

### GET /health

```text
http://127.0.0.1:7777/api/health
```

回應：

```json
{
  "status": "ok"
}
```

### GET /version

```text
http://127.0.0.1:7777/api/version
```

回應：

```json
{
  "version": "0.1.0"
}
```

### POST /items

請求內容：

```json
{
  "name": "keyboard",
  "price": 1200.5
}
```

回應：

```json
{
  "name": "keyboard",
  "price": 1200.5
}
```

### Notes CRUD

建立筆記：

```http
POST /api/notes
Content-Type: application/json
```

```json
{
  "title": "學習 REST",
  "content": "理解 CRUD"
}
```

建立成功回傳 HTTP 201 與新筆記。列表使用 `GET /api/notes`；查詢單筆使用
`GET /api/notes/1`。完整更新使用 `PUT /api/notes/1`，並傳入包含 `title` 和
`content` 的完整 JSON body。刪除使用 `DELETE /api/notes/1`，成功回傳 HTTP 204。
查詢、更新或刪除不存在的筆記會回傳 HTTP 404。

API 文件：

```text
http://127.0.0.1:7777/docs
```

## 環境變數

目前 PostgreSQL 設定範例放在：

```text
.env.example
```

真正的 `.env` 不應該上傳到 GitHub，因為裡面可能包含密碼。

## GitHub

GitHub Repository：

https://github.com/s114213515-jessy/Week1.API