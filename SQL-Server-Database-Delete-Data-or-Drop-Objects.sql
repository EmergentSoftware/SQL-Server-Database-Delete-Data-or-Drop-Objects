/**********************************************************************************************************************
** Description: This script allows the deletion of SQL Server table data without worrying about constraints by deleting 
**              in a specific table order. The script also allows you to delete any or all the SQL Server objects like 
**              tables, views, stored procedures, functions, user data types, sequences, and synonyms.
**
** Usage:       Use the changeable variables below to either delete table data or drop database objects.
**
**              Deleting Table Data
**               To delete all the rows in all the database tables set the variable @DeleteData = 1.
**               If you also want to reset all the identity columns so the next inserted row is 1, set the variable 
**               @ReseedTableIdentity = 1.
**
**              Dropping/Deleting Database Objects
**               Each database object you might want to drop has its own variable. These variables names start with 
**               "@Drop" like @DropTables. So if you want to drop all the database tables you would set the variable
**               @DropTables = 1.
**
** Notes:       There is no need to set @DeleteData = 1 if you are also setting @DropTables = 1. It will be extra 
**              unneeded work.
**********************************************************************************************************************/

/* Changeable Variables Start */

DECLARE @DeleteData bit = 1; /* 1=deletes data in all tables */
DECLARE @ReseedTableIdentity bit = 1; /* 1=Reseed the identity columns seed value to zero */
DECLARE @DropTables bit = 0; /* 1=drops all tables */
DECLARE @DropViews bit = 0; /* 1=drops all views */
DECLARE @DropStoredProcedures bit = 0; /* 1=drops all stored procedures */
DECLARE @DropFunctions bit = 0; /* 1=drops non CLR functions */
DECLARE @DropUserDefinedDataTypes bit = 0; /* 1=drops all user defined data and table types */
DECLARE @DropSequences bit = 0; /* 1=drops all sequences */
DECLARE @DropSynonyms bit = 0; /* 1=drops all synonyms */

/* Changeable Variables End*/


SET NOCOUNT ON;

/* Declare some variables for use later */
DECLARE @SQLStatement nvarchar(MAX) = N'';
DECLARE @NewLineString nvarchar(MAX) = CAST(CHAR(13) + CHAR(10) AS nvarchar(MAX));

/* Create a temporary table to store tables we will be doing things to below */
DROP TABLE IF EXISTS #Table;
CREATE TABLE #Table (
    SchemaName          nvarchar(128) NOT NULL
   ,TableName           nvarchar(128) NOT NULL
   ,IsTemporalTableFlag tinyint       NOT NULL
   ,TemporalSchemaName  nvarchar(128) NULL
   ,TemporalTableName   nvarchar(128) NULL
);

/* Find all the table and temporal metadata */
INSERT INTO #Table (SchemaName, TableName, IsTemporalTableFlag, TemporalSchemaName, TemporalTableName)
SELECT
    SchemaName          = S.name
   ,TableName           = T.name
   ,IsTemporalTableFlag = T.temporal_type
   ,TemporalSchemaName  = TS.name
   ,TemporalTableName   = TT.name
FROM
    sys.tables                  AS T
    INNER JOIN sys.schemas      AS S
        ON T.schema_id        = S.schema_id
    LEFT OUTER JOIN sys.tables  AS TT
        ON T.history_table_id = TT.object_id
    LEFT OUTER JOIN sys.schemas AS TS
        ON TT.schema_id       = TS.schema_id;

/**********************************************************************************************************************
** Disable all check constraints on all tables 
**********************************************************************************************************************/
SELECT
    @SQLStatement = @SQLStatement + COALESCE(N'ALTER TABLE ' + SchemaName + '.' + TableName + N' NOCHECK CONSTRAINT ALL;', N'') + @NewLineString
FROM
    #Table;

EXECUTE sys.sp_executesql @SQLStatement;
--PRINT @SQLStatement;
SET @SQLStatement = N'';

/**********************************************************************************************************************
** Disable all triggers on all tables
**********************************************************************************************************************/
SELECT
    @SQLStatement = @SQLStatement + COALESCE(N'DISABLE TRIGGER ALL ON ' + SchemaName + '.' + TableName + N';', N'') + @NewLineString
FROM
    #Table;

EXECUTE sys.sp_executesql @SQLStatement;
--PRINT @SQLStatement;
SET @SQLStatement = N'';

/**********************************************************************************************************************
** Disable Temporal Table - ALTER TABLE dbo.AccountCredit SET (SYSTEM_VERSIONING = OFF);
**********************************************************************************************************************/
SELECT
    @SQLStatement = @SQLStatement + COALESCE(N'ALTER TABLE ' + SchemaName + '.' + TableName + N' SET (SYSTEM_VERSIONING = OFF);', N'') + @NewLineString
FROM
    #Table
WHERE
    IsTemporalTableFlag = 2;

EXECUTE sys.sp_executesql @SQLStatement;
--PRINT @SQLStatement;
SET @SQLStatement = N'';

/**********************************************************************************************************************
** Delete all data from all tables
**********************************************************************************************************************/
IF @DeleteData = 1
    BEGIN
        SELECT
            @SQLStatement = @SQLStatement + COALESCE(N'DELETE FROM ' + SchemaName + N'.' + TableName + N' WITH (TABLOCKX);', N'') + @NewLineString
        FROM
            #Table;

        SET @SQLStatement = N'SET NOCOUNT ON; ' + @NewLineString + @SQLStatement;
        EXECUTE sys.sp_executesql @SQLStatement;
        --PRINT @SQLStatement;
        SET @SQLStatement = N'';
    END;

/**********************************************************************************************************************
** Drop all views
**********************************************************************************************************************/
IF @DropViews = 1
    BEGIN
        SELECT
            @SQLStatement = @SQLStatement + COALESCE(N'DROP VIEW ' + S.name + N'.' + V.name + N';', N'') + @NewLineString
        FROM
            sys.views              AS V
            INNER JOIN sys.schemas AS S
                ON V.schema_id = S.schema_id
        WHERE
            V.is_ms_shipped <> 1;

        EXECUTE sys.sp_executesql @SQLStatement;
        --PRINT @SQLStatement;
        SET @SQLStatement = N'';
    END;

/**********************************************************************************************************************
** Drop all stored procedures
**********************************************************************************************************************/
IF @DropStoredProcedures = 1
    BEGIN
        SELECT
            @SQLStatement = @SQLStatement + COALESCE(N'DROP PROCEDURE ' + S.name + N'.' + P.name + N';', N'') + @NewLineString
        FROM
            sys.procedures         AS P
            INNER JOIN sys.schemas AS S
                ON P.schema_id = S.schema_id;

        EXECUTE sys.sp_executesql @SQLStatement;
        --PRINT @SQLStatement;
        SET @SQLStatement = N'';
    END;

/**********************************************************************************************************************
** Drop sequences
**********************************************************************************************************************/
IF @DropSequences = 1
    BEGIN
        SELECT
            @SQLStatement = @SQLStatement + COALESCE(N'DROP SEQUENCE ' + S.name + N'.' + SQ.name + N';', N'') + @NewLineString
        FROM
            sys.sequences          AS SQ
            INNER JOIN sys.schemas AS S
                ON SQ.schema_id = S.schema_id;

        EXECUTE sys.sp_executesql @SQLStatement;
        --PRINT @SQLStatement;
        SET @SQLStatement = N'';
    END;

/**********************************************************************************************************************
** Drop synonyms
**********************************************************************************************************************/
IF @DropSynonyms = 1
    BEGIN
        SELECT
            @SQLStatement = @SQLStatement + COALESCE(N'DROP SYNONYM ' + S.name + N'.' + SY.name + N';', N'') + @NewLineString
        FROM
            sys.synonyms           AS SY
            INNER JOIN sys.schemas AS S
                ON SY.schema_id = S.schema_id;

        EXECUTE sys.sp_executesql @SQLStatement;
        --PRINT @SQLStatement;
        SET @SQLStatement = N'';
    END;

/**********************************************************************************************************************
** Drop tables
**********************************************************************************************************************/
IF @DropTables = 1
    BEGIN

        /* Drop all the foreign keys */
        SELECT
            @SQLStatement = @SQLStatement + N'ALTER TABLE ' + (OBJECT_SCHEMA_NAME(parent_object_id)) + N'.' + QUOTENAME(OBJECT_NAME(parent_object_id)) + N' DROP CONSTRAINT' + QUOTENAME(name) + N';' + @NewLineString
        FROM
            sys.foreign_keys
        ORDER BY
            OBJECT_SCHEMA_NAME(parent_object_id)
           ,OBJECT_NAME(parent_object_id);

        EXECUTE sys.sp_executesql @SQLStatement;
        --PRINT @SQLStatement;
        SET @SQLStatement = N'';

        /* Drop all the tables */
        SELECT
            @SQLStatement = @SQLStatement + COALESCE(N'DROP TABLE ' + SchemaName + N'.' + TableName + N';', N'') + @NewLineString
        FROM
            #Table;

        EXECUTE sys.sp_executesql @SQLStatement;
        --PRINT @SQLStatement;
        SET @SQLStatement = N'';
    END;

/**********************************************************************************************************************
** Drop functions
**********************************************************************************************************************/
IF @DropFunctions = 1
    BEGIN
        SELECT
            @SQLStatement = @SQLStatement + COALESCE(N'DROP FUNCTION ' + S.name + N'.' + O.name + N';', N'') + @NewLineString
        FROM
            sys.objects            AS O
            INNER JOIN sys.schemas AS S
                ON O.schema_id = S.schema_id
        WHERE
            O.type IN ('FN', 'IF', 'TF')
        AND O.name NOT IN ('fn_diagramobjects');

        EXECUTE sys.sp_executesql @SQLStatement;
        --PRINT @SQLStatement;
        SET @SQLStatement = N'';
    END;

/**********************************************************************************************************************
** Drops user defined data and table types
**********************************************************************************************************************/
IF @DropUserDefinedDataTypes = 1
    BEGIN
        SELECT
            @SQLStatement = @SQLStatement + COALESCE(N'DROP TYPE ' + S.name + N'.' + T.name + N';', N'') + @NewLineString
        FROM
            sys.types              AS T
            INNER JOIN sys.schemas AS S
                ON T.schema_id = S.schema_id
        WHERE
            T.is_user_defined = 1;

        EXECUTE sys.sp_executesql @SQLStatement;
        --PRINT @SQLStatement;
        SET @SQLStatement = N'';
    END;

/**********************************************************************************************************************
** Enable Temporal Table
**********************************************************************************************************************/
IF @DropTables <> 1
    BEGIN
        SELECT
            @SQLStatement = @SQLStatement + COALESCE(N'ALTER TABLE ' + SchemaName + N'.' + TableName + N' SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = ' + TemporalSchemaName + N'.' + TemporalTableName + N'));', N'') + @NewLineString
        FROM
            #Table
        WHERE
            IsTemporalTableFlag = 2;

        EXECUTE sys.sp_executesql @SQLStatement;
        --PRINT @SQLStatement;
        SET @SQLStatement = N'';
    END;

/**********************************************************************************************************************
** Enable all constraints on all tables
**********************************************************************************************************************/
IF @DropTables <> 1
    BEGIN
        SELECT
            @SQLStatement = @SQLStatement + COALESCE(N'ALTER TABLE ' + SchemaName + N'.' + TableName + N' WITH CHECK CHECK CONSTRAINT ALL;', N'') + @NewLineString
        FROM
            #Table;

        SET @SQLStatement = N'SET NOCOUNT ON; ' + @NewLineString + @SQLStatement;
        EXECUTE sys.sp_executesql @SQLStatement;
        --PRINT @SQLStatement;
        SET @SQLStatement = N'';
    END;

/**********************************************************************************************************************
** Enable all triggers on all tables
**********************************************************************************************************************/
IF @DropTables <> 1
    BEGIN
        SELECT
            @SQLStatement = @SQLStatement + COALESCE(N'ENABLE TRIGGER ALL ON ' + SchemaName + N'.' + TableName + N';', N'') + @NewLineString
        FROM
            #Table;

        SET @SQLStatement = N'SET NOCOUNT ON; ' + @NewLineString + @SQLStatement;
        EXECUTE sys.sp_executesql @SQLStatement;
        --PRINT @SQLStatement;
        SET @SQLStatement = N'';
    END;

/**********************************************************************************************************************
** Reseed the identity columns seed value 
**********************************************************************************************************************/
IF @DropTables <> 1
    BEGIN
        IF @ReseedTableIdentity = 1
            BEGIN
                SELECT
                    @SQLStatement = @SQLStatement + COALESCE(N'DBCC CHECKIDENT(' + CHAR(39) + SCHEMA_NAME(T.schema_id) + N'.' + T.name + CHAR(39) + N', RESEED, 0);', N'') + @NewLineString
                FROM
                    sys.columns                          AS C
                    INNER JOIN sys.tables                AS T
                        ON C.object_id = T.object_id

                    LEFT OUTER JOIN sys.identity_columns AS IC
                        ON C.object_id = IC.object_id
                WHERE
                    C.is_identity = 1
                AND IC.last_value IS NOT NULL;

                SET @SQLStatement = N'SET NOCOUNT ON; ' + @NewLineString + @SQLStatement;
                EXECUTE sys.sp_executesql @SQLStatement;
                --PRINT @SQLStatement;
                SET @SQLStatement = N'';
            END;
    END;