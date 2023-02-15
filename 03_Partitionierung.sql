USE Demo;

--Partitionierung
--Teilt Tabellen auf Partitionen auf anhand einer Spalte
--Braucht eine Funktion und ein Schema

--Partitionsfunktion
--Nimmt einen Wert als Input und gibt aus in welcher Partition dieser Wert liegen würde
--Benötigt ein Partitionsschema
CREATE PARTITION FUNCTION pf_Zahl(int)
AS
RANGE LEFT FOR VALUES (100, 200); --Ranges festlegen von links (0-100, 101-200, 201+)

--Partitionsfunktion testen
SELECT $partition.pf_Zahl(50); --1
SELECT $partition.pf_Zahl(150); --2
SELECT $partition.pf_Zahl(250); --3

--Partitionsschema
--Legt fest welche File Gruppe welchen Datensatz bekommt anhand der zugeordneten Funktion
--Benötigt eine FileGroup pro Bereich
CREATE PARTITION SCHEME sch_Zahl
AS
PARTITION pf_Zahl TO (Bis100, Bis200, Ab200);
--Einzelne Bereiche auf die entsprechenden Dateigruppen zuordnen
--Jede Dateigruppe braucht ein File
--Es wird eine Dateigruppe mehr als Grenzen der Partitionsfunktion benötigt (oder eine Dateigruppe pro Bereich)

CREATE TABLE pTable (id int identity, test char(5000)) ON sch_Zahl(id);

DECLARE @i int = 0;
WHILE @i < 15000
BEGIN
	INSERT INTO pTable VALUES ('XY');
	SET @i += 1;
END

SELECT * FROM pTable;

dbcc showcontig('pTable');

SET STATISTICS time, io ON;

SELECT * FROM pTable WHERE id = 50;
--logische Lesevorgänge: 100, CPU-Zeit = 0 ms, verstrichene Zeit = 0 ms
--50 kann nur in der untersten Partition sein

SELECT * FROM pTable WHERE id = 150;
--logische Lesevorgänge: 100, CPU-Zeit = 0 ms, verstrichene Zeit = 0 ms
--150 kann nur in der mittleren Partition sein

SELECT * FROM pTable WHERE id = 5000;
--logische Lesevorgänge: 15300, CPU-Zeit = 15 ms, verstrichene Zeit = 11 ms
--Große Partition muss durchsucht werden, kleine Partitionen wurden ausgelassen

--Partitionsfunktion neue Grenze hinzufügen
ALTER PARTITION SCHEME sch_Zahl NEXT USED Ab5000; --Neue Dateigruppe hinzufügen ------Bis100------Bis200------Ab200------Ab5000------
ALTER PARTITION FUNCTION pf_Zahl() SPLIT RANGE(5000); --Neue Grenze hinzufügen --------100-------200--------5000--------

SELECT $partition.pf_Zahl(6000); --Partition 4

SELECT * FROM pTable WHERE id = 5000;
--logische Lesevorgänge: 4800, CPU-Zeit = 16 ms, verstrichene Zeit = 6 ms
--Daten wurden automatisch verschoben

SELECT * FROM pTable WHERE id = 6000;
--logische Lesevorgänge: 10500, CPU-Zeit = 15 ms, verstrichene Zeit = 8 ms
--Partition 4

ALTER PARTITION FUNCTION pf_Zahl() MERGE RANGE(100); --Range entfernen -> -----200-----5000-----

SELECT $partition.pf_Zahl(50); --1
SELECT $partition.pf_Zahl(150); --Auch 1

--Tabellenstruktur kopieren
SELECT TOP 0 *
INTO Archiv200
FROM pTable;

CREATE TABLE Archiv200 (id int identity, test char(5000)) ON Bis200;

ALTER TABLE pTable SWITCH PARTITION 1 TO Archiv200; --Datensätze aus Partition 1 in die Archivtabelle bewegen

SELECT * FROM Archiv200;
SELECT * FROM pTable;