# SQL-Server-Database-Delete-Data-or-Drop-Objects
## Description
This script allows the deletion of SQL Server table data without worrying about constraints by deleting in a specific table order. The script also allows you to delete any or all the SQL Server objects like tables, views, stored procedures, functions, user data types, sequences, and synonyms.

## Usage:
Use the changeable variables to either delete table data or drop database objects.

### Deleting Table Data
To delete all the rows in all the database tables set the variable `@DeleteData = 1`.
If you also want to reset all the identity columns so the next inserted row is 1, set the variable `@ReseedTableIdentity = 1`.

### Dropping/Deleting Database Objects
Each database object you might want to drop has its own variable. These variables names start with "@Drop" like `@DropTables`. So if you want to drop all the database tables you would set the variable `@DropTables = 1`.

## Notes:
There is no need to set `@DeleteData = 1` if you are also setting @DropTables = 1. It will be extra unneeded work.