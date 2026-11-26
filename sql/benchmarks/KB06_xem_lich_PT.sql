/* KB06_xem_lich_PT.sql  —  Xem lịch 1 tuần của một PT, trước và sau khi có index
   Cùng một proc sp_XemLichPT, chỉ khác có/không có IX_LICH_HEN_PT_MaPT_NgayTap.
   Bật Ctrl+M, chạy từng PHẦN 3 lần, ghi lần thứ 3. Lưu ảnh KB06_truoc.png, KB06_sau.png.
*/
USE FitLifeHub;
GO

/* ===== PHẦN 1: TRƯỚC ===== */
DROP INDEX IF EXISTS IX_LICH_HEN_PT_MaPT_NgayTap ON LICH_HEN_PT;
GO
DECLARE @Tu DATE = CAST(GETDATE() AS DATE), @Den DATE = DATEADD(DAY, 6, CAST(GETDATE() AS DATE));
SET STATISTICS IO, TIME ON;
EXEC sp_XemLichPT @MaPT = 'NV0012', @TuNgay = @Tu, @DenNgay = @Den;
SET STATISTICS IO, TIME OFF;
-- Kỳ vọng: Clustered Index Scan trên PK_LICH_HEN_PT (đọc cả ~360.000 dòng để lấy ~50 dòng).
-- Hai index UX_ (lọc theo trạng thái) KHÔNG dùng được ở đây vì câu này lấy cả lịch đã hủy.
GO

/* ===== PHẦN 2: SAU ===== */
CREATE NONCLUSTERED INDEX IX_LICH_HEN_PT_MaPT_NgayTap
    ON LICH_HEN_PT (MaPT, NgayTap, GioBatDau)
    INCLUDE (GioKetThuc, TrangThaiLich, MaHV, MaCNDay);
GO
DECLARE @Tu DATE = CAST(GETDATE() AS DATE), @Den DATE = DATEADD(DAY, 6, CAST(GETDATE() AS DATE));
SET STATISTICS IO, TIME ON;
EXEC sp_XemLichPT @MaPT = 'NV0012', @TuNgay = @Tu, @DenNgay = @Den;
SET STATISTICS IO, TIME OFF;
-- Kỳ vọng: Index Seek trên IX_LICH_HEN_PT_MaPT_NgayTap, không còn Key Lookup (nhờ INCLUDE),
-- logical reads trên LICH_HEN_PT còn vài trang.
GO

/* ===== PHẦN 3 (tùy chọn, cho báo cáo): vì sao phải viết điều kiện SARGable =====
   Cùng index, nhưng bọc hàm quanh cột NgayTap => index không Seek được theo ngày nữa. */
SET STATISTICS IO ON;
SELECT MaLichHen, NgayTap, GioBatDau
FROM LICH_HEN_PT
WHERE MaPT = 'NV0012' AND MONTH(NgayTap) = 12 AND YEAR(NgayTap) = 2026;     -- không SARGable theo ngày

SELECT MaLichHen, NgayTap, GioBatDau
FROM LICH_HEN_PT
WHERE MaPT = 'NV0012' AND NgayTap >= '2026-12-01' AND NgayTap < '2027-01-01'; -- SARGable
SET STATISTICS IO OFF;
-- So logical reads của 2 câu: câu đầu phải đọc toàn bộ lịch của NV0012 trong cả năm.
GO
