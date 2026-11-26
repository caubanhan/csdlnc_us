/* KB05_b_tranh_chap_cua_so_1.sql  —  Chứng minh vấn đề 2: hai người đặt cùng PT, cùng giờ
   Cần 2 cửa sổ truy vấn trong SSMS: file này (cửa sổ 1) và KB05_c_tranh_chap_cua_so_2.sql (cửa sổ 2).
   Chạy TỪNG BƯỚC (bôi đen từ "BƯỚC ..." đến GO, bấm F5) theo đúng thứ tự đánh số,
   xen kẽ giữa 2 cửa sổ như hướng dẫn. Chụp màn hình cả 2 cửa sổ sau mỗi phần.
*/
USE FitLifeHub;
GO

/* ===================== PHẦN TRƯỚC (hệ thống cũ) ===================== */

/* BƯỚC 1 (cửa sổ 1): bỏ 2 index duy nhất để giả lập hệ thống cũ, dọn khung giờ demo */
DROP INDEX IF EXISTS UX_LICH_HEN_PT_PT_KhungGio ON LICH_HEN_PT;
DROP INDEX IF EXISTS UX_LICH_HEN_PT_HV_KhungGio ON LICH_HEN_PT;
DECLARE @Ngay DATE = DATEADD(DAY, 7, CAST(GETDATE() AS DATE));
EXEC sp_Demo_DonKhungGio @MaPT = 'NV0001', @NgayTap = @Ngay, @GioBatDau = '07:00';
GO

/* BƯỚC 2 (cửa sổ 1): hội viên HV000001 đặt NV0001 lúc 07:00. Proc dừng 10 giây giữa "kiểm tra" và "ghi".
   Chạy xong bước này thì trong vòng 10 giây chuyển sang cửa sổ 2, chạy BƯỚC 3. */
DECLARE @Ngay DATE = DATEADD(DAY, 7, CAST(GETDATE() AS DATE));
EXEC sp_DatLichPT_v0 @MaHV = 'HV000001', @MaDK = 'DKDEMO01', @MaPT = 'NV0001', @MaCN = 'CN01',
                     @NgayTap = @Ngay, @GioBatDau = '07:00', @DelayGiay = 10;
GO

/* BƯỚC 4 (cửa sổ 1): xem kết quả. Kỳ vọng: 2 dòng DA_DAT cùng PT, cùng giờ => PT bị trùng lịch. */
DECLARE @Ngay DATE = DATEADD(DAY, 7, CAST(GETDATE() AS DATE));
SELECT MaLichHen, MaHV, MaPT, NgayTap, GioBatDau, TrangThaiLich
FROM LICH_HEN_PT
WHERE MaPT = 'NV0001' AND NgayTap = @Ngay AND GioBatDau = '07:00';
GO

/* ===================== PHẦN SAU (đã tối ưu) ===================== */

/* BƯỚC 5 (cửa sổ 1): dọn 2 lịch trùng vừa tạo, rồi tạo lại 2 index duy nhất */
DECLARE @Ngay DATE = DATEADD(DAY, 7, CAST(GETDATE() AS DATE));
EXEC sp_Demo_DonKhungGio @MaPT = 'NV0001', @NgayTap = @Ngay, @GioBatDau = '07:00';
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_LICH_HEN_PT_PT_KhungGio')
    CREATE UNIQUE NONCLUSTERED INDEX UX_LICH_HEN_PT_PT_KhungGio
        ON LICH_HEN_PT (MaPT, NgayTap, GioBatDau) WHERE TrangThaiLich IN ('DA_DAT', 'HOAN_THANH');
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_LICH_HEN_PT_HV_KhungGio')
    CREATE UNIQUE NONCLUSTERED INDEX UX_LICH_HEN_PT_HV_KhungGio
        ON LICH_HEN_PT (MaHV, NgayTap, GioBatDau) WHERE TrangThaiLich IN ('DA_DAT', 'HOAN_THANH');
GO

/* BƯỚC 6 (cửa sổ 1): đặt lại bằng bản tối ưu, vẫn dừng 10 giây. Trong 10 giây chuyển sang cửa sổ 2, chạy BƯỚC 7. */
DECLARE @Ngay DATE = DATEADD(DAY, 7, CAST(GETDATE() AS DATE));
EXEC sp_DatLichPT @MaHV = 'HV000001', @MaDK = 'DKDEMO01', @MaPT = 'NV0001', @MaCN = 'CN01',
                  @NgayTap = @Ngay, @GioBatDau = '07:00', @DelayGiay = 10;
GO

/* BƯỚC 8 (cửa sổ 1): xem kết quả. Kỳ vọng: chỉ 1 dòng DA_DAT. */
DECLARE @Ngay DATE = DATEADD(DAY, 7, CAST(GETDATE() AS DATE));
SELECT MaLichHen, MaHV, MaPT, NgayTap, GioBatDau, TrangThaiLich
FROM LICH_HEN_PT
WHERE MaPT = 'NV0001' AND NgayTap = @Ngay AND GioBatDau = '07:00';
GO

/* BƯỚC 9 (cửa sổ 1): chứng minh lớp chặn cuối ở mức CSDL – chèn trùng TRỰC TIẾP, bỏ qua mọi proc.
   Kỳ vọng: lỗi 2601 "Cannot insert duplicate key row ... UX_LICH_HEN_PT_PT_KhungGio". */
DECLARE @Ngay DATE = DATEADD(DAY, 7, CAST(GETDATE() AS DATE));
INSERT INTO LICH_HEN_PT (MaLichHen, MaHV, MaPT, MaDK, MaCNDay, NgayTap, MaKhungGio, GioBatDau, GioKetThuc, TrangThaiLich)
VALUES ('LHTHUTRUNG', 'HV000003', 'NV0001', 'DKDEMO03', 'CN01', @Ngay, 'K07', '07:00', '08:00', 'DA_DAT');
GO
