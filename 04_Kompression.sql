--Kompression
--für Client komplett transparent (bei SELECT wird dekomprimiert, User sieht nix)
--Tabellen -> Zeilen und Seitenkompression
--40%-60%, 70%-80%

--Große Tabelle erzeugen
SELECT  c.CustomerID
		, c.CompanyName
		, c.ContactName
		, c.ContactTitle
		, c.City
		, c.Country
		, o.EmployeeID
		, o.OrderDate
		, o.freight
		, o.shipcity
		, o.shipcountry
		, o.OrderID
		, od.ProductID
		, od.UnitPrice
		, od.Quantity
		, p.ProductName
		, e.LastName
		, e.FirstName
		, e.birthdate
INTO dbo.KundenUmsatz
FROM	Northwind.dbo.Customers c
		INNER JOIN Northwind.dbo.Orders o ON c.CustomerID = o.CustomerID
		INNER JOIN Northwind.dbo.Employees e ON o.EmployeeID = e.EmployeeID
		INNER JOIN Northwind.dbo.[Order Details] od ON o.orderid = od.orderid
		INNER JOIN Northwind.dbo.Products p ON od.productid = p.productid

INSERT INTO KundenUmsatz
SELECT * FROM KundenUmsatz
GO 9 --Viele Daten erzeugen

SET STATISTICS TIME, IO ON;

SELECT * FROM KundenUmsatz;
--logische Lesevorgänge: 41302, CPU-Zeit = 2813 ms, verstrichene Zeit = 20168 ms

dbcc showcontig('KundenUmsatz');
--Seiten: 41302, Dichte: 98.19%

--Rechtsklick auf Tabelle -> Storage -> Manage Compression -> Row oder Page auswählen und Next

--Nach Row Compression: 322MB -> 179MB (~45%)
SELECT * FROM KundenUmsatz;
--logische Lesevorgänge: 22863, CPU-Zeit = 4078 ms, verstrichene Zeit = 21014 ms (CPU hat mehr Aufwand aber Daten brauchen weniger Platz)

dbcc showcontig('KundenUmsatz');
--Seiten: 22863, Dichte: 98.96%

--Nach Page Compression (322MB -> 83MB, ~75%)
SELECT * FROM KundenUmsatz;
--logische Lesevorgänge: 10689, CPU-Zeit = 5203 ms, verstrichene Zeit = 24002 ms (CPU hat noch mehr Aufwand, Gesamtzeit noch etwas länger)

dbcc showcontig('KundenUmsatz');
--Seiten: 10689, Dichte: 99.26%