$restored_database = "dbname"
$files = Invoke-SQL -sqlCommand "SELECT file_id, name as [logical_file_name], physical_name FROM sys.database_files" -database $restored_database
Invoke-SQL -database 'master' -sqlCommand "ALTER DATABASE [${restored_database}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE"
Invoke-SQL -database 'master' -sqlCommand "ALTER DATABASE [${restored_database}] SET OFFLINE"
foreach ($dbFile in $files) { 
    $Prefix = (New-Guid)
    $Folder = Split-Path -Path $dbFile.physical_name -Parent
    $File = Split-Path -Path $dbFile.physical_name -Leaf
    $NewFileName = Join-Path $Folder "${Prefix}${File}"
    Move-Item -Path $dbFile.physical_name -Destination $NewFileName
    Invoke-SQL -database 'master' -sqlCommand "ALTER DATABASE [${restored_database}] MODIFY FILE (Name='$($dbFile.logical_file_name)', FILENAME='${NewFileName}')"
}
Invoke-SQL -database 'master' -sqlCommand "ALTER DATABASE [${restored_database}] SET ONLINE"
Invoke-SQL -database 'master' -sqlCommand "ALTER DATABASE [${restored_database}] SET RECOVERY SIMPLE WITH NO_WAIT"
$logFileName = (Invoke-SQL -sqlCommand "SELECT name FROM sys.database_files where type = 1" -database $restored_database).name
Invoke-SQL -database $restored_database -sqlCommand "DBCC SHRINKFILE(N'${logfileName}', 1)"
Invoke-SQL -database 'master' -sqlCommand "ALTER DATABASE [${restored_database}] SET MULTI_USER"
