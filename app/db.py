"""Kết nối SQL Server và gọi stored procedure.

Mọi trang của app chỉ dùng hàm `goi_proc`; không viết câu SQL rời trong code giao diện.
Cấu hình kết nối đọc từ file app/.env (copy từ .env.example rồi sửa).
"""
import os
import re
import time

import pandas as pd
import pyodbc
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))


def _chuoi_ket_noi() -> str:
    driver = os.getenv("DB_DRIVER", "ODBC Driver 18 for SQL Server")
    phan = [
        f"DRIVER={{{driver}}}",
        f"SERVER={os.getenv('DB_SERVER', 'localhost')}",
        f"DATABASE={os.getenv('DB_NAME', 'FitLifeHub')}",
        "TrustServerCertificate=yes",
    ]
    if os.getenv("DB_TRUSTED", "yes").strip().lower() == "yes":
        phan.append("Trusted_Connection=yes")       # đăng nhập bằng tài khoản Windows
    else:
        phan.append(f"UID={os.getenv('DB_USER', '')}")
        phan.append(f"PWD={os.getenv('DB_PASSWORD', '')}")
    return ";".join(phan)


def ket_noi() -> pyodbc.Connection:
    # autocommit=True: transaction do stored procedure tự quản lý (BEGIN/COMMIT bên trong proc)
    return pyodbc.connect(_chuoi_ket_noi(), autocommit=True)


def goi_proc(ten_proc: str, **tham_so):
    """Gọi một stored procedure, trả về (DataFrame hoặc None, thời gian chạy tính bằng ms).

    Ví dụ: df, ms = goi_proc("sp_XemLichPT", MaPT="NV0001", TuNgay=d1, DenNgay=d2)
    Lỗi từ SQL Server (THROW trong proc) được ném ra dưới dạng pyodbc.Error.
    """
    if not re.fullmatch(r"sp_\w+", ten_proc):
        raise ValueError("Tên proc không hợp lệ")
    dau_hoi = ", ".join(f"@{ten}=?" for ten in tham_so)
    cau_lenh = f"EXEC {ten_proc} {dau_hoi}".strip()

    conn = ket_noi()
    cur = conn.cursor()
    try:
        bat_dau = time.perf_counter()
        cur.execute(cau_lenh, list(tham_so.values()))
        ket_qua = None
        while True:
            if cur.description:          # tập kết quả đầu tiên có cột
                cot = [c[0] for c in cur.description]
                ket_qua = pd.DataFrame.from_records(cur.fetchall(), columns=cot)
                break
            if not cur.nextset():
                break
        ms = (time.perf_counter() - bat_dau) * 1000
        return ket_qua, ms
    finally:
        # Đóng cursor trước để bỏ các tập kết quả còn lại; nếu không, connection trả về pool
        # vẫn "bận" và lần gọi sau báo lỗi "Connection is busy with results for another command".
        cur.close()
        conn.close()


def loi_de_doc(loi: Exception) -> str:
    """Rút thông báo tiếng Việt từ lỗi pyodbc, bỏ phần tiền tố [Microsoft][ODBC ...]."""
    thong_diep = str(loi.args[1]) if len(loi.args) > 1 else str(loi)
    thong_diep = thong_diep.split("]")[-1]
    thong_diep = re.sub(r"\s*\(\d+\)\s*\(SQL\w+\)\s*$", "", thong_diep)
    return thong_diep.strip()
