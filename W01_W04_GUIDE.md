# W01-W04: FastAPI + PostgreSQL Course Guide

This guide collects the course material for Weeks 1-4: FastAPI project setup, PostgreSQL installation and connection, serving a web app and API from one service, and RESTful CRUD implementation.

> W04 includes SQLAlchemy ORM examples to explain the concept. The current repository implementation uses Psycopg and repository functions, so treat those ORM snippets as instructional examples rather than copy-paste code for the current app.

## Week guide

- [W01: FastAPI project setup and basic API](#week-01)
- [W02: PostgreSQL installation and connection](#week-02)
- [W03: Run FastAPI as Web App and API](#week-03)
- [W04: Complete CRUD API](#week-04)

---

<a id="week-01"></a>

## W01：FastAPI 專案架構與基礎 API

### 學習目標
理解 FastAPI (Python) 的專案結構慣例，以及它跟 (Node.js) Express.js / Spring Boot 這類框架的對應關係。

### 為什麼這樣安排
自學 REST API 設計，不花時間講「什麼是 API」，而是直接建立你之後 12 週都會沿用的專案骨架，這樣後面每週只需要疊加功能。

### 操作步驟

* Install Python Install Manager (Windows Market)

```bash
mkdir api
cd api
py -m venv venv
venv\Scripts\activate      # Windows Powershell, Set-ExecutionPolicy
python -m pip install fastapi "uvicorn[standard]"
```

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\venv\Scripts\Activate.ps1
```

建立專案結構：開始學習與思考自己或團隊習慣的program structures
```
api/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── api/
│   │   └── __init__.py
│   ├── core/
│   │   └── __init__.py
│   └── models/
│       └── __init__.py
├── requirements.txt
└── venv/
```

`app/main.py`：
```python
from fastapi import FastAPI

app = FastAPI(title="My Backend API")

@app.get("/health")
def health_check():
    return {"status": "ok"}
```

啟動：
```bash
uvicorn app.main:app --reload
```

打開 `http://127.0.0.1:8888/docs`，這是 FastAPI 自動產生的 Swagger UI（對應你熟悉的 Swagger/OpenAPI 概念，但這裡完全自動產生，不用手寫 YAML）。

### 本週練習
1. 新增一個 `/version` 端點，回傳 `{"version": "0.1.0"}`
2. 用 Pydantic 定義一個 `Item` 模型（含 `name: str`、`price: float`），寫一個 `POST /items` 接收並回傳它
3. 執行 `pip freeze > requirements.txt`，理解這個檔案對應 Node.js 的 `package.json` 扮演什麼角色
4. AI：為 py + FastAPI + psql 建立 .gitignore
5. Install Git、建立 github repo (預設)，pull，修改後commit and push

```git
# 1. 建立本機第一個 commit
git add .
git commit -m "W1: FastAPI Test"

# 2. 設定 GitHub 遠端 repository
git remote add origin https://github.com/icsie/api.git

# 3. 設定主分支名稱
git branch -M main

# 4. 發現 GitHub 已有 Initial commit，因此先取得遠端歷史
git fetch origin

# 5. 合併本機與 GitHub 的不同歷史
git merge origin/main --allow-unrelated-histories

# 6. 推送到 GitHub
git push -u origin main
```

### 驗收標準
- [ ] `/docs` 能正常開啟並看到自訂端點
- [ ] `POST /items` 能正確驗證型別（試著傳錯誤型別，觀察 FastAPI 自動回傳的 422 錯誤）
- [ ] 了解建立根目錄的 .gitignore，涵蓋：Python 虛擬環境與快取、pytest、coverage、mypy、ruff 產物、.env 設定檔、FastAPI/Uvicorn log、PostgreSQL 本地資料與備份、VS Code、IDE 與作業系統檔案
- [ ] 學會 `.gitignore`：`!` 取消忽略，例如 !.env.example 會保留範例設定檔。
- [ ] add .env.example，並commit and push確認出現自github repo。

### Powershell經驗
- AI：讓 PowerShell 可以執行本機 `.ps1` 腳本，並了解 `RemoteSigned` 的作用；下載的腳本仍需簽章或解除封鎖（考慮資安風險）。

### VSCode心得
- 安裝軟體如Git，會寫入環境變數PATH，要完全結束VSCode (close all opened code windows)，reopen vscode才會在powershell環境生效。

### Git心得
- 本機先有 commit 時，GitHub 建立 repository 最好保持完全空白；不要同時勾選建立 README 或 LICENSE，這樣第一次 `git push -u origin main` 最簡單。

### W1 學習心得

一開始建立 FastAPI 專案時，我才發現寫出 API 程式只是第一步，還要先把資料夾整理好、建立虛擬環境，並確認套件安裝在正確的位置。完成 `/health` 後，我可以用瀏覽器確認服務有沒有正常啟動，也能在 `/docs` 直接看到 API 說明，覺得比自己從頭寫文件方便很多。練習 Git 時，我也學到本機和 GitHub 如果一開始各自有不同檔案，合併時就要多處理一次；所以先想好 repository 要怎麼建立，後面的 push 會比較順。安裝 Git 後，VS Code 也不一定會立刻讀到新的 PATH，重新開啟程式才能載入更新後的環境設定。這週讓我知道，專案骨架、工具設定和版本管理雖然不像 API 功能那麼明顯，卻會影響後面每一步能不能順利進行。

---

<a id="week-02"></a>

## W02：PostgreSQL 安裝與連線

### 學習目標
在本機建立 PostgreSQL，並讓 Python 程式成功連線。

### 為什麼這樣安排
先確保「資料庫本身活著、連得上」，再進到 ORM 抽象層。這樣之後如果連線出錯，你能分辨是資料庫問題還是程式碼問題。

### 操作步驟

**安裝 PostgreSQL（Windows Admin）**
1. 到官方下載頁安裝 PostgreSQL（建議 16 版以上）
2. 安裝時會要求設定 `postgres` 超級使用者密碼，記下來
3. 建議一併安裝 pgAdmin（GUI 管理工具，對應你熟悉的 DBeaver / TablePlus 概念）

**安裝 PostgreSQL（Windows 一般使用者權限，電腦教室用此法安裝）**

若目前帳號只有一般 Windows 使用者權限，建議使用 PostgreSQL ZIP 免安裝版。此方式不建立 Windows Service，也不需要寫入 `Program Files`，可安裝在使用者目錄。

1. 下載與作業系統相容的 PostgreSQL Windows ZIP binary。
2. 將 ZIP 解壓縮至使用者目錄，例如：

```text
C:\Users\<你的帳號>\pgsql
```

3. 建立資料目錄：

```powershell
mkdir "$env:USERPROFILE\pgsql-data"
```

4. 初始化資料庫叢集：

```powershell
cd "$env:USERPROFILE\pgsql"

.\bin\initdb.exe `
  -D "$env:USERPROFILE\pgsql-data" `
  -U postgres `
  -A scram-sha-256 `
  -W
```

執行後依提示設定 `postgres` 使用者密碼。

5. 啟動 PostgreSQL。若 `5432` 已被其他服務使用，可使用 `5433`：

```powershell
.\bin\pg_ctl.exe `
  -D "$env:USERPROFILE\pgsql-data" `
  -o "-p 5433" `
  -l "$env:USERPROFILE\pgsql-data\server.log" `
  start
```

6. 連線測試：

```powershell
.\bin\psql.exe `
  -h localhost `
  -p 5433 `
  -U postgres `
  -d postgres
```

7. 在 `psql` 中建立開發用資料庫與使用者：

```sql
CREATE USER dev_user WITH PASSWORD 'replace-with-a-local-password';
CREATE DATABASE fastapi_dev OWNER dev_user;
\c fastapi_dev
GRANT ALL ON SCHEMA public TO dev_user;
```

檢查是否成功寫入DB：

```sql
SELECT version(); SELECT current_database(), current_user;
```

結束PSQL DB：

```sql
exit
```

8. 修改 `.env`：

```env
DATABASE_URL=postgresql://dev_user:replace-with-a-local-password@localhost:5433/fastapi_dev
```

停止 PostgreSQL：

```powershell
.\bin\pg_ctl.exe `
  -D "$env:USERPROFILE\pgsql-data" `
  stop
```

> ZIP 版本不會自動建立 Windows Service，因此每次使用前需要執行 `pg_ctl start`。若要讓 PostgreSQL 開機自動啟動，通常需要系統管理員協助建立服務。


#### 建立開發用資料庫與使用者
```sql: add file .\psql\createdb.sql
-- 用 psql 或 pgAdmin 執行
CREATE USER dev_user WITH PASSWORD 'replace-with-a-local-password';
CREATE DATABASE fastapi_dev OWNER dev_user;
GRANT ALL PRIVILEGES ON DATABASE fastapi_dev TO dev_user;

\connect fastapi_dev
GRANT USAGE, CREATE ON SCHEMA public TO dev_user; -- public schema建表權限
```

```pwsh: psql 執行
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' `
  -U postgres `
  -d postgres `
  -f .\psql\createdb.sql
```

**Python 端安裝驅動**
```bash
python -m pip install "psycopg[binary]" python-dotenv
```

`.env`（不要進版控，需加入 `.gitignore`）：
```
DATABASE_URL=postgresql://dev_user:replace-with-a-local-password@localhost:5432/fastapi_dev
```

測試連線 `app/core/db_test.py`：
```python
import os
from dotenv import load_dotenv
import psycopg

load_dotenv()

def test_connection():
    conn = psycopg.connect(os.getenv("DATABASE_URL"))
    print("連線成功:", conn.info.dbname)
    conn.close()

if __name__ == "__main__":
    test_connection()
```

```pwsh
python .\app\core\db_test.py
```

連線成功: fastapi_dev

### 本週練習
1. 用 `psql` 指令手動建立一個 `notes` Table（欄位：`id`, `title`, `content`, `created_at`）；用 `INSERT` 手動塞3筆資料，再用 `SELECT` 查回來
2. New REST api: /note/{id}

### 驗收標準
- [ ] Python 程式能成功連上 PostgreSQL
- [ ] 能說明為什麼密碼要放在 `.env` 而不是寫死在程式碼裡（對應你熟悉的環境變數管理概念）
- [ ] Test API and Dataformat (了解Swagger用法，具備測試API能力)

### 心得

安裝 PostgreSQL 並讓 Python 成功連線後，我才比較清楚 API 和資料庫是兩個不同的部分：API 負責接收請求，資料庫負責保存資料，中間還需要正確的連線設定。用 `psql` 查詢和新增資料，讓我能直接確認資料到底有沒有寫進資料庫；VS Code 的 SQLTools 擴充功能也讓我不用一直切換工具就能查看資料。另一個重要觀念是不要什麼事情都用 `postgres` 管理者帳號做，開發時可以建立自己的資料庫帳號，只給它需要的權限。資料庫連線字串則放在 `.env`，避免把密碼直接寫進程式或上傳到 GitHub。這週我也開始理解把路由、資料存取和資料格式分開的好處：程式各自負責一件事，之後要修改時比較容易找到位置。


---

<a id="week-03"></a>

## W03：Run FastAPI as Web App and API

### 學習目標
用FastAPI做為http server，同時服務web app and api。

root
> Add run.bat to run FastAPI with local_IP:7777

app\main.py
> Make FastAPI to be a http server with a folder as the root.
- Set public_directory to your webui
- 仔細測試觀察是否有問題？
> Make all api paths correspond to /api/
- 仔細測試觀察是否有問題？
> `StaticFiles`: restrict public access to .html and .css only.
- 注意Browser HTTP cache問題
> 另開無痕測試就好了，why? 以後如何注意此問題
- F12 > Network > Disable Cache

### 驗收標準
- [ ] local IP可存取
- [ ] 上課與Ta設定 https://demo.wke.csie.ncnu.edu.tw/studentno 可存取
- [ ] 盡量測試，列出問題討論solutions

### 心得

這週把 FastAPI 同時當成網站和 API 的伺服器，讓我看到同一個服務可以依照不同網址提供不同內容：首頁可以回傳網頁，API 路徑則負責資料請求。把 API 統一放在 `/api/` 底下，路徑比較容易辨認，也比較不會和網站頁面混在一起。靜態檔案也不能不加限制地全部公開，所以需要只提供網頁真正會用到的檔案。測試時我注意到瀏覽器可能會保留舊的快取，讓畫面看起來像程式沒有更新；用無痕視窗或開發者工具停用快取，可以幫助我分辨是程式本身有問題，還是瀏覽器仍在使用舊檔案。這讓我學到，測試網站時不能只看畫面，也要留意瀏覽器和伺服器之間實際傳送了什麼。

---

<a id="week-04"></a>

## W04：CRUD API 完整實作

### RESTful API

RESTful API 是一種以「資源（resource）」為中心設計 HTTP API 的方式。每一種資源都有固定的 URL，例如 `/notes` 代表筆記集合，`/notes/{id}` 代表某一筆筆記；用不同的 HTTP method 表達對資源的操作，而不是為每個動作建立不同的動詞型 URL。

CRUD 分別代表 **Create（新增）**、**Read（查詢）**、**Update（更新）**、**Delete（刪除）**。以下以 `notes` 資源為例：

| CRUD | HTTP method | 範例路徑 | 使用時機 | 請求／回應範例 |
|---|---|---|---|---|
| Create | `POST` | `/notes` | 建立一筆新資源，由伺服器產生 `id` | 請求：`{"title": "學習 REST", "content": "理解 CRUD"}`<br>回應：`201 Created` 與建立後的 note |
| Read（列表） | `GET` | `/notes` | 取得資源集合，可搭配分頁、篩選或搜尋 | 回應：`200 OK` 與 notes 陣列 |
| Read（單筆） | `GET` | `/notes/{id}` | 取得指定 `id` 的資源 | 回應：`200 OK` 與單筆 note；不存在時回傳 `404 Not Found` |
| Update | `PUT` | `/notes/{id}` | 以完整資料取代指定資源 | 請求：`{"title": "更新標題", "content": "更新內容"}`<br>回應：`200 OK` 與更新後的 note |
| Delete | `DELETE` | `/notes/{id}` | 刪除指定資源 | 回應：`204 No Content`；不存在時回傳 `404 Not Found` |

設計 API 時，路徑通常使用名詞而不是動詞，例如使用 `POST /notes`，而不是 `/createNote`。同一個 HTTP method 與 URL 應具有一致且可預期的語意，讓前端、其他服務與 API 文件都容易理解與使用。


### 學習目標
串接API與資料庫，完成一組完整 RESTful CRUD。

### 為什麼這樣安排
這是第一個「垂直切片」（vertical slice）——從 HTTP 請求到資料庫的完整路徑打通，之後每一週都是在這個路徑上疊加功能，而不是零散學習。

### AI coding
> 針對/api/note 加入REST CRUD功能 (需對應慣用HTTP Method)
- 仔細觀察修改的程式碼，另開瀏覽器詢問AI以求理解
- 撰寫學習心得

### 人工操作步驟

#### 分層設計理念：routers → schemas → repositories → core

將 API 拆成不同層次，是為了讓每個檔案只負責一種工作，降低修改時彼此影響的範圍。一次請求大致會依照以下流程處理：

1. **Routers（路由層）**：決定 API 的 URL、HTTP method 與回應狀態，接收請求後呼叫下一層，不直接撰寫大量 SQL 或資料庫連線細節。
2. **Schemas（資料格式層）**：使用 Pydantic 定義請求與回應格式，負責型別驗證、欄位限制，以及避免把資料庫內部欄位直接暴露給前端。
3. **Repositories（資料存取層）**：集中處理 SQL 與資料庫 CRUD，讓 Router 不需要知道資料表查詢的細節。
4. **Core（共用基礎設施層）**：提供資料庫連線、設定、驗證或其他全域共用功能；例如 `core/db.py` 管理 PostgreSQL 連線。

因此，實際的責任關係可以理解為：

```text
HTTP request
    → routers/notes.py       路由與流程控制
    → schemas/notes.py        請求資料驗證
    → repositories/notes.py  SQL 與資料存取
    → core/db.py              PostgreSQL 連線
    → HTTP response
```

相關檔案的使用方式如下：

| 元件 | 目前專案檔案 | 主要用途 |
|---|---|---|
| Router | `app/api/notes.py` | 定義 `/api/notes` 等端點，處理 HTTP 請求與回應 |
| Schema | `app/schemas/note.py` | 定義 `NoteCreate`、`NoteResponse` 等輸入輸出模型 |
| Repository | `app/repositories/notes.py` | 封裝 notes 的 SQL 查詢、新增、更新與刪除 |
| Core | `app/core/database.py` | 建立與管理 PostgreSQL 資料庫連線 |
| Application entrypoint | `app/main.py` | 建立 FastAPI app、註冊 Router 與設定整體服務 |

這種分層方式的重點不是檔案越多越好，而是讓變更容易定位：API 路徑改動主要看 Router，資料格式改動看 Schema，SQL 改動看 Repository，資料庫連線設定則集中在 Core。

#### ORM 技術概念

ORM（Object-Relational Mapping，物件關聯式對映）是把 Python 物件與關聯式資料庫的資料表對應起來的技術。開發者可以操作 `Note` 這類 Python model，ORM 再將操作轉換成 PostgreSQL 能理解的 SQL。

簡單對照如下：

| ORM 概念 | Python / SQLAlchemy 範例 | 資料庫概念 |
|---|---|---|
| Model class | `class Note` | `notes` 資料表 |
| Object attribute | `note.title` | `title` 欄位 |
| Object instance | `note = Note(...)` | 一筆資料（row） |
| Query | `db.query(Note).filter(...)` | `SELECT ... WHERE ...` |
| `db.add()` | 將物件加入 Session | 準備新增一筆資料 |
| `db.commit()` | 提交 Session 的變更 | 真正寫入資料庫 |

例如，以下 ORM 查詢：

```python
note = db.query(Note).filter(Note.id == note_id).first()
```

概念上相當於：

```sql
SELECT * FROM notes WHERE id = :note_id LIMIT 1;
```

其中 `db` 通常是 SQLAlchemy 的 `Session`。Session 可以理解成一次資料庫操作的工作範圍，負責追蹤物件變更、送出查詢，以及透過 `commit()` 確認交易。若發生錯誤，也可以使用 `rollback()` 撤銷尚未提交的變更。

使用 ORM 的好處是可以用 Python model 與型別來表達資料操作，減少手寫 SQL 的數量，並集中處理交易與資料庫連線；但仍然需要理解 SQL，因為 ORM 最後仍會產生 SQL，複雜查詢也可能需要直接使用 SQLAlchemy 的查詢語法。

本節為了讓 CRUD 流程集中，先在 Router 中直接示範 ORM 操作。實際專案可將 `db.query()`、`db.add()` 等資料庫操作移到 `app/repositories/notes.py`，讓 Router 只負責接收請求、呼叫 Repository 與回傳結果。

`app/schemas/note.py`（Pydantic schema，區分「API 輸入輸出」與「資料庫 model」是重要慣例）：
```python
# Schema 只描述 API 收到與回傳的資料格式，不負責執行 SQL。
# import 是匯入其他套件或模組，讓目前檔案可以使用其中的類別與函式。
from pydantic import BaseModel
from datetime import datetime
from typing import Optional

# POST /notes 使用的請求格式；content 可省略。
# class 用來定義一個可重複使用的資料結構或物件類別。
class NoteCreate(BaseModel):
    # 冒號後的 str 是型別註記，表示 title 預期是一段文字。
    title: str
    # Optional[str] 表示可以是文字或 None；= None 表示預設值是 None。
    content: Optional[str] = None

# API 回應格式；不直接暴露資料庫 model 給前端。
class NoteResponse(BaseModel):
    # Pydantic 會依照這些型別註記檢查與轉換資料。
    id: int
    title: str
    content: Optional[str]
    created_at: datetime

    # 允許 Pydantic 從 ORM model 的屬性建立回應資料。
    # 內嵌 class Config 是設定這個 Pydantic model 行為的舊版寫法。
    class Config:
        # ORM 物件像 note.title；一般字典則像 {"title": "學習 REST"}。
        # True 允許 Pydantic 讀取 ORM 物件的屬性，轉成 NoteResponse。
        # 若沒有這項設定，通常只能從字典鍵值建立，例如 NoteResponse(**data)。
        from_attributes = True
```

`app/api/notes.py`：
```python
# Router 負責 HTTP 路由與流程控制；資料庫細節可再委派給 repository。
# APIRouter 是 FastAPI 用來集中管理一組相關 API 路由的類別。
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.note import Note
from app.schemas.note import NoteCreate, NoteResponse

# 同一組 notes 資源共用路徑前綴與 OpenAPI 分類。
# 關鍵字參數使用 name=value，讓設定的意義比位置順序更清楚。
router = APIRouter(prefix="/notes", tags=["notes"])

# Create：先由 NoteCreate 驗證請求，再建立資料庫 model。
# @ 是 decorator 語法：把函式註冊成指定 HTTP method 與路徑的 API endpoint。
# response_model 會驗證並限制回傳給前端的欄位格式。
@router.post("/", response_model=NoteResponse)
# note: NoteCreate 是請求 body，db 由 FastAPI 依賴注入，不需手動建立連線。
def create_note(note: NoteCreate, db: Session = Depends(get_db)):
    # ** 會把字典的 key/value 展開成函式或類別建構子的關鍵字參數。
    db_note = Note(**note.model_dump())
    # model_dump() 將 Pydantic model 轉成一般 Python 字典。
    db.add(db_note)
    # add、commit、refresh 是 ORM 常見的新增、提交、重新讀取資料流程。
    db.commit()
    db.refresh(db_note)
    return db_note

# Read：回傳所有 notes，response_model 會統一輸出格式。
# list[NoteResponse] 表示回應是一個由 NoteResponse 組成的列表。
@router.get("/", response_model=list[NoteResponse])
# Depends(get_db) 表示呼叫 endpoint 時，由 FastAPI 執行 get_db 並傳入結果。
def list_notes(db: Session = Depends(get_db)):
    # .all() 將查詢結果全部取回；資料量大時應搭配分頁。
    return db.query(Note).all()

# Read：依照 note_id 查詢單筆資源。
@router.get("/{note_id}", response_model=NoteResponse)
def get_note(note_id: int, db: Session = Depends(get_db)):
    # .filter() 加入查詢條件，== 是建立 SQL 條件，不是立即比較 Python 值。
    note = db.query(Note).filter(Note.id == note_id).first()
    # if not 可檢查查詢結果是否為 None 或其他「沒有資料」的狀態。
    if not note:
        # HTTPException 會讓 FastAPI 回傳指定的 HTTP 錯誤狀態與訊息。
        raise HTTPException(status_code=404, detail="Note not found")
    return note

# Update：以 NoteCreate 的完整資料更新指定資源。
@router.put("/{note_id}", response_model=NoteResponse)
def update_note(note_id: int, note_data: NoteCreate, db: Session = Depends(get_db)):
    note = db.query(Note).filter(Note.id == note_id).first()
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    # for 逐一處理字典內容；key 是欄位名稱，value 是要寫入的新值。
    for key, value in note_data.model_dump().items():
        # setattr(obj, name, value) 依欄位名稱動態設定物件屬性。
        setattr(note, key, value)
    db.commit()
    db.refresh(note)
    return note

# Delete：找不到資源時回傳 404，避免讓呼叫端誤以為刪除成功。
@router.delete("/{note_id}")
def delete_note(note_id: int, db: Session = Depends(get_db)):
    note = db.query(Note).filter(Note.id == note_id).first()
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    # delete 標記 ORM 物件待刪除，commit 後才會真正寫入資料庫。
    db.delete(note)
    db.commit()
    # return 的字典會被 FastAPI 自動序列化成 JSON 回應。
    return {"detail": "deleted"}
```

在 `app/main.py` 註冊路由：
```python
from app.api import notes
app.include_router(notes.router)
```

### 本週練習
1. 為 `members` 或個人專案會用到的資料表，也做一組完整 CRUD
2. 思考並實作：`DELETE` 時如果 note 不存在，回傳的狀態碼與錯誤訊息是否符合 REST 慣例
3. 用 `/docs` 的 Swagger UI 手動測試所有端點

### 驗收標準
- [ ] 五個 CRUD 端點全部正常運作
- [ ] 錯誤情境（找不到資源）回傳正確的 HTTP 狀態碼

### 學習心得

完成 Notes 的 CRUD 後，我對 API 的操作方式比較有概念了：`POST` 用來新增、`GET` 用來查詢、`PUT` 用來更新、`DELETE` 用來刪除。比起只看程式碼，我用 `/docs` 實際送出請求後，更容易看懂資料如何從 API 傳到資料庫，再回到畫面。錯誤情況也很重要，例如查詢或刪除不存在的筆記時，回傳 `404` 才能讓使用 API 的人知道資料沒有找到，而不是誤以為操作成功。程式分成 Router、Schema、Repository 和資料庫連線幾個部分後，雖然檔案變多了，但每一層的工作比較清楚，修改 API 格式或資料庫查詢時也比較不容易全部混在一起。教材中的 SQLAlchemy 範例讓我認識 ORM 的概念；實際專案目前使用 Psycopg 和 Repository 函式，兩種寫法需要分清楚，不能直接把範例當成現有程式碼照抄。

---
