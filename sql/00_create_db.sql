/* 00_create_db.sql
   Tạo CSDL FitLifeHub nếu chưa có. Chạy file này đầu tiên. */
IF DB_ID(N'FitLifeHub') IS NULL
    CREATE DATABASE FitLifeHub;
GO
