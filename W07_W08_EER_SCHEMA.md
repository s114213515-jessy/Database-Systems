# W7–W8：一步一步學會 EER 分類、PostgreSQL Schema 與可重用 View

> 本教學以 [`s114213515-jessy/Database-Systems`](https://github.com/s114213515-jessy/Database-Systems) 目前的程式為準。請先看懂本專案實際使用的 `public.class`、`public.inheritance`、`public.object`、`public.co`、`public.insertclass` 與 `public.vd_subclass`，不要把它們和另一種「大學教務系統的學生／教師子類別資料表」混為一談。
>
> 本文件是教學步驟，不會要求你刪除整個資料庫，也不會要求你把密碼、Google OAuth 憑證或其他秘密上傳到 GitHub。

## 完成後你會做到什麼？

完成 W7 後，你可以：

1. 用自己的話說明 Entity、Relationship、PK、FK、一般化／特化與 EER 分類樹。
2. 看懂本專案用 `class` 保存分類節點、用 `inheritance` 保存父子關係的做法。
3. 看懂 `co` 如何把分類節點連到一般物件。
4. 用 SQL 建立一組測試分類、掛上測試物件，並查出父子資料。
5. 確認資料庫如何阻止不存在的父節點、重複關係與重複路徑。
6. 說明資料庫目前**沒有**自動阻止哪些問題，例如分類樹形成循環。

完成 W8 後，你可以：

1. 分辨 PostgreSQL Database、Schema、Table、View 和 EER 模型。
2. 用完整名稱（例如 `public.class`）明確查詢資料，而不猜測 `search_path`。
3. 了解 `public.vd_subclass` 為什麼可以讓 API 重複使用同一份查詢邏輯。
4. 用最小必要權限讓 `dev_user` 查 View，而不是任意開放所有資料表。
5. 從 SQL 一路測到 FastAPI，確認欄位與結果一致。

---

## 開始前：先保護你的資料

### 這些資料不要放上 GitHub

- `.env` 裡的資料庫密碼。
- Google OAuth Client Secret。
- JWT signing secret。
- 真實使用者個資或真實測試帳號資料。
- PostgreSQL 資料庫備份檔。

GitHub repository 即使是 private，也不要把密碼當成一般程式碼保存。密碼應放在本機 `.env`，並確認 `.gitignore` 有忽略 `.env`。

### 先確認你在正確的專案目錄

以下命令使用 Windows PowerShell。若你已經有專案，先在 VS Code 開啟專案資料夾，然後從 VS Code 選單開啟 Terminal。

```powershell
Get-Location
```

輸出路徑應該是 `Database-Systems` 專案根目錄，而且該資料夾應看得到 `README.md`、`app`、`psql`、`tests` 等項目。

若你尚未下載專案，可用：

```powershell
git clone https://github.com/s114213515-jessy/Database-Systems.git
Set-Location .\Database-Systems
```

確認檔案：

```powershell
Get-ChildItem
```

> 如果你是從別的專案資料夾開始，請先切到你真正要操作的 `Database-Systems` 資料夾。不要在 Downloads 或錯誤 repository 執行 `git add`。

### 確認 PostgreSQL 與 psql 已安裝

```powershell
psql --version
```

應看到 PostgreSQL 的版本號。若 PowerShell 說找不到 `psql`，先安裝 PostgreSQL，或把 PostgreSQL `bin` 資料夾加入 PATH；在 `psql` 能執行之前，不要繼續資料庫步驟。

---

# W7：EER 分類模型與虛構資料

## 1. 先懂這個專案正在表示什麼

### 用一個生活例子理解「分類」

假設網站要展示一個分類目錄：

```text
首頁
└── 學習
    └── 資料庫
        └── PostgreSQL
```

每個名稱都是一個「分類節點」。分類節點之間有父子關係；節點也可能連到可展示的物件，例如一篇文章或一個資源連結。

本專案大致用下面四張表表示：

```text
class
  保存分類節點，例如「首頁」、「學習」、「資料庫」。

inheritance
  保存分類節點與分類節點之間的父子關係。

object
  保存一般物件，例如文章或資源。

co
  保存分類節點與一般物件之間的連結。
```

圖示如下：

```text
class (父分類) ──< inheritance >── class (子分類)

class ──< co >── object
```

### 名詞逐個說清楚

| 名詞 | 白話解釋 | 本專案例子 |
|---|---|---|
| Entity | 想保存的一種東西 | 分類、物件 |
| Attribute | 東西的特徵 | 分類名稱 `name`、物件標題 `title` |
| Relationship | 兩種東西之間的關係 | 分類有子分類、分類包含物件 |
| Primary Key（PK） | 每一筆資料的唯一身分證號 | `class.cid`、`object.oid` |
| Foreign Key（FK） | 指向另一筆資料的連結 | `inheritance.pcid` 指向 `class.cid` |
| EER | 比基本 ER 多表達一般化、特化等概念的資料模型 | 用模型描述分類、繼承／父子等概念 |
| View | 儲存查詢定義的虛擬表 | `public.vd_subclass` |

### 很重要：這裡的 inheritance 不是「資料表繼承」

本專案的 `inheritance` 表是**分類節點之間的父子關係**。它不是把 `faculty`、`student` 等子類型的欄位分到不同資料表，也不是 PostgreSQL 的 `INHERITS` 語法。

它實際上是「鄰接清單（adjacency list）」的一種表示方法：

- `class` 裡每一列是一個節點。
- `inheritance` 裡每一列是一條父節點到子節點的邊。
- 一個父節點可以有很多子節點。
- `inheritance` 的複合主鍵 `(pcid, ccid)` 阻止同一條父子邊重複出現。

因此，寫作業或解釋資料庫時，不要說這個程式已經實作「學生表繼承會員表」。比較精確的說法是：「本專案用分類節點與 `inheritance` 關聯表表示分類階層。」

## 2. 認識四張表的主鍵和外鍵

### `public.class`

- `cid`：分類節點的 PK；資料庫會自動產生新編號。
- `name`：分類名稱，不能是空值。
- `idpath`：以 ID 串起來的路徑，例如 `0/12/14`。
- `namepath`：以名稱串起來的路徑，例如 `首頁/學習/資料庫`。
- `idpath`、`namepath` 有 UNIQUE 限制；相同路徑不能被保存兩次。

### `public.inheritance`

- `pcid`：parent class id，也就是父分類 ID。
- `ccid`：child class id，也就是子分類 ID。
- `(pcid, ccid)` 是複合 PK。
- `pcid` 和 `ccid` 都是 FK，必須指向真的存在的 `public.class.cid`。

### `public.object`

- `oid`：物件的 PK。
- `title`、`class`、`des`、`address` 等欄位保存物件資料。
- 本教學只用虛構文章標題做練習，不輸入真實個資。

### `public.co`

- `cid` 指向分類節點。
- `oid` 指向物件。
- `(cid, oid)` 是複合 PK，避免同一物件被同一分類重複掛載。
- 一個分類可以連多個物件；一個物件也可以連到多個分類。

## 3. 安裝本專案的資料庫結構

在專案根目錄，先看一下相關 SQL 檔案：

```powershell
Get-ChildItem .\psql
```

### 選項 A：第一次設定本機開發環境

專案的 `createdb.sql` 會建立 `fastapi_dev`、`dev_user` 和 W4 的 `notes` table。它包含建立資料庫與角色的命令，第一次設定才執行；如果已經建立過，重複執行可能遇到「database/role 已存在」錯誤，不要為了解決錯誤就刪掉整個資料庫。

```powershell
psql -X -U postgres -d postgres -f .\psql\createdb.sql
```

依提示輸入本機 PostgreSQL 管理者密碼。

### 安裝學術分類結構

`academic.sql` 會在需要時建立目標資料庫，建立分類與物件相關表格、`insertclass` function、`vd_subclass` view，並在 `dev_user` 存在時設定部分權限。

```powershell
psql -X -U postgres -d postgres -f .\psql\academic.sql
```

注意：

1. `-U postgres` 表示以 PostgreSQL 管理者角色執行，並不是 Windows 使用者名稱。
2. `-d postgres` 是先連到管理資料庫；`academic.sql` 內有 `\connect`，之後會切換到目標資料庫。
3. 這份 SQL 不是清空資料庫的命令，但若你在不熟悉的資料庫執行任何 SQL，先確認目標 database 名稱。
4. 如果看到 `dev_user` 不存在的 NOTICE，代表此角色尚未建立；先依專案 README 的首次設定方式建立角色，再重新執行 academic SQL 的授權步驟。
5. 若看到錯誤，先記下完整錯誤訊息及 SQL 行號；不要直接加上 `CASCADE` 或刪除資料表。

### 選項 B：用獨立的練習資料庫，避免碰開發資料

`academic.sql` 支援 `DBName` 參數，可建立另一個資料庫作為本週練習環境：

```powershell
psql -X -U postgres -d postgres -v DBName=fastapi_w7_lab -f .\psql\academic.sql
```

請先確認 `fastapi_w7_lab` 是你要建立的新練習資料庫名稱。此步驟不會自動把 FastAPI 的 `.env` 改成連到練習資料庫；API 預設仍可能連到 `fastapi_dev`。

## 4. 確認資料表真的建立了

用 psql 連入資料庫。若使用預設開發資料庫：

```powershell
psql -X -U postgres -d fastapi_dev
```

若使用練習資料庫：

```powershell
psql -X -U postgres -d fastapi_w7_lab
```

在出現 `fastapi_dev=#` 或 `fastapi_w7_lab=#` 提示符後，逐行輸入：

```sql
\dt public.*
```

應能看到 `class`、`inheritance`、`object`、`co` 等表。

再確認主鍵、外鍵：

```sql
\d public.class
\d public.inheritance
\d public.object
\d public.co
```

結束 psql：

```sql
\q
```

## 5. 建立你的第一個測試分類樹

### 5.1 重新連到練習資料庫

以下步驟以 `fastapi_w7_lab` 為例：

```powershell
psql -X -U postgres -d fastapi_w7_lab
```

請勿在還沒確認資料庫名稱前執行 INSERT 或 UPDATE。

### 5.2 看看首頁節點

```sql
SELECT cid, name, idpath, namepath
FROM public.class
WHERE cid = 0;
```

預期會有一筆名為「首頁」的根節點。`cid = 0` 是 `academic.sql` 預先建立的首頁節點。

### 5.3 用資料庫 function 建立第一層子分類

```sql
SELECT public.insertclass(0, '首頁', 'W7練習');
```

這個 function 的三個輸入值依序是：

1. `0`：父分類 ID。
2. `'首頁'`：父分類目前的名稱。function 會用 ID 和名稱一起確認父節點。
3. `'W7練習'`：要建立的子分類名稱。

查詢結果會回傳新分類的 `cid`。**記下這個數字**，接下來需要用它當父節點 ID。不要假設每台電腦產生的 ID 都一樣。

### 5.4 用剛才的 ID 建立下一層

把下面的 `把這裡換成上一個查詢回傳的數字` 換成你實際看到的數字。

```sql
SELECT public.insertclass(
    把這裡換成上一個查詢回傳的數字,
    'W7練習',
    'EER分類'
);
```

例如，若第一個 function 回傳 `12`，就輸入：

```sql
SELECT public.insertclass(12, 'W7練習', 'EER分類');
```

這個檢查機制是刻意的：如果你傳入的 ID 是 `12`，但名稱卻寫成其他分類名稱，function 不會默默把節點加錯地方。

### 5.5 查看所有直接父子關係

```sql
SELECT pcid, parent_name, cid, child_name
FROM public.vd_subclass
ORDER BY pcid, cid;
```

輸出中的每一列只表示一組**直接**父節點和子節點。它不會自動列出所有層級的後代。

只看首頁的直接子分類：

```sql
SELECT pcid, parent_name, cid, child_name
FROM public.vd_subclass
WHERE pcid = 0
ORDER BY cid;
```

只看「W7練習」的直接子分類時，把 `0` 換成該節點的實際 ID。

### 5.6 查路徑欄位

```sql
SELECT cid, name, idpath, namepath
FROM public.class
WHERE namepath LIKE '首頁/W7練習%';
```

`idpath` 和 `namepath` 是方便顯示／查詢的路徑資料。`insertclass` 建立子節點時會更新新節點的路徑。

## 6. 把一個虛構物件放進分類

以下 SQL 會新增一篇虛構的學習文章，並把它連到名為 `EER分類` 的分類。請在練習資料庫執行。

```sql
WITH new_object AS (
    INSERT INTO public.object (title, class, des)
    VALUES (
        '虛構文章：認識資料表關係',
        'learning-resource',
        '僅供本機資料庫練習，不代表真實課程或個人資料。'
    )
    RETURNING oid
),
target_class AS (
    SELECT cid
    FROM public.class
    WHERE namepath = '首頁/W7練習/EER分類'
)
INSERT INTO public.co (cid, oid)
SELECT target_class.cid, new_object.oid
FROM target_class
CROSS JOIN new_object
RETURNING cid, oid;
```

預期回傳一筆 `cid` 和 `oid`。如果回傳 0 rows，先檢查 `namepath` 拼字是否和實際資料一致：

```sql
SELECT cid, name, namepath
FROM public.class
WHERE namepath LIKE '首頁/W7練習%';
```

查詢這個分類底下連結的物件：

```sql
SELECT c.cid, c.name, o.oid, o.title, o.class AS object_class
FROM public.class AS c,
     public.co AS link,
     public.object AS o
WHERE c.cid = link.cid
  AND link.oid = o.oid
  AND c.namepath = '首頁/W7練習/EER分類'
ORDER BY o.oid;
```

這裡用 `FROM` 列出資料表、`WHERE` 寫關聯條件。關鍵是每個連結都要寫清楚：

- `c.cid = link.cid`：分類節點連到分類—物件關聯表。
- `link.oid = o.oid`：關聯表連到物件。

少寫其中一個條件可能形成笛卡兒積，讓每個分類都配上每個物件，查詢結果會突然變得很多。

## 7. 故意測試資料庫的保護措施

每一項錯誤測試請分開執行。發生錯誤時，先觀察訊息，不要把錯誤的資料硬塞進資料庫。

### 測試 A：父分類 ID 不存在

```sql
SELECT public.insertclass(999999, '不存在的父分類', '錯誤子分類');
```

預期：function 回報父分類不存在。這是外鍵／function 驗證在保護資料。

### 測試 B：父 ID 和名稱不相符

將第一個數字換成一個存在的 `cid`，但故意把第二個參數寫成另一個名稱：

```sql
SELECT public.insertclass(0, '故意寫錯的首頁名稱', '不應建立');
```

預期：function 回報父分類名稱不符合該 ID。這可以避免呼叫端不小心把孩子掛到錯誤的分類。

### 測試 C：子分類名稱只有空白

```sql
SELECT public.insertclass(0, '首頁', '   ');
```

預期：function 拒絕空白名稱。

### 測試 D：不存在的 FK

在確認使用練習資料庫後，測試以下語句：

```sql
INSERT INTO public.inheritance (pcid, ccid)
VALUES (999999, 999998);
```

預期：外鍵錯誤。`inheritance` 不允許指向不存在的 `class` 節點。

## 8. 看懂目前資料庫仍需注意的限制

PK、FK、UNIQUE 很重要，但它們不會自動替你實作每一條業務規則。

### 資料庫已經保護的事情

- `class.cid`、`object.oid` 必須唯一。
- `inheritance.pcid`、`inheritance.ccid` 必須找到已存在的分類。
- 同一組 `(pcid, ccid)` 不可重複。
- 同一組 `(cid, oid)` 不可重複。
- `idpath`、`namepath` 不可重複（但 PostgreSQL UNIQUE 對 NULL 的處理另有規則）。

### 目前模型不能只靠上述限制保證的事情

- **分類不能形成循環。** 例如 A 是 B 的父節點，B 又是 A 的父節點。FK 只會確認節點存在，不會檢查整張圖是否有環。
- **物件必須至少屬於一個分類。** `object` 和 `co` 分開保存，單靠 `co` 的 FK 不會要求每個 `object` 至少有一個關聯。
- **某一種分類只能出現在特定位置。** 如需這種規則，要再設計欄位、限制、交易或 function。
- **路徑欄位永遠與父子關係一致。** 若有人直接修改 `inheritance`，現有 `insertclass` 不一定會替其他節點重算路徑。

回答「資料庫已經幫我保證了什麼？」時，請看實際的 constraint、function、trigger 和交易，不要只看 EER 圖上的文字。

## 9. 了解 `insertclass` 的重複執行

在同一個父節點下再次呼叫相同名稱，可觀察 function 是否重用既有節點與關係：

```sql
SELECT public.insertclass(0, '首頁', 'W7練習');
```

比較前後 ID：

```sql
SELECT cid, name, idpath, namepath
FROM public.class
WHERE namepath = '首頁/W7練習';
```

此 function 會在指定父節點下尋找同名孩子，並以 `ON CONFLICT` 避免重複插入同一條父子關係。請以查詢結果驗證，不要只因 SQL 沒有報錯就認定資料完全符合預期。

## 10. W7 小結與作業

請用自己的話回答：

1. `class` 和 `inheritance` 各保存什麼？
2. 為什麼 `inheritance` 的 PK 有兩個欄位？
3. `vd_subclass` 回傳直接孩子，還是所有層級的後代？
4. FK 為什麼不能阻止 A → B → A 的循環？
5. `object` 和 `co` 分開保存後，為什麼同一物件可以放入不同分類？
6. 哪一種測試資料可以提交到 GitHub？哪一種不可？

**W7 驗收清單**

- [ ] 能在不看筆記時畫出四張表以及它們的 PK/FK。
- [ ] 能在練習資料庫建立至少兩層分類。
- [ ] 能透過 `vd_subclass` 查出一層父子關係。
- [ ] 能將虛構物件連到分類並查回來。
- [ ] 能重現至少一個預期的 FK 或 function 錯誤，並說明原因。
- [ ] 能說出目前尚未由資料庫保證的規則。

---

# W8：PostgreSQL Schema、View 與資料重用

## 1. 先把 Database 和 Schema 分開想

可以把 PostgreSQL Server 想成一棟圖書館：

```text
PostgreSQL Server（整棟圖書館）
└── Database（某一間獨立館藏室）
    ├── Schema（館藏區／命名空間）
    │   ├── Table（實際保存資料的書架）
    │   └── View（依規則整理出來的查詢窗口）
    └── 其他 Schema
```

- **Database** 是連線時選擇的資料庫，例如 `fastapi_dev`。
- **Schema** 是 Database 內的命名空間，例如 `public`。
- **Table** 儲存實際資料，例如 `public.class`。
- **View** 保存一個查詢定義，例如 `public.vd_subclass`。
- **EER** 是分析實體、屬性與關係的模型，不是 PostgreSQL Schema 的同義字。

同一個 Database 裡可以同時有 `public.class` 和 `practice.class`。完整名稱中的第一段是 Schema，第二段是物件名稱。

## 2. 確認本專案的 Schema 與 View

本 repository 的學術分類表目前放在 `public` Schema。因此以下寫法：

```sql
SELECT * FROM public.class;
```

比下面這個未指定 Schema 的寫法更清楚：

```sql
SELECT * FROM class;
```

未指定 Schema 時，PostgreSQL 會依 `search_path` 找物件。不同帳號或連線可能有不同設定；教學和 API 程式明確寫 `public.class`，比較不容易查到同名的錯誤資料表。

查目前連線的設定：

```sql
SHOW search_path;
```

列出可用 Schema：

```sql
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name NOT LIKE 'pg_%'
  AND schema_name <> 'information_schema'
ORDER BY schema_name;
```

列出 `public` 裡的資料表和 View：

```sql
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_type, table_name;
```

## 3. 為什麼 API 使用 View？

如果每個 API endpoint 都自己把 `class`、`inheritance` 拼在一起，容易出現：

- 有的端點忘記連接條件。
- 有的端點把父分類和子分類寫反。
- 各端點欄位命名不一樣。
- 修改資料表後，要逐一改很多份重複 SQL。

View 可以把常用的查詢定義集中管理。FastAPI repository 只要查 View，就不用每次都重寫整段關聯。

專案中的 `public.vd_subclass` 大意如下：

```sql
CREATE OR REPLACE VIEW public.vd_subclass AS
SELECT
    p.cid AS pcid,
    p.name AS parent_name,
    c.cid AS cid,
    c.name AS child_name
FROM public.class AS p
JOIN public.inheritance AS i ON i.pcid = p.cid
JOIN public.class AS c ON c.cid = i.ccid;
```

逐行看：

1. `p` 是父分類 `class` 的別名。
2. `i` 是父子關係表 `inheritance` 的別名。
3. `c` 是子分類 `class` 的別名。
4. `i.pcid = p.cid` 把關係表的父 ID 接到父分類。
5. `i.ccid = c.cid` 把關係表的子 ID 接到子分類。
6. 每一列輸出一組直接的父分類與子分類。

`JOIN` 是把兩張或多張表依共同條件連起來的寫法。它和用 `FROM p, i, c` 再在 `WHERE` 放關聯條件，目的相同；無論採哪一種寫法，都必須明確寫出每一個連接條件。

看資料庫實際安裝的 View 定義：

```sql
\d+ public.vd_subclass
```

或：

```sql
SELECT pg_get_viewdef('public.vd_subclass'::regclass, true);
```

## 4. 從 API repository 一路追到資料庫

本專案的讀取流程可以這樣理解：

```text
HTTP GET /api/subclass/pcid/{parent_id}
        ↓
app/api/classes.py 的 list_subclasses
        ↓
app/repositories/classes.py 的 list_subclass_records
        ↓
SELECT ... FROM public.vd_subclass WHERE pcid = %s
        ↓
PostgreSQL 回傳列
        ↓
FastAPI 驗證回應 Schema 並回 JSON
```

Repository 查詢使用參數 placeholder：

```python
cursor.execute(
    """
    SELECT pcid, parent_name, cid, child_name
    FROM public.vd_subclass
    WHERE pcid = %s
    ORDER BY cid
    """,
    (parent_id,),
)
```

`%s` 是 psycopg 的參數位置，不是 Python 字串格式化符號。ID 會作為資料參數傳入，不要改成把使用者輸入直接用 `f-string` 拼進 SQL。

### 在 PostgreSQL 直接測 View

先連到 FastAPI 正在使用的 database：

```powershell
psql -X -U postgres -d fastapi_dev
```

查首頁的直接子分類：

```sql
SELECT pcid, parent_name, cid, child_name
FROM public.vd_subclass
WHERE pcid = 0
ORDER BY cid;
```

即使沒有任何符合的孩子，SQL 也會正常回傳 0 rows；「查不到資料」和「查詢失敗」是兩件不同的事。

### 再透過 API 測一次

1. 確認 `.env` 的 `DATABASE_URL` 指向剛才查詢的 `fastapi_dev`。
2. 啟動專案：

   ```powershell
   .\run.bat
   ```

   或在本機開發時：

   ```powershell
   uvicorn app.main:app --host 127.0.0.1 --port 7777 --reload
   ```

3. 瀏覽器開啟：

   ```text
   http://127.0.0.1:7777/docs
   ```

4. 找到 `GET /api/subclass/pcid/{parent_id}`。
5. 輸入 `0` 並送出。
6. 將 API JSON 的 `pcid`、`parent_name`、`cid`、`child_name` 與 SQL 結果比對。

此 router 需要登入會員。如果 API 回傳 401/403，先依專案 `OAUTH.md` 完成 Google 登入；不要把登入 token、cookie 或 secret 貼到 GitHub issue、README 或本文件。

## 5. Schema 權限：用「剛好需要」的原則

在 PostgreSQL 中，`USAGE` 和 `SELECT` 是不同權限：

- `USAGE ON SCHEMA`：允許角色使用 Schema 裡物件的名稱。
- `SELECT ON VIEW`：允許讀取 View 結果。
- `SELECT ON TABLE`：允許直接讀取指定 Table 的資料。
- `EXECUTE ON FUNCTION`：允許呼叫指定 Function。

只有 `USAGE` 並不代表可以讀取表格；只有 View 的 `SELECT` 也不代表可以直接讀它的來源 Table。

`academic.sql` 已經為 `dev_user` 設定了讀 `public.vd_subclass` 的權限，並只開放 `public.class` 的部分欄位及指定 function。檢查權限：

```sql
\dp public.vd_subclass
\dp public.class
\df+ public.insertclass
```

可以用管理者帳號確認授權資料：

```sql
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'dev_user'
  AND table_schema = 'public'
ORDER BY table_name, privilege_type;
```

### 最小權限練習

若在一個新環境需要重新授權，請以資料庫管理者執行：

```sql
GRANT USAGE ON SCHEMA public TO dev_user;
GRANT SELECT ON public.vd_subclass TO dev_user;
```

不要因為「View 查不到」就直接執行：

```sql
GRANT ALL ON ALL TABLES IN SCHEMA public TO dev_user;
```

這種廣泛授權會讓應用程式讀寫許多原本不需要操作的資料。先確認缺少的是 Schema `USAGE`、View `SELECT`、Table 欄位權限，還是登入了錯誤 database。

> PostgreSQL View 預設以 View 擁有者的權限解析來源資料（除非特別設定 security-invoker 行為）。因此需確認 View owner 本身能讀取來源表，並用實際 `dev_user` 連線測試。不要只憑管理者查得出來，就推論應用程式帳號也能查。

### 用應用程式帳號做讀取測試

若你知道本機 `dev_user` 密碼，可在 PowerShell 以互動方式連線：

```powershell
psql -X -h localhost -U dev_user -d fastapi_dev
```

輸入密碼後執行：

```sql
SELECT * FROM public.vd_subclass WHERE pcid = 0 ORDER BY cid;
```

再嘗試讀取未授權的底層資料表：

```sql
SELECT * FROM public.inheritance;
```

若拒絕存取，這可能正是最小權限設計的預期結果，不要立即把所有權限打開。API 只需要呼叫它所使用的 View/function 和欄位。

如果你的本機角色權限和範例不同，請查看 `psql/createdb.sql`、`psql/academic.sql` 與 PostgreSQL 的錯誤訊息，再決定要補哪一項授權。

## 6. 在獨立 Schema 做不影響現有 API 的實驗

本專案目前 API 查詢名稱寫死為 `public.vd_subclass`。不要直接搬動或重新命名它，否則 API 會找不到 View。

如果只想學習 Schema，可以在練習資料庫建立一個 `w8_lab` Schema 和測試 View：

```sql
CREATE SCHEMA IF NOT EXISTS w8_lab;

CREATE OR REPLACE VIEW w8_lab.vd_subclass AS
SELECT
    p.cid AS pcid,
    p.name AS parent_name,
    c.cid AS cid,
    c.name AS child_name
FROM public.class AS p
JOIN public.inheritance AS i ON i.pcid = p.cid
JOIN public.class AS c ON c.cid = i.ccid;
```

管理者可以查：

```sql
SELECT *
FROM w8_lab.vd_subclass
WHERE pcid = 0
ORDER BY cid;
```

若要讓 `dev_user` 也能查，授予兩項權限：

```sql
GRANT USAGE ON SCHEMA w8_lab TO dev_user;
GRANT SELECT ON w8_lab.vd_subclass TO dev_user;
```

然後用 `dev_user` 實際連線測試：

```sql
SELECT *
FROM w8_lab.vd_subclass
WHERE pcid = 0
ORDER BY cid;
```

這個練習 View 不會讓既有 API 自動改查 `w8_lab`。API repository 仍然查 `public.vd_subclass`。若未來真的要切換，至少要同步：

1. 更新 `app/repositories/classes.py` 的 View 名稱。
2. 建立或更新對應 migration。
3. 授予正確的 Schema 和 View 權限。
4. 更新測試資料庫初始化流程。
5. 執行測試並透過 `/docs` 確認 API 回應。

## 7. View 修改時避免破壞 API

View 是資料庫和應用程式之間的介面。API 依賴 `pcid`、`parent_name`、`cid`、`child_name` 這些輸出欄位，因此欄位名稱變更會影響程式。

### 相容的修改方式

通常可在輸出欄位末端新增欄位，再逐步讓 API 使用新欄位；但仍需先檢查 response schema 和測試。

### 不相容的修改方式

刪欄位、改欄位名稱、改欄位型別或改變每列代表的資料意義，都可能讓 API 壞掉。

`CREATE OR REPLACE VIEW` 不是任何欄位變更都能自動接受。遇到欄位順序／名稱／型別衝突時，先找出所有相依的 API 和 View，再設計相容 migration。不要在共用資料庫直接執行 `DROP VIEW ... CASCADE`，因為它可能把相依物件一起刪除。

修改前先查 View 的使用位置：

```powershell
rg "vd_subclass" app tests psql README.md
```

修改後至少確認：

1. View 可以建立。
2. `dev_user` 權限仍正確。
3. Repository SQL 使用的欄位仍存在。
4. Pydantic response schema 能接收回傳欄位。
5. `/api/subclass/pcid/0` 的結果和直接 SQL 查詢一致。

## 8. W8 常見問題排除

### `relation "vd_subclass" does not exist`

依序確認：

1. 目前連到正確 database 嗎？執行 `SELECT current_database();`
2. View 是否真的在 `public`？執行 `\dv public.*`
3. SQL 是否寫成 `public.vd_subclass`？
4. 是否已執行 `psql/academic.sql`？

### `permission denied for schema public`

這代表帳號可能沒有使用該 Schema 的權限。由管理者確認角色及 `USAGE` 授權，不要先授予全資料庫權限。

### `permission denied for view vd_subclass`

確認：

1. 連線使用的角色是不是 `dev_user`？
2. 對應 View 是否授予 `SELECT`？
3. View owner 是否能讀來源資料？
4. 是不是執行了另一個 database 裡的授權 SQL？

### API 是空陣列，但 SQL 也查不到資料

這通常是資料還沒建立，而不是 API 故障。先透過 `insertclass` 建立分類，再查 `public.vd_subclass`。

### API 401/403

class/subclass router 有登入依賴。依 `OAUTH.md` 登入後再測，這和 SQL 是否正確是不同層次的問題。

## 9. W8 小結與作業

請用自己的話回答：

1. `fastapi_dev` 和 `public` 的差異是什麼？
2. 為什麼 API 使用 `public.vd_subclass` 比每支 endpoint 重寫 JOIN 容易維護？
3. View 的 `SELECT` 和 Schema 的 `USAGE` 分別做什麼？
4. 為什麼「管理者查得出 View」不代表 `dev_user` 也查得出？
5. 如果把 `public.vd_subclass` 改名，哪一個 Python repository 需要一起修改？
6. 為什麼不應為了方便把 `GRANT ALL` 給 API 使用者？

**W8 驗收清單**

- [ ] 能用完整名稱查詢 `public.class` 與 `public.vd_subclass`。
- [ ] 能說明 View 每一列代表什麼，以及欄位如何從父、子分類而來。
- [ ] 能以管理者和 `dev_user` 分別測試 View 權限。
- [ ] 能從 SQL 查詢追到 repository，再追到 FastAPI endpoint。
- [ ] 能解釋為什麼改 View 欄位是 API 相容性變更。
- [ ] 建立 `w8_lab` 練習前先確認使用練習資料庫，沒有搬動正式 View。

---

## 把本教材加到 GitHub repository

本檔案建議放在 repository 根目錄，名稱為 `W07_W08_EER_SCHEMA.md`。確認 `README.md` 也有一個容易找到的連結，例如：

```markdown
## W7–W8：EER、Schema 與 View

逐步實作教材見 [W07_W08_EER_SCHEMA.md](W07_W08_EER_SCHEMA.md)。
```

提交前確認：

```powershell
git status --short
git diff --check
```

確認沒有 `.env`、密碼、token、備份檔或本機資料庫檔案，再提交：

```powershell
git add W07_W08_EER_SCHEMA.md README.md
git diff --cached --check
git diff --cached --stat
git commit -m "docs: add detailed W7-W8 EER and schema guide"
git push origin main
```

如果你不打算這次修改 README，就把 `git add` 改成：

```powershell
git add W07_W08_EER_SCHEMA.md
```

若 push 被拒絕，先執行 `git status` 和 `git pull --rebase origin main`，確認衝突後再處理；不要用 `git push --force` 覆蓋遠端工作。
