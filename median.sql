/*
Author: Tomaz Kastrun
Date: 16.01.2019

Description: Comparing database compatibility level 140 and 150 with Window function
envoking window aggregate operator in SQL Server Execution Plans.
Calculating Median.

*/

USE sqlrpy;
GO

DROP TABLE IF EXISTS  t1;
GO

CREATE TABLE t1
(id INT IDENTITY(1,1) NOT NULL
,c1 INT
,c2 SMALLINT
,t VARCHAR(10) 
)

SET NOCOUNT ON;

INSERT INTO t1 (c1,c2,t)
SELECT 
	x.* FROM
(
	SELECT 
	ABS(CAST(NEWID() AS BINARY(6)) %1000) AS c1
	,ABS(CAST(NEWID() AS BINARY(6)) %1000) AS c2
	,'text' AS t
) AS x
	CROSS JOIN (SELECT number FROM master..spt_values) AS n
	CROSS JOIN (SELECT number FROM master..spt_values) AS n2
GO 2
-- duration 00:00:33
-- rows: 13.015.202            



/*  results tests */

-- Itzik Solution
SELECT
(
 (SELECT MAX(c1) FROM
   (SELECT TOP 50 PERCENT c1 FROM t1 ORDER BY c1) AS BottomHalf)
 +
 (SELECT MIN(c1) FROM
   (SELECT TOP 50 PERCENT c1 FROM t1 ORDER BY c1 DESC) AS TopHalf)
) / 2 AS Median

-- Median: 500
-- Duration #1 00:00:46
-- Duration #2 00:00:47



-- changing compatibility mode:
SELECT name, compatibility_level   
FROM sys.databases   
WHERE name = db_name();  
-- SQLRPY	150


SELECT DISTINCT
   PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c1) OVER (PARTITION BY (SELECT 1)) AS MedianCont150
 FROM t1
-- median: 500
-- Duration #1: 00:00:01
-- Duration #2: 00:00:01


ALTER DATABASE SQLRPY  
SET COMPATIBILITY_LEVEL = 140;  
GO  


SELECT DISTINCT
   PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c1) OVER (PARTITION BY (SELECT 1)) AS MedianCont140
 FROM t1

-- Median: 500
-- Duration 00:01:11



ALTER DATABASE SQLRPY  
SET COMPATIBILITY_LEVEL = 150;  
GO  

SELECT DISTINCT
   PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c1) OVER (PARTITION BY (SELECT 1)) AS MedianCont140
 FROM t1

-- Median: 500
-- Duration 00:00:02


SELECT top 1
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c1)   OVER (PARTITION BY (SELECT 1))  as Median
FROM t1
-- Median: 500
-- Duration #1: 00:01:13
-- Duration #1: 00:01:07



sp_Execute_External_Script
 @language = N'R'
,@script = N'd <- InputDataSet
OutputDataSet <- data.frame(median(d$c1))'
,@input_data_1 = N'select c1 from t1'
WITH RESULT SETS
(( Median_R VARCHAR(100) ));
GO
--- median: 500
-- Duration #1 00:00:04
-- Duration #2 00:00:03
-- Duration #3 00:00:07



sp_Execute_External_Script
 @language = N'Python'
,@script = N'
import pandas as pd
dd = pd.DataFrame(data=InputDataSet)
os2 = dd.median()[0]
OutputDataSet = pd.DataFrame({''a'':os2}, index=[0])'
,@input_data_1 = N'select c1 from t1'
WITH RESULT SETS
(( MEdian_Python VARCHAR(100) ));
GO
-- Median: 500
-- Duration #1 00:00:06
-- Duration #2 00:00:03

