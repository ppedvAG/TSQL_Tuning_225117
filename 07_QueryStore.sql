--Query Store: Erstellt Statistiken zu ausgeführten Abfragen
--Speichert CPU-Zeit, Gesamtzeit, Reads, ...

--Rechtsklick auf die Datenbank -> Properties -> Query Store -> Operation Mode: Read/Write
--Neuer Ordner auf der Datenbank (Query Store) mit vorgegebenen Statistiken

--Speichert Performance Daten zu ausgeführten Abfragen
--Speichert Pläne zu Abfragen die dann erzwungen werden können (wenn ich einen bestimmten Index erzwingen möchte)

USE Demo;

SELECT Txt.query_text_id, Txt.query_sql_text, Pl.plan_id, Qry.*  
FROM sys.query_store_plan AS Pl 
JOIN sys.query_store_query AS Qry ON Pl.query_id = Qry.query_id  
JOIN sys.query_store_query_text AS Txt ON Qry.query_text_id = Txt.query_text_id;

--Query entfernen über Query ID
EXEC sys.sp_query_store_remove_query 132;

SELECT UseCounts, Cacheobjtype, Objtype, TEXT, query_plan
FROM sys.dm_exec_cached_plans 
CROSS APPLY sys.dm_exec_sql_text(plan_handle)
CROSS APPLY sys.dm_exec_query_plan(plan_handle)