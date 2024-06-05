create database QLCaPhe_Official 

use QLCaPhe_Official

create table Ban
(
	idBan int identity not null,
	tenBan nvarchar(20) unique(tenBan),
	trangThai bit,
	constraint PK_Ban primary key(idBan)
)
go

create table Loai
(
	idLoai int identity not null,
	tenLoai nvarchar(30) unique(tenLoai),
	constraint PK_Loai primary key(idLoai)
)
go

create table Mon
(
	idMon int identity not null,
	tenMon nvarchar(30) unique(tenMon),
	idLoai int not null,
	gia int check (gia >= 0),
	moTa ntext,
	trangThai bit not null default 1,
	constraint PK_Mon primary key(idMon),
	constraint FK_Mon_Loai foreign key(idLoai) references Loai(idLoai)
)
go

create table TaiKhoan
(
	idTaiKhoan int identity not null,
	tenHienThi nvarchar(30),
	tenDangNhap char(30),
	matKhau char(30),
	chucVu nvarchar(30),
	constraint PK_TaiKhoan primary key(idTaiKhoan)
)
go

create table HoaDon
(
	idHoaDon int identity not null,
	tenKhachHang nvarchar(30),
	ngayNhap Date not null default getdate(),
	idBan int  not null,
	tongTien int,
	giamGia float,
	thanhToan int,
	trangThai bit not null default 0,
	constraint PK_HoaDon primary key (idHoaDon),
	constraint FK_HoaDon_Ban foreign key (idBan) references Ban(idBan),
)
go

create table ChiTietHoaDon
(
	idHoaDon int not null,
	idMon int not null,
	soLuong int not null default 1,
	gia int not null default 0,
	thanhTien int not null default 0,
	constraint PK_ChiTietHoaDon primary key (idHoaDon, idMon),
	constraint FK_ChiTiet_HoaDon_Mon foreign key(idMon) references Mon(idMon),
	constraint FK_ChiTietHoaDon_HoaDon foreign key(idHoaDon) references HoaDon(idHoaDon)
)
go

-------------------------------------------------------------------------------------
--Phần ràng buộc:
--Nguyễn Quốc Gia Huy: bảng ChiTietHoaDon
--Nguyễn Đình Tiến: bảng HoaDon
--Lương Công Nhã Quân: bảng Ban, bảng Loai
--Nguyễn Đức Phát: bảng Mon, bảng TaiKhoan

-------------------------------------------------------------------------------------
--Nguyễn Quốc Gia Huy
--Cập nhật giá trong chi tiết hóa đơn từ giá trong món và tính thành tiền
create trigger thaoTacCTHD on ChiTietHoaDon
for insert, update
as
declare @sl int
declare @slton int
begin
	if update(SOLUONG)
	begin
		set @sl = isnull((select SOLUONG from inserted), 0) - isnull((select SOLUONG from deleted), 0)
	end
	else 
	begin
		set @sl = isnull((select SOLUONG from inserted), 0)
	end

	update ChiTietHoaDon	
	set gia = (select Mon.gia from Mon where Mon.idMon = (select idMon from inserted))
	where idMon = (select idMon from inserted) and idHoaDon = (select idHoaDon from inserted)

	update ChiTietHoaDon
	set thanhTien = thanhtien + @sl * gia
	where idMon = (select idMon from inserted) and idHoaDon = (select idHoaDon from inserted)
end

--Khi thực hiện thao tác sửa chi tiết hóa đơn sẽ kiểm tra xem hóa đơn đã được thanh toán chưa
create trigger xoaCTHD on ChiTietHoaDon
instead of delete
as
declare @sl int
declare @gia int
begin
	set @sl = (select soLuong from deleted)
	set @gia = (select gia from deleted)

	update HoaDon
	set tongTien = tongTien - @sl * @gia
	where idHoaDon = (select idHoaDon from deleted)

	delete from ChiTietHoaDon where idHoaDon = (select idHoaDon from deleted) and idMon = (select idMon from deleted)
end

--Thông báo khi thêm thêm Bàn đang có khách vào Hóa Đơn
create trigger nhapHoaDon on HoaDon
instead of insert
as
begin
	if (select trangThai from Ban where idBan = (select idBan from inserted)) = 1
	begin
		raiserror(N'Bàn đã có khách', 16, 1)
	end
	else 
	begin
		declare @idban int
		declare @tenkh nvarchar(30)
		set @idban = (select idBan from inserted)
		set @tenkh = (select tenKhachHang from inserted)

		insert into HoaDon(tenKhachHang, idBan)
		values(@tenkh , @idban)
	end
end

-------------------------------------------------------------------------------------
--Nguyễn Đình Tiến
--Thực hiện xóa hết trường tại bảng Món liên quan đến khóa chính bị xóa của trường tại bảng Loại
create trigger XoaLoai on Loai
instead of delete 
as 
	declare @maLoai int
begin
	set @maLoai = (select idLoai from deleted)
	delete from Mon
	where idLoai = @maLoai
end
go

--Thực hiện cập nhập lại tổng tiền của hóa đơn khi thêm, sửa, xóa trong chi tiết hóa đơn 
create trigger updateTongTienHoaDon
on CHITIETHOADON 
for insert, update, delete
as
	declare @maHoaDon int
begin
	if exists(select * from deleted)
		set @maHoaDon = (select idHoaDon from deleted)
	else
		set @maHoaDon = (select idHoaDon from inserted)
	update HoaDon 
	set tongTien = (select sum(thanhTien) from ChiTietHoaDon as CTHD where CTHD.idHoaDon = @maHoaDon) 
	where idHoaDon = @maHoaDon
end
go	

-------------------------------------------------------------------------------------
--Lương Công Nhã Quân
-- Cập nhật giảm giá và tính thanh toán
create trigger trg_HOADON
on HOADON 
for insert, update
as
begin
    DECLARE @idhd CHAR(50);
    DECLARE @tongtien INT;

    SELECT @idhd = i.idHoaDon, @tongtien = i.tongTien
    FROM inserted i;

    if(@tongtien<150000 and @tongtien>=100000)
			begin
				update HOADON
				set GIAMGIA = 0.05 where HOADON.idHoaDon = @idhd
			end
	else if(@tongtien >= 150000)
			begin
				update HOADON
				set GIAMGIA = 0.1 where HOADON.idHoaDon = @idhd
			end
	else
			begin
				update HOADON
				set GIAMGIA = 0 where HOADON.idHoaDon = @idhd
			end
		update HOADON
		set THANHTOAN = tongTien - tongTien*GIAMGIA where HOADON.idHoaDon = @idhd
    
end
go
-- kiểm tra tên đăng nhập đã trùng khi insert
CREATE TRIGGER Trigger_KiemTraTrungDangNhapKhiInsert
ON TaiKhoan
INSTEAD OF INSERT
AS
BEGIN
    IF EXISTS (SELECT 1 FROM TaiKhoan t INNER JOIN inserted i ON t.tenDangNhap = i.tenDangNhap)
    BEGIN
        print N'Tên đăng nhập đã tồn tại. Vui lòng chọn tên đăng nhập khác.'
		ROLLBACK
        RETURN; 
    END
    INSERT INTO TaiKhoan (tenHienThi, tenDangNhap, matKhau, chucVu)
    SELECT tenHienThi, tenDangNhap, matKhau, chucVu
    FROM inserted;
END;
go
--Kiểm tra tên đăng nhập trùng khi update.
CREATE TRIGGER Trigger_KiemTraTrungDangNhapKhiUpdate
ON TaiKhoan
INSTEAD OF UPDATE
AS
BEGIN
    IF EXISTS (SELECT 1 FROM TaiKhoan t INNER JOIN inserted i ON t.tenDangNhap = i.tenDangNhap WHERE t.idTaiKhoan != i.idTaiKhoan)
    BEGIN
        PRINT N'Tên đăng nhập đã tồn tại. Vui lòng chọn tên đăng nhập khác.'
		ROLLBACK
        RETURN; 
    END
    UPDATE t
    SET 
        t.tenHienThi = i.tenHienThi,
        t.tenDangNhap = i.tenDangNhap,
        t.matKhau = i.matKhau,
        t.chucVu = i.chucVu
    FROM TaiKhoan t
    INNER JOIN inserted i ON t.idTaiKhoan = i.idTaiKhoan;
END;
go
-------------------------------------------------------------------------------------
--Nguyễn Đức Phát
--Tự động thêm ngày nhập là ngày hiện hành khi thêm vào một hóa đơn mới
create trigger ngayNhap 
on HoaDon
for insert
as
	declare @ngayNhap datetime
begin 
	update HoaDon
	set ngayNhap = CURRENT_TIMESTAMP
	where idHoaDon is null
end 

--Kiểm tra id Loại được thêm có tồn tại hay không
create trigger themMon on Mon
instead of insert  
as
	declare @name nvarchar(30)
	declare @maLoai int
	declare @price int
	declare @detail nvarchar(100)
begin 
	set @name = (select tenMon from inserted)
	set @price = (select gia from inserted)
	set @detail = (select moTa from inserted)
	set @maLoai = (select idLoai from inserted)
	IF NOT EXISTS (SELECT 1 FROM Loai WHERE idLoai = @maLoai)
		begin 
			insert into Loai(tenLoai)
			values (@name)
			set @maLoai = (select idLoai from Loai where tenLoai = @name)
		end 
	insert into Mon (tenMon,idLoai, gia, moTa)
	values (@name,@maLoai,@price,@detail)
end
-------------------------------------------------------------------------------------
--Lệnh nhập dữ liệu mẫu vào mỗi bảng
-- Bảng Ban
INSERT INTO Ban (tenBan, trangThai) VALUES
('Bàn 1', 0),
('Bàn 2', 0),
('Bàn 3', 0),
('Bàn 4', 0),
('Bàn 5', 0),
('Bàn 6', 0),
('Bàn 7', 0),
('Bàn 8', 0),
('Bàn 9', 0),
('Bàn 10', 0),
('Bàn 11', 0),
('Bàn 12', 0)
go

-- Bảng Loai
INSERT INTO Loai (tenLoai) VALUES
(N'Đồ uống'),
(N'Đồ ăn'),
(N'Khác')
go

-- Bảng Mon
INSERT INTO Mon (tenMon, idLoai, gia, moTa, trangThai) VALUES
(N'Cà phê', 1, 20000, N'Cà phê đắng quá trời đắng', 1)
INSERT INTO Mon (tenMon, idLoai, gia, moTa, trangThai) VALUES
(N'Cà phê sữa', 1, 25000, N'Cà phê đen pha sữa tươi', 1)
INSERT INTO Mon (tenMon, idLoai, gia, moTa, trangThai) VALUES
(N'Bánh mì pate', 2, 35000, N'Bánh mì cuộn pate thơm ngon', 1)
INSERT INTO Mon (tenMon, idLoai, gia, moTa, trangThai) VALUES
(N'Nước ngọt', 1, 15000, N'Nước ngọt có gas', 1)
INSERT INTO Mon (tenMon, idLoai, gia, moTa, trangThai) VALUES
(N'Trà sữa', 1, 25000, N'Trà sữa ngọt ngào', 1)
INSERT INTO Mon (tenMon, idLoai, gia, moTa, trangThai) VALUES
(N'Khăn ướt', 3, 2000, N'Khăn ướt mát lạnh', 1)
INSERT INTO Mon (tenMon, idLoai, gia, moTa, trangThai) VALUES
(N'Bánh bao', 2, 20000, N'Bánh bao 2 trứng', 1)
INSERT INTO Mon (tenMon, idLoai, gia, moTa, trangThai) VALUES
(N'Trà đào', 1, 20000, N'Trà đào ngọt thanh', 1)
INSERT INTO Mon (tenMon, idLoai, gia, moTa, trangThai) VALUES
(N'Bạc xĩu', 1, 25000, N'Sự cân bằng giữa ngọt và đắng', 1)
INSERT INTO Mon (tenMon, idLoai, gia, moTa, trangThai) VALUES
(N'Cacao', 1, 25000, N'Cacao nguyên chất tuyệt ngon', 1)
go

-- Bảng TaiKhoan
INSERT INTO TaiKhoan (tenHienThi, tenDangNhap, matKhau, chucVu) VALUES
(N'Admin', 'admin', 'admin123', N'admin'),
(N'Nhân viên 1', 'nv1', 'nv1123', N'Nhân viên bán hàng'),
(N'Nhân viên 2', 'nv2', 'nv2123', N'Nhân viên phục vụ')
go

-------------------------------------------------------------------------------------
--Viết các thủ tục, hàm, cursor để thực hiện các yêu cầu ở chương 03
--Nguyễn Quốc Gia Huy
--Xóa chi tiết hóa đơn có món sẽ được xóa trong quản lý món
create proc xoaMon_CTHD @idmon int
as
declare @dangban int
begin
	if exists(select * from ChiTietHoaDon cthd where cthd.idMon = @idmon)
		delete from ChiTietHoaDon where idMon = @idmon
	else 
		return
end
--Xóa món
create proc xoaMon @idmon int
as
declare @dangban int
begin
	set @dangban = (select count(*) from ChiTietHoaDon cthd, HoaDon hd where cthd.idMon = @idmon and cthd.idHoaDon = hd.idHoaDon and hd.trangThai = 0)
	if @dangban = 0
	begin
		exec xoaMon_CTHD @idmon 
		delete from Mon where idMon = @idmon
	end
	else 
		rollback
end
--Tính số lượng món ăn trong loại món
create function tinhSLMon_Loai (@idloai int)
returns int
as
begin
	declare @sl int
	set @sl = (select count(*) from Mon where idLoai = @idloai)
	return @sl
end
--Xuất bẳng loại và số lượng các món có trong loại đó
create function xemLoai()
returns @loai table
(
	idLoai int,
	tenLoai nvarchar(30),
	slmon int
)
as
begin
	declare cs_Loai cursor 
	for	
		select idLoai, tenLoai
		from Loai
	open cs_Loai
	declare @id int, @ten nvarchar(30), @slmon int
	fetch next from cs_Loai into @id, @ten
	while(@@FETCH_STATUS = 0)
	begin
		select @slmon = dbo.tinhSLMon_Loai(idLoai)
		from Loai
		where idLoai = @id

		insert into @loai(idLoai, tenLoai, slmon)
		values(@id, @ten, @slmon)

		fetch next from cs_Loai into @id, @ten
	end
	close cs_Loai
	deallocate cs_Loai
	return
end

--Tính tổng tiền hiện tại của các bàn có khách
create function tinhTongTien (@idban int)
returns int
as
begin
	declare @tongtien int 
	if exists(select * from HoaDon where idBan = @idban and trangThai = 0)
		set @tongtien = (select hd.tongTien from HoaDon hd, Ban b where b.idBan = @idban and hd.idBan = b.idBan and b.trangThai = 1)
	else 
		set @tongtien = 0
	return @tongtien
end
--Xem bàn có thêm cột tổng tiền của các bàn có khách
create function xemBan()
returns @ban table
(
	idBan int,
	tenBan nvarchar(30),
	trangThai bit,
	tongTien int
)
as
begin
	declare cs_Ban cursor 
	for	
		select idBan, tenBan, trangThai
		from Ban
	open cs_Ban
	declare @id int, @ten nvarchar(30), @trangthai bit, @tongtien int
	fetch next from cs_Ban into @id, @ten, @trangthai
	while(@@FETCH_STATUS = 0)
	begin
		select @tongtien = dbo.tinhTongTien(idBan)
		from Ban
		where idBan = @id

		insert into @ban(idBan, tenBan, trangThai, tongTien)
		values(@id, @ten, @trangthai, @tongtien)

		fetch next from cs_Ban into @id, @ten, @trangthai
	end
	close cs_Ban
	deallocate cs_Ban
	return
end

drop function xemBan
select * from dbo.xemBan()
--Không được sửa trạng thái bàn khi hóa đơn ở bàn đó chưa được thanh toán hoặc khách chưa đổi bàn
create proc suaBan @id int, @ten nvarchar(30), @trangthai bit
as
begin
	if exists(select * from HoaDon where idBan = @id and trangThai = 0)
		rollback
	else 
		update Ban set tenBan = @ten, trangThai = @trangthai where idBan = @id
end
--Hàm trả về bàn có ký tự đã nhập vào trong tên
create function timBan(@find nvarchar(10))
returns table
as
	return (select * from dbo.xemBan() where tenBan like @find)
--Hàm trả về loại có ký tự đã nhập vào trong tên
create function timLoai(@find nvarchar(10))
returns table 
as
	return (select * from dbo.xemLoai() where tenLoai like @find)
-------------------------------------------------------------------------------------
--Nguyễn Đình Tiến
create proc xemMonTheoLoai 
@idLoai int
as
	begin
		select * from Mon as MA where idLoai = @idLoai
	end
go
-----------------------------
create function timIdHoaDon(@idBan int)
returns int
as
	begin
		return (select idHoaDon from HoaDon where idBan =  @IDBan and trangThai = 'False')
	end
go
-----------------------------
create function thongTinHoaDon(@idHoaDon int)
returns @hoaDon table 
(
	Stt int,
	Name nvarchar(30),
	Sl int,
	ThanhTien int
)
as
begin
	declare cursorHoaDon cursor for 
	select ROW_NUMBER() OVER (ORDER BY MA.tenMon) AS [STT], MA.tenMon as [Name], ttHD.soLuong as [Số Lượng], ttHD.soLuong * MA.gia as [Thành tiền] from Mon as MA, ChiTietHoaDon as ttHD, HoaDon as HD where MA.idMon = ttHD.idMon and ttHD.idHoaDon = @idHoaDon and HD.idHoaDon = ttHD.idHoaDon and HD.trangThai = 'false'
	declare @stt int
	declare @name nvarchar(30)
	declare @sl int
	declare @thanhTien int

	open cursorHoaDon
	fetch next from cursorHoaDon
	into @stt, @name, @sl, @thanhTien
	while @@FETCH_STATUS = 0
		begin 
			insert into @hoaDon(Stt, Name, Sl, ThanhTien)
			values(@stt, @name, @sl, @thanhTien)
			fetch next from cursorHoaDon
			into @stt, @name, @sl, @thanhTien
		end
	close cursorHoaDon
	return
end
go
-----------------------------
create function thongTinLoai()
returns @Loai table 
(
	idLoai int,
	tenLoai nvarchar(30)
)
as
begin
	declare cursorLaoi cursor for 
	select idLoai, tenLoai from Loai
	declare @Id int
	declare @name nvarchar(30)

	open cursorLaoi
	fetch next from cursorLaoi
	into @Id, @name
	while @@FETCH_STATUS = 0
		begin 
			insert into @Loai(idLoai, tenLoai)
			values(@Id, @name)
			fetch next from cursorLaoi
			into @Id, @name
		end
	close cursorLaoi
	return
end
go
-----------------------------
create function loadChiTietHoaDon(@idHoaDon int)
returns int 
as 
	begin
		return (select count(*) from ChiTietHoaDon where idHoaDon = @idHoaDon)
	end
go
-----------------------------
--Thêm thông tin khách hàng và cập nhập
create proc themThongTinKhach @nameGuest nvarchar(30), @idbanDangChon int, @soSanh int
as
begin
	if (@soSanh = 1)
	begin
		insert into HoaDon 
		values(@nameGuest, GETDATE(),@idbanDangChon, 0, 0, 0, 'false')
		update Ban set trangThai = 'true' where idBan = @idbanDangChon
	end
	else 
		return 0
end
go

-------------------------------------------------------------------------------------
--Nguyễn Đức Phát
create proc spDoanhThu
AS
BEGIN
	SELECT SUM(ChiTietHoaDon.thanhTien) as TongTien, MONTH(HoaDon.ngayNhap) as Thang
	FROM ChiTietHoaDon
	INNER JOIN HoaDon ON HoaDon.idHoaDon = ChiTietHoaDon.idHoaDon and HoaDon.trangThai = 'True'
	GROUP BY MONTH(HoaDon.ngayNhap);
END
go

create proc spInHoaDon
@IDHOADON int
as
	begin
	select HoaDon.idHoaDon, idBan, tenMon, soLuong, Mon.gia, thanhTien,tongTien, giamGia, thanhToan
	from ChiTietHoaDon, HoaDon, Mon
	where HoaDon.idHoaDon = ChiTietHoaDon.idHoaDon and Mon.idMon = ChiTietHoaDon.idMon and HoaDon.idHoaDon = @IDHOADON
	end
go

CREATE FUNCTION fc_TongTienOfBill
(
    @idHoaDon int
)
RETURNS int
AS
BEGIN
    DECLARE @tong int;

    SELECT @tong = ISNULL(SUM(thanhTien), 0)
    FROM ChiTietHoaDon
    WHERE idHoaDon = @idHoaDon;

    RETURN @tong;
END
go


go
CREATE FUNCTION fc_TongThanhTienOfDay
(
    @year int,
    @month int,
    @day int
)
RETURNS int
AS
BEGIN
    DECLARE @totalSum int;

    SELECT @totalSum = ISNULL(SUM(thanhToan), 0)
    FROM HoaDon
    WHERE YEAR(ngayNhap) = @year
    AND MONTH(ngayNhap) = @month
    AND DAY(ngayNhap) = @day;

    RETURN @totalSum;
END


DECLARE @idHoaDon int, @tenKhachHang nvarchar(30), @ngayNhap date, @idBan int, @tongTien int, @giamGia float, @thanhToan int, @trangThai bit;

DECLARE HoaDonCursor CURSOR FOR
SELECT idHoaDon, tenKhachHang, ngayNhap, idBan, tongTien, giamGia, thanhToan, trangThai
FROM HoaDon;

OPEN HoaDonCursor;

FETCH NEXT FROM HoaDonCursor INTO @idHoaDon, @tenKhachHang, @ngayNhap, @idBan, @tongTien, @giamGia, @thanhToan, @trangThai;

WHILE @@FETCH_STATUS = 0
BEGIN
    FETCH NEXT FROM HoaDonCursor INTO @idHoaDon, @tenKhachHang, @ngayNhap, @idBan, @tongTien, @giamGia, @thanhToan, @trangThai;
END


CLOSE HoaDonCursor;
DEALLOCATE HoaDonCursor;

DECLARE @idMon int, @soLuong int, @gia int, @thanhTien int;

DECLARE ChiTietCursor CURSOR FOR
SELECT idMon, soLuong, gia, thanhTien
FROM ChiTietHoaDon;

OPEN ChiTietCursor;

FETCH NEXT FROM ChiTietCursor INTO @idMon, @soLuong, @gia, @thanhTien;

WHILE @@FETCH_STATUS = 0
BEGIN
    
    FETCH NEXT FROM ChiTietCursor INTO @idMon, @soLuong, @gia, @thanhTien;
END

CLOSE ChiTietCursor;
DEALLOCATE ChiTietCursor;

-------------------------------------------------------------------------------------
--Lương Công Nhã Quân
-- kiểm tra đăng nhập
select * from TaiKhoan
CREATE PROCEDURE KiemTraDangNhap
    @tenDangNhap char(30),
    @matKhau char(30)
AS
BEGIN
    IF EXISTS (SELECT 1 FROM TaiKhoan WHERE tenDangNhap = @tenDangNhap AND matKhau = @matKhau)
    BEGIN
        SELECT 1; --Thành công
    END
    ELSE
    BEGIN
        SELECT 0; --Thất bại
    END
END;
---
go
-- 
--kiểm tra tình trạng món
CREATE PROCEDURE LayDanhSachMon
AS
BEGIN
    -- Lấy danh sách các món có trạng thái khác 0
    SELECT *
    FROM Mon
    WHERE trangThai != 0;
END;
go

-- function
--- kiểm tra khi quyền
CREATE FUNCTION dbo.PhanQuyenFunction
(
    @tenDangNhap char(30)
)
RETURNS bit
AS
BEGIN
    DECLARE @ketqua bit
    DECLARE @chucVu nvarchar(30)

    -- Lấy chức vụ của tài khoản
    SELECT @chucVu = chucVu
    FROM TaiKhoan
    WHERE tenDangNhap = @tenDangNhap

    -- Phân quyền dựa vào chức vụ
    IF @chucVu = 'Admin'
    BEGIN
        Set @ketqua = 1 
    END
    ELSE 
    BEGIN
        SET @ketqua = 0
    END

    RETURN @ketqua
END
go
-- kiểm tra khi đổi mật khẩu
CREATE FUNCTION dbo.KiemTraXacNhanMatKhau
(
    @tenDangNhap char(30),
    @matKhauCu char(30),
    @matKhauMoi char(30),
    @xacNhanMatKhauMoi char(30)
)
RETURNS bit
AS
BEGIN
    DECLARE @ketQua bit

    -- Kiểm tra xác nhận mật khẩu
    IF @matKhauCu IS NOT NULL AND @matKhauCu = (SELECT matKhau FROM TaiKhoan WHERE tenDangNhap = @tenDangNhap) AND
       @matKhauMoi IS NOT NULL AND @matKhauMoi = @xacNhanMatKhauMoi
    BEGIN
        SET @ketQua = 1 -- Mật khẩu đúng và xác nhận mật khẩu khớp nhau
    END
    ELSE
    BEGIN
        SET @ketQua = 0 -- Mật khẩu không đúng hoặc xác nhận mật khẩu không khớp
    END

    RETURN @ketQua
END;

-- giảm 30% cho tất cả các món khi vào tháng 12
CREATE PROCEDURE ApDungGiamGiaThangMuoiCursor
AS
BEGIN
    DECLARE @CurrentMonth INT;
    SET @CurrentMonth = MONTH(GETDATE());
    IF @CurrentMonth = 12
    BEGIN
        DECLARE @MonId INT;
        DECLARE @Gia INT;
        DECLARE discountCursor CURSOR FOR
        SELECT idMon, gia
        FROM Mon;

        OPEN discountCursor;

        FETCH NEXT FROM discountCursor INTO @MonId, @Gia;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            UPDATE Mon
            SET gia = @Gia * 0.7  
            WHERE idMon = @MonId;

            FETCH NEXT FROM discountCursor INTO @MonId, @Gia;
        END;

        CLOSE discountCursor;
        DEALLOCATE discountCursor;
    END
END;
go
-- 
exec ApDungGiamGiaThangMuoiCursor

-- tính tống hóa thành tiền của Hóa đơn trong chi tiết hóa đơn
CREATE PROCEDURE TongHoaDon
    @idHoaDon int
AS
BEGIN
    DECLARE @thanhTien int
    DECLARE @idMon int
    DECLARE @soLuong int
    DECLARE @gia int
    DECLARE chiTietCursor CURSOR FOR
    SELECT idMon, soLuong, gia
    FROM ChiTietHoaDon
    WHERE idHoaDon = @idHoaDon
    SET @thanhTien = 0
    OPEN chiTietCursor
    FETCH NEXT FROM chiTietCursor INTO @idMon, @soLuong, @gia
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @thanhTien = @thanhTien + (@soLuong * @gia)
        FETCH NEXT FROM chiTietCursor INTO @idMon, @soLuong, @gia
    END
    CLOSE chiTietCursor
    DEALLOCATE chiTietCursor
    PRINT 'Tong thanh tien cua HoaDon ' + CAST(@idHoaDon AS NVARCHAR(10)) + ': ' + CAST(@thanhTien AS NVARCHAR(10))
END
EXEC TongHoaDon @idHoaDon = 1;