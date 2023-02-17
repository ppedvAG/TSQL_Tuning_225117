CREATE TABLE Transactions (test varchar(10));

BEGIN TRAN;
	INSERT INTO Transactions VALUES ('Test2');
	UPDATE Transactions SET test = 'TestTestTest';
ROLLBACK;

SELECT * FROM Transactions;

BEGIN TRY
	BEGIN TRANSACTION;
	UPDATE Transactions SET test = 'x';
	UPDATE Transactions SET test = 'TestTestTest';
	COMMIT;
	Print 'Erfolg'
END TRY
BEGIN CATCH
	ROLLBACK;
	Print 'Fehler'
END CATCH