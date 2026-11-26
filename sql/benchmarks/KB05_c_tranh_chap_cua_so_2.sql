/* KB05_c_tranh_chap_cua_so_2.sql  —  Cửa sổ 2 của kịch bản tranh chấp (xem cửa sổ 1 trước)
   Mỗi bước phải chạy TRONG LÚC cửa sổ 1 đang đợi 10 giây.
*/
USE FitLifeHub;
GO

/* BƯỚC 3 (cửa sổ 2, PHẦN TRƯỚC): hội viên HV000002 đặt CÙNG PT, CÙNG giờ.
   Kỳ vọng: báo "Đặt lịch thành công" ngay lập tức – vì lúc kiểm tra, lịch của cửa sổ 1 chưa được ghi.
   Khi cửa sổ 1 hết 10 giây cũng báo thành công => trùng lịch. */
DECLARE @Ngay DATE = DATEADD(DAY, 7, CAST(GETDATE() AS DATE));
EXEC sp_DatLichPT_v0 @MaHV = 'HV000002', @MaDK = 'DKDEMO02', @MaPT = 'NV0001', @MaCN = 'CN01',
                     @NgayTap = @Ngay, @GioBatDau = '07:00';
GO

/* BƯỚC 7 (cửa sổ 2, PHẦN SAU): đặt CÙNG PT, CÙNG giờ bằng bản tối ưu.
   Kỳ vọng: câu lệnh "treo" đến khi cửa sổ 1 xong (bị khóa chờ), rồi báo lỗi 50003
   "PT đã có lịch vào khung giờ này". Không có lịch trùng. */
DECLARE @Ngay DATE = DATEADD(DAY, 7, CAST(GETDATE() AS DATE));
EXEC sp_DatLichPT @MaHV = 'HV000002', @MaDK = 'DKDEMO02', @MaPT = 'NV0001', @MaCN = 'CN01',
                  @NgayTap = @Ngay, @GioBatDau = '07:00';
GO
