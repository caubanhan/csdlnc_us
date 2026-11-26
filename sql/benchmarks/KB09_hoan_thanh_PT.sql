/* KB09_hoan_thanh_PT.sql  —  Vấn đề 5: chốt hoa hồng đúng chi nhánh khi PT đã điều chuyển
   KB09 khác KB05/KB06: thứ cần so sánh là TÍNH ĐÚNG, không phải tốc độ.
   Bảng LICH_SU_CONG_TAC chỉ vài trăm dòng và đã có khóa chính (MaNV, TuNgay) để Seek,
   nên không cần index mới. Báo cáo nên nói rõ điều này thay vì cố tạo index cho có.
*/
USE FitLifeHub;
GO

/* ===== PHẦN 1: quy mô sai lệch nếu dùng "chi nhánh hiện tại" như hệ thống cũ =====
   Với mỗi buổi đã hoàn thành: so chi nhánh dạy đúng (MaCNDay, đã lưu lúc đặt)
   với chi nhánh hiện tại của PT. */
SELECT COUNT(*)                                                          AS TongBuoiHoanThanh,
       SUM(CASE WHEN l.MaCNDay <> ht.MaCN THEN 1 ELSE 0 END)             AS SoBuoiBiGanSaiChiNhanh,
       SUM(CASE WHEN l.MaCNDay <> ht.MaCN THEN l.TienHoaHongPT ELSE 0 END) AS TienHoaHongBiGanSai
FROM LICH_HEN_PT l
JOIN LICH_SU_CONG_TAC ht ON ht.MaNV = l.MaPT AND ht.DenNgay IS NULL   -- "chi nhánh hiện tại"
WHERE l.TrangThaiLich = 'HOAN_THANH';

-- Chi tiết theo PT bị điều chuyển (dùng làm bảng minh họa trong báo cáo)
SELECT l.MaPT, l.MaCNDay AS ChiNhanhDayThucTe, ht.MaCN AS ChiNhanhHienTai,
       COUNT(*) AS SoBuoi, SUM(l.TienHoaHongPT) AS TienHoaHong
FROM LICH_HEN_PT l
JOIN LICH_SU_CONG_TAC ht ON ht.MaNV = l.MaPT AND ht.DenNgay IS NULL
WHERE l.TrangThaiLich = 'HOAN_THANH' AND l.MaCNDay <> ht.MaCN
GROUP BY l.MaPT, l.MaCNDay, ht.MaCN
ORDER BY l.MaPT;
GO

/* ===== PHẦN 2: chạy thử 1 buổi bằng v0 và bản tối ưu (đều ROLLBACK, không đổi dữ liệu) =====
   Chọn 1 buổi của PT đã điều chuyển, diễn ra TRƯỚC ngày điều chuyển. */
DECLARE @MaLichHen VARCHAR(20) =
    (SELECT TOP (1) l.MaLichHen
     FROM LICH_HEN_PT l
     JOIN LICH_SU_CONG_TAC c ON c.MaNV = l.MaPT AND c.DenNgay IS NOT NULL
                            AND l.NgayTap BETWEEN c.TuNgay AND c.DenNgay
     WHERE l.TrangThaiLich = 'HOAN_THANH'
     ORDER BY l.NgayTap DESC);

SELECT @MaLichHen AS BuoiDungDeThu, MaPT, NgayTap, MaCNDay AS ChiNhanhDayDung
FROM LICH_HEN_PT WHERE MaLichHen = @MaLichHen;

-- 2a. Bản v0: gán theo chi nhánh hiện tại
BEGIN TRANSACTION;
    UPDATE LICH_HEN_PT SET TrangThaiLich = 'DA_DAT', TyLeHoaHongChot = NULL, TienHoaHongPT = NULL
    WHERE MaLichHen = @MaLichHen;
    EXEC sp_HoanThanhBuoiPT_v0 @MaLichHen = @MaLichHen;   -- Kỳ vọng: ChiNhanhTinhHoaHong = chi nhánh MỚI (sai)
ROLLBACK TRANSACTION;

-- 2b. Bản tối ưu: tra lịch sử công tác tại ngày tập, chốt tỷ lệ và tiền
BEGIN TRANSACTION;
    UPDATE LICH_HEN_PT SET TrangThaiLich = 'DA_DAT', TyLeHoaHongChot = NULL, TienHoaHongPT = NULL
    WHERE MaLichHen = @MaLichHen;
    SET STATISTICS IO ON;
    EXEC sp_HoanThanhBuoiPT @MaLichHen = @MaLichHen;      -- Kỳ vọng: ChiNhanhTinhHoaHong = chi nhánh CŨ (đúng)
    SET STATISTICS IO OFF;
ROLLBACK TRANSACTION;
-- Trong plan của 2b: Clustered Index Seek trên PK_LICH_SU_CONG_TAC, logical reads 2–3 trang.
GO
