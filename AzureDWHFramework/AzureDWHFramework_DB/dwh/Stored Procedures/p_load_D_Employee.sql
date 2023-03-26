﻿CREATE PROCEDURE dwh.p_load_D_Employee@ETLLogID BIGINT ASDECLARE @ETLTableLoadLogID BIGINTDECLARE @ErrorMessage NVARCHAR(MAX)DECLARE @DateTime DATETIME2DECLARE @InsertedCount INT = 0DECLARE @DeletedCount INT = 0DECLARE @UpdatedCount INT = 0BEGIN TRYEXEC log.p_WriteETLTableLoadLog @ETLLogID = @ETLLogID, @Name = 'dwh.p_load_D_Employee', @TargetSchemaName = 'dwh ', @TargetTableName = 'D_Employee', @Type = 'Stored procedure', @Status = 1, @StatusDescription = 'Running', @NewETLTableLoadLogID = @ETLTableLoadLogID OUTPUTCREATE TABLE #D_Employee ( Change NVARCHAR(255), [EmployeeCode] int NOT NULL, [LoginID] nvarchar(256) NOT NULL, [JobTitle] nvarchar(50) NOT NULL, [Gender] nchar(5) NOT NULL, [MaritalStatus] nchar(5) NOT NULL,[RowValidDateFrom] DATETIME2 NULL,[RowValidDateTo] DATETIME2 NULL,[InsertedETLLogID] BIGINT NOT NULL,[UpdatedETLLogID] BIGINT NOT NULL,[Active] BIT NOT NULL )IF NOT EXISTS (SELECT 1 FROM dwh.D_Employee WHERE EmployeeID = -1)BEGINSET IDENTITY_INSERT dwh.D_Employee ON;INSERT INTO dwh.D_Employee(EmployeeID,EmployeeCode,Gender,JobTitle,LoginID,MaritalStatus,[RowValidDateFrom],[RowValidDateTO],InsertedETLLogID,UpdatedETLLogID,Active)VALUES(-1,-1,-1,-1,-1,-1,GETUTCDATE(),NULL,@ETLLogID,@ETLLogID,1)SET IDENTITY_INSERT dwh.D_Employee OFF;ENDMERGE dwh.D_Employee AS targetUSING(SELECT BusinessEntityID, Gender, JobTitle, LoginID, MaritalStatusFROM stage_onpremisedb.Employee) AS sourceON (target.EmployeeCode = source.BusinessEntityID AND target.Active = 1)WHEN MATCHED ANDtarget.LoginID <> source.LoginID ORtarget.JobTitle <> source.JobTitle ORtarget.Gender <> source.Gender ORtarget.MaritalStatus <> source.MaritalStatusTHEN UPDATE SET target.RowValidDateTo = GETUTCDATE(), target.Active = 0WHEN NOT MATCHED BY TARGET THEN INSERT(EmployeeCode,LoginID,JobTitle,Gender,MaritalStatus, RowValidDateFrom, RowValidDateTo,InsertedETLLogID,UpdatedETLLogID,Active)VALUES(source.BusinessEntityID,source.LoginID,source.JobTitle,source.Gender,source.MaritalStatus, GETUTCDATE(), NULL,@ETLLogID,@ETLLogID,1)WHEN NOT MATCHED BY SOURCE AND target.Active = 1 AND target.EmployeeID <> -1 THENUPDATE SET target.RowValidDateTo = GETUTCDATE(), target.Active = 0OUTPUT $action,source.BusinessEntityID,source.LoginID,source.JobTitle,source.Gender,source.MaritalStatus,GETDATE(), NULL, @ETLLogID, @ETLLogID, 1 INTO #D_Employee;select * FROM #D_Employee WHERE Change = 'UPDATE'INSERT INTO dwh.D_Employee(EmployeeCode,LoginID,JobTitle,Gender,MaritalStatus,[RowValidDateFrom],[RowValidDateTo],InsertedETLLogID,UpdatedETLLogID,Active)SELECTEmployeeCode,LoginID,JobTitle,Gender,MaritalStatus,[RowValidDateFrom],[RowValidDateTo],@ETLLogID,@ETLLogID,1FROM #D_Employee WHERE Change = 'UPDATE'SELECT @InsertedCount = COUNT(1) FROM #D_Employee WHERE Change = 'INSERT'SELECT @UpdatedCount = COUNT(1) FROM #D_Employee WHERE Change = 'UPDATE'SELECT @DeletedCount = COUNT(1) FROM #D_Employee WHERE Change = 'DELETE'SELECT @DateTime = GETUTCDATE()EXEC log.p_UpdateETLTableLoadLog @ETLTableLoadLogID, 2, 'Finished', @InsertedCount, @UpdatedCount, @DeletedCountEND TRYBEGIN CATCHSELECT @DateTime = GETUTCDATE()SELECT @ErrorMessage = ERROR_MESSAGE()EXEC log.p_UpdateETLTableLoadLog @ETLTableLoadLogID, 3, 'Failed', @InsertedCount, @UpdatedCount, @DeletedCount, @ErrorMessageEXEC log.p_UpdateETLLog @ETLLogID, 3, 'Failed';THROWEND CATCH