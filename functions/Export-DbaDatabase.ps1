function Export-DbaDatabase {
    <#
    .SYNOPSIS
        Exports SQL Server *ALL* database restore scripts, logins, database mail profiles/accounts, credentials, SQL Agent objects, linked servers,
        Central Management Server objects, server configuration settings (sp_configure), user objects in systems databases,
        system triggers and backup devices from one SQL Server to another.

        For more granular control, please use one of the -Exclude parameters and use the other functions available within the dbatools module.

    .DESCRIPTION
        Export-DbaDatabase consolidates export of scripts for Database level objects into one command.

        This can be used to create a Schema Only backup or to script out an entire databse to be put in Source Control or for documentation
        The following database level object will be exported unless overridded by Include or Exclude switches

        Databases
        Schemas
        Tables
        Views
        StoredProcedures
        UserDefinedFunctions
        UserDefinedDataTypes
        UserDefinedTableTypes
        UserDefinedTypes
        UserDefinedAggregates
        Assemblies
        PartitionFunctions
        PartitionSchemes
        Triggers
        Sequencies
        Synonyms
        Roles
        Rules

    .PARAMETER SqlInstance
        The target SQL Server instances

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Database
        The database(s) to process - this list is auto-populated from the server. If unspecified, all databases will be processed.

    .PARAMETER Path
        Specifies the directory where the file or files will be exported.
        Will default to Path.DbatoolsExport Configuration entry

    .PARAMETER FilePath
        Specifies the full file path of the output file. If left blank then filename based on Instance name, Database name and date is created.
        If more than one database or instance is input then this parameter should normally be blank.

    .PARAMETER Include
        Include one or more objects to export.

        Databases
        Schemas
        Tables
        Views
        StoredProcedures
        UserDefinedFunctions
        UserDefinedDataTypes
        UserDefinedTableTypes
        UserDefinedTypes
        UserDefinedAggregates
        Assemblies
        PartitionFunctions
        PartitionSchemes
        Triggers
        Sequencies
        Synonyms
        Roles
        Rules

        If left blank all object are expported

    .PARAMETER Exclude
        Exclude one or more objects to export, Exclude will overide Include

        Databases
        Schemas
        Tables
        Views
        StoredProcedures
        UserDefinedFunctions
        UserDefinedDataTypes
        UserDefinedTableTypes
        UserDefinedTypes
        UserDefinedAggregates
        Assemblies
        PartitionFunctions
        PartitionSchemes
        Triggers
        Sequencies
        Synonyms
        Roles
        Rules

    .PARAMETER ScriptingOption
        Add scripting options to scripting output for all objects except Registered Servers and Extended Events.

    .PARAMETER BatchSeparator
        Batch separator for scripting output. Uses the value from configuration Formatting.BatchSeparator by default. This is normally "GO"

    .PARAMETER NoPrefix
        Do not include a Prefix

    .PARAMETER NoClobber
        Do not overwrite file

    .PARAMETER Append
        Append to file

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Export, Database
        Author: Patrick Flynn (@sqllensman)

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Export-DbaDatabase

    .EXAMPLE
        PS C:\> Export-DbaDatabase -SqlInstance sqlserver\instance

        All databases, logins, job objects and sp_configure options will be exported from
        sqlserver\instance to an automatically generated folder name in Documents.

    .EXAMPLE
        PS C:\> Export-DbaInstance -SqlInstance sqlcluster -Exclude Databases, Logins -Path C:\dr\sqlcluster

        Exports everything but logins and database restore scripts to C:\dr\sqlcluster

    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [Alias("ServerInstance", "SqlServer")]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [Microsoft.SqlServer.Management.Smo.ScriptingOptions]$ScriptingOption,
        [object[]]$Database,
        [string]$Path,
        [string]$FilePath,
        [ValidateSet('SingleFile', 'Nested', 'NestedByDate')]
        [string]$OutputStyle = 'NestedByDate',
        [ValidateSet('Databases', 'Schemas', 'Tables', 'Views', 'StoredProcedures', 'UserDefinedFunctions', 'UserDefinedDataTypes', 'UserDefinedTableTypes', 'UserDefinedTypes', 'UserDefinedAggregates', 'Assemblies', 'PartitionFunctions', 'PartitionSchemes', 'Triggers', 'Sequencies', 'Synonyms', 'Roles', 'Rules')]
        [string[]]$Include,
        [ValidateSet('Databases', 'Schemas', 'Tables', 'Views', 'StoredProcedures', 'UserDefinedFunctions', 'UserDefinedDataTypes', 'UserDefinedTableTypes', 'UserDefinedTypes', 'UserDefinedAggregates', 'Assemblies', 'PartitionFunctions', 'PartitionSchemes', 'Triggers', 'Sequencies', 'Synonyms', 'Roles', 'Rules')]
        [string[]]$Exclude,
        [string]$BatchSeparator = (Get-DbatoolsConfigValue -FullName 'Formatting.BatchSeparator'),
        [switch]$NoClobber,
        [switch]$Append,
        [switch]$NoPrefix,
        [ValidateSet('ASCII', 'BigEndianUnicode', 'Byte', 'String', 'Unicode', 'UTF7', 'UTF8', 'Unknown')]
        [string]$Encoding = 'UTF8',
        [switch]$EnableException
    )
    begin {
        if ((Test-Bound -ParameterName Path)) {
            if (-not ((Get-Item $Path -ErrorAction Ignore) -is [System.IO.DirectoryInfo])) {
                Stop-Function -Message "Path must be a directory"
            }
        } 

        if (-not $ScriptingOption) {
            $ScriptingOption = New-DbaScriptingOption
            $ScriptingOption.ScriptBatchTerminator = $true
            $ScriptingOption.AnsiFile = $true
        }

        $elapsed = [System.Diagnostics.Stopwatch]::StartNew()
        $started = Get-Date

        [string[]]$databaseObjects = 'Databases', 'Schemas', 'Tables', 'Views', 'StoredProcedures', 'UserDefinedFunctions', 'UserDefinedDataTypes', 'UserDefinedTableTypes', 'UserDefinedTypes', 'UserDefinedAggregates', 'Assemblies', 'PartitionFunctions', 'PartitionSchemes', 'Triggers', 'Sequencies', 'Synonyms', 'Roles', 'Rules'

        if (Test-Bound -ParameterName Include) {
            $DatabaseObjects = $DatabaseObjects | Where-Object { $Include -contains $_ }
        }
        if (Test-Bound -ParameterName Exclude) {
            $DatabaseObjects = $DatabaseObjects | Where-Object { $Exclude -notcontains $_ }
        }
        
    }
    process {
        if (Test-FunctionInterrupt) { return }

        foreach ($instance in $SqlInstance) {
            try {
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $sqlcredential -MinimumVersion 10 
            } catch {
                Stop-Function -Message "Error occurred while establishing connection to $instance" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            $serverName = $($server.name.replace('\', '$'))
            $timeNow = (Get-Date -uformat (Get-DbatoolsConfigValue -FullName 'Formatting.UFormat'))

            if ($OutputStyle -eq 'NestedByDate') {
                $scriptPath = Join-DbaPath -Path $Path $servername $timenow
            } elseif ($OutputStyle -eq 'Nested') {
                $scriptPath = Join-DbaPath -Path $Path $serverName
            } else  {
                $scriptPath = $Path
            }

            $Databases = Get-DbaDatabase -SqlInstance $server -Database $Database 

            foreach ($db in $Databases) {
                $dbName = $db.Name.replace('\', '$')

                if ($OutputStyle -ne 'SingleFile') {
                    $nestedPath = Join-DbaPath -Path $scriptPath $dbName 
                    $scriptFile = Join-DbaPath -Path $nestedPath -Child "$dbName.sql"
                } else  {
                    if ($FilePath) {
                        $scriptFile = $FilePath
                    } else {
                        $scriptFile = Join-DbaPath -Path $scriptPath -Child "$serverName-$dbName-$timeNow.sql"
                    }
                    $nestedPath = $Path
                }

                 #region Database Scripts
                if ($DatabaseObjects -contains 'Databases') {
                    Export-DbaScript -InputObject $db -Path $nestedPath -FilePath $scriptFile  -Encoding $Encoding -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix -Append:$Append -NoClobber:$NoClobber -BatchSeparator $BatchSeparator
                }
                $scriptPath = $nestedPath
                #endregion \

                #region Schema Scripts
                $objectName = 'Schemas'
                if ($DatabaseObjects -contains $objectName) {
                    $objectName = 'Schemas'
                    Write-Message -Level Verbose -Message "Creating script for $objectName in database $dbName."

                    $objCollection = ($db.Schemas | Where-Object {$_.IsSystemObject -eq $false})

                    if ($objCollection.Count -gt 0) {
                        foreach($obj in $objCollection) {
                            if ($OutputStyle -ne 'SingleFile') { 
                                $nestedPath = Join-DbaPath -Path $scriptPath $objectName 
                                $scriptFile = Join-DbaPath -Path $nestedPath -Child "$($obj.Name).sql"
                            } 
                            Export-DbaScript -InputObject $obj -Path $nestedPath -FilePath $scriptFile -Encoding $Encoding -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix -Append:$Append -NoClobber:$NoClobber -BatchSeparator $BatchSeparator                    
                        }
                    }
                }
                #endregion

                #region Tables Scripts
                $objectName = 'Tables'
                if ($DatabaseObjects -contains $objectName) {
                    Write-Message -Level Verbose -Message "Creating script for $objectName in database $dbName."

                    $objCollection =  ($db.Tables | Where-Object {$_.IsSystemObject -eq $false})

                    if ($objCollection.Count -gt 0) {
                        #Scripting Options
                        $ScriptingOption.ColumnStoreIndexes = $true
                        $ScriptingOption.ConvertUserDefinedDataTypesToBaseType  = $true
                        $ScriptingOption.DriAll  = $true
                        $ScriptingOption.IncludeDatabaseContext  = $true
                        $ScriptingOption.IncludeIfNotExists = $false
                        $ScriptingOption.Indexes  = $true
                        $ScriptingOption.NoFileGroup = $false
                        $ScriptingOption.NonClusteredIndexes  = $true
                        $ScriptingOption.SpatialIndexes  = $true
                        $ScriptingOption.XmlIndexes  = $true
                        $ScriptingOption.Triggers = ($DatabaseObjects -contains 'Triggers')
                
                        foreach($obj in $objCollection) {
                            if ($OutputStyle -ne 'SingleFile') { 
                                $nestedPath = Join-DbaPath -Path $scriptPath $objectName 
                                $scriptFile = Join-DbaPath -Path $nestedPath -Child "$($obj.Schema).$($obj.Name).sql"
                            }
                            Export-DbaScript -InputObject $obj -Path $nestedPath -FilePath $scriptFile -Encoding $Encoding -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix -Append:$Append -NoClobber:$NoClobber -BatchSeparator $BatchSeparator                    
                        }
                    }
                }
                #endregion

                #region Views Scripts
                $objectName = 'Views'
                if ($DatabaseObjects -contains $objectName) {
                    Write-Message -Level Verbose -Message "Creating script for $objectName in database $dbName."
                    
                    $modules = Get-DbaModule -InputObject $db -Type View -ExcludeSystemObjects 
                    if ($modules) {
                        #Scripting Options
                        $ScriptingOption.IncludeDatabaseContext  = $true
                        $ScriptingOption.IncludeIfNotExists = $false
                        $ScriptingOption.Indexes  = $true
                        $ScriptingOption.NoFileGroup = $false
                        $ScriptingOption.Triggers = ($DatabaseObjects -contains 'Triggers')
                
                        foreach($colObject in $modules) {
                            Write-Message -Level Verbose -Message "Creating script for view $($colObject.SchemaName).$($colObject.Name)"
                            $obj = $db.Views.ItemById($colObject.ObjectID)

                            if ($OutputStyle -ne 'SingleFile') {  
                                $nestedPath = Join-DbaPath -Path $scriptPath $objectName
                                $scriptFile = Join-DbaPath -Path $nestedPath -Child "$($obj.Schema).$($obj.Name).sql"
                            }
                            Write-Message -Level Verbose -Message "$nestedPath"
                            Export-DbaScript -InputObject $obj -Path $nestedPath -FilePath $scriptFile -Encoding $Encoding -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix -Append:$Append -NoClobber:$NoClobber -BatchSeparator $BatchSeparator                         
                        }
                    }
                }
                #endregion

                #region StoredProcedures Scripts
                $objectName = 'StoredProcedures'
                if ($DatabaseObjects -contains $objectName) {
                    Write-Message -Level Verbose -Message "Creating script for $objectName in database $dbName."
                    
                    $modules = Get-DbaModule -InputObject $db -Type StoredProcedure -ExcludeSystemObjects 
                    if ($modules) {
                        #Scripting Options
                        $ScriptingOption.IncludeDatabaseContext  = $true
                        $ScriptingOption.IncludeIfNotExists = $false
                
                        foreach($colObject in $modules) {
                            Write-Message -Level Verbose -Message "Creating script for stored procedure $($colObject.SchemaName).$($colObject.Name)"
                            $obj = $db.StoredProcedures.ItemById($colObject.ObjectID)

                            if ($OutputStyle -ne 'SingleFile') {  
                                $nestedPath = Join-DbaPath -Path $scriptPath $objectName
                                $scriptFile = Join-DbaPath -Path $nestedPath -Child "$($obj.Schema).$($obj.Name).sql"
                            }
                            Export-DbaScript -InputObject $obj -Path $nestedPath -FilePath $scriptFile -Encoding $Encoding -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix -Append:$Append -NoClobber:$NoClobber -BatchSeparator $BatchSeparator                        
                        }

                    }
                }
                #endregion

                #region UserDefinedFunctions Scripts
                $objectName = 'UserDefinedFunctions'
                if ($DatabaseObjects -contains $objectName) {
                    Write-Message -Level Verbose -Message "Creating script for $objectName in database $dbName."

                    # ScalarFunction
                    $modules = Get-DbaModule -InputObject $db -Type ScalarFunction -ExcludeSystemObjects 
                    if ($modules) {
                        #Scripting Options
                        $ScriptingOption.IncludeDatabaseContext  = $true
                        $ScriptingOption.IncludeIfNotExists = $false
                
                        foreach($colObject in $modules) {
                            Write-Message -Level Verbose -Message "Creating script for User Defined Function $($colObject.SchemaName).$($colObject.Name)"
                            $obj = $db.UserDefinedFunctions.ItemById($colObject.ObjectID)

                            if ($OutputStyle -ne 'SingleFile') {  
                                $nestedPath = Join-DbaPath -Path $scriptPath $objectName 'ScalarFunctions'
                                $scriptFile = Join-DbaPath -Path $nestedPath -Child "$($obj.Schema).$($obj.Name).sql"
                            }
                            Export-DbaScript -InputObject $obj -Path $nestedPath -FilePath $scriptFile -Encoding $Encoding -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix -Append:$Append -NoClobber:$NoClobber -BatchSeparator $BatchSeparator                         
                        }
                    }

                    # TableValuedFunction
                    $modules = Get-DbaModule -InputObject $db -Type TableValuedFunction -ExcludeSystemObjects 
                    if ($modules) {
                        #Scripting Options
                        $ScriptingOption.IncludeDatabaseContext  = $true
                        $ScriptingOption.IncludeIfNotExists = $false
                
                        foreach($colObject in $modules) {
                            Write-Message -Level Verbose -Message "Creating script for User Defined Function $($colObject.SchemaName).$($colObject.Name)"
                            $obj = $db.UserDefinedFunctions.ItemById($colObject.ObjectID)

                            if ($OutputStyle -ne 'SingleFile') {  
                                $nestedPath = Join-DbaPath -Path $scriptPath $objectName 'TableValuedFunctions'
                                $scriptFile = Join-DbaPath -Path $nestedPath -Child "$($obj.Schema).$($obj.Name).sql"
                            }
                            Export-DbaScript -InputObject $obj -Path $nestedPath -FilePath $scriptFile -Encoding $Encoding -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix -Append:$Append -NoClobber:$NoClobber -BatchSeparator $BatchSeparator                         
                        }
                    }

                    # ScalarFunction
                    $modules = Get-DbaModule -InputObject $db -Type InlineTableValuedFunction -ExcludeSystemObjects 
                    if ($modules) {
                        #Scripting Options
                        $ScriptingOption.IncludeDatabaseContext  = $true
                        $ScriptingOption.IncludeIfNotExists = $false
                
                        foreach($colObject in $modules) {
                            Write-Message -Level Verbose -Message "Creating script for User Defined Function $($colObject.SchemaName).$($colObject.Name)"
                            $obj = $db.UserDefinedFunctions.ItemById($colObject.ObjectID)

                            if ($OutputStyle -ne 'SingleFile') {  
                                $nestedPath = Join-DbaPath -Path $scriptPath $objectName 'InlineTableValuedFunction'
                                $scriptFile = Join-DbaPath -Path $nestedPath -Child "$($obj.Schema).$($obj.Name).sql"
                            }
                            Export-DbaScript -InputObject $obj -Path $nestedPath -FilePath $scriptFile -Encoding $Encoding -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix -Append:$Append -NoClobber:$NoClobber -BatchSeparator $BatchSeparator                         
                        }
                    }
                }
                #endregion

                #region UserDefinedDataTypes Scripts
                $objectName = 'UserDefinedDataTypes'
                if ($DatabaseObjects -contains $objectName) {
                    Write-Message -Level Verbose -Message "Creating script for $objectName in database $dbName."

                    $objCollection = $db.UserDefinedDataTypes

                    if ($objCollection.Count -gt 0) {
                        #Scripting Options
                        $ScriptingOption.IncludeDatabaseContext  = $true
                        $ScriptingOption.IncludeIfNotExists = $false
                 
                        foreach($obj in $objCollection) {
                            if ($OutputStyle -ne 'SingleFile') {  
                                $nestedPath = Join-DbaPath -Path $scriptPath $objectName
                                $scriptFile = Join-DbaPath -Path $nestedPath -Child "$($obj.Schema).$($obj.Name).sql"
                            }
                            Export-DbaScript -InputObject $obj -Path $nestedPath -FilePath $scriptFile -Encoding $Encoding -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix -Append:$Append -NoClobber:$NoClobber -BatchSeparator $BatchSeparator                   
                        }
                    }
                }
                #endregion

                #region UserDefinedTableTypes Scripts
                $objectName = 'UserDefinedTableTypes'
                if ($DatabaseObjects -contains $objectName) {
                    Write-Message -Level Verbose -Message "Creating script for $objectName in database $dbName."
                    
                    $objCollection = $db.UserDefinedTableTypes

                    if ($objCollection.Count -gt 0) {
                        #Scripting Options
                        $ScriptingOption.IncludeDatabaseContext  = $true
                        $ScriptingOption.IncludeIfNotExists = $false
                
                        foreach($obj in $objCollection) {
                            if ($OutputStyle -ne 'SingleFile') {  
                                $nestedPath = Join-DbaPath -Path $scriptPath $objectName
                                $scriptFile = Join-DbaPath -Path $nestedPath -Child "$($obj.Schema).$($obj.Name).sql"
                            }
                            Export-DbaScript -InputObject $obj -Path $nestedPath -FilePath $scriptFile -Encoding $Encoding -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix -Append:$Append -NoClobber:$NoClobber -BatchSeparator $BatchSeparator                    
                        }
                    }
                }
                #endregion    
                        
                #region UserDefinedTypes Scripts
                $objectName = 'UserDefinedTypes'
                if ($DatabaseObjects -contains $objectName) {
                    Write-Message -Level Verbose -Message "Creating script for $objectName in database $dbName."

                    $objCollection = $db.UserDefinedTypes

                    if ($objCollection.Count -gt 0) {
                        #Scripting Options
                        $ScriptingOption.IncludeDatabaseContext  = $true
                        $ScriptingOption.IncludeIfNotExists = $false
                
                        foreach($obj in $objCollection) {
                            if ($OutputStyle -ne 'SingleFile') { 
                                $nestedPath = Join-DbaPath -Path $scriptPath $objectName 
                                $scriptFile = Join-DbaPath -Path $nestedPath -Child "$($obj.Schema).$($obj.Name).sql"
                            }
                            Export-DbaScript -InputObject $obj -Path $nestedPath -FilePath $scriptFile -Encoding $Encoding -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix -Append:$Append -NoClobber:$NoClobber -BatchSeparator $BatchSeparator                    
                        }
                    }
                }
                #endregion   

                #region UserDefinedAggregates Scripts
                $objectName = 'UserDefinedAggregates'
                if ($DatabaseObjects -contains $objectName) {
                    Write-Message -Level Verbose -Message "Creating script for $objectName in database $dbName."

                    $objCollection = $db.UserDefinedAggregates

                    if ($objCollection.Count -gt 0) {
                        #Scripting Options
                        $ScriptingOption.IncludeDatabaseContext  = $true
                        $ScriptingOption.IncludeIfNotExists = $false
                
                        foreach($obj in $objCollection) {
                            if ($OutputStyle -ne 'SingleFile') {  
                                $nestedPath = Join-DbaPath -Path $scriptPath $objectName
                                $scriptFile = Join-DbaPath -Path $nestedPath -Child "$($obj.Schema).$($obj.Name).sql"
                            }
                            Export-DbaScript -InputObject $obj -Path $nestedPath -FilePath $scriptFile -Encoding $Encoding -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix -Append:$Append -NoClobber:$NoClobber -BatchSeparator $BatchSeparator                     
                        }
                    }
                }
                #endregion   

                #region Assemblies Scripts
                $objectName = 'Assemblies'
                if ($DatabaseObjects -contains $objectName) {
                    Write-Message -Level Verbose -Message "Creating script for $objectName in database $dbName."

                    $objCollection =  ($db.Assemblies | Where-Object {$_.IsSystemObject -eq $false})

                    if ($objCollection.Count -gt 0) {
                        #Scripting Options
                        $ScriptingOption.IncludeDatabaseContext  = $true
                        $ScriptingOption.IncludeIfNotExists = $false
                
                        foreach($obj in $objCollection) {
                            if ($OutputStyle -ne 'SingleFile') { 
                                $nestedPath = Join-DbaPath -Path $scriptPath $objectName 
                                $scriptFile = Join-DbaPath -Path $nestedPath -Child "$($obj.Name).sql"
                            }
                            Export-DbaScript -InputObject $obj -Path $nestedPath -FilePath $scriptFile -Encoding $Encoding -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix -Append:$Append -NoClobber:$NoClobber -BatchSeparator $BatchSeparator                     
                        }
                    }
                }
                #endregion  

                #region PartitionFunctions Scripts
                $objectName = 'PartitionFunctions'
                if ($DatabaseObjects -contains 'PartitionFunctions') {
                    Write-Message -Level Verbose -Message "Creating script for $objectName in database $dbName."
                    

                    $objCollection =  $db.PartitionFunctions

                    if ($objCollection.Count -gt 0) {
                        #Scripting Options
                        $ScriptingOption.IncludeDatabaseContext  = $true
                        $ScriptingOption.IncludeIfNotExists = $false
                
                        foreach($obj in $objCollection) {
                            if ($OutputStyle -ne 'SingleFile') { 
                                $nestedPath = Join-DbaPath -Path $scriptPath $objectName 
                                $scriptFile = Join-DbaPath -Path $nestedPath -Child "$($obj.Schema).$($obj.Name).sql"
                            }
                            Export-DbaScript -InputObject $obj -Path $nestedPath -FilePath $scriptFile -Encoding $Encoding -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix -Append:$Append -NoClobber:$NoClobber -BatchSeparator $BatchSeparator                     
                        }
                    }
                }
                #endregion  

                #region PartitionSchemes Scripts
                $objectName = 'PartitionSchemes'
                if ($DatabaseObjects -contains $objectName) {
                    Write-Message -Level Verbose -Message "Creating script for $objectName in database $dbName."

                    $objCollection =  $db.PartitionSchemes

                    if ($objCollection.Count -gt 0) {
                        #Scripting Options
                        $ScriptingOption.IncludeDatabaseContext  = $true
                        $ScriptingOption.IncludeIfNotExists = $false
                
                        foreach($obj in $objCollection) {
                            if ($OutputStyle -ne 'SingleFile') {  
                                $nestedPath = Join-DbaPath -Path $scriptPath $objectName
                                $scriptFile = Join-DbaPath -Path $nestedPath -Child "$($obj.Schema).$($obj.Name).sql"
                            }
                            Export-DbaScript -InputObject $obj -Path $nestedPath -FilePath $scriptFile -Encoding $Encoding -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix -Append:$Append -NoClobber:$NoClobber -BatchSeparator $BatchSeparator                    
                        }
                    }
                }
                #endregion  

                #region Triggers Scripts
                $objectName = 'Triggers'
                if ($DatabaseObjects -contains $objectName) {
                    Write-Message -Level Verbose -Message "Creating script for $objectName in database $dbName."

                    $objCollection =  $db.Triggers

                    if ($objCollection.Count -gt 0) {
                        #Scripting Options
                        $ScriptingOption.IncludeDatabaseContext  = $true
                        $ScriptingOption.IncludeIfNotExists = $false
                
                        foreach($obj in $objCollection) {
                            if ($OutputStyle -ne 'SingleFile') { 
                                $nestedPath = Join-DbaPath -Path $scriptPath $objectName
                                $scriptFile = Join-DbaPath -Path $nestedPath -Child "$($obj.Name).sql"
                            }
                            Export-DbaScript -InputObject $obj -Path $nestedPath -FilePath $scriptFile -Encoding $Encoding -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix -Append:$Append -NoClobber:$NoClobber -BatchSeparator $BatchSeparator                     
                        }
                    }
                }
                #endregion  

                #region Sequencies Scripts
                $objectName = 'Sequencies'
                if ($DatabaseObjects -contains $objectName) {
                    Write-Message -Level Verbose -Message "Creating script for $objectName in database $dbName."

                    $objCollection =  $db.Sequencies

                    if ($objCollection.Count -gt 0) {
                        #Scripting Options
                        $ScriptingOption.IncludeDatabaseContext  = $true
                        $ScriptingOption.IncludeIfNotExists = $false
                
                        foreach($obj in $objCollection) {
                            if ($OutputStyle -ne 'SingleFile') { 
                                $nestedPath = Join-DbaPath -Path $scriptPath $objectName 
                                $scriptFile = Join-DbaPath -Path $nestedPath -Child "$($obj.Schema).$($obj.Name).sql"
                            }
                            Export-DbaScript -InputObject $obj -Path $nestedPath -FilePath $scriptFile -Encoding $Encoding -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix -Append:$Append -NoClobber:$NoClobber -BatchSeparator $BatchSeparator                    
                        }
                    }
                }
                #endregion   

                #region Synonyms Scripts
                $objectName = 'Synonyms'
                if ($DatabaseObjects -contains $objectName) {
                    Write-Message -Level Verbose -Message "Creating script for $objectName in database $dbName."

                    $objCollection =  $db.Synonyms

                    if ($objCollection.Count -gt 0) {
                        #Scripting Options
                        $ScriptingOption.IncludeDatabaseContext  = $true
                        $ScriptingOption.IncludeIfNotExists = $false
                
                        foreach($obj in $objCollection) {
                            if ($OutputStyle -ne 'SingleFile') {  
                                $nestedPath = Join-DbaPath -Path $scriptPath $objectName
                                $scriptFile = Join-DbaPath -Path $nestedPath -Child "$($obj.Schema).$($obj.Name).sql"
                            }
                            Export-DbaScript -InputObject $obj -Path $nestedPath -FilePath $scriptFile -Encoding $Encoding -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix -Append:$Append -NoClobber:$NoClobber -BatchSeparator $BatchSeparator                   
                        }
                    }
                }
                #endregion 

                #region Roles Scripts
                $objectName = 'Roles'
                if ($DatabaseObjects -contains $objectName) {
                    Write-Message -Level Verbose -Message "Creating script for $objectName in database $dbName."

                    $objCollection =  $db | Get-DbaDbRole -ExcludeFixedRole

                    if ($objCollection.Count -gt 0) {
                        #Scripting Options
                        $ScriptingOption.IncludeDatabaseContext  = $true
                        $ScriptingOption.IncludeIfNotExists = $false
                
                        foreach($obj in $objCollection) {
                            if ($OutputStyle -ne 'SingleFile') {  
                                $nestedPath = Join-DbaPath -Path $scriptPath $objectName
                                $scriptFile = Join-DbaPath -Path $nestedPath -Child "$($obj.Name).sql"
                            }   
                            Export-DbaDbRole -InputObject $obj -Path $nestedPath -FilePath $scriptFile -Encoding $Encoding -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix -Append:$Append -NoClobber:$NoClobber -BatchSeparator $BatchSeparator -ExcludeFixedRole -IncludeRoleMember                 
                        }
                    }
                }
                #endregion 

                #region Roles Scripts
                $objectName = 'Rules'
                if ($DatabaseObjects -contains $objectName) {
                    Write-Message -Level Verbose -Message "Creating script for $objectName in database $dbName."

                    $objCollection =  $db.Rules

                    if ($objCollection.Count -gt 0) {
                        #Scripting Options
                        $ScriptingOption.IncludeDatabaseContext  = $true
                        $ScriptingOption.IncludeIfNotExists = $false
                
                        foreach($obj in $objCollection) {
                            if ($OutputStyle -ne 'SingleFile') {  
                                $nestedPath = Join-DbaPath -Path $scriptPath $objectName
                                $scriptFile = Join-DbaPath -Path $nestedPath -Child "$($obj.Name).sql"
                            }   
                            Export-DbaScript -InputObject $obj -Path $nestedPath -FilePath $scriptFile -Encoding $Encoding -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix -Append:$Append -NoClobber:$NoClobber -BatchSeparator $BatchSeparator                   
                        }
                    }
                }
                #endregion 
            }
            
        }
    }
    end {
        $totaltime = ($elapsed.Elapsed.toString().Split(".")[0])
        Write-Message -Level Verbose -Message "SQL Server export complete."
        Write-Message -Level Verbose -Message "Export started: $started"
        Write-Message -Level Verbose -Message "Export completed: $(Get-Date)"
        Write-Message -Level Verbose -Message "Total Elapsed time: $totaltime"
    }
}