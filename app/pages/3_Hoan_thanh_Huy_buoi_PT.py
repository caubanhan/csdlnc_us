"""KB09 – Hoàn thành buổi PT (chốt hoa hồng theo chi nhánh công tác tại ngày tập) và CN05 – Hủy lịch."""
import datetime as dt

import pyodbc
import streamlit as st

from db import goi_proc, loi_de_doc

st.set_page_config(page_title="Hoàn thành / Hủy buổi PT", layout="wide")
st.title("Hoàn thành / Hủy buổi PT (KB09)")

if "tb_buoi_pt" in st.session_state:
    loai, noi_dung, chi_tiet = st.session_state.pop("tb_buoi_pt")
    (st.success if loai == "ok" else st.error)(noi_dung)
    if chi_tiet is not None:
        st.dataframe(chi_tiet, hide_index=True)

c1, c2 = st.columns(2)
ma_pt = c1.text_input("Mã PT", value="NV0001").strip()
ngay = c2.date_input("Ngày tập", value=dt.date.today())

try:
    lich, _ = goi_proc("sp_XemLichPT", MaPT=ma_pt, TuNgay=ngay, DenNgay=ngay)
except pyodbc.Error as loi:
    st.error(loi_de_doc(loi))
    st.stop()

st.dataframe(lich, hide_index=True)
da_dat = lich[lich["TrangThaiLich"] == "DA_DAT"]
if da_dat.empty:
    st.info("Không có buổi nào ở trạng thái Đã đặt trong ngày này.")
    st.stop()

nhan = {r.MaLichHen: f"{r.MaLichHen} – {str(r.GioBatDau)[:5]} – {r.TenHoiVien}" for r in da_dat.itertuples()}
ma_lich = st.selectbox("Chọn buổi", list(nhan), format_func=nhan.get)

b1, b2 = st.columns(2)
hanh_dong = None
if b1.button("Hoàn thành buổi", type="primary",
             help="Chỉ với buổi hôm nay hoặc đã qua. Chốt tỷ lệ và tiền hoa hồng."):
    hanh_dong = ("sp_HoanThanhBuoiPT", "Hoàn thành")
if b2.button("Hủy lịch", help="Chỉ với buổi hôm nay hoặc tương lai. Trả lại 1 buổi cho gói."):
    hanh_dong = ("sp_HuyLichPT", "Hủy")

if hanh_dong:
    ten_proc, ten = hanh_dong
    try:
        kq, ms = goi_proc(ten_proc, MaLichHen=ma_lich)
        st.session_state["tb_buoi_pt"] = ("ok", f"{kq.at[0, 'ThongBao']} ({ms:.0f} ms).", kq)
    except pyodbc.Error as loi:
        st.session_state["tb_buoi_pt"] = ("loi", f"{ten} thất bại: {loi_de_doc(loi)}", None)
    st.rerun()
