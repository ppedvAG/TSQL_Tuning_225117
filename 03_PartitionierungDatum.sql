--Datumspartitionierung
CREATE PARTITION FUNCTION pf_Datum(date)
AS
RANGE LEFT FOR VALUES ('20181231', '20191231', '20201231', '20211231');
--Grenzen sind inklusiv '20190101' -> Partition 1, würde 2019 in die unterste Partition geben

CREATE PARTITION SCHEME datum_scheme
AS
PARTITION pf_Datum TO (Bis2019, Bis2020, Bis2021, Bis2022, BisHeute);

CREATE TABLE Rechnungsdaten (id int identity, rechnungsdatum date, betrag float) ON datum_scheme(rechnungsdatum);

DECLARE @i int = 0;
WHILE @i < 20000
BEGIN
	INSERT INTO Rechnungsdaten VALUES
	(DATEADD(DAY, FLOOR(RAND() * 1826), '20180101'), RAND() * 1000);
	SET @i += 1;
END

SELECT * FROM Rechnungsdaten ORDER BY 2;

CREATE TABLE ArchivBis2019 (id int identity, rechnungsdatum date, betrag float) ON Bis2019; --Archivtabelle für bis 2019 erstellen

ALTER TABLE Rechnungsdaten SWITCH PARTITION 1 TO ArchivBis2019; --Alle 2018 und davor Daten ins Archiv bewegen

SELECT * FROM ArchivBis2019 ORDER BY 2;

SELECT OBJECT_NAME(object_id), * FROM sys.dm_db_partition_stats;

--Gibt eine Übersicht über die Partitionen einer Tabelle
SELECT
$partition.pf_Datum(rechnungsdatum) AS Partition,
COUNT(*) AS AnzDatensätze,
MIN(rechnungsdatum) AS Untergrenze,
MAX(rechnungsdatum) AS Obergrenze
FROM Rechnungsdaten
GROUP BY $partition.pf_Datum(rechnungsdatum)