-- Knesset Tables Migration
-- Generated from existing MySQL tables
-- These tables are created via raw SQL (not in Prisma schema) because they come from external Knesset data

CREATE TABLE IF NOT EXISTS `_KNS_Status` (
  `StatusID` int NOT NULL,
  `Desc` text COLLATE utf8mb4_unicode_ci,
  `TypeID` int DEFAULT NULL,
  `TypeDesc` text COLLATE utf8mb4_unicode_ci,
  `OrderTransition` text COLLATE utf8mb4_unicode_ci,
  `IsActive` int DEFAULT NULL,
  `LastUpdatedDate` text COLLATE utf8mb4_unicode_ci,
  `DYID` int DEFAULT NULL,
  PRIMARY KEY (`StatusID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `_KNS_Faction` (
  `FactionID` int NOT NULL,
  `Name` text COLLATE utf8mb4_unicode_ci,
  `KnessetNum` int DEFAULT NULL,
  `StartDate` text COLLATE utf8mb4_unicode_ci,
  `FinishDate` text COLLATE utf8mb4_unicode_ci,
  `IsCurrent` int DEFAULT NULL,
  `LastUpdatedDate` text COLLATE utf8mb4_unicode_ci,
  `DYID` int DEFAULT NULL,
  PRIMARY KEY (`FactionID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `_KNS_Person` (
  `PersonID` int NOT NULL,
  `LastName` text COLLATE utf8mb4_unicode_ci,
  `FirstName` text COLLATE utf8mb4_unicode_ci,
  `GenderID` int DEFAULT NULL,
  `GenderDesc` text COLLATE utf8mb4_unicode_ci,
  `Email` text COLLATE utf8mb4_unicode_ci,
  `IsCurrent` int DEFAULT NULL,
  `LastUpdatedDate` text COLLATE utf8mb4_unicode_ci,
  `DYID` int DEFAULT NULL,
  PRIMARY KEY (`PersonID`),
  UNIQUE KEY `DYID` (`DYID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `_KNS_Committee` (
  `CommitteeID` int NOT NULL,
  `Name` text COLLATE utf8mb4_unicode_ci,
  `CategoryID` int DEFAULT NULL,
  `CategoryDesc` text COLLATE utf8mb4_unicode_ci,
  `KnessetNum` int DEFAULT NULL,
  `CommitteeTypeID` int DEFAULT NULL,
  `CommitteeTypeDesc` text COLLATE utf8mb4_unicode_ci,
  `Email` text COLLATE utf8mb4_unicode_ci,
  `StartDate` text COLLATE utf8mb4_unicode_ci,
  `FinishDate` text COLLATE utf8mb4_unicode_ci,
  `AdditionalTypeID` int DEFAULT NULL,
  `AdditionalTypeDesc` text COLLATE utf8mb4_unicode_ci,
  `ParentCommitteeID` int DEFAULT NULL,
  `CommitteeParentName` text COLLATE utf8mb4_unicode_ci,
  `IsCurrent` int DEFAULT NULL,
  `LastUpdatedDate` text COLLATE utf8mb4_unicode_ci,
  `DYID` int DEFAULT NULL,
  PRIMARY KEY (`CommitteeID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `_KNS_Bill` (
  `BillID` int NOT NULL,
  `KnessetNum` int DEFAULT NULL,
  `Name` text COLLATE utf8mb4_unicode_ci,
  `SubTypeID` int DEFAULT NULL,
  `SubTypeDesc` text COLLATE utf8mb4_unicode_ci,
  `PrivateNumber` int DEFAULT NULL,
  `CommitteeID` int DEFAULT NULL,
  `StatusID` int DEFAULT NULL,
  `Number` int DEFAULT NULL,
  `PostponementReasonID` int DEFAULT NULL,
  `PostponementReasonDesc` text COLLATE utf8mb4_unicode_ci,
  `PublicationDate` text COLLATE utf8mb4_unicode_ci,
  `MagazineNumber` int DEFAULT NULL,
  `PageNumber` int DEFAULT NULL,
  `IsContinuationBill` int DEFAULT NULL,
  `SummaryLaw` text COLLATE utf8mb4_unicode_ci,
  `PublicationSeriesID` int DEFAULT NULL,
  `PublicationSeriesDesc` text COLLATE utf8mb4_unicode_ci,
  `PublicationSeriesFirstCall` text COLLATE utf8mb4_unicode_ci,
  `LastUpdatedDate` text COLLATE utf8mb4_unicode_ci,
  `DYID` int DEFAULT NULL,
  PRIMARY KEY (`BillID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `_KNS_DocumentBill` (
  `DocumentBillID` text COLLATE utf8mb4_unicode_ci,
  `BillID` int DEFAULT NULL,
  `GroupTypeID` int DEFAULT NULL,
  `GroupTypeDesc` text COLLATE utf8mb4_unicode_ci,
  `ApplicationID` int DEFAULT NULL,
  `ApplicationDesc` text COLLATE utf8mb4_unicode_ci,
  `FilePath` text COLLATE utf8mb4_unicode_ci,
  `LastUpdatedDate` text COLLATE utf8mb4_unicode_ci,
  `DYID` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `_KNS_CommitteeSession` (
  `CommitteeSessionID` int NOT NULL,
  `Number` int DEFAULT NULL,
  `KnessetNum` int DEFAULT NULL,
  `TypeID` int DEFAULT NULL,
  `TypeDesc` text COLLATE utf8mb4_unicode_ci,
  `CommitteeID` int DEFAULT NULL,
  `StatusID` int DEFAULT NULL,
  `StatusDesc` text COLLATE utf8mb4_unicode_ci,
  `Location` text COLLATE utf8mb4_unicode_ci,
  `SessionUrl` text COLLATE utf8mb4_unicode_ci,
  `BroadcastUrl` text COLLATE utf8mb4_unicode_ci,
  `StartDate` text COLLATE utf8mb4_unicode_ci,
  `FinishDate` text COLLATE utf8mb4_unicode_ci,
  `Note` text COLLATE utf8mb4_unicode_ci,
  `LastUpdatedDate` text COLLATE utf8mb4_unicode_ci,
  `DYID` int DEFAULT NULL,
  PRIMARY KEY (`CommitteeSessionID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
