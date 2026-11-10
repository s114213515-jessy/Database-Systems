# W10：錯誤處理、Logging 與 Middleware

本週從 Uvicorn 已經顯示的 HTTP access log 開始，練習讓 FastAPI 回傳一致的錯誤格式，並為每個請求加上 Request ID、狀態碼與處理時間。接著再把必要的紀錄存進 PostgreSQL。

> 這份文件是 W10 教材，不代表目前 API 已經完成下方所有功能。先依步驟觀察與驗收，再把程式整合進 `app/main.py`。不要直接覆蓋現有登入、Cookie 或路由設定。

## 完成本週後

- 能分辨 Middleware、Exception Handler 和一般 Logging 各自負責什麼。
- 能用 Request ID 串起一次請求的回應與伺服器紀錄。
- 能讓 HTTP 錯誤、輸入驗證錯誤和未預期錯誤使用一致且安全的 JSON 格式。
- 能在 PostgreSQL 建立 Session 與 API Log 資料表，並用查詢檢查紀錄。
- 能說明 BackgroundTasks 的限制，以及為什麼不能把它當成可靠的工作佇列。

## 先了解目前專案

目前專案已使用 FastAPI、Psycopg 3、`.env` 中的 `DATABASE_URL`，並以 `SessionMiddleware` 支援登入流程；一般資料庫操作是同步的。W10 開始時先保留既有 API 行為，不要一次把同步資料庫存取全部改成非同步，也不要把 OAuth state cookie 當成 API 工作階段 ID。

開始修改前：

1. 確認目前 Git working tree 沒有其他尚未提交的修改。
2. 讀 `app/main.py`、`app/core/database.py`、`app/api/auth.py` 和 `run.bat`。
3. 啟動服務，記下目前正常請求、404 和登入流程的行為，作為修改前基準。
4. 確認 `.env` 和任何憑證都不會被加入 Git。

## 1. 觀察 Uvicorn access log

啟動專案後，Uvicorn 會在終端機顯示類似：

```text
INFO:     127.0.0.1:53120 - "GET /api/health HTTP/1.1" 200 OK
INFO:     127.0.0.1:53120 - "GET /missing HTTP/1.1" 404 Not Found
```

這些訊息可以看出 HTTP method、path 和 status code，但每筆紀錄沒有應用程式自己的 Request ID，也沒有清楚的錯誤分類與執行時間。W10 會在這些基本資訊上增加可追蹤、可查詢的紀錄。

## 2. 分清楚三個角色

| 元件 | 白話說明 | 本週工作 |
|---|---|---|
| Middleware | 每個 HTTP 請求都會經過的檢查站 | 建立 Request ID、計時、收集 status |
| Exception Handler | 發生特定錯誤時決定如何回覆 | 把錯誤轉成一致、安全的 JSON |
| Logger | 把事件寫到終端或其他紀錄系統 | 協助開發者追查原因 |

一次請求的大致流程：

```text
Browser
  → Middleware：建立 Request ID、開始計時
  → Endpoint：執行功能
  → Exception Handler：必要時產生統一錯誤回應
  → Middleware：取得 status、計算時間
  → Response：回傳 X-Request-ID
  → Logging：記錄必要欄位
```

**Request ID 和 Session ID 不一樣：**

- `request_id` 識別單一次 HTTP 請求，每個請求都不同。
- `session_id` 識別一段使用者工作階段，可能對應多次請求。
- 尚未完成經驗證的應用程式 Session 前，`session_id` 應為 `NULL`；不要信任使用者自行傳入的 ID。

## 3. 建立 PostgreSQL Log 結構

先確認 `.env` 的 `DATABASE_URL` 指向開發資料庫，再以 PostgreSQL 管理者執行：

```powershell
psql -h localhost -U postgres -d fastapi_dev -f psql/w10_logging.sql
```

腳本可重複執行，不會刪除現有資料。資料表都明確放在 `public` Schema：

```text
public.api_sessions  1 ───── N  public.api_logs
```

`api_sessions` 保存 Session 的起訖時間；`api_logs` 每個 HTTP 請求保存一筆必要紀錄。匿名請求或尚未整合 Session 的請求，`session_id` 可以是 `NULL`。

建立後用管理者帳號確認：

```sql
\d public.api_sessions
\d public.api_logs
\di public.idx_api_logs_*
```

再用應用程式帳號確認被授予的權限恰好符合需求。應用程式不需要管理整個 Database，也不應為了排除權限錯誤就直接授予所有資料表完整權限。

## 4. 統一錯誤回應

API 錯誤可以使用一致的外層格式，讓前端不必為每種錯誤猜不同欄位：

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "請求參數驗證失敗"
  },
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

常見狀況：

| HTTP Status | Error Code 範例 | 用途 |
|---|---|---|
| 400 | `BAD_REQUEST` | 請求內容不合法 |
| 401 | `UNAUTHORIZED` | 尚未登入或憑證無效 |
| 403 | `FORBIDDEN` | 已登入但權限不足 |
| 404 | `NOT_FOUND` | 找不到指定資源 |
| 422 | `VALIDATION_ERROR` | FastAPI/Pydantic 輸入驗證失敗 |
| 500 | `INTERNAL_ERROR` | 未預期的伺服器錯誤 |

### 安全原則

- 500 回應只提供一般訊息，不回傳 traceback、SQL、檔案路徑或連線字串。
- Validation error 可以回傳安全的欄位錯誤，但不要把整個 Request Body 原封不動記錄下來。
- 保留既有 API 使用者依賴的 status code 和必要錯誤訊息；重構前先記錄基準行為。
- 每個錯誤回應都應帶上同一個請求的 `request_id`，方便使用者回報問題。

### Handler 範例

以下是概念範例。整合前要確認專案既有的 HTTPException 行為，避免無意改變公開 API。`exc.detail` 只有在內容確定是可公開訊息時才可回傳；內部錯誤應改成一般化訊息。

```python
from fastapi import Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException


def error_response(
    request: Request,
    status_code: int,
    code: str,
    message: str,
) -> JSONResponse:
    request_id = getattr(request.state, "request_id", None)
    return JSONResponse(
        status_code=status_code,
        content={
            "success": False,
            "error": {"code": code, "message": message},
            "request_id": str(request_id) if request_id is not None else None,
        },
    )


@app.exception_handler(StarletteHTTPException)
async def handle_http_error(request: Request, exc: StarletteHTTPException):
    code = "NOT_FOUND" if exc.status_code == 404 else f"HTTP_{exc.status_code}"
    return error_response(request, exc.status_code, code, str(exc.detail))


@app.exception_handler(RequestValidationError)
async def handle_validation_error(
    request: Request,
    exc: RequestValidationError,
):
    return error_response(
        request,
        422,
        "VALIDATION_ERROR",
        "請求參數驗證失敗",
    )
```

對未預期的例外要記錄 traceback 到伺服器 Logger，但只回傳一般化的 500 訊息。Middleware 和 Exception Handler 的責任要先規劃清楚，避免同一個例外被記錄兩次。

## 5. Middleware：Request ID 與執行時間

Middleware 會經過每個 HTTP 請求，可在開始時設定 `request.state.request_id`，結束時將它放入 `X-Request-ID` response header。計時建議使用 `time.perf_counter()`，它適合量測一段程式的經過時間。

概念流程：

```python
request.state.request_id = uuid.uuid4()
start = time.perf_counter()
response = await call_next(request)
duration_ms = (time.perf_counter() - start) * 1000
response.headers["X-Request-ID"] = str(request.state.request_id)
```

這只是流程示意，不是完整 middleware。真正實作時要一起處理：

- `HTTPException`、驗證錯誤與未預期例外的 status。
- 如何避免 Middleware 和 Exception Handler 重複記錄同一錯誤。
- 既有 `response.background` 工作不能被新背景工作覆蓋。
- `/docs`、靜態檔案和健康檢查是否都要寫入資料庫 Log。
- `path` 不要直接保存可能包含敏感資訊的 query string。

Request ID 應由伺服器產生。若未來接受代理傳入的 request ID，必須明確驗證格式和信任的代理來源，不能直接把任意 Header 當成可信資料。

## 6. 將必要欄位寫入 PostgreSQL

Log 建議只包含實際需要的欄位：

- `request_id`、`session_id`
- `method`、`path`、`status_code`
- `duration_ms`、`level`、`error_code`
- 必要且已過濾的 `message`、`details`
- 如有正當用途，再保存 IP

所有 SQL 都要使用 Psycopg 參數化查詢，不要把使用者輸入用 f-string 拼進 SQL：

```python
await cursor.execute(
    """
    INSERT INTO public.api_logs (
        session_id, request_id, level, method, path,
        status_code, duration_ms, error_code, message
    )
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
    """,
    (
        data["session_id"],
        data["request_id"],
        data["level"],
        data["method"],
        data["path"],
        data["status_code"],
        data["duration_ms"],
        data["error_code"],
        data["message"],
    ),
)
```

`async def` 只表示函式可以在等待非同步 I/O 時讓出控制權，不代表程式會自動平行執行。Psycopg `AsyncConnection`、Windows event loop、Uvicorn 啟動方式和連線池必須一起驗證；不要只改成 `async def` 就假設資料庫操作已經非同步。

## 7. BackgroundTasks 的適用範圍

FastAPI `BackgroundTasks` 可以在回應送出後執行非關鍵工作，適合教學或允許少量遺失的診斷紀錄。但它仍在同一個應用程式 Process 中執行：

- 程式或主機在工作執行前停止，Log 可能遺失。
- 它不是持久化 Queue，也不會自動提供可靠 Retry。
- 背景任務寫入失敗時，應以一般 Logger 記錄失敗原因，不可假裝資料已成功保存。
- 掛到 `response.background` 時要保留既有背景任務。

若紀錄屬於稽核、付款或其他不可遺失的資料，不應只依賴 BackgroundTasks；需要另外設計有持久化、重試和失敗告警的 Queue/Worker，或評估與業務交易一起提交。

## 8. 查詢與驗證紀錄

送出幾種測試請求後，先查最近的紀錄：

```sql
SELECT request_id, level, method, path, status_code,
       duration_ms, error_code, created_at
FROM public.api_logs
ORDER BY created_at DESC
LIMIT 20;
```

查詢錯誤數量：

```sql
SELECT path, status_code, COUNT(*) AS error_count
FROM public.api_logs
WHERE status_code >= 400
GROUP BY path, status_code
ORDER BY error_count DESC;
```

查看各路徑平均處理時間：

```sql
SELECT path,
       COUNT(*) AS request_count,
       ROUND(AVG(duration_ms)::numeric, 2) AS average_ms
FROM public.api_logs
GROUP BY path
ORDER BY average_ms DESC;
```

在瀏覽器開發者工具 Network 面板檢查 response 的 `X-Request-ID`，再比對資料庫中相同的 ID。確認資料庫寫入失敗時，API 的既有回應不會被改成成功，也不會洩漏資料庫錯誤。

## 9. 測試情境

新增暫時的測試路由，或使用已存在的端點測試下列狀況；測完後移除只供測試使用的路由：

| 請求狀況 | 預期 HTTP Status | 檢查重點 |
|---|---:|---|
| 正常健康檢查 | 200 | 有唯一 Request ID 和 Log |
| 查詢不存在的資源 | 404 | 使用統一錯誤格式 |
| 輸入錯誤型別 | 422 | 不回傳內部 traceback |
| 測試用未預期例外 | 500 | Client 看不到 SQL/traceback，Server 可用 ID 查到原因 |
| 未登入的受保護 API | 401 | 原本認證行為仍正常 |

不要把測試用 `RuntimeError` 路由留在公開服務中。

## 10. Logging 安全檢查

絕對不要記錄：

- 密碼、JWT、Refresh Token、Session Cookie。
- `Authorization` Header、API Key、OAuth client secret。
- 完整 Request Body 或含個資的資料。
- 資料庫連線字串、完整 SQL 錯誤或 traceback 到 Client 回應中。

另外要注意：

- 將可記錄欄位列白名單，限制訊息長度。
- 不可信字串可能含換行或控制字元，避免 Log Injection。
- 限制誰能讀取 Log，並規劃保留期限、封存與容量監控。
- IP 位址也可能是個人資料；只有在有需求並符合規範時才保存。

## 11. 本週實作順序與驗收

建議分批完成，不要一次讓 AI 重寫整個 `main.py`：

1. 先檢查並執行 `psql/w10_logging.sql`，確認表格、索引及最小權限。
2. 加入 Request ID 和 response header；確認既有健康檢查、登入與 API 正常。
3. 加入 HTTP/validation error response；用 `/docs` 驗證 status code 和 JSON 欄位。
4. 記錄 method、path、status 和 duration；避免記錄 query string、token 或 body。
5. 最後才加入 PostgreSQL 寫入及非同步背景工作，測試 DB 暫時無法連線的情況。
6. 檢查 Log 寫入失敗不會偽裝成功，也不會破壞已完成的 API response。

**驗收清單**

- [ ] 每個請求都有不同的 Request ID，回應含 `X-Request-ID`。
- [ ] 200、401、404、422 和 500 都保留正確 HTTP status。
- [ ] 錯誤回應格式一致，500 不包含 traceback 或資料庫細節。
- [ ] `api_logs` 能依 Request ID 找到對應請求，並包含狀態碼和處理時間。
- [ ] Session 尚未驗證前，Log 的 `session_id` 為 `NULL`。
- [ ] SQL 使用參數化查詢，沒有記錄 Token、Cookie、Password 或完整 Request Body。
- [ ] 資料庫無法寫入 Log 時，錯誤會記到伺服器 Logger，API 不會回報「Log 已成功保存」。
- [ ] 既有 Google 登入、Notes API 和分類 API 的行為沒有被破壞。

## 12. W10 學習心得題目

請用自己的話寫一段心得，可以想想：

1. Middleware 和 Exception Handler 分別在什麼時候工作？
2. Request ID 和 Session ID 有什麼不同？
3. 有了統一錯誤格式後，前端和除錯流程有什麼改變？
4. BackgroundTasks 為什麼不保證 Log 一定寫入？
5. 如果資料庫暫時連不上，API 回應與 Log 紀錄各應如何處理？
6. 你如何確認程式沒有把 Token、Cookie 或其他敏感資料寫進 Log？

心得應寫實際觀察到的結果；如果某個測試還沒做，就不要寫成已經驗證成功。
