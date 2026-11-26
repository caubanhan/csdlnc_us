"""KB05 – Đặt lịch PT, kèm mô phỏng 2 người đặt cùng lúc (vấn đề 2)."""
import datetime as dt
import time
from concurrent.futures import ThreadPoolExecutor

import pandas as pd
import pyodbc
import streamlit as st

from db import goi_proc, loi_de_doc

st.set_page_config(page_title="Đặt lịch PT", layout="wide")
st.title("Đặt lịch PT (KB05)")

# Thông báo từ lần bấm trước (giữ qua st.rerun)
if "tb_dat_lich" in st.session_state:
    loai, noi_dung = st.session_state.pop("tb_dat_lich")
    (st.success if loai == "ok" else st.error)(noi_dung)


@st.cache_data(ttl=300)
def ds_chi_nhanh() -> pd.DataFrame:
    df, _ = goi_proc("sp_DSChiNhanh")
    return df


# ---------------- Đặt lịch thông thường ----------------
ma_hv = st.text_input("Mã hội viên", value="HV000001",
                      help="HV000001 đến HV000010 luôn có gói PT còn hiệu lực (dữ liệu demo).").strip()
try:
    goi, _ = goi_proc("sp_DSGoiPT_HoiVien", MaHV=ma_hv)
except pyodbc.Error as loi:
    st.error(loi_de_doc(loi))
    st.stop()

if goi is None or goi.empty:
    st.warning("Hội viên này không có gói PT còn hiệu lực và còn buổi.")
    st.stop()

st.caption("Gói PT còn hiệu lực của hội viên")
st.dataframe(goi, hide_index=True)

c1, c2, c3 = st.columns(3)
ma_dk = c1.selectbox("Gói PT", goi["MaDK"].tolist())
cn = ds_chi_nhanh()
ten_cn = dict(zip(cn["MaCN"], cn["TenCN"]))
ma_cn = c2.selectbox("Chi nhánh", list(ten_cn), format_func=lambda m: f"{m} – {ten_cn[m]}")
ngay = c3.date_input("Ngày tập", value=dt.date.today() + dt.timedelta(days=1), min_value=dt.date.today())

pt, _ = goi_proc("sp_DSPT_TheoChiNhanhNgay", MaCN=ma_cn, Ngay=ngay)
if pt is None or pt.empty:
    st.warning("Không có PT nào công tác tại chi nhánh này vào ngày đã chọn.")
    st.stop()
ten_pt = dict(zip(pt["MaPT"], pt["HoTen"]))

c4, c5 = st.columns(2)
ma_pt = c4.selectbox("Huấn luyện viên (PT)", list(ten_pt), format_func=lambda m: f"{m} – {ten_pt[m]}")
gio_df, _ = goi_proc("sp_KhungGioTrong", MaPT=ma_pt, Ngay=ngay)
gio_trong = [] if gio_df is None else gio_df["GioBatDau"].astype(str).str.strip().tolist()
if not gio_trong:
    c5.warning("PT đã kín lịch trong ngày này.")
gio = c5.selectbox("Khung giờ còn trống (60 phút)", gio_trong)

if st.button("Đặt lịch", type="primary", disabled=not gio_trong):
    try:
        kq, ms = goi_proc("sp_DatLichPT", MaHV=ma_hv, MaDK=ma_dk, MaPT=ma_pt, MaCN=ma_cn,
                          NgayTap=ngay, GioBatDau=gio)
        st.session_state["tb_dat_lich"] = (
            "ok", f"{kq.at[0, 'ThongBao']}: mã lịch {kq.at[0, 'MaLichHen']} ({ms:.0f} ms).")
    except pyodbc.Error as loi:
        st.session_state["tb_dat_lich"] = ("loi", loi_de_doc(loi))
    st.rerun()

# ---------------- Mô phỏng tranh chấp ----------------
st.divider()
st.subheader("Mô phỏng: 2 hội viên đặt cùng PT, cùng giờ, cùng một lúc")

ngay_demo = dt.date.today() + dt.timedelta(days=7)
st.write(
    f"Khung giờ thử: PT **NV0001**, chi nhánh **CN01**, ngày **{ngay_demo:%d/%m/%Y}**, **07:00**. "
    "Phiên A (HV000001) kiểm tra xong thì giữ khoảng hở 3 giây rồi mới ghi; "
    "phiên B (HV000002) chen vào sau 0,5 giây."
)
phien_ban = st.radio("Phiên bản proc", ["sp_DatLichPT_v0 – hệ thống cũ", "sp_DatLichPT – đã tối ưu"],
                     horizontal=True)


def dat_mot_phien(proc: str, ma_hv: str, ma_dk: str, cho_truoc: float, khoang_ho: int):
    time.sleep(cho_truoc)
    bat_dau = time.perf_counter()
    try:
        kq, _ = goi_proc(proc, MaHV=ma_hv, MaDK=ma_dk, MaPT="NV0001", MaCN="CN01",
                         NgayTap=ngay_demo, GioBatDau="07:00", DelayGiay=khoang_ho)
        ket_qua, chi_tiet = "Thành công", kq.at[0, "MaLichHen"]
    except pyodbc.Error as loi:
        ket_qua, chi_tiet = "Bị từ chối", loi_de_doc(loi)
    return ma_hv, ket_qua, chi_tiet, round((time.perf_counter() - bat_dau) * 1000)


if st.button("Chạy mô phỏng"):
    proc = "sp_DatLichPT_v0" if phien_ban.startswith("sp_DatLichPT_v0") else "sp_DatLichPT"
    goi_proc("sp_Demo_DonKhungGio", MaPT="NV0001", NgayTap=ngay_demo, GioBatDau="07:00")

    with st.spinner("Hai phiên đang chạy song song..."):
        with ThreadPoolExecutor(max_workers=2) as ex:
            phien_a = ex.submit(dat_mot_phien, proc, "HV000001", "DKDEMO01", 0, 3)
            phien_b = ex.submit(dat_mot_phien, proc, "HV000002", "DKDEMO02", 0.5, 0)
            ket_qua = [phien_a.result(), phien_b.result()]

    st.dataframe(pd.DataFrame(ket_qua, columns=["Hội viên", "Kết quả", "Mã lịch / Lý do", "Thời gian (ms)"]),
                 hide_index=True)

    lich, _ = goi_proc("sp_XemLichPT", MaPT="NV0001", TuNgay=ngay_demo, DenNgay=ngay_demo)
    lich_7h = lich[lich["GioBatDau"].astype(str).str.startswith("07:00") & (lich["TrangThaiLich"] != "HUY")]
    if len(lich_7h) > 1:
        st.error(f"PT NV0001 có {len(lich_7h)} lịch lúc 07:00 → TRÙNG LỊCH (overbooking).")
    else:
        st.success("PT NV0001 chỉ có 1 lịch lúc 07:00 → không trùng.")
    st.dataframe(lich_7h, hide_index=True)

    st.info(
        "Bản v0 chỉ trùng lịch khi CSDL chưa có index duy nhất `UX_LICH_HEN_PT_PT_KhungGio` "
        "(chạy bước 1 của `KB05_b_tranh_chap_cua_so_1.sql` để bỏ index). Nếu index đã có, phiên ghi sau "
        "của v0 bị CSDL chặn bằng lỗi 'duplicate key'. Đó chính là ý nghĩa của ràng buộc ở mức CSDL: "
        "chặn được cả khi code sai. Bản tối ưu thì phiên B phải chờ phiên A xong rồi nhận thông báo dễ hiểu."
    )
