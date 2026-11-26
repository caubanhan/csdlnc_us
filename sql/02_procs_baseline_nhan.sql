/* 02_procs_baseline_nhan.sql  —  BẢN CHƯA TỐI ƯU (v0), dùng để đo "TRƯỚC"
   Không sửa các proc này cho tốt hơn: chúng cố tình giữ đúng những lỗi của hệ thống cũ
   để báo cáo có cái so sánh. App gọi bản tối ưu trong 05_procs_nhan.sql.

   sp_DatLichPT_v0        KB05 – kiểm tra trùng bằng "đọc rồi ghi", không khóa, không transaction
   sp_HoanThanhBuoiPT_v0  KB09 – mô phỏng hệ thống cũ: chỉ biết "chi nhánh hiện tại" của PT
   (KB06 không có bản v0 riêng: cùng một proc sp_XemLichPT, đo trước/sau khi tạo index.)
*/
USE FitLifeHub;
GO

CREATE OR ALTER PROCEDURE sp_DatLichPT_v0
    @MaHV      VARCHAR(15),
    @MaDK      VARCHAR(20),
    @MaPT      VARCHAR(15),
    @MaCN      VARCHAR(10),
    @NgayTap   DATE,
    @GioBatDau TIME(0),
    @DelayGiay INT = 0          -- chỉ để demo: kéo dài khoảng hở giữa "kiểm tra" và "ghi"
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Gói PT phải thuộc hội viên, còn hiệu lực, còn buổi
    IF NOT EXISTS (SELECT 1 FROM DANG_KY_GOI
                   WHERE MaDK = @MaDK AND MaHV = @MaHV AND TrangThaiGoi = 'HIEU_LUC'
                     AND SoBuoiPTConLai > 0 AND @NgayTap BETWEEN NgayBatDau AND NgayKetThuc)
        THROW 50001, N'Gói PT không hợp lệ, đã hết hạn hoặc đã hết buổi.', 1;

    -- 2. PT phải công tác tại chi nhánh này vào ngày tập
    IF NOT EXISTS (SELECT 1 FROM LICH_SU_CONG_TAC
                   WHERE MaNV = @MaPT AND MaCN = @MaCN AND TuNgay <= @NgayTap
                     AND (DenNgay IS NULL OR DenNgay >= @NgayTap))
        THROW 50002, N'PT không công tác tại chi nhánh này vào ngày đã chọn.', 1;

    -- 3. LỖ HỔNG: đọc để kiểm tra trùng, KHÔNG giữ khóa. Hai phiên chạy cùng lúc
    --    đều thấy "còn trống" rồi cùng ghi => PT bị trùng lịch (vấn đề 2).
    --    Chưa có index trên (MaPT, NgayTap) nên câu này còn phải quét cả bảng.
    IF EXISTS (SELECT 1 FROM LICH_HEN_PT
               WHERE MaPT = @MaPT AND NgayTap = @NgayTap AND GioBatDau = @GioBatDau
                 AND TrangThaiLich <> 'HUY')
        THROW 50003, N'PT đã có lịch vào khung giờ này.', 1;

    IF @DelayGiay > 0
    BEGIN
        DECLARE @Cho CHAR(8) = CONVERT(CHAR(8), DATEADD(SECOND, @DelayGiay, 0), 108);
        WAITFOR DELAY @Cho;
    END

    -- 4. Ghi (không có transaction: nếu bước UPDATE lỗi thì lịch đã ghi vẫn nằm đó)
    DECLARE @So BIGINT = NEXT VALUE FOR seq_LichHen;
    DECLARE @MaLichHen VARCHAR(20) = 'LH' + RIGHT('0000000000' + CAST(@So AS VARCHAR(10)), 10);

    INSERT INTO LICH_HEN_PT (MaLichHen, MaHV, MaPT, MaDK, MaCNDay, NgayTap, MaKhungGio,
                             GioBatDau, GioKetThuc, TrangThaiLich)
    VALUES (@MaLichHen, @MaHV, @MaPT, @MaDK, @MaCN, @NgayTap,
            'K' + RIGHT('0' + CAST(DATEPART(HOUR, @GioBatDau) AS VARCHAR(2)), 2),
            @GioBatDau, DATEADD(HOUR, 1, @GioBatDau), 'DA_DAT');

    UPDATE DANG_KY_GOI SET SoBuoiPTConLai = SoBuoiPTConLai - 1 WHERE MaDK = @MaDK;

    SELECT @MaLichHen AS MaLichHen, N'Đặt lịch thành công (bản v0)' AS ThongBao;
END
GO

CREATE OR ALTER PROCEDURE sp_HoanThanhBuoiPT_v0
    @MaLichHen VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    -- MÔ PHỎNG HỆ THỐNG CŨ: chỉ lưu "chi nhánh hiện tại" của nhân viên, nên khi chốt buổi tập
    -- thì gán chi nhánh tính hoa hồng = chi nhánh hiện tại của PT, bất kể buổi tập diễn ra lúc nào.
    -- Sai khi PT đã điều chuyển sau ngày tập (vấn đề 5). Tỷ lệ hoa hồng cũng không được chốt,
    -- cuối tháng mới tính theo tỷ lệ lúc đó.
    DECLARE @MaPT VARCHAR(15), @CNHienTai VARCHAR(10);

    SELECT @MaPT = MaPT FROM LICH_HEN_PT WHERE MaLichHen = @MaLichHen AND TrangThaiLich = 'DA_DAT';
    IF @MaPT IS NULL
        THROW 50010, N'Không tìm thấy buổi tập ở trạng thái Đã đặt.', 1;

    SELECT @CNHienTai = MaCN FROM LICH_SU_CONG_TAC WHERE MaNV = @MaPT AND DenNgay IS NULL;

    UPDATE LICH_HEN_PT
    SET TrangThaiLich = 'HOAN_THANH', MaCNDay = @CNHienTai,
        TyLeHoaHongChot = NULL, TienHoaHongPT = NULL
    WHERE MaLichHen = @MaLichHen;

    SELECT @MaLichHen AS MaLichHen, @CNHienTai AS ChiNhanhTinhHoaHong,
           N'Đã hoàn thành (bản v0)' AS ThongBao;
END
GO
