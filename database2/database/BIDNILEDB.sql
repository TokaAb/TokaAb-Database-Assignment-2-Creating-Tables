
USE BidNile;
GO

CREATE SCHEMA [Identity];
GO

CREATE SCHEMA Operations;
GO

CREATE SCHEMA Catalogue;
GO

CREATE SCHEMA Auctions;
GO

--  City

CREATE TABLE [Identity].City
(
    ID INT IDENTITY(1,1) PRIMARY KEY,

    CityName NVARCHAR(60) NOT NULL,

    CountryCode CHAR(2) NOT NULL
        CONSTRAINT CK_City_Country
        CHECK (CountryCode IN ('EG', 'SA', 'AE'))

CONSTRAINT UQ_City_Name_Country
    UNIQUE (CityName, CountryCode)
);

--Member

CREATE TABLE [Identity].Member
(
    ID UNIQUEIDENTIFIER PRIMARY KEY
        DEFAULT NEWID(),

    FullName NVARCHAR(100) NOT NULL,

    Email VARCHAR(254) NOT NULL UNIQUE,

    Mobile VARCHAR(16) NOT NULL,

    NationalID VARCHAR(20) NOT NULL UNIQUE,

    BirthDate DATE NOT NULL,

    IsVerified BIT NOT NULL DEFAULT 0,

    RegisteredAt DATETIME2(3) NOT NULL
        DEFAULT SYSDATETIME(),

    CityID INT NOT NULL,

    CONSTRAINT FK_Member_City
        FOREIGN KEY (CityID)
        REFERENCES [Identity].City(ID),

    InvitedByMemberID UNIQUEIDENTIFIER NULL,

    CONSTRAINT FK_Member_Inviter
        FOREIGN KEY (InvitedByMemberID)
        REFERENCES [Identity].Member(ID)
);


-- Wallet

CREATE TABLE [Identity].Wallet
(
    WalletID INT IDENTITY(1,1) PRIMARY KEY,

    MemberID UNIQUEIDENTIFIER NOT NULL UNIQUE,

    CONSTRAINT FK_Wallet_Member
        FOREIGN KEY (MemberID)
        REFERENCES [Identity].Member(ID),

    Balance DECIMAL(12,2) NOT NULL DEFAULT 0,

    CONSTRAINT CK_Wallet_Balance
        CHECK (Balance >= 0),

    AmountOnHold DECIMAL(12,2) NOT NULL DEFAULT 0,

    CONSTRAINT CK_Wallet_Hold
        CHECK (AmountOnHold >= 0 AND AmountOnHold <= Balance),

    Currency CHAR(3) NOT NULL DEFAULT 'EGP',

    LastUpdatedAt DATETIME2(3) NOT NULL
        DEFAULT SYSDATETIME()
);


-- Warehouse

CREATE TABLE Operations.Warehouse
(
    ID INT IDENTITY(1,1) PRIMARY KEY,

    WarehouseName NVARCHAR(80) NOT NULL UNIQUE,

    Capacity INT NOT NULL
        CONSTRAINT CK_Warehouse_Capacity
        CHECK (Capacity > 0),

    CityID INT NOT NULL,

    CONSTRAINT FK_Warehouse_City
        FOREIGN KEY (CityID)
        REFERENCES [Identity].City(ID),

    Latitude DECIMAL(10,7) NOT NULL
        CONSTRAINT CK_Warehouse_Latitude
        CHECK (Latitude BETWEEN -90 AND 90),

    Longitude DECIMAL(11,7) NOT NULL
        CONSTRAINT CK_Warehouse_Longitude
        CHECK (Longitude BETWEEN -180 AND 180),

    ManagerEmployeeID UNIQUEIDENTIFIER NULL,

    ManagerStartDate DATE NOT NULL
);


--  Employee

CREATE TABLE Operations.Employee
(
    ID UNIQUEIDENTIFIER PRIMARY KEY,

    CONSTRAINT FK_Employee_Member
        FOREIGN KEY (ID)
        REFERENCES [Identity].Member(ID),

    WarehouseID INT NOT NULL,

    CONSTRAINT FK_Employee_Warehouse
        FOREIGN KEY (WarehouseID)
        REFERENCES Operations.Warehouse(ID),

		CONSTRAINT UQ_Employee_ID_Warehouse
         UNIQUE (ID, WarehouseID)

);


ALTER TABLE Operations.Warehouse
ADD CONSTRAINT FK_Warehouse_Manager
    FOREIGN KEY (ManagerEmployeeID)
    REFERENCES Operations.Employee(ID);
GO

ALTER TABLE Operations.Warehouse
ADD CONSTRAINT UQ_Warehouse_Manager
    UNIQUE (ManagerEmployeeID);
GO


--Category
CREATE TABLE Catalogue.Category
(
    CategoryCode INT PRIMARY KEY,

    EnglishName NVARCHAR(50) NOT NULL UNIQUE,
    ArabicName NVARCHAR(50) NULL,

    CommissionRate DECIMAL(4,2) NOT NULL,
	 CONSTRAINT CK_Category_Commission
        CHECK (CommissionRate BETWEEN 0 AND 30),

    ParentCategoryCode INT NULL,

    CONSTRAINT FK_Category_Parent
        FOREIGN KEY (ParentCategoryCode)
        REFERENCES Catalogue.Category(CategoryCode)
);



--Item
CREATE TABLE Catalogue.Item
(
    ItemID INT IDENTITY(1,1) PRIMARY KEY,

    SellerMemberID UNIQUEIDENTIFIER NOT NULL,
	CONSTRAINT FK_Item_Seller
        FOREIGN KEY (SellerMemberID)
        REFERENCES [Identity].Member(ID),

		CONSTRAINT CK_Item_DifferentPeople
        CHECK (SellerMemberID <> InspectorMemberID),

    InspectorMemberID UNIQUEIDENTIFIER NOT NULL,
	CONSTRAINT FK_Item_Inspector
        FOREIGN KEY (InspectorMemberID)
        REFERENCES Operations.Employee(ID),

    CategoryCode INT NOT NULL,
	CONSTRAINT FK_Item_Category
        FOREIGN KEY (CategoryCode)
        REFERENCES Catalogue.Category(CategoryCode),

    WarehouseID INT NULL,
	CONSTRAINT FK_Item_Warehouse
        FOREIGN KEY (WarehouseID)
        REFERENCES Operations.Warehouse(ID),

    Title NVARCHAR(150) NOT NULL,
    Description NVARCHAR(MAX) NULL,

    ConditionScore TINYINT NOT NULL,
	
    CONSTRAINT CK_Item_Condition
        CHECK (ConditionScore BETWEEN 1 AND 10),

    Specifications NVARCHAR(MAX) NOT NULL,
	
    CONSTRAINT CK_Item_ValidJSON
        CHECK (ISJSON(Specifications) = 1),

    ListedAt DATETIME2(3) NOT NULL
        DEFAULT SYSDATETIME()
   
);


-- ItemPhoto

CREATE TABLE Catalogue.ItemPhoto
(
    ItemID INT NOT NULL,
    PhotoPosition TINYINT NOT NULL,

    PhotoURL VARCHAR(500) NOT NULL,

    IsMainPhoto BIT NOT NULL DEFAULT 0,

    CONSTRAINT PK_ItemPhoto
        PRIMARY KEY (ItemID, PhotoPosition),

    CONSTRAINT FK_ItemPhoto_Item
        FOREIGN KEY (ItemID)
        REFERENCES Catalogue.Item(ItemID)
        ON DELETE CASCADE,

    CONSTRAINT CK_ItemPhoto_Position
        CHECK (PhotoPosition BETWEEN 1 AND 20)
);

CREATE TABLE Auctions.Auction
(
    ID INT IDENTITY(1,1) PRIMARY KEY,
	ItemID INT NOT NULL,
	 
	CONSTRAINT FK_Auctions_Items
	     FOREIGN KEY (ItemID)
		 REFERENCES Catalogue.Item(ItemID),

    StartingPrice DECIMAL(12,2) NOT NULL,
    CONSTRAINT CK_Auction_StartingPrice
        CHECK (StartingPrice > 0),

    ReservePrice DECIMAL(12,2) NULL,
	CONSTRAINT CK_Auction_ReservePrice
        CHECK (ReservePrice IS NULL
               OR ReservePrice >= StartingPrice),

    BidIncrement DECIMAL(12,2) NOT NULL
        DEFAULT 50.00,
    CONSTRAINT CK_Auction_BidIncrement
        CHECK (BidIncrement > 0),


    StartAt DATETIMEOFFSET(3) NOT NULL,
	
    EndAt DATETIMEOFFSET(3) NOT NULL,
	CONSTRAINT CK_Auction_Dates
        CHECK (EndAt > StartAt),


    Status VARCHAR(10) NOT NULL
        DEFAULT 'Draft',
    CONSTRAINT CK_Auction_Status
        CHECK (Status IN ('Draft', 'Live', 'Ended', 'Cancelled'))
);


CREATE TABLE Auctions.Bid
(
    ID BIGINT IDENTITY(1,1) PRIMARY KEY,

    AuctionID INT NOT NULL,
	 CONSTRAINT FK_Bid_Auction
        FOREIGN KEY (AuctionID)
        REFERENCES Auctions.Auction(ID),

    MemberID UNIQUEIDENTIFIER NOT NULL,
	  CONSTRAINT FK_Bid_Member
        FOREIGN KEY (MemberID)
        REFERENCES [Identity].Member(ID),

    Amount DECIMAL(12,2) NOT NULL,
	CONSTRAINT CK_Bid_Amount
        CHECK (Amount > 0),
    CONSTRAINT UQ_Bid_Auction_Amount
        UNIQUE (AuctionID, Amount),

    PlacedAt DATETIME2(3) NOT NULL
        DEFAULT SYSDATETIME(),

    IPAddress VARCHAR(45) NOT NULL,

);

--Many-to-Many BETWEEN Member, Auction
CREATE TABLE Auctions.AuctionFollower
(
    MemberID UNIQUEIDENTIFIER NOT NULL,

    AuctionID INT NOT NULL,
	 CONSTRAINT PK_AuctionFollower
        PRIMARY KEY (MemberID, AuctionID),

    FollowedAt DATETIME2(3) NOT NULL
        DEFAULT SYSDATETIME(),

    CONSTRAINT FK_AuctionFollower_Member
        FOREIGN KEY (MemberID)
        REFERENCES [Identity].Member(ID),

    CONSTRAINT FK_AuctionFollower_Auction
        FOREIGN KEY (AuctionID)
        REFERENCES Auctions.Auction(ID)
);

ALTER TABLE Operations.Warehouse
DROP CONSTRAINT FK_Warehouse_Manager;
GO

ALTER TABLE Operations.Warehouse
ADD CONSTRAINT FK_Warehouse_Manager
FOREIGN KEY (ManagerEmployeeID, ID)
REFERENCES Operations.Employee(ID, WarehouseID);

ALTER TABLE [Identity].Member
ADD Language VARCHAR(2) NOT NULL
    CONSTRAINT DF_Member_Language DEFAULT 'ar';
GO

ALTER TABLE Catalogue.Item
ADD IsFeatured BIT NOT NULL
    CONSTRAINT DF_Item_IsFeatured DEFAULT 0;
GO


EXEC sp_rename
    '[Auctions].[Bid].[IPAddress]',
    'DeviceIp',
    'COLUMN';
GO


ALTER TABLE Operations.Warehouse
DROP CONSTRAINT CK_Warehouse_Capacity;
GO


EXEC sp_rename
    '[Operations].[Warehouse].[Capacity]',
    'MaxItems',
    'COLUMN';
GO

ALTER TABLE [Identity].Member
ALTER COLUMN FullName NVARCHAR(150) NOT NULL;
GO


ALTER TABLE Operations.Warehouse
ALTER COLUMN MaxItems SMALLINT NOT NULL;
GO

ALTER TABLE Operations.Warehouse
ADD CONSTRAINT CK_Warehouse_MaxItems
CHECK (MaxItems > 0);
GO

ALTER TABLE Catalogue.Category
DROP CONSTRAINT CK_Category_Commission;
GO

ALTER TABLE Catalogue.Category
ADD CONSTRAINT CK_Category_Commission
CHECK (CommissionRate BETWEEN 0 AND 25);
GO



ALTER TABLE Auctions.Auction
DROP CONSTRAINT CK_Auction_Status;
GO

ALTER TABLE Auctions.Auction
ADD CONSTRAINT CK_Auction_Status
CHECK (Status IN
('Draft', 'PendingReview', 'Live', 'Ended', 'Cancelled'));
GO



ALTER TABLE Auctions.Auction
DROP CONSTRAINT DF__Auction__Status__73BA3083;
GO


ALTER TABLE Auctions.Auction
ADD CONSTRAINT DF_Auction_Status
DEFAULT 'PendingReview' FOR Status;
GO



ALTER TABLE Auctions.Auction
ADD BuyNowPrice DECIMAL(12,2) NULL;
GO

ALTER TABLE Auctions.Auction
ADD CONSTRAINT CK_Auction_BuyNowPrice
CHECK
(
    BuyNowPrice IS NULL
    OR BuyNowPrice > StartingPrice
);
GO

ALTER TABLE [Identity].Member
ADD CONSTRAINT UQ_Member_Mobile UNIQUE (Mobile);
GO

ALTER TABLE [Identity].Member
ADD VerifiedAt DATETIME2(3) NULL;
GO


CREATE SCHEMA Marketing;
GO

ALTER SCHEMA Marketing
TRANSFER Auctions.AuctionFollower;
GO



