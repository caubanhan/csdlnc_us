"""Trang chủ ứng dụng demo FitLife Hub.

Chạy:  streamlit run app/app.py
Các trang nằm trong app/pages/, Streamlit tự hiện ở thanh bên trái theo thứ tự số đầu tên file.
"""
import pyodbc
import streamlit as st

from db import goi_proc, loi_de_doc

st.set_page_config(page_title="FitLife Hub – Demo CSDLNC", layout="wide")
st.title("FitLife Hub – Demo đồ án CSDL nâng cao")

try:
    chi_nhanh, ms = goi_proc("sp_DSChiNhanh")
    st.success(f"Đã kết nối CSDL: {len(chi_nhanh)} chi nhánh ({ms:.0f} ms).")
except pyodbc.Error as loi:
    st.error("Chưa kết nối được CSDL. Kiểm tra file app/.env và SQL Server.")
    st.caption(loi_de_doc(loi))
    st.stop()

st.markdown(
    """
Mọi thao tác trong app đều gọi **stored procedure**; app không chứa câu SQL rời.
Mỗi trang hiện thời gian xử lý (ms) để đối chiếu với phần đo trong báo cáo.

| Trang | Kịch bản | Proc được gọi | Người phụ trách |
| --- | --- | --- | --- |
| Đặt lịch PT | KB05 | `sp_DatLichPT`, `sp_DatLichPT_v0` (chỉ trong mô phỏng) | Nhân |
| Lịch của PT | KB06 | `sp_XemLichPT` | Nhân |
| Hoàn thành / Hủy buổi PT | KB09, CN05 | `sp_HoanThanhBuoiPT`, `sp_HuyLichPT` | Nhân |
| *(Anh, Ngọc thêm trang của mình: `pages/4_...py`, `pages/5_...py`, ...)* | | | |
"""
)
