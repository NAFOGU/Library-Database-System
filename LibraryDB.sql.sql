--TASK 1
--PART 1

--Creates the library database
CREATE DATABASE LibraryDB;

--ensures that all statements are executed within LibraryDB
USE LibraryDB;
GO

--Creates a  schema for the database
CREATE SCHEMA Records;
GO

--Creates the Memebers table
CREATE TABLE Records.Members (
		MemberID					int NOT NULL PRIMARY KEY IDENTITY(1, 1),
		FirstName					nvarchar(50) NOT NULL,
		LastName						nvarchar(50) NOT NULL,
		AddressLine1				nvarchar(50) NOT NULL,
		AddressLine2				nvarchar(50) NULL,
		Postcode						nvarchar(50) NOT NULL,
		City								nvarchar(50)  NOT NULL,
		DateOfBirth					date NOT NULL,
		Username						nvarchar(50)  NOT NULL,
		PasswordHash				binary(64) NOT NULL,
		Salt								uniqueidentifier NULL,
		EmailAddress				nvarchar(100) UNIQUE NULL CHECK (EmailAddress LIKE '%_@_%._%'),
		TelephoneNumber		nvarchar(20) NULL,
		MembershipStartDate  date NOT NULL,
		MembershipEndDate	 date NULL
		);

--Creates the Catalogue table
CREATE TABLE Records.Catalogue (
		ItemID							int NOT NULL PRIMARY KEY IDENTITY(1, 1),
		ItemTitle						nvarchar(80) NOT NULL,
		ItemType						nvarchar(50) NOT NULL,
		Author							nvarchar(150) NOT NULL,
		YearOfPublication		int NOT NULL,
		ISBN							nvarchar(20) NULL,
		AddedDate					date  NOT NULL,
		CurrentStatus				nvarchar(20) NOT NULL,
		LostOrRemovedDate	date  NULL,
		);

 --Creates the Loans table
CREATE TABLE Records.Loans (
		LoanID							int NOT NULL PRIMARY KEY IDENTITY(1, 1),
		MemberID					int NOT NULL FOREIGN KEY (MemberID) REFERENCES Records.Members (MemberID),
		ItemID							int NOT NULL FOREIGN KEY (ItemID) REFERENCES Records.Catalogue (ItemID),
		LoanDate						date NOT NULL,
		DueDate						date NOT NULL,
		ReturnDate					date NULL,
		OverdueDays				int  NULL,
		OverdueAmount			money NULL,
		);

--Creates the FineRepayments table
CREATE TABLE Records.FineRepayments (
		FineID							int NOT NULL PRIMARY KEY IDENTITY(1, 1),
		LoanID							int NOT NULL FOREIGN KEY (LoanID) REFERENCES Records.Loans (LoanID),
		FineOwed					money NOT NULL,
		AmountRepaid				money NULL,
		OutstandingBalance		money NULL,
		DateOfRepayment		datetime NULL,
		RepaymentMethod		nvarchar(6) NULL,
		);	


--Create the ArchivedMembers table for deleted records in members table

CREATE TABLE Records.ArchivedMembers (
		MemberID					int NOT NULL PRIMARY KEY IDENTITY(1, 1),
		FirstName					nvarchar(50) NOT NULL,
		LastName						nvarchar(50) NOT NULL,
		AddressLine1				nvarchar(50) NOT NULL,
		AddressLine2				nvarchar(50) NULL,
		Postcode						nvarchar(50) NOT NULL,
		City								nvarchar(50)  NULL,
		DateOfBirth					date NOT NULL,
		EmailAddress				nvarchar(100) UNIQUE NULL CHECK (EmailAddress LIKE '%_@_%._%'),
		TelephoneNumber		nvarchar(20) NULL,
		MembershipEndDate	 date NULL
		);


--Creates a trigger on Members table that inserts records into ArchivedMembers table after a record is deleted from Members table
DROP TRIGGER IF EXISTS Records.t_member_delete_archive;
GO
CREATE TRIGGER Records.t_member_delete_archive ON Records.Members
AFTER DELETE
AS 
		BEGIN
		INSERT INTO Records.ArchivedMembers
		(FirstName, LastName, AddressLine1, AddressLine2,
		Postcode, City, DateOfBirth, EmailAddress, TelephoneNumber, MembershipEndDate)
		SELECT
		d.FirstName, d.LastName, d.AddressLine1, d.AddressLine2,
		d.Postcode,d.City, d.DateOfBirth, d.EmailAddress, d.TelephoneNumber, d.MembershipEndDate
		FROM
		deleted d
		END;


--PART 2(a)
--Creates a user-defined function to search for specific items in the Catalogue table

CREATE FUNCTION Records.CatalogueItemSearch(@pattern AS nvarchar(20))
RETURNS TABLE AS
RETURN
	 (SELECT TOP 100 PERCENT c.*
	FROM Records.Catalogue AS c 
	WHERE c.ItemTitle LIKE '%' + @pattern + '%'
	ORDER BY c.YearOfPublication DESC);


--PART 2(b)
--Creates a stored procedure for all items on loan with due date of less than 5 days

CREATE PROCEDURE Records.uspItemsOnLoan
AS
SELECT l.*
FROM Records.Loans l 
WHERE l.DueDate < (GETDATE() + 5) AND l.DueDate > GETDATE();


--PART 2(c)
--Creates a stored procedure that inserts the details of a new member into Members table

CREATE PROCEDURE Records.uspInsertNewMember
		@mFirstName	  nvarchar(50), @mLastName	nvarchar(50), @mAddLine1	nvarchar(50),
		@mAddLine2	  nvarchar(50), @mPostcode		nvarchar(50), @mCity	 nvarchar(50),
		@mDOB	 date, @mUsername	nvarchar(50), @mPassword	nvarchar(50),
		@mEmailAddress	nvarchar(100), @mTelephoneNumber	nvarchar(20), @mMembershipStartDate	date, @mMembershipEndDate date
    
AS
BEGIN
DECLARE @salt UNIQUEIDENTIFIER=NEWID()
    INSERT INTO Records.Members(FirstName, LastName, AddressLine1, AddressLine2, Postcode, City, DateOfBirth, Username, 
											PasswordHash, Salt, EmailAddress, TelephoneNumber, MembershipStartDate, MembershipEndDate)
    VALUES (@mFirstName, @mLastName, @mAddLine1, @mAddLine2, @mPostcode, @mCity, @mDOB, @mUsername, 
					 HASHBYTES('SHA2_512', @mPassword + CAST(@salt AS nvarchar(36))), @salt, @mEmailAddress, 
					 @mTelephoneNumber, @mMembershipStartDate, @mMembershipEndDate)
END;


--Part 2(d)
--Creates a stored proceedure to update a member's last name and telephone number

CREATE PROCEDURE Records.uspUpdateMembersDetails
@mID int, @mLastName nvarchar(50), @mTel nvarchar(20)
AS
	BEGIN
	UPDATE Members
	SET
	LastName =@mLastName, TelephoneNumber = @mTel
	WHERE MemberID = @mID
	END


--PART 3
--Creates a view for members loan history, including the details of the items borrowed and any associated fines

CREATE VIEW Records.LoanHistory (
	LoanID, ItemID, ItemType, ItemTitle, LoanDate, DueDate,  FineOwed, 
	AmountRepaid, DateOfRepayment, RepaymentMethod, OutstandingBalance
	)
AS
SELECT TOP 100 PERCENT
	l.LoanID, c.ItemID, c.ItemType, c.ItemTitle, l.LoanDate, l.DueDate, f.FineOwed, 
	f.AmountRepaid, f.DateOfRepayment, f.RepaymentMethod, f.OutstandingBalance
FROM Records.Loans l
INNER JOIN Records.Catalogue c ON l.ItemID = c.ItemID
INNER JOIN Records.FineRepayments f ON l.LoanID = f.LoanID
ORDER BY l.LoanID;


--PART 4
--Creates a trigger that automatically updates the status of an item to Available when the item is returned

DROP TRIGGER IF EXISTS Records.udtrg_CurrentStatusUpdate
GO
CREATE TRIGGER Records.udtrg_CurrentStatusUpdate
ON Records.Loans
AFTER UPDATE
AS
BEGIN
    IF UPDATE(ReturnDate)
    BEGIN
        UPDATE c
        SET CurrentStatus = 'Available'
        FROM Records.Catalogue c
        INNER JOIN inserted i ON i.ItemID = c.ItemID
        INNER JOIN deleted d ON d.ItemID = c.ItemID
        INNER JOIN Records.Loans l ON l.ItemID = c.ItemID
        WHERE l.ReturnDate > '2023-01-01' 
        AND c.CurrentStatus IN ('On Loan', 'Overdue')
        AND i.ReturnDate != d.ReturnDate;
    END
END


--PART 5
--Creates a function that returns the total number of loans on a specified date

CREATE FUNCTION Records.SpecificDateLoans(@TakeOutDate AS DATE)
RETURNS int
AS
		BEGIN
		RETURN
		(SELECT COUNT(*)
		FROM Records.Loans AS l
		WHERE l.LoanDate = @TakeOutDate)
		END;


--PART 6
--Insert records into members table

INSERT INTO Records.Members
VALUES 
				('Nafisat', 'Ogunleye', '131 Redearth Road', NULL, 'BB3 2AR','Darwen', '1995-02-06', 'Naflat@9875', HASHBYTES('SHA2_512', 'AwwalIretomiwa20#'), 
				NEWID(), 'adenike2014@gmail.com', '07831857056', '2021-01-01', NULL),

				('Abdulhakeem', 'Ajagbe', 'Oxford Centre for Innovation', ' Oxford', 'OX1 1BY','Oxfordshire', '1985-08-31', 'Ajagbe123#', 
				HASHBYTES('SHA2_512', 'Tayelolu@_24'), NEWID(), 'kenny101@gmail.com', '07421967176', '2017-11-23', '2022-11-22'),

				('Rose', 'Lawal', '29, Earl Street', NULL, 'G14 0BA', 'Glasgow', '1991-04-28', 'Emily_12', HASHBYTES('SHA2_512', 'Iyanu@oluwa#'), NEWID(),
				'aminatlawal@gmail.com', '07821345657', '2018-05-18', NULL),

				('Alice', 'Roberts', '121 Little Wind Street', NULL, 'SA1 1ED', 'Swansea', '1981-06-24', 'Alice30#', HASHBYTES('SHA2_512', 'MyPassword$_24'), 
				NEWID(), 'aliceroberts@yahoo.co.uk', '07421967176', '2020-08-11', NULL),

				('Damilola', 'Opoola', '98, Redcar Road', NULL, 'BD10 0DP','Bradford', '1991-01-18', 'Dammy20', HASHBYTES('SHA2_512', 'Moshood@24#'), 
				NEWID(), 'Damyopoola@gmail.com', NULL, '2019-12-15', '2023-01-22');

--Return all records from members table

SELECT *
FROM Records.Members;

--Insert records into catalogue table

INSERT INTO Records.Catalogue
VALUES 
				('Introduction to Data Science', 'Book', 'Nafisat Ogunleye', '2022', '15065-23457', '2023-02-06', 'Available', NULL),

				('The Son', 'DVD', 'Florian Zeller & Christopher Hampton', '2023', NULL,	'2023-03-31', 'On Loan', NULL),

				('A Study on the Fundamentals of Database Design', 'Journal', 'Ben Turner', '2002', NULL, '2002-02-02', 'Available', NULL),

				('Complex Variable Univalent Functions', 'Book', 'Lateef Iyanda', '2015', '20551-56109', '2018-03-19', 'On Loan', NULL),

				('No Time to Die', 'DVD', 'Neal Purvis, Robert Wade, Scott Z. Burns, Cary Joji Fukunaga, Phoebe Waller-Bridge', '2021', NULL, '2022-02-17',
				'Overdue', NULL),

				('Unorthodox Jukebox', 'Music CD', 'Bruno Mars', '2013', NULL, '2014-02-03', 'On Loan', NULL),

				('Night Visions', 'Music CD', 'Imagine Dragons', '2012', NULL, '2012-12-29', 'Available', NULL),

				('The Hitchhikers Guide to the Galaxy', 'Book', 'Douglas Adams', '1979', '10245-98756', '2019-05-17', 'Removed', '2020-10-27' ),

				('Continued Fraction for Attitudes of Female Students Toward Mathematics', 'Journal', 'Nafisat Ogunleye', '2014', NULL, '2015-09-13', 'Available', NULL),
				
				('Army of One', 'DVD', 'Rajiv Joseph, Scott Rothman', '2016', NULL, '2016-12-17', 'Lost', '2020-02-25');

--Returns all records from the Catalogue table
SELECT *
FROM Records.Catalogue;


--Inserts values into Loans table

INSERT INTO Records.Loans
VALUES 
	(2, 5, '2023-03-27', '2023-03-29', NULL, DATEDIFF(day, '2023-03-29', CURRENT_TIMESTAMP), DATEDIFF(day, '2023-03-29', CURRENT_TIMESTAMP) * 0.10),

	(4, 1, '2022-05-19', '2022-05-28', '2022-06-05', DATEDIFF(day, '2022-05-28', '2022-06-05'), DATEDIFF(day, '2022-05-28', '2022-06-05') * 0.10),

	(3, 4, '2023-02-28', '2023-03-28', NULL, DATEDIFF(day, '2023-03-28', CURRENT_TIMESTAMP), DATEDIFF(day, '2023-03-28', CURRENT_TIMESTAMP) * 0.10),

	(3, 1, '2019-07-22', '2019-07-25', '2019-07-25', NULL, NULL),

	(2, 6, '2023-01-13', '2023-01-31', NULL, DATEDIFF(day, '2023-01-31', CURRENT_TIMESTAMP), DATEDIFF(day, '2023-01-31', CURRENT_TIMESTAMP) * 0.10),

	(5, 9, '2020-03-14', '2023-03-20', '2023-03-31', DATEDIFF(day, '2023-03-20', '2023-03-31'), DATEDIFF(day, '2023-03-20', '2023-03-31') * 0.10),
			
	(1, 7, '2019-07-22', '2019-07-23', '2019-07-25', DATEDIFF(day, '2019-07-23', '2019-07-25'), DATEDIFF(day, '2019-07-23', '2019-07-25') * 0.10),

	(5, 2, '2023-03-31', '2023-04-03', '2023-04-03', NULL, NULL),

	(1, 8, '2019-10-22', '2019-10-30', '2019-11-15', DATEDIFF(day, '2019-10-30', '2019-11-15'), DATEDIFF(day, '2019-10-30', '2019-11-15') * 0.10),

	(4, 7, '2017-12-02', '2017-12-05', '2017-12-22', DATEDIFF(day, '2017-12-05', '2017-12-22'), DATEDIFF(day, '2017-12-05', '2017-12-22') * 0.10);

--Returns all the records in the Loans table

SELECT *
FROM Records.Loans


--Inserts values into FineRepayments table

INSERT INTO Records.FineRepayments
VALUES 
				(1, 0.70, NULL, 0.70, NULL, NULL),
				(2, 0.80, 0.60, 0.80-0.60, GETDATE(), 'Cash'),
				(3, 0.80, 0.80, 0.80-0.80, GETDATE(), 'Card'),
				(5, 6.40, 5.00, 6.40-5.00, GETDATE(), 'Card'),
				(6, 1.10, 0.95, 1.10-0.95, GETDATE(), 'Cash'),
				(7, 0.20, NULL, 0.20, NULL, NULL),
				(9, 1.60, 1.60, 1.60-1.60, GETDATE(), 'Cash'),
				(10, 1.70, NULL, 1.70, NULL, NULL);


--Returns all records in the FineRepayments table

SELECT *
FROM Records.FineRepayments



--PART 6: Test the udf, usp, triggers and view created in parts 2 to 5 above

--2(a)
SELECT * from Records.CatalogueItemSearch('the ')

--2(b)
EXEC Records.uspItemsOnLoan;

--2(c)
EXEC Records.uspInsertNewMember 
					@mFirstName  = 'Kimberly', @mLastName  = 'Daher', @mAddLine1  = '129, Alice Street', @mAddLine2  = NULL, @mPostcode  = 'BB3 3AD', 
					@mCity  = 'Darwen', @mDOB  = '1996-05-21', @mUsername  = 'TisCur19', @mPassword  = 'Daher_@56', @mEmailAddress  = 'kimcurt@gmail.com', 
					@mTelephoneNumber  = '07845979435', @mMembershipStartDate = '2022-10-25', @mMembershipEndDate  = NULL;

SELECT *
FROM Records.Members
WHERE FirstName = 'Kimberly';

--2(d)
Exec Records.uspUpdateMembersDetails @mID = '3', @mLastName = 'Rodgers', @mTel = '07842567235'

SELECT *
FROM Records.Members
WHERE LastName = 'Rodgers';

--3
SELECT *
FROM Records.LoanHistory

--4
--Updates the ReturnDate of an item and the trigger on the table is executed

UPDATE Records.Loans
SET ReturnDate = '2023-04-05'
WHERE ItemID = 6;


SELECT *
FROM Records.Catalogue
WHERE ItemID = 6

SELECT *
FROM Records.Loans
WHERE ItemID = 6

--5
SELECT Records.SpecificDateLoans('2023-03-27') AS TotalLoans

--Archived Members table
--Alters the Loans and FineRepayments tablles to allow cascading delete

ALTER TABLE Records.Loans
DROP CONSTRAINT [FK__Loans__MemberID__1332DBDC]

ALTER TABLE Records.Loans
ADD CONSTRAINT [FK__Loans__MemberID__1332DBDC]  FOREIGN KEY (MemberID) REFERENCES Records.Members (MemberID)
ON DELETE CASCADE;

ALTER TABLE Records.FineRepayments
DROP CONSTRAINT FK__FineRepay__LoanI__19DFD96B


ALTER TABLE Records.FineRepayments
ADD CONSTRAINT FK__FineRepay__LoanI__19DFD96B  FOREIGN KEY (LoanID) REFERENCES Records.Loans (LoanID)
ON DELETE CASCADE;

--Deletethe record of a member from Members table
DELETE FROM Records.Members
WHERE LastName = 'Ajagbe'

--Verify that the details of the member has been removed from Members table
SELECT *
FROM Records.Members
WHERE LastName = 'Ajagbe'

--Verify that the details of the deleted member has been inserted into ArchivedMember table
SELECT * 
FROM Records.ArchivedMembers

--PART 7
--Create a user defined function to calculate the number of overdue days

CREATE FUNCTION Records.OverdueDays(@loanDate DATE, @dueDate DATE)
RETURNS INT
AS
BEGIN
		DECLARE @CurrentDate  DATE
		DECLARE @OverdueDays  INT

		SET @CurrentDate = GETDATE()
		SET @OverdueDays = DATEDIFF(day, @dueDate, @CurrentDate)
		RETURN @OverdueDays
END;

--Create a user defined function to calculate overdue amount

CREATE FUNCTION Records.FineOwed(@loanDate DATE, @dueDate DATE, @fineRatePerDay MONEY)
RETURNS MONEY
AS
BEGIN
		DECLARE @CurrentDate  DATE
		DECLARE @OverdueDays  INT
		DECLARE @OverdueFineAmount MONEY

		SET @CurrentDate = GETDATE()
		SET @OverdueDays = DATEDIFF(day, @dueDate, @CurrentDate)
		
		IF @OverdueDays < 0
		BEGIN
			SET @OverdueDays = 0
		END
		
		SET @OverdueFineAmount = @OverdueDays * @fineRatePerDay

		RETURN @OverdueFineAmount
END;

--Return all records from the loans table

SELECT *
FROM Records.Loans

--Calling the functions

SELECT Records.OverdueDays('2023-02-28', '2023-03-28') AS 'Overdue Days'

SELECT Records.FineOwed('2023-02-28', '2023-03-28', 0.10) AS 'Fine Amount'



