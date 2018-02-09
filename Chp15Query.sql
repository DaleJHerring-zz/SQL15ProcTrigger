--1
CREATE PROC Dale.spInsertCategory
@CategoryName varchar(25)
AS
INSERT INTO Categories
VALUES (@CategoryName);

EXEC spInsertCategory @CategoryName = 'Violins';

EXEC spInsertCategory 'Saxophone';

GO;

SELECT *
FROM Categories
ORDER BY CategoryID;

GO;

--2
CREATE FUNCTION Dale.fnDiscountPrice(@ItemID int)
RETURNS money
BEGIN
 RETURN (SELECT (ItemPrice - DiscountAmount) AS DiscountPrice
         FROM OrderItems
		 WHERE @ItemID = ItemID);
END;

GO;

SELECT ItemID, Dale.fnDiscountPrice(3) AS DiscountPrice
FROM OrderItems
WHERE ItemID = 3;

GO;

--3
CREATE FUNCTION Dale.fnItemTotal(@ItemID int)
RETURNS money
BEGIN
 RETURN (SELECT(dale.fnDiscountPrice(@ItemID) * Quantity)
         FROM OrderItems
		 WHERE @ItemID = ItemID);
END;

GO;

SELECT ItemID, Dale.fnItemTotal(5) AS ItemTotal
FROM OrderItems
WHERE ItemID = 5;

GO;

--4
CREATE PROC Dale.spInsertProduct
@CategoryID int, @ProductCode varchar(10), @ProductName varchar(255), @ListPrice money, @DiscountPercent money
AS
IF(@ListPrice < 0 OR @DiscountPercent < 0)
THROW 50001, 'ListPrice or DiscountPercent cannot be negative', 1;
INSERT INTO Products
VALUES
(@CategoryID, @ProductCode, @ProductName, ' ', @ListPrice, @DiscountPercent, GETDATE());

GO;

BEGIN TRY
 EXEC Dale.spInsertProduct 4, 'casio', 'Casio CTK-5000', 300.00, 50.00;
END TRY
BEGIN CATCH
 PRINT CONVERT(varchar, ERROR_MESSAGE());
END CATCH;

BEGIN TRY
 EXEC Dale.spInsertProduct 4, 'yamaha', 'Yamaha CTK-6220', -300.00, 50.00;
END TRY
BEGIN CATCH
 PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH;

GO;

--5
CREATE PROC spUpdateProductDiscount
@ProductId int, @DiscountPercent money
AS
IF(@DiscountPercent < 0)
THROW 50001, 'DiscountPercent cannot be negative', 1;
UPDATE Products
SET DiscountPercent = @DiscountPercent
WHERE ProductID = @ProductID;

GO;

BEGIN TRY
 EXEC spUpdateProductDiscount 11, -50.00;
END TRY
BEGIN CATCH
 PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
 EXEC spUpdateProductDiscount 11, 100.00
END TRY
BEGIN CATCH
 PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH;

GO;

--6
CREATE TRIGGER Dale.Products_UPDATE
ON Products
AFTER UPDATE
AS
BEGIN
IF (SELECT DiscountPercent FROM Inserted) > 100
BEGIN;
THROW 50001, 'DiscountPercent cannot be greater than 100 or negative', 1;
ROLLBACK TRAN;
END;
IF(SELECT DiscountPercent FROM Inserted) < 0
BEGIN;
THROW 50001, 'DiscountPercent cannot be greater than 100 or negative', 1;
ROLLBACK TRAN;
END;
IF(SELECT DiscountPercent FROM Inserted) > 0 
BEGIN
IF(SELECT DiscountPercent FROM Inserted) < 1
BEGIN
UPDATE Products
SET DiscountPercent = DiscountPercent * 100
WHERE Products.ProductID = (SELECT ProductID FROM Inserted)
END;
END;
END;

GO;

BEGIN TRY
UPDATE Products
SET DiscountPercent = -107
WHERE ProductID = 11;
END TRY
BEGIN CATCH
 PRINT 'ERROR: ' + ERROR_MESSAGE()
END CATCH;

BEGIN TRY
UPDATE Products
SET DiscountPercent = .2
WHERE ProductID = 11;
END TRY
BEGIN CATCH
 PRINT 'ERROR: ' + ERROR_MESSAGE()
END CATCH;

GO;

--7
CREATE TRIGGER Dale.Products_INSERT
ON Products
AFTER INSERT
AS
UPDATE Products
SET DateAdded = GETDATE()
WHERE DateAdded IS NULL;

GO;

INSERT INTO Products
VALUES(4, 'yamaha', 'CTK-6240', ' ', 400.00, 35, NULL);

--8
CREATE TABLE Dale.ProductsAudit
(AuditID  INT PRIMARY KEY IDENTITY,
 ProductID INT NULL REFERENCES Products(ProductID),
 CategoryID INT NULL REFERENCES Categories(CategoryID),
 ProductCode VARCHAR(10) NOT NULL,
 ProductName VARCHAR(255) NOT NULL,
 ListPrice MONEY NOT NULL,
 DiscountPercent MONEY NOT NULL,
 DateUpdated DATETIME NULL);

 GO;

CREATE TRIGGER Products_UPDATE
ON ProductsAudit
AFTER UPDATE
AS
INSERT INTO ProductsAudit
SELECT Products.ProductID, Products.CategoryID, Products.ProductCode, Products.ProductName, Products.ListPrice,
       Products.DiscountPercent, Products.DateAdded
FROM Products JOIN ProductsAudit
     ON Products.ProductID = ProductsAudit.ProductID
WHERE Products.ProductID = ProductsAudit.ProductID;

GO;

UPDATE ProductsAudit
SET ProductID = 1;
