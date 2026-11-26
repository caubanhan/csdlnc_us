# Đặc tả kịch bản – phần của Nhân (KB05, KB06, KB09)

Tần suất lấy từ bảng chức năng B.3 của báo cáo GĐ1. Ba kịch bản này nối tiếp nhau trong cùng một mạch: hội viên **đặt** buổi PT (KB05) → PT và lễ tân **xem lịch** (KB06) → sau buổi tập **đánh dấu hoàn thành** và chốt hoa hồng (KB09). Cuối tháng, KB10 của Ngọc cộng hoa hồng đã chốt ở KB09.

Mã trạng thái dùng trong CSDL (không dấu vì cột kiểu VARCHAR): `DA_DAT` = Đã đặt, `HOAN_THANH` = Đã hoàn thành, `HUY` = Hủy.

---

## KB05 – Đặt lịch PT

| Mục | Nội dung |
| --- | --- |
| Chức năng GĐ1 | CN04 – Đặt lịch hẹn PT (có kiểm tra trùng, số buổi còn lại) |
| Tác nhân | Hội viên, Lễ tân |
| Tần suất | ~1.000 lần/ngày (120 PT × ~8 buổi); dồn vào 17h–20h và cuối tuần. Mức: **Cao** |
| Loại | Đọc + Ghi |
| Vấn đề liên quan | Vấn đề 2 – Xung đột đặt lịch PT (overbooking) |
| Proc | `sp_DatLichPT` (bản tối ưu), `sp_DatLichPT_v0` (bản cũ để so sánh) |

**Tiền điều kiện:** hội viên có gói PT ở trạng thái `HIEU_LUC`, còn buổi (`SoBuoiPTConLai > 0`), và ngày tập nằm trong thời hạn gói.

**Luồng chính**

1. Lễ tân nhập mã hội viên; hệ thống hiện các gói PT còn hiệu lực (`sp_DSGoiPT_HoiVien`).
2. Chọn gói, chi nhánh, ngày tập. Hệ thống hiện các PT công tác tại chi nhánh vào ngày đó (`sp_DSPT_TheoChiNhanhNgay`).
3. Chọn PT. Hệ thống hiện các khung giờ còn trống của PT (`sp_KhungGioTrong`).
4. Chọn khung giờ, bấm Đặt. Hệ thống trong **một giao dịch**:
   1. khóa dòng gói PT và kiểm tra còn buổi;
   2. kiểm tra PT công tác tại chi nhánh vào ngày tập;
   3. kiểm tra PT và hội viên chưa có lịch trong khung giờ đó (có giữ khóa);
   4. thêm dòng `LICH_HEN_PT` trạng thái `DA_DAT`, trừ 1 buổi ở `DANG_KY_GOI`.
5. Hiện mã lịch hẹn vừa tạo.

**Luồng ngoại lệ:** gói không hợp lệ/hết buổi (50001); PT không công tác tại chi nhánh (50002); PT đã có lịch (50003); giờ không tròn hoặc ngoài 06:00–20:00 (50004); ngày đã qua (50005); hội viên trùng giờ (50006). Khi có lỗi thì không có gì được ghi.

**Dữ liệu đọc/ghi (một lần thực hiện)**

| Bảng | Thao tác | Số dòng |
| --- | --- | --- |
| DANG_KY_GOI | Đọc (có khóa) + Sửa | 1 |
| LICH_SU_CONG_TAC | Đọc | 1 |
| LICH_HEN_PT | Đọc (kiểm tra trùng) + Thêm | 0–1 đọc, 1 thêm |

**Mẫu phân tích truy vấn – câu kiểm tra trùng (câu nặng nhất của KB05)**

```sql
SELECT 1 FROM LICH_HEN_PT
WHERE MaPT = @MaPT AND NgayTap = @NgayTap AND GioBatDau = @GioBatDau
  AND TrangThaiLich IN ('DA_DAT', 'HOAN_THANH');
```

| Mục | Nội dung |
| --- | --- |
| Tần suất | ~1.000 lần/ngày, đỉnh trong 17h–20h |
| Bảng | LICH_HEN_PT (~360.000 dòng/năm, tăng ~30.000 dòng/tháng) |
| Thuộc tính chọn (WHERE) | MaPT (=), NgayTap (=), GioBatDau (=), TrangThaiLich (IN) |
| Thuộc tính kết (JOIN) | Không có |
| Sắp xếp / gom nhóm | Không có |
| Thuộc tính trả về | Không có (chỉ cần biết có tồn tại) |
| Yêu cầu | Đúng tuyệt đối khi 2 người đặt đồng thời; nhanh vì nằm trên đường nóng |
| Đề xuất | Index duy nhất có lọc `UX_LICH_HEN_PT_PT_KhungGio (MaPT, NgayTap, GioBatDau) WHERE TrangThaiLich IN ('DA_DAT','HOAN_THANH')`, cộng với transaction và khóa `UPDLOCK, HOLDLOCK` |

**Nhận xét:** Lỗi của hệ thống cũ không nằm ở tốc độ mà ở cách làm "đọc rồi mới ghi" mà không giữ khóa. Hai phiên cùng đọc thấy khung giờ trống, rồi cùng ghi. Chỉ sửa code ứng dụng (ví dụ kiểm tra bằng `IF EXISTS` trong Python) không đủ, vì khoảng hở giữa đọc và ghi vẫn còn. Giải pháp có hai lớp. Lớp 1 là khóa trong giao dịch: phiên sau phải chờ phiên trước xong mới đọc, nên người dùng nhận thông báo dễ hiểu. Lớp 2 là index duy nhất ở mức CSDL: chặn bản ghi trùng từ bất kỳ đường nào, kể cả khi code sai. Lọc theo trạng thái để lịch đã hủy không chiếm khung giờ. Đổi lại, mỗi lần thêm hoặc sửa lịch phải cập nhật thêm index. Chi phí này chấp nhận được vì LICH_HEN_PT chỉ ghi ~2.000 lần/ngày.

**Cách đo:** `sql/benchmarks/KB05_a_hieu_nang.sql` đo logical reads trước/sau. `KB05_b_...` và `KB05_c_...` dùng 2 cửa sổ SSMS để chứng minh trùng lịch xảy ra ở bản cũ và bị chặn ở bản mới. App có nút mô phỏng tương tự.

---

## KB06 – Xem lịch của một PT

| Mục | Nội dung |
| --- | --- |
| Chức năng GĐ1 | CN31 – Xem lịch PT của một PT trong ngày/tuần |
| Tác nhân | PT, Lễ tân |
| Tần suất | ~1.200 lần/ngày (120 PT × 10 lần); sáng và tối. Mức: **Cao** |
| Loại | Chỉ đọc |
| Proc | `sp_XemLichPT @MaPT, @TuNgay, @DenNgay` |

**Luồng chính:** chọn PT và khoảng ngày (mặc định 7 ngày từ hôm nay) → hệ thống trả danh sách buổi tập kèm tên hội viên, chi nhánh dạy, trạng thái, sắp theo ngày và giờ.

**Dữ liệu đọc:** LICH_HEN_PT (~50 dòng/tuần/PT), HOI_VIEN và CHI_NHANH (tra theo khóa chính).

**Mẫu phân tích truy vấn**

```sql
SELECT l.MaLichHen, l.NgayTap, l.GioBatDau, l.GioKetThuc, l.TrangThaiLich,
       l.MaHV, hv.HoTen, l.MaCNDay, cn.TenCN
FROM LICH_HEN_PT l
JOIN HOI_VIEN hv  ON hv.MaHV = l.MaHV
JOIN CHI_NHANH cn ON cn.MaCN = l.MaCNDay
WHERE l.MaPT = @MaPT AND l.NgayTap BETWEEN @TuNgay AND @DenNgay
ORDER BY l.NgayTap, l.GioBatDau;
```

| Mục | Nội dung |
| --- | --- |
| Tần suất | ~1.200 lần/ngày |
| Bảng | LICH_HEN_PT, HOI_VIEN, CHI_NHANH |
| Thuộc tính chọn | MaPT (=), NgayTap (khoảng) |
| Thuộc tính kết | MaHV, MaCNDay |
| Sắp xếp | NgayTap, GioBatDau |
| Thuộc tính trả về | MaLichHen, GioKetThuc, TrangThaiLich, MaHV, MaCNDay + HoTen, TenCN |
| Đề xuất | `IX_LICH_HEN_PT_MaPT_NgayTap (MaPT, NgayTap, GioBatDau) INCLUDE (GioKetThuc, TrangThaiLich, MaHV, MaCNDay)` |

**Nhận xét:** Không có index thì SQL Server phải quét toàn bộ LICH_HEN_PT để lấy khoảng 50 dòng. Index đặt MaPT (so sánh bằng) trước, NgayTap (so sánh khoảng) sau, và GioBatDau ở cuối, nên kết quả đã có sẵn thứ tự của ORDER BY và không cần bước Sort. INCLUDE các cột hiển thị giúp bỏ Key Lookup. Index này cũng phục vụ luôn bước kiểm tra trùng của KB05. Hai index UX_ có lọc theo trạng thái không dùng được cho KB06, vì KB06 cần hiện cả lịch đã hủy. Phần 3 của script đo minh họa thêm: nếu viết `MONTH(NgayTap) = 12` thay vì so sánh khoảng ngày, index không Seek theo ngày được nữa.

---

## KB09 – Hoàn thành buổi PT, chốt hoa hồng

| Mục | Nội dung |
| --- | --- |
| Chức năng GĐ1 | CN06 – Đánh dấu hoàn thành buổi PT (chốt TyLeHoaHongChot, TienHoaHongPT theo chi nhánh dạy) |
| Tác nhân | PT, Lễ tân |
| Tần suất | ~900 lần/ngày, rải cả ngày. Mức: **Trung bình** |
| Loại | Đọc + Ghi |
| Vấn đề liên quan | Vấn đề 5 – Lịch sử điều chuyển và hoa hồng PT |
| Proc | `sp_HoanThanhBuoiPT` (tối ưu), `sp_HoanThanhBuoiPT_v0` (mô phỏng hệ thống cũ), `sp_HuyLichPT` (CN05) |

**Luồng chính**

1. Chọn PT và ngày; hệ thống hiện các buổi `DA_DAT` (dùng `sp_XemLichPT`).
2. Chọn buổi, bấm Hoàn thành. Hệ thống trong một giao dịch:
   1. khóa dòng lịch hẹn, kiểm tra đang `DA_DAT` và ngày tập không ở tương lai;
   2. tìm chi nhánh PT công tác **tại ngày tập** trong LICH_SU_CONG_TAC; nếu khác chi nhánh dạy đã lưu thì báo lỗi để quản lý xử lý;
   3. lấy tỷ lệ hoa hồng của PT và giá mỗi buổi của gói (đơn giá ÷ tổng buổi);
   4. cập nhật `HOAN_THANH`, chốt `TyLeHoaHongChot` và `TienHoaHongPT`.
3. Luồng phụ: bấm Hủy (chỉ với lịch chưa tới ngày) → trạng thái `HUY`, trả lại 1 buổi cho gói.

**Dữ liệu đọc/ghi (một lần thực hiện):** LICH_HEN_PT đọc + sửa 1 dòng; LICH_SU_CONG_TAC đọc 1 dòng; HUAN_LUYEN_VIEN đọc 1 dòng; DANG_KY_GOI và GOI_DICH_VU đọc 1 dòng mỗi bảng.

**Mẫu phân tích truy vấn – tra chi nhánh công tác tại ngày tập**

```sql
SELECT TOP (1) MaCN FROM LICH_SU_CONG_TAC
WHERE MaNV = @MaPT AND TuNgay <= @NgayTap AND (DenNgay IS NULL OR DenNgay >= @NgayTap)
ORDER BY TuNgay DESC;
```

| Mục | Nội dung |
| --- | --- |
| Tần suất | ~900 lần/ngày (KB09) + ~1.000 lần/ngày (bước 2 của KB05) |
| Bảng | LICH_SU_CONG_TAC (vài trăm dòng, tăng ~5 dòng/tháng) |
| Thuộc tính chọn | MaNV (=), TuNgay (≤), DenNgay (≥ hoặc NULL) |
| Sắp xếp | TuNgay giảm dần |
| Đề xuất | Không cần index mới: khóa chính clustered `(MaNV, TuNgay)` đã cho phép Seek |

**Nhận xét:** Vấn đề 5 là vấn đề **đúng/sai**, không phải nhanh/chậm. Hệ thống cũ chỉ biết "chi nhánh hiện tại" của PT, nên buổi dạy trước ngày điều chuyển bị tính hoa hồng cho chi nhánh mới. Thiết kế mới giải bằng hai việc. Thứ nhất, lịch sử công tác có hiệu lực theo khoảng ngày. Thứ hai, mỗi buổi lưu chi nhánh dạy và chốt tiền hoa hồng ngay lúc hoàn thành, nên cuối tháng (KB10) chỉ cần cộng, không phải tính lại. Phần 1 của script đo đếm được bao nhiêu buổi và bao nhiêu tiền hoa hồng sẽ bị gán sai nếu dùng cách cũ. Báo cáo nên ghi rõ không tạo index mới cho KB09 và nói lý do, vì "không thêm index thừa" cũng là một quyết định thiết kế.

---

## Dòng cho ma trận tham chiếu truy vấn (gửi Anh)

Ký hiệu: Đ = đọc, T = thêm, S = sửa, X = xóa; số = lần/ngày.

| KB | LICH_HEN_PT | DANG_KY_GOI | LICH_SU_CONG_TAC | HUAN_LUYEN_VIEN | GOI_DICH_VU | HOI_VIEN | CHI_NHANH | NHAN_VIEN |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| KB05 Đặt lịch PT | Đ 1.000, T 1.000 | Đ 1.000, S 1.000 | Đ 1.000 | | | | | |
| KB06 Xem lịch PT | Đ 1.200 | | | | | Đ 1.200 | Đ 1.200 | |
| KB09 Hoàn thành buổi PT | Đ 900, S 900 | Đ 900 | Đ 900 | Đ 900 | Đ 900 | | | |
| CN05 Hủy lịch (phụ) | Đ 100, S 100 | S 100 | | | | | | |

Nhận xét cho phần của Nhân: LICH_HEN_PT bị đọc ~3.200 lần/ngày nhưng chỉ ghi ~2.000 lần/ngày, nên thêm index cho phía đọc là đáng.
