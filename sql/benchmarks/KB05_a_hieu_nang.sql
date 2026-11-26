/* KB05_a_hieu_nang.sql  —  Đo chi phí MỘT lần đặt lịch PT, trước và sau tối ưu
   Cách chạy: mở trong SSMS, bật Include Actual Execution Plan (Ctrl+M), chạy TỪNG PHẦN
   (bôi đen từ "PHẦN ..." đến GO, bấm F5). Mỗi phần chạy 3 lần, ghi lại lần thứ 3.
   Chụp tab Messages (logical reads) và tab Execution plan, lưu:
     report/screenshots/KB05_truoc.png, KB05_sau.png

   Dữ liệu không bị thay đổi: mỗi lần đặt nằm trong BEGIN TRAN ... ROLLBACK.
*/
USE FitLifeHub;
GO

/* ===== PHẦN 0: chuẩn bị – dọn khung giờ demo (07:00, 7 ngày sau hôm nay, PT NV0001) ===== */
DECLARE @Ngay DATE = DATEADD(DAY, 7, CAST(GETDATE() AS DATE));
EXEC sp_Demo_DonKhungGio @MaPT = 'NV0001', @NgayTap = @Ngay, @GioBatDau = '07:00';
GO

/* ===== PHẦN 1: TRƯỚC – bỏ các index của Nhân, gọi bản v0 ===== */
DROP INDEX IF EXISTS IX_LICH_HEN_PT_MaPT_NgayTap ON LICH_HEN_PT;
DROP INDEX IF EXISTS UX_LICH_HEN_PT_PT_KhungGio  ON LICH_HEN_PT;
DROP INDEX IF EXISTS UX_LICH_HEN_PT_HV_KhungGio  ON LICH_HEN_PT;

DECLARE @Ngay DATE = DATEADD(DAY, 7, CAST(GETDATE() AS DATE));
SET STATISTICS IO, TIME ON;
BEGIN TRANSACTION;
    EXEC sp_DatLichPT_v0 @MaHV = 'HV000001', @MaDK = 'DKDEMO01', @MaPT = 'NV0001', @MaCN = 'CN01',
                         @NgayTap = @Ngay, @GioBatDau = '07:00';
ROLLBACK TRANSACTION;
SET STATISTICS IO, TIME OFF;
-- Kỳ vọng: plan có Clustered Index Scan trên LICH_HEN_PT (quét ~360.000 dòng để kiểm tra trùng).
GO

/* ===== PHẦN 2: SAU – tạo index (giống 04_indexes_nhan.sql), gọi bản tối ưu ===== */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_LICH_HEN_PT_MaPT_NgayTap')
    CREATE NONCLUSTERED INDEX IX_LICH_HEN_PT_MaPT_NgayTap
        ON LICH_HEN_PT (MaPT, NgayTap, GioBatDau)
        INCLUDE (GioKetThuc, TrangThaiLich, MaHV, MaCNDay);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_LICH_HEN_PT_PT_KhungGio')
    CREATE UNIQUE NONCLUSTERED INDEX UX_LICH_HEN_PT_PT_KhungGio
        ON LICH_HEN_PT (MaPT, NgayTap, GioBatDau) WHERE TrangThaiLich IN ('DA_DAT', 'HOAN_THANH');
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_LICH_HEN_PT_HV_KhungGio')
    CREATE UNIQUE NONCLUSTERED INDEX UX_LICH_HEN_PT_HV_KhungGio
        ON LICH_HEN_PT (MaHV, NgayTap, GioBatDau) WHERE TrangThaiLich IN ('DA_DAT', 'HOAN_THANH');
GO

DECLARE @Ngay DATE = DATEADD(DAY, 7, CAST(GETDATE() AS DATE));
SET STATISTICS IO, TIME ON;
BEGIN TRANSACTION;
    EXEC sp_DatLichPT @MaHV = 'HV000001', @MaDK = 'DKDEMO01', @MaPT = 'NV0001', @MaCN = 'CN01',
                      @NgayTap = @Ngay, @GioBatDau = '07:00';
ROLLBACK TRANSACTION;
SET STATISTICS IO, TIME OFF;
-- Kỳ vọng: Index Seek, logical reads trên LICH_HEN_PT giảm từ vài nghìn xuống một chữ số.
-- Ghi chú cho báo cáo: logical reads của INSERT tăng nhẹ vì phải cập nhật thêm 3 index – đó là cái giá của index.
GO
