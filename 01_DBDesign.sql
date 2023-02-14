/*
	Normalerweise:
	1. Jede Zelle sollte genau einen Wert haben
	2. Jeder Datensatz sollte einen Primärschlüssel haben
	3. Keine Beziehungen zwischen nicht-PK Spalten

	Redundanz verringern (Daten nicht doppelt speichern)
	- Beziehungen zwischen Tabellen
	PK -- Beziehung -- FK

	Kundentabelle: 1 Mio. DS
	Bestellungen: 20 Mio. DS
	Bestellungen -> Beziehung -> Kunden
*/

/*
	Seiten:
	8192 Byte gesamt (8KB)
	132 Byte für Management Daten
	8060 Byte für tatsächliche Daten

	Max. 700 Datensätze
	Leerer Raum kann existieren (sollte vermieden werden)
	Seiten werden 1:1 geladen
*/

CREATE DATABASE Demo;
USE Demo;

CREATE TABLE T1 (id int identity, test char(4100)); --Absichtlich ineffiziente Tabelle

INSERT INTO T1
SELECT 'xy'
GO 20000; --GO <Zahl>: führt einen Befehl X-mal aus

--DBCC: Database Console Commands
dbcc showcontig('T1'); --Seitenstatistiken über eine Tabelle anschauen

--Wie groß ist die Tabelle wirklich?
--C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA
--20000 Datensätze * 4100 Byte/Datensatz = 80MB, .mdf hat aber 200MB

CREATE TABLE T2 (id int identity, test varchar(MAX));

INSERT INTO T2
SELECT 'xy'
GO 20000;

--Durch 700 Datensätze "nur" 93.87%
dbcc showcontig('T2');

--Gibt verschiedene Page-Daten über die Tabellen zurück
SELECT * FROM sys.dm_db_index_physical_stats(DB_ID(), 0, -1, 0, 'DETAILED');

SELECT OBJECT_ID('T1'); --ID über einen Namen holen
SELECT OBJECT_NAME(581577110); --Namen über eine ID holen

--OBJECT_NAME hier einbauen
SELECT OBJECT_NAME(object_id), *
FROM sys.dm_db_index_physical_stats(DB_ID(), 0, -1, 0, 'DETAILED');

--Nur einzelne Tabelle anschauen
SELECT *
FROM sys.dm_db_index_physical_stats(DB_ID(), 0, -1, 0, 'DETAILED')
WHERE object_id = OBJECT_ID('T1');


--Northwind anschauen

USE Northwind;

--Customers Tabelle: 97% Füllgrad -> gut
--alle Spalten mit n -> Unicode, brauchen doppelt soviel Speicherplatz
--CustomerID ist ein nchar(5) -> 10 Byte pro Datensatz, könnte ein char(5) sein -> 5 Byte pro Datensatz
--Bei Country, Phone, Fax das gleiche
--> Weniger Seiten, schnelleres Laden der Daten
dbcc showcontig('Customers');

--nvarchar könnte auf varchar optimiert werden (teilweise)

--INFORMATION_SCHEMA: Gibt verschiedene Informationen über die Datenbank zurück
SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Orders';

--Zeigt die Ausführungszeiten und Lesevorgänge aller Abfragen an
SET STATISTICS time, io ON;

USE Demo;

SELECT * FROM T1;
--Logische Lesevorgänge: 20000 (weil 20000 Seiten), CPU-Zeit: 125ms, Gesamtzeit: 678ms
--Lesevorgänge reduzieren -> Gesamtzeit reduziert sich automatisch, danach CPU-Zeit

SELECT * FROM T2;
--Logische Lesevorgänge: 50, CPU-Zeit: 31ms, Gesamtzeit: 125ms
--weniger Lesevorgänge -> weniger Gesamtzeit

SELECT * FROM T1 WHERE id = 100;
--Logische Lesevorgänge: 20000, CPU-Zeit: 15ms, Gesamtzeit: 25ms
--Nicht relevante Datensätze überspringen

SELECT TOP 1 * FROM T1 WHERE id = 100;
--Logische Lesevorgänge: 100, CPU-Zeit: 0ms, Gesamtzeit: 0ms
--Durch TOP 1 wird beim ersten Datensatz aufgehört

--Seiten reduzieren
--Bessere Datentypen oder durch Redesign (mehr Tabellen und Beziehungen)
--Bessere Verteilung der Daten, andere Schlüssel, ...

--1 Mio. Seiten * 2DS / Seite: 500000 Seiten -> 4GB
--1 Mio. Seiten * 50DS / Seite: 12500 Seiten -> 110MB

SET STATISTICS time, io OFF;

CREATE TABLE T3 (id int identity, test nvarchar(MAX));

INSERT INTO T3
SELECT 'xy'
GO 20000

dbcc showcontig('T2'); --50 Seiten
dbcc showcontig('T3'); --55 Seiten durch nvarchar

--Northwind
--CustomerID = nchar(5) -> char(5)
--varchar(50) -> standardmäßig 4B
--nvarchar(50) -> standardmäßig 8B
--text -> deprecated seit 2005

--float: 4B bei kleinen Zahlen, 8B bei großen Zahlen
--decimal(X, Y): je weniger Platz desto weniger Bytes

--money: 8B
--smallmoney: 4B

--tinyint: 1B, smallint: 2B, int: 4B, bigint: 8B

USE Northwind;

SET STATISTICS time, io ON;

SELECT * FROM Orders WHERE YEAR(OrderDate) = 1997; --83ms (sollte am schnellsten sein)
SELECT * FROM Orders WHERE OrderDate BETWEEN '19970101' AND '19971231'; --77ms (sollte am langsamsten sein)
SELECT * FROM Orders WHERE OrderDate >= '19970101' AND OrderDate <= '19971231'; --93ms

--Rechtsklick auf Datenbank -> Reports -> Disk Usage ...