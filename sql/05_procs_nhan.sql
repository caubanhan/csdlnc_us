/* 05_procs_nhan.sql  —  BẢN ĐÃ TỐI ƯU, ứng dụng gọi các proc này
   Chạy sau 02_procs_baseline_nhan.sql. File này chỉ tạo proc, không tạo index, nên chạy trước
   khi đo "trước" cũng được (các script đo cần sp_XemLichPT và sp_Demo_DonKhungGio từ file này).

   Nghiệp vụ (KB):
     sp_DatLichPT          KB05  Đặt lịch PT – transaction + khóa + index duy nhất (vấn đề 2)
     sp_XemLichPT          KB06  Xem lịch của một PT theo khoảng ngày
     sp_HoanThanhBuoiPT    KB09  Hoàn thành buổi, chốt hoa hồng theo chi nhánh công tác tại ngày tập (vấn đề 5)
     sp_HuyLichPT          CN05  Hủy lịch, trả lại 1 buổi cho gói
   Hỗ trợ màn hình:
     sp_DSChiNhanh, sp_DSPT_TheoChiNhanhNgay, sp_DSGoiPT_HoiVien, sp_KhungGioTrong
   Chỉ dùng cho demo:
     sp_Demo_DonKhungGio

   Mã lỗi tự đặt (THROW 5xxxx) để app hiện thông báo dễ hiểu:
     50001 gói không hợp lệ | 50002 PT không công tác tại chi nhánh | 50003 trùng lịch PT
     50004 giờ không hợp lệ | 50005 ngày đã qua | 50006 hội viên trùng giờ
     50010–50013 hoàn thành buổi | 50020–50022 hủy lịch
*/
USE FitLifeHub;
GO

/* ---------- KB05: Đặt lịch PT ---------- */
CREATE OR ALTER PROCEDURE sp_DatLichPT
    @MaHV      VARCHAR(15),
    @MaDK      VARCHAR(20),
    @MaPT      VARCHAR(15),
    @MaCN      VARCHAR(10),
    @NgayTap   DATE,
    @GioBatDau TIME(0),
    @DelayGiay INT = 0          -- chỉ để demo, giống bản v0, để so sánh công bằng
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;          -- lỗi bất kỳ => hủy cả giao dịch, không để dữ liệu dở dang

    IF DATEPART(MINUTE, @GioBatDau) <> 0 OR @GioBatDau < '06:00' OR @GioBatDau > '20:00'
        THROW 50004, N'Khung giờ phải tròn giờ, từ 06:00 đến 20:00.', 1;
    IF @NgayTap < CAST(GETDATE() AS DATE)
        THROW 50005, N'Không thể đặt lịch cho ngày đã qua.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Khóa dòng gói PT (UPDLOCK): hội viên bấm 2 lần liên tiếp thì lần sau phải chờ lần trước xong,
        --    nên số buổi không bị trừ quá.
        DECLARE @SoBuoi INT;
        SELECT @SoBuoi = SoBuoiPTConLai
        FROM DANG_KY_GOI WITH (UPDLOCK, ROWLOCK)
        WHERE MaDK = @MaDK AND MaHV = @MaHV AND TrangThaiGoi = 'HIEU_LUC'
          AND @NgayTap BETWEEN NgayBatDau AND NgayKetThuc;

        IF @SoBuoi IS NULL OR @SoBuoi <= 0
            THROW 50001, N'Gói PT không hợp lệ, đã hết hạn hoặc đã hết buổi.', 1;

        -- 2. PT công tác tại chi nhánh vào ngày tập (Seek trên PK_LICH_SU_CONG_TAC)
        IF NOT EXISTS (SELECT 1 FROM LICH_SU_CONG_TAC
                       WHERE MaNV = @MaPT AND MaCN = @MaCN AND TuNgay <= @NgayTap
                         AND (DenNgay IS NULL OR DenNgay >= @NgayTap))
            THROW 50002, N'PT không công tác tại chi nhánh này vào ngày đã chọn.', 1;

        -- 3. Kiểm tra trùng CÓ GIỮ KHÓA: UPDLOCK + HOLDLOCK khóa cả "khoảng trống" trên index,
        --    nên phiên thứ hai đặt cùng PT/khung giờ phải chờ phiên đầu commit rồi mới đọc,
        --    và khi đó sẽ thấy lịch vừa được đặt.
        IF EXISTS (SELECT 1 FROM LICH_HEN_PT WITH (UPDLOCK, HOLDLOCK)
                   WHERE MaPT = @MaPT AND NgayTap = @NgayTap AND GioBatDau = @GioBatDau
                     AND TrangThaiLich IN ('DA_DAT', 'HOAN_THANH'))
            THROW 50003, N'PT đã có lịch vào khung giờ này. Vui lòng chọn giờ khác.', 1;

        IF EXISTS (SELECT 1 FROM LICH_HEN_PT WITH (UPDLOCK, HOLDLOCK)
                   WHERE MaHV = @MaHV AND NgayTap = @NgayTap AND GioBatDau = @GioBatDau
                     AND TrangThaiLich IN ('DA_DAT', 'HOAN_THANH'))
            THROW 50006, N'Hội viên đã có buổi tập khác vào khung giờ này.', 1;

        IF @DelayGiay > 0
        BEGIN
            DECLARE @Cho CHAR(8) = CONVERT(CHAR(8), DATEADD(SECOND, @DelayGiay, 0), 108);
            WAITFOR DELAY @Cho;
        END

        -- 4. Ghi lịch và trừ buổi trong CÙNG giao dịch
        DECLARE @So BIGINT = NEXT VALUE FOR seq_LichHen;
        DECLARE @MaLichHen VARCHAR(20) = 'LH' + RIGHT('0000000000' + CAST(@So AS VARCHAR(10)), 10);

        INSERT INTO LICH_HEN_PT (MaLichHen, MaHV, MaPT, MaDK, MaCNDay, NgayTap, MaKhungGio,
                                 GioBatDau, GioKetThuc, TrangThaiLich)
        VALUES (@MaLichHen, @MaHV, @MaPT, @MaDK, @MaCN, @NgayTap,
                'K' + RIGHT('0' + CAST(DATEPART(HOUR, @GioBatDau) AS VARCHAR(2)), 2),
                @GioBatDau, DATEADD(HOUR, 1, @GioBatDau), 'DA_DAT');

        UPDATE DANG_KY_GOI SET SoBuoiPTConLai = SoBuoiPTConLai - 1 WHERE MaDK = @MaDK;

        COMMIT TRANSACTION;

        SELECT @MaLichHen AS MaLichHen, N'Đặt lịch thành công' AS ThongBao;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        -- 2601/2627: vi phạm index duy nhất. Lớp chặn cuối cùng vẫn đổi thành thông báo dễ hiểu.
        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 50003, N'PT hoặc hội viên đã có lịch vào khung giờ này (bị chặn bởi ràng buộc duy nhất).', 1;
        THROW;
    END CATCH
END
GO

/* ---------- KB06: Xem lịch của một PT ---------- */
CREATE OR ALTER PROCEDURE sp_XemLichPT
    @MaPT   VARCHAR(15),
    @TuNgay DATE,
    @DenNgay DATE
AS
BEGIN
    SET NOCOUNT ON;
    -- Điều kiện viết dạng so sánh trực tiếp trên cột (SARGable) để dùng được IX_LICH_HEN_PT_MaPT_NgayTap
    SELECT l.MaLichHen, l.NgayTap, l.GioBatDau, l.GioKetThuc, l.TrangThaiLich,
           l.MaHV, hv.HoTen AS TenHoiVien, l.MaCNDay, cn.TenCN
    FROM LICH_HEN_PT l
    JOIN HOI_VIEN hv  ON hv.MaHV = l.MaHV
    JOIN CHI_NHANH cn ON cn.MaCN = l.MaCNDay
    WHERE l.MaPT = @MaPT AND l.NgayTap BETWEEN @TuNgay AND @DenNgay
    ORDER BY l.NgayTap, l.GioBatDau;
END
GO

/* ---------- KB09: Hoàn thành buổi PT, chốt hoa hồng ---------- */
CREATE OR ALTER PROCEDURE sp_HoanThanhBuoiPT
    @MaLichHen VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @MaPT VARCHAR(15), @NgayTap DATE, @MaCNDay VARCHAR(10), @MaDK VARCHAR(20),
                @TrangThai VARCHAR(20), @CNCongTac VARCHAR(10), @TyLe DECIMAL(5,2), @GiaMoiBuoi DECIMAL(18,2);

        SELECT @MaPT = MaPT, @NgayTap = NgayTap, @MaCNDay = MaCNDay, @MaDK = MaDK, @TrangThai = TrangThaiLich
        FROM LICH_HEN_PT WITH (UPDLOCK, ROWLOCK)
        WHERE MaLichHen = @MaLichHen;

        IF @TrangThai IS NULL
            THROW 50010, N'Không tìm thấy buổi tập.', 1;
        IF @TrangThai <> 'DA_DAT'
            THROW 50011, N'Chỉ hoàn thành được buổi tập đang ở trạng thái Đã đặt.', 1;
        IF @NgayTap > CAST(GETDATE() AS DATE)
            THROW 50012, N'Buổi tập chưa diễn ra, chưa thể đánh dấu hoàn thành.', 1;

        -- Chi nhánh PT công tác TẠI NGÀY TẬP (không phải chi nhánh hiện tại).
        -- Seek trên PK_LICH_SU_CONG_TAC (MaNV, TuNgay): lấy giai đoạn bắt đầu gần nhất trước ngày tập.
        SELECT TOP (1) @CNCongTac = MaCN
        FROM LICH_SU_CONG_TAC
        WHERE MaNV = @MaPT AND TuNgay <= @NgayTap AND (DenNgay IS NULL OR DenNgay >= @NgayTap)
        ORDER BY TuNgay DESC;

        IF @CNCongTac IS NULL OR @CNCongTac <> @MaCNDay
            THROW 50013, N'Chi nhánh dạy không khớp chi nhánh công tác của PT tại ngày tập. Cần quản lý kiểm tra.', 1;

        SELECT @TyLe = TyLeHoaHongMacDinh FROM HUAN_LUYEN_VIEN WHERE MaNV = @MaPT;

        SELECT @GiaMoiBuoi = g.DonGiaNiemYet / NULLIF(g.TongBuoiPT, 0)
        FROM DANG_KY_GOI dk JOIN GOI_DICH_VU g ON g.MaGoi = dk.MaGoi
        WHERE dk.MaDK = @MaDK;

        -- Chốt tỷ lệ và tiền hoa hồng ngay lúc hoàn thành: cuối tháng chỉ cần cộng, không tính lại
        UPDATE LICH_HEN_PT
        SET TrangThaiLich   = 'HOAN_THANH',
            TyLeHoaHongChot = @TyLe,
            TienHoaHongPT   = ROUND(@GiaMoiBuoi * @TyLe / 100, 0)
        WHERE MaLichHen = @MaLichHen;

        COMMIT TRANSACTION;

        SELECT @MaLichHen AS MaLichHen, @MaCNDay AS ChiNhanhTinhHoaHong, @TyLe AS TyLeHoaHongChot,
               ROUND(@GiaMoiBuoi * @TyLe / 100, 0) AS TienHoaHongPT, N'Đã hoàn thành buổi tập' AS ThongBao;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* ---------- CN05: Hủy lịch PT ---------- */
CREATE OR ALTER PROCEDURE sp_HuyLichPT
    @MaLichHen VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @MaDK VARCHAR(20), @NgayTap DATE, @TrangThai VARCHAR(20);

        SELECT @MaDK = MaDK, @NgayTap = NgayTap, @TrangThai = TrangThaiLich
        FROM LICH_HEN_PT WITH (UPDLOCK, ROWLOCK)
        WHERE MaLichHen = @MaLichHen;

        IF @TrangThai IS NULL
            THROW 50020, N'Không tìm thấy lịch hẹn.', 1;
        IF @TrangThai <> 'DA_DAT'
            THROW 50021, N'Chỉ hủy được lịch đang ở trạng thái Đã đặt.', 1;
        IF @NgayTap < CAST(GETDATE() AS DATE)
            THROW 50022, N'Không hủy được lịch của ngày đã qua.', 1;

        UPDATE LICH_HEN_PT SET TrangThaiLich = 'HUY' WHERE MaLichHen = @MaLichHen;
        UPDATE DANG_KY_GOI SET SoBuoiPTConLai = SoBuoiPTConLai + 1 WHERE MaDK = @MaDK;

        COMMIT TRANSACTION;

        SELECT @MaLichHen AS MaLichHen, N'Đã hủy lịch, trả lại 1 buổi cho gói' AS ThongBao;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* ---------- Hỗ trợ màn hình ---------- */
CREATE OR ALTER PROCEDURE sp_DSChiNhanh
AS
BEGIN
    SET NOCOUNT ON;
    SELECT MaCN, TenCN FROM CHI_NHANH WHERE TrangThaiHoatDong = 'HOAT_DONG' ORDER BY MaCN;
END
GO

CREATE OR ALTER PROCEDURE sp_DSPT_TheoChiNhanhNgay
    @MaCN VARCHAR(10),
    @Ngay DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT nv.MaNV AS MaPT, nv.HoTen, hlv.ChuyenMon
    FROM LICH_SU_CONG_TAC ct
    JOIN NHAN_VIEN nv        ON nv.MaNV = ct.MaNV
    JOIN HUAN_LUYEN_VIEN hlv ON hlv.MaNV = ct.MaNV
    WHERE ct.MaCN = @MaCN AND ct.TuNgay <= @Ngay AND (ct.DenNgay IS NULL OR ct.DenNgay >= @Ngay)
    ORDER BY nv.MaNV;
END
GO

CREATE OR ALTER PROCEDURE sp_DSGoiPT_HoiVien
    @MaHV VARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT dk.MaDK, g.TenGoi, dk.MaCNDangKy, dk.NgayBatDau, dk.NgayKetThuc, dk.SoBuoiPTConLai
    FROM DANG_KY_GOI dk
    JOIN GOI_DICH_VU g ON g.MaGoi = dk.MaGoi
    WHERE dk.MaHV = @MaHV AND dk.TrangThaiGoi = 'HIEU_LUC'
      AND g.LoaiDichVu = 'PT' AND dk.SoBuoiPTConLai > 0
    ORDER BY dk.NgayKetThuc;
END
GO

CREATE OR ALTER PROCEDURE sp_KhungGioTrong
    @MaPT VARCHAR(15),
    @Ngay DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CONVERT(CHAR(5), TIMEFROMPARTS(h.Gio, 0, 0, 0, 0), 108) AS GioBatDau
    FROM (VALUES (6), (7), (8), (9), (10), (11), (12), (13), (14), (15), (16), (17), (18), (19), (20)) AS h (Gio)
    WHERE NOT EXISTS (SELECT 1 FROM LICH_HEN_PT l
                      WHERE l.MaPT = @MaPT AND l.NgayTap = @Ngay
                        AND l.GioBatDau = TIMEFROMPARTS(h.Gio, 0, 0, 0, 0)
                        AND l.TrangThaiLich IN ('DA_DAT', 'HOAN_THANH'))
      AND (@Ngay > CAST(GETDATE() AS DATE) OR h.Gio > DATEPART(HOUR, GETDATE()))
    ORDER BY h.Gio;
END
GO

/* ---------- CHỈ DÙNG CHO DEMO: dọn một khung giờ để chạy lại kịch bản tranh chấp ---------- */
CREATE OR ALTER PROCEDURE sp_Demo_DonKhungGio
    @MaPT      VARCHAR(15),
    @NgayTap   DATE,
    @GioBatDau TIME(0)
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM LICH_HEN_PT
    WHERE NgayTap = @NgayTap AND GioBatDau = @GioBatDau
      AND (MaPT = @MaPT OR MaHV IN ('HV000001', 'HV000002'));

    UPDATE DANG_KY_GOI SET SoBuoiPTConLai = 20 WHERE MaDK IN ('DKDEMO01', 'DKDEMO02');

    SELECT N'Đã dọn khung giờ demo' AS ThongBao;
END
GO
