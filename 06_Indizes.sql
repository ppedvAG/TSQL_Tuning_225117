USE Demo;

SELECT * FROM KundenUmsatz; --Table Scan da kein Index vorhanden

/*
Heap: Tabelle in unsortierter Form (alle Daten)

Non-Clustered Index (NCIX):
Baumstruktur (von oben nach unten)
Maximal 1000 Stück pro Tabelle
Sollte auf häufig angewandte SQL-Statements angepasst werden
Auch auf Spalten die häufig mit WHERE gesucht werden

Clustered Index (CIX):
Maximal einer pro Tabelle
Bietet sich an auf eine ID Spalte anzuwenden
Wird automatisch sortiert (bei INSERT wird der Datensatz automatisch an der richtigen Stelle eingefügt)
Sollte vermieden werden auf sehr großen Tabellen oder auf Tabellen mit vielen INSERTs -> viele Sortierungen, kostet Performance

Table Scan: Suche die ganze Tabelle
Index Scan: Durchsuche den ganzen Index
Index Seek: bestimmte Daten im Index suchen (beste)
*/

USE Northwind;

--Clustered Index
SELECT * FROM Orders; --Clustered Index Scan (Kosten: 0.0182)
SELECT * FROM Orders WHERE OrderID = 10248; --Clustered Index Seek (Kosten: 0.0032)
INSERT INTO Customers (CustomerID, CompanyName) VALUES ('PPEDV', 'ppedv AG'); --Clustered Index Insert (Kosten: 0.05 da Sortierung)
DELETE FROM Customers WHERE CustomerID = 'PPEDV'; --Index Seek um den Datensatz zu finden und danach Clustered Index Delete (hohe Kosten dank Sortierung)

USE Demo;

SET STATISTICS time, io ON;

SELECT * INTO KU2 FROM KundenUmsatz; --Neue Tabelle anlegen um Kompression zu entfernen

SELECT * FROM KU2;
--logische Lesevorgänge: 41330, CPU-Zeit = 4453 ms, verstrichene Zeit = 28952 ms, Kosten = 31.8

ALTER TABLE KU2 ADD ID int identity primary key; --ID hinzufügen, Clustered Index automatisch

SELECT * FROM KU2; --logische Lesevorgänge: 41960 -> Index Scan

SELECT OBJECT_NAME(object_id), * --Indizes + Ebenen anschauen
FROM sys.dm_db_index_physical_stats(DB_ID(), 0, -1, 0, 'DETAILED');

SELECT * FROM KU2 WHERE ID = 50; --Clustered Index Seek, logische Lesevorgänge: 3

SELECT * FROM KU2 WHERE ID = 50;
--Ohne Index: Table Scan, aber schnell weil Primärschlüssel eindeutig ist
--logische Lesevorgänge: 41960

--Index Key Columns: Spalten nach denen indiziert wird (generell Spalten die im WHERE verwendet werden)
--Included Columns: Spalten die im SELECT noch extra geholt werden sollen

SELECT * FROM KU2 WHERE freight > 50;
--Index Seek über den NCIX_Freight Index
--logische Lesevorgänge: 21314, CPU-Zeit = 2296 ms, verstrichene Zeit = 17129 ms, Kosten = 16.7
--logische Lesevorgänge: 41963, CPU-Zeit = 1765 ms, verstrichene Zeit = 12069 ms, Kosten = 32.2

SELECT ID, birthdate FROM KU2 WHERE freight > 50; --Auch über NCIX_Freight gegangen
--logische Lesevorgänge: 21314, CPU-Zeit = 922 ms, verstrichene Zeit = 7693 ms, Kosten = 16.5 (NCIX_Freight)
--logische Lesevorgänge: 1845, CPU-Zeit = 313 ms, verstrichene Zeit = 3879 ms, Kosten = ~2 (NCIX_Freight_ID_Birthdate)
--Bei beiden Indizes überlegt die Datenbank welcher Index schneller ist

SELECT CompanyName, birthdate FROM KU2 WHERE freight > 1000;
--Key Lookup: Datensätze innerhalb der Seiten anschauen und so die Spalten holen
--logische Lesevorgänge: 6292, CPU-Zeit = 31 ms, verstrichene Zeit = 117 ms, Kosten = 0.01 für Seek, 6.8 für Lookup
--logische Lesevorgänge: 17, CPU-Zeit = 0 ms, verstrichene Zeit = 108 ms, Kosten = ~0.02 (CompanyName zum Index hinzugefügt)

SELECT * FROM KU2; --Table Scan, da nicht über einen Teil von einem Index gegangen werden kann

SELECT * FROM KU2 WHERE freight > 50; --Table Scan, da Lookup wesentlich mehr kosten würde

SELECT * FROM KU2 WHERE ID > 50 AND CustomerID LIKE 'A%'; --Table Scan
--Hier Reihenfolge der Index Key Columns ändern
SELECT * FROM KU2 WHERE CustomerID LIKE 'A%' AND ID > 50; --Index Seek -> Reihenfolge der Prädikate im WHERE oder Index Key Columns im Index ist relevant

--Indizierte View
GO
CREATE VIEW ixDemo
AS
SELECT Country, COUNT(*) AS Anzahl
FROM KU2
GROUP BY Country;
GO

SELECT * FROM ixDemo; --Table Scan

--WITH SCHEMABINDING: Verhindert Änderungen an der unterliegenden Tabelle
--Fehlermeldung wenn originale Tabelle verändert werden soll
GO
ALTER VIEW ixDemo WITH SCHEMABINDING
AS
SELECT Country, COUNT_BIG(*) AS Anzahl --COUNT_BIG() statt COUNT() notwendig
FROM dbo.KU2 --Hier muss der volle Name angegeben werden
GROUP BY Country;
GO

--Jetzt kann ich einen Index erstellen
SELECT * FROM ixDemo; --Index Scan
SELECT * FROM ixDemo WHERE Country LIKE 'A%'; --Index Seek

--Index von der View wurde auf die Tabelle übernommen
SELECT Country, COUNT_BIG(*) AS Anzahl
FROM dbo.KU2
GROUP BY Country;

GO
CREATE VIEW ixDemo2 WITH SCHEMABINDING
AS
SELECT freight FROM dbo.KU2
GO

--Indizes von der Tabelle sind auch in der View dabei
SELECT * FROM ixDemo2 WHERE freight > 50;

--Columnstore Index:
--Speichert Spalten als "eigene Tabelle"
--kann genau eine oder mehrere (wenige) Spalten sehr effizient durchsuchen
--Teilt die ausgewählten Spalten in der Tabelle in 2^20 große Teile auf und speichert diese als neue Spalten in der extra Tabelle
--Rest: Deltastore

ALTER TABLE KUColumnStore DROP COLUMN ID;

INSERT INTO KUColumnStore
SELECT * FROM KUColumnStore
GO 3

SELECT COUNT(*) FROM KUColumnStore;

--ColumnStore auf CompanyName
--8 Mio. Datensätze -> 2^20 große Teile -> 8 Stück
--Extra Tabelle Spalten: | CN1 | CN2 | CN3 | CN4 | CN5 | CN6 | CN7 | CN8 |

SELECT CompanyName FROM KUColumnStore; --kein Index -> Table Scan
--logische Lesevorgänge: 319485, CPU-Zeit = 9203 ms, verstrichene Zeit = 75761 ms, Kosten = 246

SELECT CompanyName FROM KUColumnStore; --normaler NCIX, Index Scan
--logische Lesevorgänge: 58660, CPU-Zeit = 6250 ms, verstrichene Zeit = 68418 ms, Kosten = 52.8

SELECT CompanyName FROM KUColumnStore; --Columnstore Index (Non-Clustered)
--logische LOB-Lesevorgänge: 8873, CPU-Zeit = 6656 ms, verstrichene Zeit = 72462 ms, Kosten = 0.97

SELECT CompanyName FROM KUColumnStore; --Columnstore Index (Non-Clustered) und normaler Index
--Datenbank wählt aus welcher Index für die Aufgabe effizienter ist
--Datenbank hat ColumnStore Index ausgewählt

--Welche Indizes sollten existieren?
--Indizes auf Views und Prozeduren die oft gebraucht werden anpassen
--Spalten die oft angegriffen werden (im WHERE, oder generell bei großen Tabellen ColumnStore)

--Index auf Abfrage anpassen
GO
CREATE PROC p_Test
AS
SELECT LastName, YEAR(OrderDate), MONTH(OrderDate), SUM(UnitPrice * Quantity)
FROM KU2
WHERE Country = 'UK'
GROUP BY LastName, Year(OrderDate), MONTH(OrderDate)
ORDER BY 1, 2, 3

EXEC p_Test;
--Ohne Index: logische Lesevorgänge: 41891, CPU-Zeit = 985 ms, verstrichene Zeit = 1401 ms, Kosten = 31.3
--Mit Index: logische Lesevorgänge: 490, CPU-Zeit = 172 ms, verstrichene Zeit = 452 ms, Kosten = 0.48

--Indizes warten
--Indizes werden über Zeit veraltet (durch INSERT, UPDATE, DELETE)
--Index aktualisieren -> 2 Möglichkeiten
--Reorganize: Index neu sortieren ohne Neuaufbau (bei kleineren Tabellen)
--Rebuild: Von Grund auf neu aufbauen
--Bei Reorganize die Fragmentierung möglichst verringern

SELECT OBJECT_NAME(object_id), *
FROM sys.dm_db_index_physical_stats(DB_ID(), 0, -1, 0, 'DETAILED')
WHERE index_level = 0; --Auch hier steht die Fragmentierung