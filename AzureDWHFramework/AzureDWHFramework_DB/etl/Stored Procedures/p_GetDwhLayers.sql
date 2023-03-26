﻿

CREATE PROCEDURE [etl].[p_GetDwhLayers]
	@Area NVARCHAR(1000)

AS

DECLARE @cmd NVARCHAR(max)

IF @Area <> 'all' 
BEGIN
SELECT @cmd = N'
	SELECT 
       distinct [Layer]
  FROM [etl].[v_DwhMapping]
  WHERE 
  [Area] IN (''' + REPLACE(REPLACE(@Area, ' ',''), ',', ''',''') + ''')
  AND
  [Active] = 1
  ORDER BY Layer ASC'
  
EXEC sp_executesql @cmd

END
ELSE
BEGIN

SELECT @cmd = N'
	SELECT 
       distinct [Layer]
  FROM [etl].[v_DwhMapping]
  WHERE 
  [Active] = 1
  ORDER BY Layer ASC'
 
EXEC sp_executesql @cmd

END

RETURN 0