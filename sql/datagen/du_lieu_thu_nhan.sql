/* du_lieu_thu_nhan.sql
   Sinh dữ liệu thử cho các bảng phần của Nhân, viết hoàn toàn bằng T-SQL (không cần Python).
   Chạy sau 01_schema_tam_nhan.sql. Thời gian chạy: khoảng 1–3 phút.

   Kết quả (xấp xỉ):
     CHI_NHANH 12 | NHAN_VIEN 250 (120 PT) | LICH_SU_CONG_TAC ~280 (30 PT có điều chuyển)
     HOI_VIEN 80.000 | DANG_KY_GOI ~40.000 gói PT | LICH_HEN_PT ~360.000 (năm 2026)

   Dữ liệu cố định để demo (luôn có, không ngẫu nhiên):
     HV000001..HV000010 có gói PT còn hiệu lực DKDEMO01..DKDEMO10 (20 buổi, chi nhánh CN01)
     NV0001 là PT ở CN01, không điều chuyển.

   Khi Ngọc viết script sinh dữ liệu chung, có thể gộp file này vào hoặc giữ nguyên phần LICH_HEN_PT.
*/
USE FitLifeHub;
SET NOCOUNT ON;
GO

-- 0. Xóa dữ liệu cũ (con trước, cha sau)
DELETE FROM LICH_HEN_PT;
DELETE FROM DANG_KY_GOI;
DELETE FROM GOI_DICH_VU;
DELETE FROM HOI_VIEN;
DELETE FROM HANG_HOI_VIEN;
DELETE FROM LICH_SU_CONG_TAC;
DELETE FROM HUAN_LUYEN_VIEN;
DELETE FROM NHAN_VIEN;
DELETE FROM CHI_NHANH;

-- Bảng số 1..100.000 dùng để sinh dòng hàng loạt (nhanh hơn vòng lặp WHILE rất nhiều)
DROP TABLE IF EXISTS #So;
SELECT TOP (100000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
INTO #So
FROM sys.all_objects a CROSS JOIN sys.all_objects b;

DECLARE @HomNay DATE = CAST(GETDATE() AS DATE);

-- 1. Chi nhánh
INSERT INTO CHI_NHANH (MaCN, TenCN, DiaChi, TrangThaiHoatDong)
SELECT 'CN' + RIGHT('0' + CAST(i AS VARCHAR(2)), 2),
       N'FitLife ' + CHOOSE(i, N'Quận 1', N'Quận 3', N'Thủ Đức', N'Bình Thạnh', N'Gò Vấp', N'Hà Đông',
                               N'Cầu Giấy', N'Hoàn Kiếm', N'Hải Châu', N'Ninh Kiều', N'Biên Hòa', N'Nha Trang'),
       N'Địa chỉ chi nhánh số ' + CAST(i AS NVARCHAR(5)),
       'HOAT_DONG'
FROM #So WHERE i <= 12;

-- 2. Nhân viên: NV0001..NV0120 là PT, NV0121..NV0250 là nhân viên vận hành
DROP TABLE IF EXISTS #NV;
SELECT i,
       MaNV   = 'NV' + RIGHT('0000' + CAST(i AS VARCHAR(4)), 4),
       CNCu   = 'CN' + RIGHT('0' + CAST((i - 1) % 12 + 1 AS VARCHAR(2)), 2),
       CNMoi  = 'CN' + RIGHT('0' + CAST(i % 12 + 1 AS VARCHAR(2)), 2),
       -- 30 PT (mã chia hết cho 4) được điều chuyển trong khoảng 01/03/2026 – 27/10/2026
       NgayDC = CASE WHEN i <= 120 AND i % 4 = 0
                     THEN DATEADD(DAY, (i * 7) % 240, CAST('2026-03-01' AS DATE)) END
INTO #NV
FROM #So WHERE i <= 250;

INSERT INTO NHAN_VIEN (MaNV, HoTen, SDT, NgayVaoLam, LuongCoBan, LoaiNV)
SELECT MaNV,
       CHOOSE(i % 10 + 1, N'Nguyễn', N'Trần', N'Lê', N'Phạm', N'Hoàng', N'Huỳnh', N'Phan', N'Vũ', N'Võ', N'Đặng')
         + N' ' + CHOOSE((i / 10) % 6 + 1, N'Văn', N'Thị', N'Minh', N'Ngọc', N'Đức', N'Thanh')
         + N' ' + CHOOSE((i / 3) % 15 + 1, N'An', N'Bình', N'Châu', N'Dũng', N'Giang', N'Hà', N'Khoa',
                         N'Linh', N'Mai', N'Nam', N'Phúc', N'Quân', N'Tâm', N'Uyên', N'Vy'),
       '090' + RIGHT('0000000' + CAST(i AS VARCHAR(7)), 7),
       CAST('2024-06-01' AS DATE),
       CASE WHEN i <= 120 THEN 8000000 ELSE 7000000 END,
       CASE WHEN i <= 120 THEN 'PT' ELSE 'VAN_HANH' END
FROM #NV;

INSERT INTO HUAN_LUYEN_VIEN (MaNV, ChuyenMon, ChungChiHanhNghe, TyLeHoaHongMacDinh)
SELECT MaNV,
       CHOOSE(i % 4 + 1, 'GYM', 'YOGA', 'GIAM_CAN', 'PHUC_HOI'),
       'CC-PT-' + RIGHT('0000' + CAST(i AS VARCHAR(4)), 4),
       10 + (i % 4) * 5          -- 10%, 15%, 20%, 25%
FROM #NV WHERE i <= 120;

-- 3. Lịch sử công tác: giai đoạn đầu cho mọi nhân viên, thêm giai đoạn mới cho người được điều chuyển
INSERT INTO LICH_SU_CONG_TAC (MaNV, TuNgay, DenNgay, MaCN, VaiTroTaiCN)
SELECT MaNV, CAST('2025-01-01' AS DATE), DATEADD(DAY, -1, NgayDC), CNCu,
       CASE WHEN i <= 120 THEN 'PT' WHEN i % 3 = 0 THEN 'LE_TAN' WHEN i % 3 = 1 THEN 'BAN_HANG' ELSE 'QUAN_LY' END
FROM #NV;

INSERT INTO LICH_SU_CONG_TAC (MaNV, TuNgay, DenNgay, MaCN, VaiTroTaiCN)
SELECT MaNV, NgayDC, NULL, CNMoi, 'PT'
FROM #NV WHERE NgayDC IS NOT NULL;

-- 4. Hạng và hội viên (80.000 dòng)
INSERT INTO HANG_HOI_VIEN (MaHang, TenHang, MucChiTieuToiThieu, HeSoNhanDiem)
VALUES ('SILVER', N'Silver', 0, 1.0), ('GOLD', N'Gold', 20000000, 1.2), ('PLATINUM', N'Platinum', 50000000, 1.5);

INSERT INTO HOI_VIEN (MaHV, HoTen, SDT, MaTheTuQR, MaHang, DiemHienTai, ChiTieuKy, TrangThaiThe)
SELECT 'HV' + RIGHT('000000' + CAST(i AS VARCHAR(6)), 6),
       CHOOSE(i % 10 + 1, N'Nguyễn', N'Trần', N'Lê', N'Phạm', N'Hoàng', N'Huỳnh', N'Phan', N'Vũ', N'Võ', N'Đặng')
         + N' ' + CHOOSE((i / 10) % 6 + 1, N'Văn', N'Thị', N'Minh', N'Ngọc', N'Đức', N'Thanh')
         + N' ' + CHOOSE((i / 60) % 15 + 1, N'An', N'Bình', N'Châu', N'Dũng', N'Giang', N'Hà', N'Khoa',
                         N'Linh', N'Mai', N'Nam', N'Phúc', N'Quân', N'Tâm', N'Uyên', N'Vy'),
       '091' + RIGHT('0000000' + CAST(i AS VARCHAR(7)), 7),
       'QR' + RIGHT('00000000' + CAST(i AS VARCHAR(8)), 8),
       CASE WHEN i % 10 < 7 THEN 'SILVER' WHEN i % 10 < 9 THEN 'GOLD' ELSE 'PLATINUM' END,
       0, 0, 'HOAT_DONG'
FROM #So WHERE i <= 80000;

-- 5. Gói dịch vụ
INSERT INTO GOI_DICH_VU (MaGoi, TenGoi, LoaiDichVu, ThoiHanNgay, TongBuoiPT, PhamViToanHeThong, DonGiaNiemYet)
VALUES ('GYM03', N'Gym 3 tháng', 'GYM', 90, NULL, 1, 1500000),
       ('GYM12', N'Gym 12 tháng', 'GYM', 365, NULL, 1, 5000000),
       ('YOGA06', N'Yoga 6 tháng', 'YOGA', 180, NULL, 0, 3000000),
       ('SPA01', N'Vé Spa lẻ', 'SPA', 30, NULL, 0, 300000),
       ('PT10', N'PT 1-1 10 buổi', 'PT', 90, 10, 0, 5000000),
       ('PT20', N'PT 1-1 20 buổi', 'PT', 120, 20, 0, 9000000),
       ('PT30', N'PT 1-1 30 buổi', 'PT', 180, 30, 0, 12000000);

-- 6. Đăng ký gói PT (~40.000). Giá trị ngẫu nhiên được "chốt" vào bảng tạm trước,
--    vì NEWID() trong CTE có thể bị tính lại mỗi lần dùng, làm ngày bắt đầu/kết thúc lệch nhau.
DROP TABLE IF EXISTS #DK;
SELECT i,
       MaGoi  = CHOOSE(i % 3 + 1, 'PT10', 'PT20', 'PT30'),
       HVSo   = ABS(CHECKSUM(NEWID())) % 80000 + 1,
       CNSo   = ABS(CHECKSUM(NEWID())) % 12 + 1,
       NgayBD = DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 330, CAST('2026-01-01' AS DATE)),
       Rnd    = ABS(CHECKSUM(NEWID())) % 1000
INTO #DK
FROM #So WHERE i <= 40000;

INSERT INTO DANG_KY_GOI (MaDK, MaHV, MaGoi, MaCNDangKy, MaHD, NgayBatDau, NgayKetThuc, SoBuoiPTConLai, TrangThaiGoi)
SELECT 'DK' + RIGHT('00000000' + CAST(d.i AS VARCHAR(8)), 8),
       'HV' + RIGHT('000000' + CAST(d.HVSo AS VARCHAR(6)), 6),
       d.MaGoi,
       'CN' + RIGHT('0' + CAST(d.CNSo AS VARCHAR(2)), 2),
       NULL,
       d.NgayBD,
       DATEADD(DAY, g.ThoiHanNgay - 1, d.NgayBD),
       d.Rnd % (g.TongBuoiPT + 1),
       CASE WHEN DATEADD(DAY, g.ThoiHanNgay - 1, d.NgayBD) < @HomNay THEN 'HET_HAN'
            WHEN d.NgayBD > @HomNay THEN 'CHO_HIEU_LUC'
            ELSE 'HIEU_LUC' END
FROM #DK d JOIN GOI_DICH_VU g ON g.MaGoi = d.MaGoi;

-- Gói cố định để demo: HV000001..HV000010, còn hiệu lực đến hết năm sau
INSERT INTO DANG_KY_GOI (MaDK, MaHV, MaGoi, MaCNDangKy, MaHD, NgayBatDau, NgayKetThuc, SoBuoiPTConLai, TrangThaiGoi)
SELECT 'DKDEMO' + RIGHT('0' + CAST(i AS VARCHAR(2)), 2),
       'HV' + RIGHT('000000' + CAST(i AS VARCHAR(6)), 6),
       'PT20', 'CN01', NULL, DATEADD(DAY, -10, @HomNay), DATEADD(YEAR, 1, @HomNay), 20, 'HIEU_LUC'
FROM #So WHERE i <= 10;

-- 7. Lịch hẹn PT năm 2026 (~360.000)
--    Ứng viên: 120 PT x 365 ngày x 15 khung giờ (06:00–20:00); giữ ngẫu nhiên khoảng 55%.
--    Mỗi (PT, ngày, giờ) xuất hiện tối đa 1 lần nên dữ liệu gốc không trùng lịch PT.
DROP TABLE IF EXISTS #Slot;
SELECT p.MaNV AS MaPT, p.i AS PTSo, d.Ngay, s.Gio,
       DKRn = ABS(CHECKSUM(NEWID())) % 40000 + 1,
       Rnd  = ABS(CHECKSUM(NEWID())) % 100
INTO #Slot
FROM (SELECT MaNV, i FROM #NV WHERE i <= 120) p
CROSS JOIN (SELECT DATEADD(DAY, i - 1, CAST('2026-01-01' AS DATE)) AS Ngay FROM #So WHERE i <= 365) d
CROSS JOIN (SELECT i + 5 AS Gio FROM #So WHERE i <= 15) s
WHERE ABS(CHECKSUM(NEWID())) % 100 < 55;

-- Đánh số các gói PT để gán ngẫu nhiên cho từng buổi
DROP TABLE IF EXISTS #DKPT;
SELECT ROW_NUMBER() OVER (ORDER BY MaDK) AS rn, MaDK, MaHV, MaGoi
INTO #DKPT
FROM DANG_KY_GOI WHERE MaDK LIKE 'DK0%';

INSERT INTO LICH_HEN_PT (MaLichHen, MaHV, MaPT, MaDK, MaCNDay, NgayTap, MaKhungGio, GioBatDau, GioKetThuc,
                         TrangThaiLich, TyLeHoaHongChot, TienHoaHongPT)
SELECT 'LH' + RIGHT('0000000000' + CAST(ROW_NUMBER() OVER (ORDER BY s.Ngay, s.Gio, s.MaPT) AS VARCHAR(10)), 10),
       dk.MaHV, s.MaPT, dk.MaDK,
       ct.MaCN,                                        -- chi nhánh PT công tác ĐÚNG vào ngày tập
       s.Ngay,
       'K' + RIGHT('0' + CAST(s.Gio AS VARCHAR(2)), 2),
       TIMEFROMPARTS(s.Gio, 0, 0, 0, 0),
       TIMEFROMPARTS(s.Gio + 1, 0, 0, 0, 0),
       tt.TrangThai,
       CASE WHEN tt.TrangThai = 'HOAN_THANH' THEN hlv.TyLeHoaHongMacDinh END,
       CASE WHEN tt.TrangThai = 'HOAN_THANH'
            THEN ROUND(g.DonGiaNiemYet / g.TongBuoiPT * hlv.TyLeHoaHongMacDinh / 100, 0) END
FROM #Slot s
JOIN #DKPT dk            ON dk.rn = s.DKRn
JOIN GOI_DICH_VU g       ON g.MaGoi = dk.MaGoi
JOIN HUAN_LUYEN_VIEN hlv ON hlv.MaNV = s.MaPT
JOIN LICH_SU_CONG_TAC ct ON ct.MaNV = s.MaPT AND ct.TuNgay <= s.Ngay
                        AND (ct.DenNgay IS NULL OR ct.DenNgay >= s.Ngay)
CROSS APPLY (SELECT TrangThai = CASE WHEN s.Ngay >= @HomNay THEN 'DA_DAT'
                                     WHEN s.Rnd < 90 THEN 'HOAN_THANH'
                                     ELSE 'HUY' END) tt;

-- Một hội viên không thể có 2 buổi cùng giờ (khác PT). Dữ liệu ngẫu nhiên có thể tạo ra vài trăm
-- trường hợp như vậy: chuyển bản sau thành HUY để sau này tạo được index duy nhất theo hội viên.
WITH Trung AS (
    SELECT TrangThaiLich, TyLeHoaHongChot, TienHoaHongPT,
           ROW_NUMBER() OVER (PARTITION BY MaHV, NgayTap, GioBatDau ORDER BY MaLichHen) AS rn
    FROM LICH_HEN_PT
    WHERE TrangThaiLich <> 'HUY')
UPDATE Trung SET TrangThaiLich = 'HUY', TyLeHoaHongChot = NULL, TienHoaHongPT = NULL
WHERE rn > 1;

-- Cho sequence chạy tiếp từ sau mã lớn nhất đã sinh
DECLARE @Tiep BIGINT = (SELECT COUNT(*) FROM LICH_HEN_PT) + 1;
DECLARE @Sql NVARCHAR(200) = N'ALTER SEQUENCE seq_LichHen RESTART WITH ' + CAST(@Tiep AS NVARCHAR(20));
EXEC (@Sql);

-- 8. Kiểm tra nhanh
SELECT 'CHI_NHANH' AS Bang, COUNT(*) AS SoDong FROM CHI_NHANH
UNION ALL SELECT 'NHAN_VIEN', COUNT(*) FROM NHAN_VIEN
UNION ALL SELECT 'LICH_SU_CONG_TAC', COUNT(*) FROM LICH_SU_CONG_TAC
UNION ALL SELECT 'HOI_VIEN', COUNT(*) FROM HOI_VIEN
UNION ALL SELECT 'DANG_KY_GOI', COUNT(*) FROM DANG_KY_GOI
UNION ALL SELECT 'LICH_HEN_PT', COUNT(*) FROM LICH_HEN_PT;

SELECT TrangThaiLich, COUNT(*) AS SoBuoi FROM LICH_HEN_PT GROUP BY TrangThaiLich;
GO
