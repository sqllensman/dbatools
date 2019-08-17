Function Invoke-DbaDbccCheckIntegrity {
    <#
    .SYNOPSIS
        Checks the logical or physical integrity of database objects via DBCC CheckDB or other variant.

    .DESCRIPTION
        Executes a DBCC CHECKDB Statement (or variant)

        https://docs.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-checkdb-transact-sql
        https://docs.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-checkalloc-transact-sql
        https://docs.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-checkcatalog-transact-sql
        https://docs.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-checktable-transact-sql
        https://docs.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-checkfilegroup-transact-sql

        Does not support Repair options
        Repair options are supported in Repair-DbaDbIntegrity

    .PARAMETER SqlInstance
        The SQL Server instance. You must have sysadmin access

    .PARAMETER SqlCredential
        Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted.
        To use: $scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

        Windows Authentication will be used if SqlCredential is not specified.
        SQL Server does not accept Windows credentials being passed as credentials.
        To connect as a different Windows user, run PowerShell as that user.

    .PARAMETER Database
        The database(s) to process. If unspecified, all databases will be processed.
        The Name or Id of a database can be specified
        Database names must comply with the rules for identifiers.

    .PARAMETER FileGroup
        Performs Integrity Check Operation for Specified Filegroups
        Applies only if Operation is CheckFilegroup

    .PARAMETER TableName
        Performs Integrity Check Operation for Specified Tables
        You can specify up to three-part name like db.sch.tbl
        Applies only if Operation is CheckTable

        If the object has special characters please wrap them in square brackets [ ].
        Using dbo.First.Table will try to find a table named 'Table' on schema 'First' and database 'dbo'.
        The correct way to find a table named 'First.Table' on schema 'dbo' is by passing dbo.[First.Table]
        Any actual usage of the ] must be escaped by duplicating the ] character.
        The correct way to find a table Name] in schema Schema.Name is by passing [Schema.Name].[Name]]]

    .PARAMETER IndexName
        Performs Integrity Check Operation for Specified Index on Specified Table
        Applies only if Operation is CheckTable

    .PARAMETER InputObject
        Enables piping from Get-DbaDatabase, GetDbaDbTable or Get-DbaDbFileGroup

    .PARAMETER Operation
        Valid Operations are CheckDb, CheckAlloc, CheckCatalog, CheckTable, CheckFilegroup
        Default is CheckDB

    .PARAMETER MaxDop
        Overrides the max degree of parallelism configuration option of sp_configure for the statement.
        Applies to: SQL Server ( SQL Server 2014 (12.x) SP2 through SQL Server 2019

    .PARAMETER NoIndex
        Specifies that intensive checks of nonclustered indexes for user tables should not be performed.
        This decreases the overall execution time.
        NOINDEX does not affect system tables because integrity checks are always performed on system table indexes.

    .PARAMETER AllErrorMessages
        Displays all reported errors per object.
        Error messages are sorted by object ID, except for those messages generated from tempdb database.
        For SQL Server 2016 or Higher all error messages are displayed by default. Specifying or omitting this option has no effect.

    .PARAMETER NoInformationalMessages
        Suppresses all informational messages.

    .PARAMETER PhysicalOnly
        Limits the checking to the integrity of the physical structure of the page and record headers and the allocation consistency of the database.
        This check is designed to provide a small overhead check of the physical consistency of the database.
        It can also detect torn pages, checksum failures, and common hardware failures that can compromise a user's data.
        Using the PhysicalOnly option may cause a much shorter run-time for DBCC CHECKDB on large databases
        It is recommended for frequent use on production systems.
        PHYSICAL_ONLY always implies NO_INFOMSGS and is not allowed with any one of the repair options.

    .PARAMETER DataPurity
        Causes DBCC CHECKDB to check the database for column values that are not valid or out-of-range.
        For example, DBCC CHECKDB detects columns with date and time values that are larger than or less than the acceptable range for the datetime data type;
        or decimal or approximate-numeric data type columns with scale or precision values that are not valid.
        Column-value integrity checks are enabled by default and do not require the DATA_PURITY option.
        For databases upgraded from earlier versions of SQL Server, column-value checks are not enabled by default
        until DBCC CHECKDB WITH DATA_PURITY has been run error free on the database.
        After this, DBCC CHECKDB checks column-value integrity by default.

    .PARAMETER ExtendedLogicalChecks
        Performs logical consistency checks on an indexed view, XML indexes, and spatial indexes, where present.
        Applies only if the compatibility level is 100 ( SQL Server 2008) or higher,

    .PARAMETER Tablock
        Causes DBCC CHECKDB to obtain locks instead of using an internal database snapshot.
        This includes a short-term exclusive (X) lock on the database.
        TABLOCK will cause DBCC CHECKDB to run faster on a database under heavy load,
        but decreases the concurrency available on the database while DBCC CHECKDB is running.

    .PARAMETER EstimateOnly
        Displays the estimated amount of tempdb space that is required to run DBCC CHECKDB with all the other specified options.
        The actual database check is not performed.

    .PARAMETER OutputScriptOnly
        Switch causes only the T-SQL script for the DBCC operation to be output.

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: DBCC
        Author: Patrick Flynn (@sqllensman)

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Invoke-DbaDbccCheckIntegrity
        https://www.mssqltips.com/sqlservertip/2325/capture-and-store-sql-server-database-integrity-history-using-dbcc-checkdb/

    .EXAMPLE
        PS C:\> Invoke-DbaDbccCheckIntegrity -SqlInstance sqlserver2014a

        Execute DBCC CHECKDB against all accessible databases on sqlserver2014a.
        Results are returned as a recordset and include all informational records
        Logs into the SQL Server with Windows credentials.

    .EXAMPLE
        PS C:\> Invoke-DbaDbccCheckIntegrity -SqlInstance sqlserver2014 -SqlCredential $credential -Database dbatools

        Execute DBCC CHECKDB against database dbatools on sqlserver2014a.
        Results are returned as a recordset and include all informational records
        Logs into the SQL Server with SQL Authentication.

    .EXAMPLE
        PS C:\> Invoke-DbaDbccCheckIntegrity -SqlInstance sqlserver2014a -OutputScriptOnly

        Generates script for running DBCC CHECKDB against all databases on sqlserver2014a.
        Logs into the SQL Server with Windows credentials.

    .EXAMPLE
        PS C:\> Invoke-DbaDbccCheckIntegrity -SqlInstance sqlserver2014a -Operation CheckAlloc

        Execute DBCC CHECKALLOC against database dbatools on sqlserver2014a.
        Results are returned as a recordset and include all informational records
        Logs into the SQL Server with Windows credentials.

    .EXAMPLE
        PS C:\> Invoke-DbaDbccCheckIntegrity -SqlInstance sqlserver2014a -Operation CheckCatalog -NoInformationalMessages

        Generates script for running DBCC CHECKCATALOG against all databases on sqlserver2014a.
        Results are returned as a recordset. Exclude all informational records
        Logs into the SQL Server with Windows credentials.

    .EXAMPLE
        PS C:\> $fg = Get-DbaDbFileGroup -SqlInstance sql2014
        PS C:\> $fg | Invoke-DbaDbccCheckIntegrity

        Creates a connection string that connects using alternative Windows credentials

    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    Param (
        [parameter(ValueFromPipeline)]
        [DbaInstanceParameter[]]$SqlInstance,
        [PsCredential]$SqlCredential,
        [string[]]$Database,
        [string[]]$Filegroup,
        [string[]]$TableName,
        [string]$IndexName,
        [parameter(ValueFromPipeline)]
        [object[]]$InputObject,
        [ValidateSet('CheckDb', 'CheckAlloc', 'CheckCatalog', 'CheckTable', 'CheckFilegroup')]
        [string]$Operation = "CheckDb",
        [int]$MaxDOP = 0,
        [switch]$NoIndex,
        [switch]$AllErrorMessages,
        [switch]$NoInformationalMessages,
        [switch]$PhysicalOnly,
        [switch]$DataPurity,
        [switch]$ExtendedLogicalChecks,
        [switch]$TabLock,
        [switch]$EstimateOnly,
        [switch]$OutputScriptOnly,
        [switch]$EnableException
    )

    BEGIN {
        $tableResults = $true

        if ($Operation -eq 'CheckAlloc') {
            $PhysicalOnly = $false
            $DataPurity = $false
            $ExtendedLogicalChecks = $false
            $MaxDOP = $null
        }

        if ($Operation -eq 'CheckCatalog') {
            $NoIndex = $false
            $AllErrorMessages = $false
            $PhysicalOnly = $false
            $DataPurity = $false
            $ExtendedLogicalChecks = $false
            $TabLock = $false
            $EstimateOnly = $false
            $MaxDOP = $null
            $tableResults = $false
        }

        if ($Operation -eq 'CheckFileGroup') {
            $DataPurity = $false
            $ExtendedLogicalChecks = $false
        }

        if (Test-Bound -ParameterName PHYSICAL_ONLY) {
            $NoInformationalMessages = $true
        }

        $stringBuilder = New-Object System.Text.StringBuilder
        $null = $stringBuilder.Append("DBCC $Operation(#db#")

        if ($NoIndex) {
            $null = $stringBuilder.Append(",NOINDEX")
        }

        $null = $stringBuilder.Append(')')

        # Add WITH Options
        $optionInit = " WITH "

        if (Test-Bound -ParameterName MaxDOP) {
            $null = $stringBuilder.Append($optionInit)
            $null = $stringBuilder.Append("MAXDOP = $MaxDOP")
            $optionInit = ", "
        }

        if (Test-Bound -ParameterName AllErrorMessages) {
            $null = $stringBuilder.Append($optionInit)
            $null = $stringBuilder.Append("ALL_ERRORMSGS")
            $optionInit = ", "
        }

        if (Test-Bound -ParameterName ExtendedLogicalChecks) {
            $null = $stringBuilder.Append($optionInit)
            $null = $stringBuilder.Append("EXTENDED_LOGICAL_CHECKS")
            $optionInit = ", "
        }

        if (Test-Bound -ParameterName NoInformationalMessages) {
            $null = $stringBuilder.Append($optionInit)
            $null = $stringBuilder.Append("NO_INFOMSGS")
            $optionInit = ", "
        }

        if (Test-Bound -ParameterName TabLock) {
            $null = $stringBuilder.Append($optionInit)
            $null = $stringBuilder.Append("TABLOCK")
            $optionInit = ", "
        }

        if (Test-Bound -ParameterName EstimateOnly) {
            $null = $stringBuilder.Append($optionInit)
            $null = $stringBuilder.Append("ESTIMATEONLY")
            $optionInit = ", "
        }

        if (Test-Bound -ParameterName PhysicalOnly) {
            $null = $stringBuilder.Append($optionInit)
            $null = $stringBuilder.Append("PHYSICAL_ONLY")
            $optionInit = ", "
        }

        if ($tableResults -eq $true) {
            $null = $stringBuilder.Append($optionInit)
            $null = $stringBuilder.Append("TABLERESULTS")
            $optionInit = ", "
        }
    }

    PROCESS {
        if (Test-Bound -not 'SqlInstance', 'InputObject') {
            Write-Message -Level Warning -Message "You must specify either a SQL instance or supply an InputObject"
            return
        }
        if ($Operation -eq 'CheckTable') {
            if ((Test-Bound -Not -ParameterName InputObject) -and (Test-Bound -Not -ParameterName TableName)) {
                Stop-Function -Message "If you select the CheckTable option, you must supply values for either InputObject or TableName"
                return
            }
        }
        if ($Operation -eq 'CheckFileGroup') {
            if ((Test-Bound -Not -ParameterName InputObject) -and (Test-Bound -Not -ParameterName Filegroup)) {
                Stop-Function -Message "If you select the CheckFileGroup option, you must supply values for either InputObject or Filegroup"
                return
            }
        }

        if (Test-Bound -ParameterName InputObject) {
            foreach ($object in $InputObject) {
                $typeName = $object.GetType().ToString()
                $validObject = $false

                if ($typeName -eq 'Microsoft.SqlServer.Management.Smo.Table') {
                    $validObject = $true
                    if ($Operation -ne 'CheckTable') {
                        Write-Message -Message "InputObject passed of type $typename is not compatible with operation $Operation " -Level Verbose
                        Stop-Function -Message "If you supply an InputObject of type Microsoft.SqlServer.Management.Smo.Table the operation must be CheckTable"
                        return
                    }
                }

                if ($typeName -eq 'Microsoft.SqlServer.Management.Smo.FileGroup') {
                    $validObject = $true
                    if ($Operation -ne 'CheckFileGroup') {
                        Write-Message -Message "InputObject passed of type $typename is not compatible with operation $Operation " -Level Verbose
                        Stop-Function -Message "If you supply an InputObject of type Microsoft.SqlServer.Management.Smo.FileGroup the operation must be CheckFileGroup"
                        return
                    }
                }

                if ($typeName -eq 'Microsoft.SqlServer.Management.Smo.Database') {
                    $validObject = $true
                    if (($Operation -eq 'CheckTable') -AND (Test-Bound -not 'TableName')) {
                        Stop-Function -Message "The operation $Operation requires an entry for the TableName Parameter"
                        return
                    }
                    if (($Operation -eq 'CheckFileGroup') -AND (Test-Bound -not 'Filegroup')) {
                        Stop-Function -Message "The operation $Operation requires an entry for the FileGroup Parameter"
                        return
                    }
                }

                if (-not $validObject) {
                    Write-Message -Message "InputObject passed of type $typename is not compatible with operation $Operation " -Level Verbose
                    Stop-Function -Message "The InputObject of type $typename is not compatible with operation $Operation"
                    return
                }
            }
        } else {
            if ($Operation -eq 'CheckTable') {
                Write-Message -Message "Creating InputObject from Get-DbaDbTable" -Level Verbose
                $typeName = 'Microsoft.SqlServer.Management.Smo.Table'
                $InputObject = Get-DbaDbTable -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database -Table $TableName  -EnableException:$EnableException
            } elseif ($Operation -eq 'CheckFileGroup') {
                Write-Message -Message "Creating InputObject from Get-DbaDbFileGroup" -Level Verbose
                $typeName = 'Microsoft.SqlServer.Management.Smo.FileGroup'
                $InputObject = Get-DbaDbFileGroup -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database -FileGroup $FileGroup -EnableException:$EnableException

            } else {
                Write-Message -Message "Creating InputObject from Get-DbaDatabase" -Level Verbose
                $typeName = 'Microsoft.SqlServer.Management.Smo.Database'
                $InputObject += Get-DbaDatabase -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database
            }   # Process Data from SqlInstance
        }

        if (!$InputObject) {
            Write-Message -Message "No InputObject available" -Level Verbose
        }

        if (($Operation -eq 'CheckTable') -and ($typeName = 'Microsoft.SqlServer.Management.Smo.Table')) {
            Write-Message -Message "Processing CheckTable" -Level Verbose
            foreach ($tbl in $InputObject) {
                $db = $tbl.Parent
                $server = $db.Parent
                $dbName = $db.Name
                $tblName = '[' + $tbl.Schema.Replace(']', ']]') + '].[' + $tbl.Name.Replace(']', ']]') + ']'
                $results = $null

                $query = $StringBuilder.ToString()
                $query = $query.Replace('#db#', "'$tblName'")
                Write-Message -Message "Query to run: $query" -Level Verbose

                $startTime = Get-Date
                if (Test-Bound -ParameterName OutputScriptOnly) {
                    $results = 'Script Only'
                } elseif ($Pscmdlet.ShouldProcess($tblName, "Running operation DBCC $Operation")) {
                    try {
                        $results = Invoke-DbaQuery -SqlInstance $server -Database $dbName  -Query $query -MessagesToOutput -EnableException
                    } catch {
                        Stop-Function -Message "Failed to execute query: $query against the database $dbName on Server  $server" -ErrorRecord $_
                        return
                    }
                } else {
                    $results = 'No Operation performed.'
                }
                $endTime = Get-Date
                $duration = NEW-TIMESPAN -Start $startTime -End $endTime

                if (($null -eq $results) -or ($results.GetType().Name -eq 'String') ) {
                    [PSCustomObject]@{
                        ComputerName = $server.ComputerName
                        InstanceName = $server.ServiceName
                        SqlInstance  = $server.DomainInstanceName
                        DatabaseName = $dbName
                        Schema       = $tbl.Schema
                        TableName    = $tbl.Name
                        Operation    = $Operation
                        Query        = $query
                        Result       = $results
                        Error        = $null
                        Level        = $null
                        State        = $null
                        MessageText  = $null
                        RepairLevel  = $null
                        Status       = $null
                        DbId         = $null
                        DbFragId     = $null
                        ObjectId     = $null
                        IndexId      = $null
                        PartitionId  = $null
                        AllocUnitId  = $null
                        RidDbId      = $null
                        RidPruId     = $null
                        File         = $null
                        Page         = $null
                        Slot         = $null
                        RefDbId      = $null
                        RefPruId     = $null
                        RefFile      = $null
                        RefPage      = $null
                        RefSlot      = $null
                        Allocation   = $null
                        StartTime    = $startTime
                        Duratation   = $duration.TotalSeconds
                    }
                } elseif (($results.GetType().Name -eq 'Object[]') -or ($results.GetType().Name -eq 'DataRow')) {
                    foreach ($row in $results) {
                        Write-Message -Message $row.GetType().Name -Level Verbose
                        if ($row.GetType().Name -eq 'String') {
                            [PSCustomObject]@{
                                ComputerName = $server.ComputerName
                                InstanceName = $server.ServiceName
                                SqlInstance  = $server.DomainInstanceName
                                DatabaseName = $dbName
                                Schema       = $tbl.Schema
                                TableName    = $tbl.Name
                                Operation    = $Operation
                                Query        = $query
                                Result       = $row
                                Error        = $null
                                Level        = $null
                                State        = $null
                                MessageText  = $null
                                RepairLevel  = $null
                                Status       = $null
                                DbId         = $null
                                DbFragId     = $null
                                ObjectId     = $null
                                IndexId      = $null
                                PartitionId  = $null
                                AllocUnitId  = $null
                                RidDbId      = $null
                                RidPruId     = $null
                                File         = $null
                                Page         = $null
                                Slot         = $null
                                RefDbId      = $null
                                RefPruId     = $null
                                RefFile      = $null
                                RefPage      = $null
                                RefSlot      = $null
                                Allocation   = $null
                                StartTime    = $startTime
                                Duratation   = $duration.TotalSeconds
                            }
                        } else {
                            # Adjustments for change in Schema across Versions
                            # SQL Server 2000
                            if ($versionMajor -eq 8) {
                                $objectId = $row.Id
                                $indexId = $row.IndId
                                $partitionId = $null
                                $allocUnitId = $null
                            } else {
                                $objectId = $row.ObjectId
                                $indexId = $row.IndexId
                                $partitionId = $row.PartitionId
                                $allocUnitId = $row.AllocUnitId
                            }
                            # SQL Server 2008R2 or earlier
                            if ($versionMajor -lt 11) {
                                $dbFragId = $null
                                $ridDbId = $null
                                $ridPruId = $null
                                $refDbId = $null
                                $refPruId = $null
                            } else {
                                $dbFragId = $row.DbFragId
                                $ridDbId = $row.RidDbId
                                $ridPruId = $row.RidPruId
                                $refDbId = $row.RefDbId
                                $refPruId = $row.RefPruId
                            }

                            [PSCustomObject]@{
                                ComputerName = $server.ComputerName
                                InstanceName = $server.ServiceName
                                SqlInstance  = $server.DomainInstanceName
                                DatabaseName = $dbName
                                Schema       = $tbl.Schema
                                TableName    = $tbl.Name
                                Operation    = $Operation
                                Query        = $query
                                Result       = $null
                                Error        = $row.Error
                                Level        = $row.Level
                                State        = $row.State
                                MessageText  = $row.MessageText
                                RepairLevel  = $row.RepairLevel
                                Status       = $row.Status
                                DbId         = $row.DbId
                                DbFragId     = $dbFragId
                                ObjectId     = $objectId
                                IndexId      = $indexId
                                PartitionId  = $partitionId
                                AllocUnitId  = $allocUnitId
                                RidDbId      = $ridDbId
                                RidPruId     = $ridPruId
                                File         = $row.File
                                Page         = $row.Page
                                Slot         = $row.Slot
                                RefDbId      = $refDbId
                                RefPruId     = $refPruId
                                RefFile      = $row.RefFile
                                RefPage      = $row.RefPage
                                RefSlot      = $row.RefSlot
                                Allocation   = $row.Allocation
                                StartTime    = $startTime
                                Duratation   = $duration.TotalSeconds
                            }
                        }
                    }
                }

            }
        } elseif (($Operation -eq 'CheckFileGroup') -and ($typeName = 'Microsoft.SqlServer.Management.Smo.FileGroup')) {
            Write-Message -Message "Processing CheckFileGroup" -Level Verbose
            foreach ($fg in $InputObject) {
                if ($fg.FileGroupType -ne 'RowsFileGroup') {
                    Write-Message -Message "Skipping Processing of FileGroup $fg as not supported type" -Level Verbose
                    Continue
                }

                $db = $fg.Parent
                $server = $db.Parent
                $dbName = $db.Name
                $fgNameQuoted = '[' + $fg.Name.Replace(']', ']]') + ']'
                $results = $null

                $query = $StringBuilder.ToString()
                $query = $query.Replace('#db#', "$fgNameQuoted")
                Write-Message -Message "Query to run: $query" -Level Verbose

                $startTime = Get-Date
                if (Test-Bound -ParameterName OutputScriptOnly) {
                    $results = 'Script Only'
                } elseif ($Pscmdlet.ShouldProcess($fg.Name, "Running operation DBCC $Operation  ")) {
                    try {
                        $results = Invoke-DbaQuery -SqlInstance $server -Database $dbName  -Query $query -MessagesToOutput -EnableException
                    } catch {
                        Stop-Function -Message "Failed to execute query: $query against the database $dbName on Server  $server" -ErrorRecord $_
                        return
                    }
                } else {
                    $results = 'No Operation performed.'
                }
                $endTime = Get-Date
                $duration = NEW-TIMESPAN -Start $startTime -End $endTime

                if (($null -eq $results) -or ($results.GetType().Name -eq 'String') ) {
                    [PSCustomObject]@{
                        ComputerName = $server.ComputerName
                        InstanceName = $server.ServiceName
                        SqlInstance  = $server.DomainInstanceName
                        DatabaseName = $dbName
                        FileGroup    = $fg.Name
                        Operation    = $Operation
                        Query        = $query
                        Result       = $results
                        Error        = $null
                        Level        = $null
                        State        = $null
                        MessageText  = $null
                        RepairLevel  = $null
                        Status       = $null
                        DbId         = $null
                        DbFragId     = $null
                        ObjectId     = $null
                        IndexId      = $null
                        PartitionId  = $null
                        AllocUnitId  = $null
                        RidDbId      = $null
                        RidPruId     = $null
                        File         = $null
                        Page         = $null
                        Slot         = $null
                        RefDbId      = $null
                        RefPruId     = $null
                        RefFile      = $null
                        RefPage      = $null
                        RefSlot      = $null
                        Allocation   = $null
                        StartTime    = $startTime
                        Duratation   = $duration.TotalSeconds
                    }
                } elseif (($results.GetType().Name -eq 'Object[]') -or ($results.GetType().Name -eq 'DataRow')) {
                    foreach ($row in $results) {
                        Write-Message -Message $row.GetType().Name -Level Verbose
                        if ($row.GetType().Name -eq 'String') {
                            [PSCustomObject]@{
                                ComputerName = $server.ComputerName
                                InstanceName = $server.ServiceName
                                SqlInstance  = $server.DomainInstanceName
                                DatabaseName = $dbName
                                FileGroup    = $fg.Name
                                Operation    = $Operation
                                Query        = $query
                                Result       = $row
                                Error        = $null
                                Level        = $null
                                State        = $null
                                MessageText  = $null
                                RepairLevel  = $null
                                Status       = $null
                                DbId         = $null
                                DbFragId     = $null
                                ObjectId     = $null
                                IndexId      = $null
                                PartitionId  = $null
                                AllocUnitId  = $null
                                RidDbId      = $null
                                RidPruId     = $null
                                File         = $null
                                Page         = $null
                                Slot         = $null
                                RefDbId      = $null
                                RefPruId     = $null
                                RefFile      = $null
                                RefPage      = $null
                                RefSlot      = $null
                                Allocation   = $null
                                StartTime    = $startTime
                                Duratation   = $duration.TotalSeconds
                            }
                        } else {
                            # Adjustments for change in Schema across Versions
                            # SQL Server 2000
                            if ($versionMajor -eq 8) {
                                $objectId = $row.Id
                                $indexId = $row.IndId
                                $partitionId = $null
                                $allocUnitId = $null
                            } else {
                                $objectId = $row.ObjectId
                                $indexId = $row.IndexId
                                $partitionId = $row.PartitionId
                                $allocUnitId = $row.AllocUnitId
                            }
                            # SQL Server 2008R2 or earlier
                            if ($versionMajor -lt 11) {
                                $dbFragId = $null
                                $ridDbId = $null
                                $ridPruId = $null
                                $refDbId = $null
                                $refPruId = $null
                            } else {
                                $dbFragId = $row.DbFragId
                                $ridDbId = $row.RidDbId
                                $ridPruId = $row.RidPruId
                                $refDbId = $row.RefDbId
                                $refPruId = $row.RefPruId
                            }


                            [PSCustomObject]@{
                                ComputerName = $server.ComputerName
                                InstanceName = $server.ServiceName
                                SqlInstance  = $server.DomainInstanceName
                                DatabaseName = $dbName
                                FileGroup    = $fg.Name
                                Operation    = $Operation
                                Query        = $query
                                Result       = $null
                                Error        = $row.Error
                                Level        = $row.Level
                                State        = $row.State
                                MessageText  = $row.MessageText
                                RepairLevel  = $row.RepairLevel
                                Status       = $row.Status
                                DbId         = $row.DbId
                                DbFragId     = $dbFragId
                                ObjectId     = $objectId
                                IndexId      = $indexId
                                PartitionId  = $partitionId
                                AllocUnitId  = $allocUnitId
                                RidDbId      = $ridDbId
                                RidPruId     = $ridPruId
                                File         = $row.File
                                Page         = $row.Page
                                Slot         = $row.Slot
                                RefDbId      = $refDbId
                                RefPruId     = $refPruId
                                RefFile      = $row.RefFile
                                RefPage      = $row.RefPage
                                RefSlot      = $row.RefSlot
                                Allocation   = $row.Allocation
                                StartTime    = $startTime
                                Duratation   = $duration.TotalSeconds
                            }
                        }
                    }
                }

            }
        } else {
            Write-Message -Message "Processing $Operation" -Level Verbose
            foreach ($db in $InputObject) {

                $server = $db.Parent
                $versionMajor = $server.VersionMajor
                $dbName = $db.Name
                $dbNameQuoted = '[' + $db.Name.Replace(']', ']]') + ']'
                $results = $null

                if ($db.IsAccessible -eq $false) {
                    Stop-Function -Message "The database $db on server $instance is not accessible. Skipping database." -Continue
                }

                $query = $StringBuilder.ToString()
                $query = $query.Replace('#db#', "$dbNameQuoted")
                Write-Message -Message "Query to run: $query" -Level Verbose

                $startTime = Get-Date
                if (Test-Bound -ParameterName OutputScriptOnly) {
                    $results = 'Script Only'
                } elseif ($Pscmdlet.ShouldProcess($dbName, "Running operation DBCC $Operation  ")) {
                    try {
                        $results = Invoke-DbaQuery -SqlInstance $server -Database $dbName  -Query $query -MessagesToOutput -EnableException
                    } catch {
                        Stop-Function -Message "Failed to execute query: $query against the datbase $dbName on Server  $server" -ErrorRecord $_
                        return
                    }
                } else {
                    $results = 'No Operation performed.'
                }
                $endTime = Get-Date
                $duration = NEW-TIMESPAN -Start $startTime -End $endTime

                if (($null -eq $results) -or ($results.GetType().Name -eq 'String') ) {
                    [PSCustomObject]@{
                        ComputerName = $server.ComputerName
                        InstanceName = $server.ServiceName
                        SqlInstance  = $server.DomainInstanceName
                        DatabaseName = $dbName
                        Operation    = $Operation
                        Query        = $query
                        Result       = $results
                        Error        = $null
                        Level        = $null
                        State        = $null
                        MessageText  = $null
                        RepairLevel  = $null
                        Status       = $null
                        DbId         = $null
                        DbFragId     = $null
                        ObjectId     = $null
                        IndexId      = $null
                        PartitionId  = $null
                        AllocUnitId  = $null
                        RidDbId      = $null
                        RidPruId     = $null
                        File         = $null
                        Page         = $null
                        Slot         = $null
                        RefDbId      = $null
                        RefPruId     = $null
                        RefFile      = $null
                        RefPage      = $null
                        RefSlot      = $null
                        Allocation   = $null
                        StartTime    = $startTime
                        Duratation   = $duration.TotalSeconds
                    }
                } elseif (($results.GetType().Name -eq 'Object[]') -or ($results.GetType().Name -eq 'DataRow')) {
                    foreach ($row in $results) {
                        Write-Message -Message $row.GetType().Name -Level Verbose
                        if ($row.GetType().Name -eq 'String') {
                            [PSCustomObject]@{
                                ComputerName = $server.ComputerName
                                InstanceName = $server.ServiceName
                                SqlInstance  = $server.DomainInstanceName
                                DatabaseName = $dbName
                                Operation    = $Operation
                                Query        = $query
                                Result       = $row
                                Error        = $null
                                Level        = $null
                                State        = $null
                                MessageText  = $null
                                RepairLevel  = $null
                                Status       = $null
                                DbId         = $null
                                DbFragId     = $null
                                ObjectId     = $null
                                IndexId      = $null
                                PartitionId  = $null
                                AllocUnitId  = $null
                                RidDbId      = $null
                                RidPruId     = $null
                                File         = $null
                                Page         = $null
                                Slot         = $null
                                RefDbId      = $null
                                RefPruId     = $null
                                RefFile      = $null
                                RefPage      = $null
                                RefSlot      = $null
                                Allocation   = $null
                                StartTime    = $startTime
                                Duratation   = $duration.TotalSeconds
                            }
                        } else {
                            # Adjustments for change in Schema across Versions
                            # SQL Server 2000
                            if ($versionMajor -eq 8) {
                                $objectId = $row.Id
                                $indexId = $row.IndId
                                $partitionId = $null
                                $allocUnitId = $null
                            } else {
                                $objectId = $row.ObjectId
                                $indexId = $row.IndexId
                                $partitionId = $row.PartitionId
                                $allocUnitId = $row.AllocUnitId
                            }
                            # SQL Server 2008R2 or earlier
                            if ($versionMajor -lt 11) {
                                $dbFragId = $null
                                $ridDbId = $null
                                $ridPruId = $null
                                $refDbId = $null
                                $refPruId = $null
                            } else {
                                $dbFragId = $row.DbFragId
                                $ridDbId = $row.RidDbId
                                $ridPruId = $row.RidPruId
                                $refDbId = $row.RefDbId
                                $refPruId = $row.RefPruId
                            }

                            [PSCustomObject]@{
                                ComputerName = $server.ComputerName
                                InstanceName = $server.ServiceName
                                SqlInstance  = $server.DomainInstanceName
                                DatabaseName = $dbName
                                Operation    = $Operation
                                Query        = $query
                                Result       = $null
                                Error        = $row.Error
                                Level        = $row.Level
                                State        = $row.State
                                MessageText  = $row.MessageText
                                RepairLevel  = $row.RepairLevel
                                Status       = $row.Status
                                DbId         = $row.DbId
                                DbFragId     = $dbFragId
                                ObjectId     = $objectId
                                IndexId      = $indexId
                                PartitionId  = $partitionId
                                AllocUnitId  = $allocUnitId
                                RidDbId      = $ridDbId
                                RidPruId     = $ridPruId
                                File         = $row.File
                                Page         = $row.Page
                                Slot         = $row.Slot
                                RefDbId      = $refDbId
                                RefPruId     = $refPruId
                                RefFile      = $row.RefFile
                                RefPage      = $row.RefPage
                                RefSlot      = $row.RefSlot
                                Allocation   = $row.Allocation
                                StartTime    = $startTime
                                Duratation   = $duration.TotalSeconds
                            }
                        }
                    }
                }
            }
        }
    }
}