--MAXDOP
--Maximum Degree of Parallelism
--Festlegen wie sehr eine Abfrage parallelisiert wird (wieviele Prozessorkerne eine Abfrage verwendet)
--Datenbank parallelisiert von alleine

--MAXDOP konfigurierbar auf 3 Ebenen: Server, DB, Query
--Query > DB > Server

--ab einem Kostenschwellwert (Estimated Operator Cost) von 5 (standardmäßig) wird parallelisiert

SELECT freight, birthdate FROM KundenUmsatz WHERE freight > 1000;
--Im Plan sichtbar mit 2 schwarzen Pfeilen im gelben Kreis auf der Abfrage
--Number of Executions bei Abfragen rechts: Anzahl Kerne verwendet
--Bei SELECT ganz links: Anzahl Kerne gesamt verwendet (z.B. bei UNION)

SET STATISTICS TIME, IO ON;

SELECT freight, birthdate
FROM KundenUmsatz
WHERE freight > 1000
OPTION (MAXDOP 1); --OPTION (MAXDOP <Anzahl>)
--MAXDOP 8: CPU-Zeit = 295 ms, verstrichene Zeit = 92 ms
--MAXDOP 4: CPU-Zeit = 248 ms, verstrichene Zeit = 95 ms
--MAXDOP 2: CPU-Zeit = 172 ms, verstrichene Zeit = 118 ms
--MAXDOP 1: CPU-Zeit = 156 ms, verstrichene Zeit = 161 ms

SELECT *, YEAR(OrderDate), CONCAT_WS(' ', FirstName, LastName)
FROM KundenUmsatz
WHERE Country IN(SELECT Country FROM KundenUmsatz WHERE Country LIKE 'A%');
--CPU-Zeit = 1111 ms, verstrichene Zeit = 1417 ms

SELECT *, YEAR(OrderDate), CONCAT_WS(' ', FirstName, LastName)
FROM KundenUmsatz
WHERE Country IN(SELECT Country FROM KundenUmsatz WHERE Country LIKE 'A%')
OPTION (MAXDOP 4);
--CPU-Zeit = 1031 ms, verstrichene Zeit = 1421 ms

SELECT *, YEAR(OrderDate), CONCAT_WS(' ', FirstName, LastName)
FROM KundenUmsatz
WHERE Country IN(SELECT Country FROM KundenUmsatz WHERE Country LIKE 'A%')
OPTION (MAXDOP 2);
--CPU-Zeit = 1344 ms, verstrichene Zeit = 2221 ms

SELECT *, YEAR(OrderDate), CONCAT_WS(' ', FirstName, LastName)
FROM KundenUmsatz
WHERE Country IN(SELECT Country FROM KundenUmsatz WHERE Country LIKE 'A%')
OPTION (MAXDOP 1);
--CPU-Zeit = 906 ms, verstrichene Zeit = 1651 ms