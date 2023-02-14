/*
	Dateigruppen:
	[PRIMARY]: Hauptgruppe: enthält alle Systemdatenbanken, Tabellen sind standardmäßig auf PRIMARY, kann nicht entfernt werden (.mdf)
	Nebengruppen: Datenbankobjekte können auf Nebengruppen gelegt werden (.ndf)
*/

USE Demo;

CREATE TABLE FG1 (id int identity) ON [PRIMARY]; --Auf Primärgruppe legen, standard (außer PRIMARY ist nicht die Standardgruppe)

--Neue Filegroup erstellen: Rechtsklick auf Datenbank -> Properties -> Filegroups -> Add Filegroup
CREATE TABLE FG2 (id int identity) ON [Aktiv]; --Tabelle auf eine andere Gruppe legen

--File erstellen: Rechtsklick auf Datenbank -> Properties -> Files -> Add File
--Name festlegen, Dateigruppe festlegen, Pfad festlegen, Dateiname festlegen mit .ndf Endung

ALTER DATABASE Demo ADD FILE
(
	NAME='Test',
	FILENAME='C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\Test.ndf',
	SIZE=8MB,
	FILEGROWTH=64MB
);

--Wie bewegt man eine Tabelle auf eine andere FileGroup?
--Tabelle auf der anderen Seite erstellen und Daten bewegen
CREATE TABLE Test (id int identity) ON [Aktiv];
INSERT INTO Test SELECT * FROM FG1;
DROP TABLE FG1;

--Salamitaktik
--Aufteilung von großen Tabellen auf mehrere kleine Tabellen
--Zusammenbauen mit indizierten Sicht

CREATE TABLE Umsatz
(
	Datum date,
	Umsatz float
);

DECLARE @i int = 0;
WHILE @i < 20000
BEGIN
	INSERT INTO Umsatz VALUES
	(DATEADD(DAY, FLOOR(RAND()*1096), '20190101'), RAND() * 1000);
	SET @i += 1;
END

SELECT * FROM Umsatz;

SET STATISTICS TIME, IO ON;

/*
	Pläne
	Zeigen den Ablauf einer Abfrage an
	Aktivieren mit Include Actual Execution Plan (Strg + M)
	Wichtige Spalten:
	- Estimated Operator Cost: Kosten des Teils der Abfrage
	- Number of Rows Read: Gelesene Zeilen -> reduzieren um Performance zu erhöhen
*/

SELECT * FROM Umsatz WHERE YEAR(Datum) = 2019; --20000 Rows gelesen obwohl ich nur 6632 Rows haben möchte

DBCC showcontig('Umsatz');

CREATE TABLE Umsatz2019
(
	Datum date,
	Umsatz float,
	CONSTRAINT CHK_Year2019 CHECK (YEAR(Datum)=2019)
);

INSERT INTO Umsatz2019
SELECT * FROM Umsatz WHERE YEAR(Datum) = 2019;

CREATE TABLE Umsatz2020
(
	Datum date,
	Umsatz float,
	CONSTRAINT CHK_Year2020 CHECK (YEAR(Datum)=2020)
);

INSERT INTO Umsatz2020
SELECT * FROM Umsatz WHERE YEAR(Datum) = 2020;

CREATE TABLE Umsatz2021
(
	Datum date,
	Umsatz float,
	CONSTRAINT CHK_Year2021 CHECK (YEAR(Datum)=2021)
);

INSERT INTO Umsatz2021
SELECT * FROM Umsatz WHERE YEAR(Datum) = 2021;

--Indizierte Sicht
--View die über CHECK-Constraints nur auf die benötigten unterliegenden Tabellen zugreift

CREATE VIEW UmsatzGesamt
AS
	SELECT * FROM Umsatz2019
	UNION ALL --UNION filtert Duplikate, UNION ALL filtert keine Duplikate
	SELECT * FROM Umsatz2020
	UNION ALL
	SELECT * FROM Umsatz2021
GO

SELECT * FROM UmsatzGesamt WHERE YEAR(Datum) = 2020; --28% Scan auf alle Tabellen (bringt nix, 2020 kann nur in einer Tabelle enthalten sein)

--CHECK Constraints
ALTER TABLE Umsatz2019 ADD CONSTRAINT CHK_Year2019 CHECK (YEAR(Datum) = 2019);
ALTER TABLE Umsatz2020 ADD CONSTRAINT CHK_Year2020 CHECK (YEAR(Datum) = 2020);
ALTER TABLE Umsatz2021 ADD CONSTRAINT CHK_Year2021 CHECK (YEAR(Datum) = 2021);

SELECT * FROM UmsatzGesamt WHERE YEAR(Datum) = 2020; --Sollte nurnoch auf die 2020 Tabelle greifen