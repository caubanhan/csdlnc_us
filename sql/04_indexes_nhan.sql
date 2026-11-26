/* 04_indexes_nhan.sql  —  Index cho KB05, KB06, KB09 (phần của Nhân)
   Chạy SAU khi đã đo "trước". Chạy lại nhiều lần được (có kiểm tra tồn tại).

   Cân nhắc chi phí ghi: LICH_HEN_PT có ~1.000 lượt thêm + ~1.000 lượt sửa mỗi ngày nhưng ~2.200 lượt đọc
   (KB05 kiểm tra trùng + KB06 xem lịch). Thêm 3 index làm mỗi lượt ghi chậm hơn một chút,
   chấp nhận được vì tần suất ghi thấp và đọc nằm trên đường nóng (giờ cao điểm 17h–20h).
*/
USE FitLifeHub;
GO

-- (1) KB06 + bước kiểm tra trùng của KB05: tìm lịch theo PT và khoảng ngày.
--     Thứ tự cột: MaPT (so sánh =) trước, NgayTap (so sánh khoảng) sau.
--     INCLUDE các cột hiển thị để không phải quay lại bảng (bỏ Key Lookup).
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_LICH_HEN_PT_MaPT_NgayTap')
    CREATE NONCLUSTERED INDEX IX_LICH_HEN_PT_MaPT_NgayTap
        ON LICH_HEN_PT (MaPT, NgayTap, GioBatDau)
        INCLUDE (GioKetThuc, TrangThaiLich, MaHV, MaCNDay);
GO

-- (2) VẤN ĐỀ 2 – chặn tuyệt đối việc một PT có 2 lịch còn hiệu lực trong cùng khung giờ.
--     Filtered unique index: chỉ tính các lịch chưa hủy, nên lịch đã hủy không chiếm khung giờ.
--     Đây là lớp chặn cuối cùng ở mức CSDL: dù code ứng dụng sai, CSDL vẫn từ chối bản ghi trùng.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_LICH_HEN_PT_PT_KhungGio')
    CREATE UNIQUE NONCLUSTERED INDEX UX_LICH_HEN_PT_PT_KhungGio
        ON LICH_HEN_PT (MaPT, NgayTap, GioBatDau)
        WHERE TrangThaiLich IN ('DA_DAT', 'HOAN_THANH');
GO

-- (3) Một hội viên không thể có 2 buổi PT cùng giờ (với 2 PT khác nhau).
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_LICH_HEN_PT_HV_KhungGio')
    CREATE UNIQUE NONCLUSTERED INDEX UX_LICH_HEN_PT_HV_KhungGio
        ON LICH_HEN_PT (MaHV, NgayTap, GioBatDau)
        WHERE TrangThaiLich IN ('DA_DAT', 'HOAN_THANH');
GO

-- (4) Danh sách gói PT còn hiệu lực của một hội viên (trang Đặt lịch PT).
--     LƯU Ý NHÓM: Anh cũng cần index trên DANG_KY_GOI theo MaHV cho KB01 (check-in).
--     Dùng CHUNG index này, không tạo thêm cái thứ hai gần giống.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_DANG_KY_GOI_MaHV_TrangThai')
    CREATE NONCLUSTERED INDEX IX_DANG_KY_GOI_MaHV_TrangThai
        ON DANG_KY_GOI (MaHV, TrangThaiGoi, NgayKetThuc)
        INCLUDE (MaGoi, NgayBatDau, SoBuoiPTConLai, MaCNDangKy);
GO

-- KB09 không cần index mới: tìm "chi nhánh của PT tại ngày X" dùng khóa chính
-- PK_LICH_SU_CONG_TAC (MaNV, TuNgay) — đã là clustered index, cho phép Seek theo MaNV.
