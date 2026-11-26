/* 01_schema_tam_nhan.sql  —  BẢN TẠM
   Chỉ gồm các bảng phần của Nhân (KB05, KB06, KB09) cần, đặt tên đúng theo EER.
   Mục đích: Nhân chạy thử được ngay, không phải chờ.
   Khi Ngọc xong sql/01_schema.sql (đủ 21+ bảng) thì chạy file đó THAY CHO file này.

   Quy ước cho cả nhóm (cần Ngọc dùng giống):
   - Cột trạng thái kiểu VARCHAR nên KHÔNG lưu tiếng Việt có dấu (VARCHAR không giữ được dấu).
     Dùng mã không dấu: 'DA_DAT', 'HOAN_THANH', 'HUY', 'HIEU_LUC', ...
   - Mỗi buổi PT dài 60 phút, bắt đầu tròn giờ từ 06:00 đến 20:00 (giả định GĐ2 trong báo cáo GĐ1).
*/
USE FitLifeHub;
GO

-- Xóa theo thứ tự con trước, cha sau để chạy lại được nhiều lần
DROP TABLE IF EXISTS LICH_HEN_PT, DANG_KY_GOI, GOI_DICH_VU, HOI_VIEN, HANG_HOI_VIEN,
                     LICH_SU_CONG_TAC, HUAN_LUYEN_VIEN, NHAN_VIEN, CHI_NHANH;
DROP SEQUENCE IF EXISTS seq_LichHen;
GO

CREATE TABLE CHI_NHANH (
    MaCN              VARCHAR(10)   NOT NULL CONSTRAINT PK_CHI_NHANH PRIMARY KEY,
    TenCN             NVARCHAR(100) NOT NULL,
    DiaChi            NVARCHAR(255) NULL,
    TrangThaiHoatDong VARCHAR(20)   NOT NULL CONSTRAINT DF_CHI_NHANH_TrangThai DEFAULT 'HOAT_DONG'
        CONSTRAINT CK_CHI_NHANH_TrangThai CHECK (TrangThaiHoatDong IN ('HOAT_DONG', 'TAM_DONG'))
);

CREATE TABLE NHAN_VIEN (
    MaNV        VARCHAR(15)   NOT NULL CONSTRAINT PK_NHAN_VIEN PRIMARY KEY,
    HoTen       NVARCHAR(100) NOT NULL,
    SDT         VARCHAR(15)   NULL,
    NgayVaoLam  DATE          NULL,
    LuongCoBan  DECIMAL(18,2) NULL CONSTRAINT CK_NHAN_VIEN_Luong CHECK (LuongCoBan >= 0),
    LoaiNV      VARCHAR(20)   NOT NULL CONSTRAINT CK_NHAN_VIEN_Loai CHECK (LoaiNV IN ('PT', 'VAN_HANH'))
);

CREATE TABLE HUAN_LUYEN_VIEN (
    MaNV               VARCHAR(15)  NOT NULL CONSTRAINT PK_HUAN_LUYEN_VIEN PRIMARY KEY
        CONSTRAINT FK_HLV_NHAN_VIEN REFERENCES NHAN_VIEN (MaNV),
    ChuyenMon          VARCHAR(50)  NULL,
    ChungChiHanhNghe   VARCHAR(100) NULL,
    TyLeHoaHongMacDinh DECIMAL(5,2) NOT NULL
        CONSTRAINT CK_HLV_TyLe CHECK (TyLeHoaHongMacDinh BETWEEN 0 AND 100)
);

-- Thực thể yếu: mỗi dòng là một giai đoạn công tác [TuNgay, DenNgay] của nhân viên tại một chi nhánh.
-- DenNgay NULL = đang công tác. Khóa chính (MaNV, TuNgay) cũng chính là index để tìm
-- "chi nhánh của PT tại ngày X" (vấn đề 5).
CREATE TABLE LICH_SU_CONG_TAC (
    MaNV        VARCHAR(15) NOT NULL CONSTRAINT FK_LSCT_NHAN_VIEN REFERENCES NHAN_VIEN (MaNV),
    TuNgay      DATE        NOT NULL,
    DenNgay     DATE        NULL,
    MaCN        VARCHAR(10) NOT NULL CONSTRAINT FK_LSCT_CHI_NHANH REFERENCES CHI_NHANH (MaCN),
    VaiTroTaiCN VARCHAR(50) NULL,
    CONSTRAINT PK_LICH_SU_CONG_TAC PRIMARY KEY (MaNV, TuNgay),
    CONSTRAINT CK_LSCT_Ngay CHECK (DenNgay IS NULL OR DenNgay >= TuNgay)
);

CREATE TABLE HANG_HOI_VIEN (
    MaHang             VARCHAR(10)   NOT NULL CONSTRAINT PK_HANG_HOI_VIEN PRIMARY KEY,
    TenHang            NVARCHAR(50)  NOT NULL,
    MucChiTieuToiThieu DECIMAL(18,2) NOT NULL,
    HeSoNhanDiem       FLOAT         NOT NULL
);

CREATE TABLE HOI_VIEN (
    MaHV         VARCHAR(15)   NOT NULL CONSTRAINT PK_HOI_VIEN PRIMARY KEY,
    HoTen        NVARCHAR(100) NOT NULL,
    SDT          VARCHAR(15)   NULL,
    MaTheTuQR    VARCHAR(64)   NOT NULL CONSTRAINT UQ_HOI_VIEN_QR UNIQUE,
    MaHang       VARCHAR(10)   NOT NULL CONSTRAINT FK_HOI_VIEN_HANG REFERENCES HANG_HOI_VIEN (MaHang),
    DiemHienTai  INT           NOT NULL CONSTRAINT DF_HOI_VIEN_Diem DEFAULT 0,
    ChiTieuKy    DECIMAL(18,2) NOT NULL CONSTRAINT DF_HOI_VIEN_ChiTieu DEFAULT 0,
    TrangThaiThe VARCHAR(20)   NOT NULL CONSTRAINT DF_HOI_VIEN_The DEFAULT 'HOAT_DONG'
        CONSTRAINT CK_HOI_VIEN_The CHECK (TrangThaiThe IN ('HOAT_DONG', 'KHOA'))
    -- Ngọc bổ sung: Email, CCCD, GioiTinh, NgaySinh, NgayDangKy (xem mục "Việc cần vá")
);

CREATE TABLE GOI_DICH_VU (
    MaGoi             VARCHAR(15)   NOT NULL CONSTRAINT PK_GOI_DICH_VU PRIMARY KEY,
    TenGoi            NVARCHAR(100) NOT NULL,
    LoaiDichVu        VARCHAR(30)   NOT NULL CONSTRAINT CK_GOI_Loai CHECK (LoaiDichVu IN ('GYM', 'YOGA', 'PT', 'SPA')),
    ThoiHanNgay       INT           NOT NULL CONSTRAINT CK_GOI_ThoiHan CHECK (ThoiHanNgay > 0),
    TongBuoiPT        INT           NULL,
    PhamViToanHeThong BIT           NOT NULL CONSTRAINT DF_GOI_PhamVi DEFAULT 0,   -- EER ghi BOOLEAN, SQL Server dùng BIT
    DonGiaNiemYet     DECIMAL(18,2) NOT NULL CONSTRAINT CK_GOI_DonGia CHECK (DonGiaNiemYet >= 0),
    CONSTRAINT CK_GOI_BuoiPT CHECK ((LoaiDichVu = 'PT' AND TongBuoiPT > 0) OR (LoaiDichVu <> 'PT'))
);

CREATE TABLE DANG_KY_GOI (
    MaDK           VARCHAR(20) NOT NULL CONSTRAINT PK_DANG_KY_GOI PRIMARY KEY,
    MaHV           VARCHAR(15) NOT NULL CONSTRAINT FK_DKG_HOI_VIEN REFERENCES HOI_VIEN (MaHV),
    MaGoi          VARCHAR(15) NOT NULL CONSTRAINT FK_DKG_GOI REFERENCES GOI_DICH_VU (MaGoi),
    MaCNDangKy     VARCHAR(10) NOT NULL CONSTRAINT FK_DKG_CHI_NHANH REFERENCES CHI_NHANH (MaCN),
    MaHD           VARCHAR(20) NULL,   -- FK tới HOA_DON: thêm khi có schema đầy đủ của Ngọc
    NgayBatDau     DATE        NOT NULL,
    NgayKetThuc    DATE        NOT NULL,
    SoBuoiPTConLai INT         NULL CONSTRAINT CK_DKG_SoBuoi CHECK (SoBuoiPTConLai >= 0),
    TrangThaiGoi   VARCHAR(20) NOT NULL CONSTRAINT CK_DKG_TrangThai
        CHECK (TrangThaiGoi IN ('CHO_THANH_TOAN', 'CHO_HIEU_LUC', 'HIEU_LUC', 'HET_HAN', 'HUY')),
    CONSTRAINT CK_DKG_Ngay CHECK (NgayKetThuc >= NgayBatDau)
);

CREATE TABLE LICH_HEN_PT (
    MaLichHen       VARCHAR(20)   NOT NULL CONSTRAINT PK_LICH_HEN_PT PRIMARY KEY,
    MaHV            VARCHAR(15)   NOT NULL CONSTRAINT FK_LHPT_HOI_VIEN REFERENCES HOI_VIEN (MaHV),
    MaPT            VARCHAR(15)   NOT NULL CONSTRAINT FK_LHPT_HLV REFERENCES HUAN_LUYEN_VIEN (MaNV),
    MaDK            VARCHAR(20)   NOT NULL CONSTRAINT FK_LHPT_DANG_KY_GOI REFERENCES DANG_KY_GOI (MaDK),
    MaCNDay         VARCHAR(10)   NOT NULL CONSTRAINT FK_LHPT_CHI_NHANH REFERENCES CHI_NHANH (MaCN),
    NgayTap         DATE          NOT NULL,
    MaKhungGio      VARCHAR(10)   NOT NULL,
    GioBatDau       TIME(0)       NOT NULL,
    GioKetThuc      TIME(0)       NOT NULL,
    TrangThaiLich   VARCHAR(20)   NOT NULL CONSTRAINT CK_LHPT_TrangThai
        CHECK (TrangThaiLich IN ('DA_DAT', 'HOAN_THANH', 'HUY')),
    TyLeHoaHongChot DECIMAL(5,2)  NULL,
    TienHoaHongPT   DECIMAL(18,2) NULL,
    CONSTRAINT CK_LHPT_Gio CHECK (GioKetThuc > GioBatDau)
);

-- Sinh mã lịch hẹn an toàn khi nhiều người đặt cùng lúc (không dùng MAX(...)+1)
CREATE SEQUENCE seq_LichHen AS BIGINT START WITH 1 INCREMENT BY 1;
GO
