"""KB06 – Xem lịch của một PT theo khoảng ngày."""
import datetime as dt

import pyodbc
import streamlit as st

from db import goi_proc, loi_de_doc

st.set_page_config(page_title="Lịch của PT", layout="wide")
st.title("Lịch của PT (KB06)")

hom_nay = dt.date.today()
c1, c2, c3 = st.columns(3)
ma_pt = c1.text_input("Mã PT", value="NV0001", help="NV0001 đến NV0120 là PT.").strip()
tu_ngay = c2.date_input("Từ ngày", value=hom_nay)
den_ngay = c3.date_input("Đến ngày", value=hom_nay + dt.timedelta(days=6))

if den_ngay < tu_ngay:
    st.error("'Đến ngày' phải sau 'Từ ngày'.")
    st.stop()

try:
    lich, ms = goi_proc("sp_XemLichPT", MaPT=ma_pt, TuNgay=tu_ngay, DenNgay=den_ngay)
except pyodbc.Error as loi:
    st.error(loi_de_doc(loi))
    st.stop()

m1, m2, m3 = st.columns(3)
m1.metric("Số buổi", len(lich))
m2.metric("Đã đặt", int((lich["TrangThaiLich"] == "DA_DAT").sum()))
m3.metric("Thời gian xử lý", f"{ms:.0f} ms")

chi_hien_con_hieu_luc = st.checkbox("Ẩn lịch đã hủy", value=True)
if chi_hien_con_hieu_luc:
    lich = lich[lich["TrangThaiLich"] != "HUY"]
st.dataframe(lich, hide_index=True)
