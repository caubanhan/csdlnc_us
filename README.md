# FitLife Hub – Đồ án CSDL nâng cao, Giai đoạn 2

SQL Server + ứng dụng demo Python/Streamlit. Mọi thao tác của app đều gọi stored procedure.

## Cài đặt (mỗi máy làm một lần)

1. **SQL Server 2022 Developer** (miễn phí) và **SSMS**.
2. **ODBC Driver 18 for SQL Server** (thường có sẵn khi cài SSMS; nếu app báo lỗi driver thì cài riêng).
3. **Python 3.11 trở lên**, rồi mở terminal tại thư mục repo:
   ```
   python -m venv .venv
   .venv\Scripts\activate          (Windows)   |   source .venv/bin/activate   (macOS/Linux)
   pip install -r app/requirements.txt
   ```
4. Copy `app/.env.example` thành `app/.env`, sửa `DB_SERVER` nếu cần. Ví dụ nếu cài SQL Server dạng instance có tên thì ghi `localhost\SQLEXPRESS`.

## Tạo CSDL – chạy trong SSMS theo đúng thứ tự

| Thứ tự | File | Ghi chú |
| --- | --- | --- |
| 1 | `sql/00_create_db.sql` | Tạo CSDL FitLifeHub |
| 2 | `sql/01_schema_tam_nhan.sql` | **Tạm thời**, chỉ có các bảng phần PT. Khi Ngọc xong `sql/01_schema.sql` thì chạy file đó thay vào |
| 3 | `sql/datagen/du_lieu_thu_nhan.sql` | Sinh dữ liệu thử, khoảng 1–3 phút |
| 4 | `sql/02_procs_baseline_nhan.sql` | Proc bản cũ (v0) để đo "trước" |
| 5 | `sql/05_procs_nhan.sql` | Proc bản tối ưu, app dùng bản này. Chỉ tạo proc, chưa tạo index, nên vẫn đo "trước" được |
| 6 | *(đo TRƯỚC – xem mục dưới)* | Phải đo trước khi tạo index |
| 7 | `sql/04_indexes_nhan.sql` | Index, sau đó đo SAU |

Mỗi người giữ file riêng theo tên mình (`04_indexes_anh.sql`, `05_procs_ngoc.sql`, ...), để hai người không sửa chung một file và bị xung đột khi merge.

## Chạy app

```
streamlit run app/app.py
```
Trình duyệt mở `http://localhost:8501`. Trang chủ báo "Đã kết nối CSDL" là được.

## Đo hiệu năng phần của Nhân

| File | Đo gì | Khi nào |
| --- | --- | --- |
| `sql/benchmarks/KB05_a_hieu_nang.sql` | Logical reads của 1 lần đặt lịch, v0 so với bản tối ưu | Phần 1 trước, phần 2 sau |
| `sql/benchmarks/KB05_b_...cua_so_1.sql` + `KB05_c_...cua_so_2.sql` | 2 người đặt cùng PT, cùng giờ: trùng lịch ở v0, bị chặn ở bản mới | Mở 2 cửa sổ SSMS, chạy xen kẽ theo số bước |
| `sql/benchmarks/KB06_xem_lich_PT.sql` | Xem lịch tuần của PT: Scan → Seek | Phần 1 trước, phần 2 sau, phần 3 minh họa SARGable |
| `sql/benchmarks/KB09_hoan_thanh_PT.sql` | Số buổi, số tiền hoa hồng bị gán sai chi nhánh nếu dùng cách cũ | Bất kỳ lúc nào sau khi có dữ liệu |

Trong SSMS: bật **Include Actual Execution Plan** (Ctrl+M), chạy mỗi phần 3 lần, ghi lại lần thứ 3. Chụp tab *Messages* và tab *Execution plan*, lưu vào `report/screenshots/KBxx_truoc.png` và `KBxx_sau.png`.

## Thiết lập GitHub (Nhân làm, một lần)

1. Trên github.com: **New repository** → tên `fitlife-hub`, chọn **Private** → Create.
2. Trong thư mục này:
   ```
   git init
   git add .
   git commit -m "Khung repo GĐ2 + phần của Nhân"
   git branch -M main
   git remote add origin https://github.com/<tài-khoản>/fitlife-hub.git
   git push -u origin main
   ```
3. Repo → **Settings → Collaborators** → mời Anh và Ngọc.
4. Repo → **Settings → Branches** → thêm quy tắc cho `main`: bật *Require a pull request before merging*, 1 người duyệt.
5. Tạo nhãn, mốc tuần và các việc: cài [GitHub CLI](https://cli.github.com), chạy `gh auth login`, rồi chạy `bash scripts/tao_board_github.sh`. Trên Windows, chạy trong Git Bash.
6. Tab **Projects → New project → Board**, đặt tên "FitLife GĐ2", rồi thêm toàn bộ issue vào board (Add item → chọn repo → chọn tất cả). Cột: Todo, Đang làm, Chờ review, Xong.

**Quy ước làm việc:** mỗi việc làm trên một nhánh riêng (ví dụ `nhan/kb05`), mở pull request, người khác duyệt rồi mới merge. Không commit file `.env`.

## Cấu trúc thư mục

```
sql/                 script tạo CSDL, proc, index (đánh số theo thứ tự chạy)
sql/datagen/         sinh dữ liệu
sql/benchmarks/      script đo trước/sau cho từng KB
app/                 Streamlit: app.py (trang chủ), db.py (kết nối), pages/ (mỗi KB một trang)
docs/                đặc tả kịch bản, mẫu phân tích truy vấn
report/screenshots/  ảnh chụp cho báo cáo
scripts/             tiện ích (tạo board GitHub)
```
