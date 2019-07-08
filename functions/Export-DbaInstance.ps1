function Export-DbaInstance {
    <#
    .SYNOPSIS
        Exports SQL Server *ALL* database restore scripts, logins, database mail profiles/accounts, credentials, SQL Agent objects, linked servers,
        Central Management Server objects, server configuration settings (sp_configure), user objects in systems databases,
        system triggers and backup devices from one SQL Server to another.

        For more granular control, please use one of the -Exclude parameters and use the other functions available within the dbatools module.

    .DESCRIPTION
        Export-DbaInstance consolidates most of the export scripts in dbatools into one command.

        This is useful when you're looking to Export entire instances. It less flexible than using the underlying functions.
        Think of it as an easy button. Unless an -Exclude is specified, it exports:

        All database restore scripts.
        All logins.
        All database mail objects.
        All credentials.
        All objects within the Job Server (SQL Agent).
        All linked servers.
        All groups and servers within Central Management Server.
        All SQL Server configuration objects (everything in sp_configure).
        All user objects in system databases.
        All system triggers.
        All system backup devices.
        All Audits.
        All Endpoints.
        All Extended Events.
        All Policy Management objects.
        All Resource Governor objects.
        All Server Audit Specifications.
        All Custom Errors (User Defined Messages).
        All Server Roles.
        All Availability Groups.

    .PARAMETER SqlInstance
        The target SQL Server instances

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Credential
        Alternative Windows credentials for exporting Linked Servers and Credentials. Accepts credential objects (Get-Credential)

    .PARAMETER Path
        Specifies the directory where the file or files will be exported.

    .PARAMETER NoRecovery
        If this switch is used, databases will be left in the No Recovery state to enable further backups to be added.

    .PARAMETER Include
        Include one or more objects to export. If left blank all objects will be exported

        Databases
        Logins
        AgentServer
        Credentials
        LinkedServers
        SpConfigure
        CentralManagementServer
        DatabaseMail
        SysDbUserObjects
        SystemTriggers
        BackupDevices
        Audits
        Endpoints
        ExtendedEvents
        PolicyManagement
        ResourceGovernor
        ServerAuditSpecifications
        CustomErrors
        ServerRoles
        AvailabilityGroups
        ReplicationSettings

    .PARAMETER Exclude
        Exclude one or more objects to export

        Databases
        Logins
        AgentServer
        Credentials
        LinkedServers
        SpConfigure
        CentralManagementServer
        DatabaseMail
        SysDbUserObjects
        SystemTriggers
        BackupDevices
        Audits
        Endpoints
        ExtendedEvents
        PolicyManagement
        ResourceGovernor
        ServerAuditSpecifications
        CustomErrors
        ServerRoles
        AvailabilityGroups
        ReplicationSettings

    .PARAMETER BatchSeparator
        Batch separator for scripting output. Uses the value from configuration Formatting.BatchSeparator by default. This is normally "GO"

    .PARAMETER Append
        Append to the target file instead of overwriting.

    .PARAMETER ScriptingOption
        Add scripting options to scripting output for all objects except Registered Servers and Extended Events.

    .PARAMETER NoPrefix
        If this switch is used, the scripts will not include prefix information containing creator and datetime.

    .PARAMETER ExcludePassword
        If this switch is used, the scripts will not include passwords for Credentials, LinkedServers or Logins.

    .PARAMETER OutputStyle
        Specifies the directory structure where the file or files will be exported. Can be eiither NestedByDate or Nested

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Export
        Author: Chrissy LeMaire (@cl), netnerds.net

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Export-DbaInstance

    .EXAMPLE
        PS C:\> Export-DbaInstance -SqlInstance sqlserver\instance

        All databases, logins, job objects and sp_configure options will be exported from
        sqlserver\instance to an automatically generated folder name in Documents.

    .EXAMPLE
        PS C:\> Export-DbaInstance -SqlInstance sqlcluster -Exclude Databases, Logins -Path C:\dr\sqlcluster

        Exports everything but logins and database restore scripts to C:\dr\sqlcluster

.EXAMPLE
        PS C:\> Export-DbaInstance -SqlInstance sqlcluster -Path C:\servers\ -NoPrefix

        Exports everything to C:\servers but scripts do not include prefix information.
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [PSCredential]$Credential,
        [string]$Path = (Get-DbatoolsConfigValue -FullName 'Path.DbatoolsExport'),
        [Alias("OutFile", "FileName")]
        [switch]$NoRecovery,
        [ValidateSet('Databases', 'Logins', 'AgentServer', 'Credentials', 'LinkedServers', 'SpConfigure', 'CentralManagementServer', 'DatabaseMail', 'SysDbUserObjects', 'SystemTriggers', 'BackupDevices', 'Audits', 'Endpoints', 'ExtendedEvents', 'PolicyManagement', 'ResourceGovernor', 'ServerAuditSpecifications', 'CustomErrors', 'ServerRoles', 'AvailabilityGroups', 'ReplicationSettings')]
        [string[]]$Exclude,
        [ValidateSet('Databases', 'Logins', 'AgentServer', 'Credentials', 'LinkedServers', 'SpConfigure', 'CentralManagementServer', 'DatabaseMail', 'SysDbUserObjects', 'SystemTriggers', 'BackupDevices', 'Audits', 'Endpoints', 'ExtendedEvents', 'PolicyManagement', 'ResourceGovernor', 'ServerAuditSpecifications', 'CustomErrors', 'ServerRoles', 'AvailabilityGroups', 'ReplicationSettings')]
        [string[]]$Include,
        [string]$BatchSeparator = (Get-DbatoolsConfigValue -FullName 'Formatting.BatchSeparator'),
        [switch]$Append,
        [Microsoft.SqlServer.Management.Smo.ScriptingOptions]$ScriptingOption,
        [switch]$NoPrefix = $false,
        [switch]$ExcludePassword,
        [ValidateSet('Nested', 'NestedByDate')]
        [string]$OutputStyle = 'NestedByDate',
        [switch]$EnableException
    )
    begin {
        $null = Test-ExportDirectory -Path $Path

        if (-not $ScriptingOption) {
            $ScriptingOption = New-DbaScriptingOption
            $ScriptingOption.ScriptSchema = $true
            $ScriptingOption.IncludeDatabaseContext = $true
            $ScriptingOption.NoCommandTerminator = $false
            $ScriptingOption.ScriptBatchTerminator = $true
            $ScriptingOption.AnsiFile = $true
        }

        $elapsed = [System.Diagnostics.Stopwatch]::StartNew()
        $started = Get-Date

        [string[]]$exportObjects = 'Databases', 'Logins', 'AgentServer', 'Credentials', 'LinkedServers', 'SpConfigure', 'CentralManagementServer', 'DatabaseMail', 'SysDbUserObjects', 'SystemTriggers', 'BackupDevices', 'Audits', 'Endpoints', 'ExtendedEvents', 'PolicyManagement', 'ResourceGovernor', 'ServerAuditSpecifications', 'CustomErrors', 'ServerRoles', 'AvailabilityGroups', 'ReplicationSettings'

        if (Test-Bound -ParameterName Include) {
            $exportObjects = $exportObjects | Where-Object { $Include -contains $_ }
        }
        if (Test-Bound -ParameterName Exclude) {
            $exportObjects = $exportObjects | Where-Object { $exportObjects -contains $_ }
        }

    }
    process {
        if (Test-FunctionInterrupt) { return }
        foreach ($instance in $SqlInstance) {
            $stepCounter = $filecounter = 0
            try {
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $sqlcredential -MinimumVersion 10
            } catch {
                Stop-Function -Message "Error occurred while establishing connection to $instance" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }
            $timenow = (Get-Date -uformat (Get-DbatoolsConfigValue -FullName 'Formatting.UFormat'))

            if ($OutputStyle -eq 'NestedByDate') {
                $scriptPath = Join-DbaPath -Path $Path -Child "$($server.name.replace('\', '$'))-$timenow"
            } elseif ($OutputStyle -eq 'Nested') {
                $scriptPath = Join-DbaPath -Path $Path -Child "$($server.name.replace('\', '$'))"
            }

            if (-not (Test-Path $scriptPath)) {
                try {
                    $null = New-Item -ItemType Directory -Path $scriptPath -ErrorAction Stop
                } catch {
                    Stop-Function -Message "Failure" -ErrorRecord $_
                    return
                }
            }

            if ($exportObjects -contains 'SpConfigure') {
                $fileCounter++
                if ($OutputStyle -eq 'NestedByDate') {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "$fileCounter-sp_configure.sql"
                } else {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "1-sp_configure.sql"
                }
                Write-Message -Level Verbose -Message "Exporting SQL Server Configuration"
                Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Exporting SQL Server Configuration"
                Export-DbaSpConfigure -SqlInstance $server -FilePath $filePath -Append:$Append -BatchSeparator $BatchSeparator -NoPrefix:$NoPrefix
                if (-not (Test-Path $filePath)) {
                    $fileCounter--
                }
            }

            if ($exportObjects -contains 'CustomErrors') {
                $fileCounter++
                if ($OutputStyle -eq 'NestedByDate') {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "$fileCounter-customererrors.sql"
                } else {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "2-customererrors.sql"
                }
                Write-Message -Level Verbose -Message "Exporting custom errors (user defined messages)"
                Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Exporting custom errors (user defined messages)"
                $null = Get-DbaCustomError -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append:$Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                Get-ChildItem -ErrorAction Ignore -Path $filePath
                if (-not (Test-Path $filePath)) {
                    $fileCounter--
                }
            }

            if ($exportObjects -contains 'ServerRoles') {
                $fileCounter++
                if ($OutputStyle -eq 'NestedByDate') {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "$fileCounter-serverroles.sql"
                } else {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "3-serverroles.sql"
                }
                Write-Message -Level Verbose -Message "Exporting server roles"
                Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Exporting server roles"
                $null = Get-DbaServerRole -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append:$Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                Get-ChildItem -ErrorAction Ignore -Path $filePath
                if (-not (Test-Path $filePath)) {
                    $fileCounter--
                }
            }

            if ($exportObjects -contains 'Credentials') {
                $fileCounter++
                if ($OutputStyle -eq 'NestedByDate') {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "$fileCounter-credentials.sql"
                } else {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "4-credentials.sql"
                }
                Write-Message -Level Verbose -Message "Exporting SQL credentials"
                Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Exporting SQL credentials"
                $null = Export-DbaCredential -SqlInstance $server -Credential $Credential -FilePath $filePath -Append:$Append -ExcludePassword:$ExcludePassword
                Get-ChildItem -ErrorAction Ignore -Path $filePath
                if (-not (Test-Path $filePath)) {
                    $fileCounter--
                }
            }

            if ($exportObjects -contains 'DatabaseMail') {
                $fileCounter++
                if ($OutputStyle -eq 'NestedByDate') {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "$fileCounter-dbmail.sql"
                } else {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "5-dbmail.sql"
                }
                Write-Message -Level Verbose -Message "Exporting database mail"
                Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Exporting database mail"
                $null = Get-DbaDbMailConfig -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append:$Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                $null = Get-DbaDbMailAccount -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                $null = Get-DbaDbMailProfile -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                $null = Get-DbaDbMailServer -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                $null = Get-DbaDbMail -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                Get-ChildItem -ErrorAction Ignore -Path $filePath
                if (-not (Test-Path $filePath)) {
                    $fileCounter--
                }
            }

            if ($exportObjects -contains 'CentralManagementServer') {
                $fileCounter++
                if ($OutputStyle -eq 'NestedByDate') {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "$fileCounter-regserver.sql"
                } else {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "6-regserver.sql"
                }
                Write-Message -Level Verbose -Message "Exporting Central Management Server"
                Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Exporting Central Management Server"
                $null = Get-DbaRegServerGroup -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append:$Append -BatchSeparator $BatchSeparator
                $null = Get-DbaRegServer -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append -BatchSeparator $BatchSeparator
                Get-ChildItem -ErrorAction Ignore -Path $filePath
                if (-not (Test-Path $filePath)) {
                    $fileCounter--
                }
            }

            if ($exportObjects -contains 'BackupDevices') {
                $fileCounter++
                if ($OutputStyle -eq 'NestedByDate') {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "$fileCounter-backupdevices.sql"
                } else {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "7-backupdevices.sql"
                }
                Write-Message -Level Verbose -Message "Exporting Backup Devices"
                Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Exporting Backup Devices"
                $null = Get-DbaBackupDevice -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append:$Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                Get-ChildItem -ErrorAction Ignore -Path $filePath
                if (-not (Test-Path $filePath)) {
                    $fileCounter--
                }
            }

            if ($exportObjects -contains 'LinkedServers') {
                $fileCounter++
                if ($OutputStyle -eq 'NestedByDate') {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "$fileCounter-linkedservers.sql"
                } else {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "8-linkedservers.sql"
                }
                Write-Message -Level Verbose -Message "Exporting linked servers"
                Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Exporting linked servers"
                Export-DbaLinkedServer -SqlInstance $server -FilePath $filePath -Credential $Credential -Append:$Append -ExcludePassword:$ExcludePassword
                if (-not (Test-Path $filePath)) {
                    $fileCounter--
                }
            }

            if ($exportObjects -contains 'SystemTriggers') {
                $fileCounter++
                if ($OutputStyle -eq 'NestedByDate') {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "$fileCounter-servertriggers.sql"
                } else {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "9-servertriggers.sql"
                }
                Write-Message -Level Verbose -Message "Exporting System Triggers"
                Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Exporting System Triggers"
                $null = Get-DbaInstanceTrigger -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append:$Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                $triggers = Get-Content -Path $filePath -Raw -ErrorAction Ignore
                if ($triggers) {
                    $triggers = $triggers.ToString() -replace 'CREATE TRIGGER', "GO`r`nCREATE TRIGGER"
                    $triggers = $triggers.ToString() -replace 'ENABLE TRIGGER', "GO`r`nENABLE TRIGGER"
                    $null = $triggers | Set-Content -Path $filePath -Force
                    Get-ChildItem -ErrorAction Ignore -Path $filePath
                }
                if (-not (Test-Path $filePath)) {
                    $fileCounter--
                }
            }

            if ($exportObjects -contains 'Databases') {
                $fileCounter++
                if ($OutputStyle -eq 'NestedByDate') {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "$fileCounter-databases.sql"
                } else {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "10-databases.sql"
                }
                Write-Message -Level Verbose -Message "Exporting database restores"
                Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Exporting database restores"
                Get-DbaDbBackupHistory -SqlInstance $server -Last | Restore-DbaDatabase -SqlInstance $server -NoRecovery:$NoRecovery -WithReplace -OutputScriptOnly -WarningAction SilentlyContinue | Out-File -FilePath $filePath -Append:$Append
                Get-ChildItem -ErrorAction Ignore -Path $filePath
                if (-not (Test-Path $filePath)) {
                    $fileCounter--
                }
            }

            if ($exportObjects -contains 'Logins') {
                $fileCounter++
                if ($OutputStyle -eq 'NestedByDate') {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "$fileCounter-logins.sql"
                } else {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "11-logins.sql"
                }
                Write-Message -Level Verbose -Message "Exporting logins"
                Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Exporting logins"
                Export-DbaLogin -SqlInstance $server -FilePath $filePath -Append:$Append -BatchSeparator $BatchSeparator -NoPrefix:$NoPrefix -ExcludePassword:$ExcludePassword -WarningAction SilentlyContinue
                if (-not (Test-Path $filePath)) {
                    $fileCounter--
                }
            }

            if ($exportObjects -contains 'Audits') {
                $fileCounter++
                if ($OutputStyle -eq 'NestedByDate') {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "$fileCounter-audits.sql"
                } else {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "12-audits.sql"
                }
                Write-Message -Level Verbose -Message "Exporting Audits"
                Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Exporting Audits"
                $null = Get-DbaInstanceAudit -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append:$Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                Get-ChildItem -ErrorAction Ignore -Path $filePath
                if (-not (Test-Path $filePath)) {
                    $fileCounter--
                }
            }

            if ($exportObjects -contains 'ServerAuditSpecifications') {
                $fileCounter++
                if ($OutputStyle -eq 'NestedByDate') {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "$fileCounter-auditspecs.sql"
                } else {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "13-auditspecs.sql"
                }
                Write-Message -Level Verbose -Message "Exporting Server Audit Specifications"
                Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Exporting Server Audit Specifications"
                $null = Get-DbaInstanceAuditSpecification -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append:$Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                Get-ChildItem -ErrorAction Ignore -Path $filePath
                if (-not (Test-Path $filePath)) {
                    $fileCounter--
                }
            }

            if ($exportObjects -contains 'Endpoints') {
                $fileCounter++
                if ($OutputStyle -eq 'NestedByDate') {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "$fileCounter-endpoints.sql"
                } else {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "14-endpoints.sql"
                }
                Write-Message -Level Verbose -Message "Exporting Endpoints"
                Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Exporting Endpoints"
                $null = Get-DbaEndpoint -SqlInstance $server | Where-Object IsSystemObject -eq $false | Export-DbaScript -FilePath $filePath -Append:$Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                Get-ChildItem -ErrorAction Ignore -Path $filePath
                if (-not (Test-Path $filePath)) {
                    $fileCounter--
                }
            }

            if ($exportObjects -contains 'PolicyManagement') {
                $fileCounter++
                if ($OutputStyle -eq 'NestedByDate') {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "$fileCounter-policymanagement.sql"
                } else {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "15-policymanagement.sql"
                }
                Write-Message -Level Verbose -Message "Exporting Policy Management"
                Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Exporting Policy Management"
                $null = Get-DbaPbmCondition -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append:$Append -BatchSeparator $BatchSeparator
                $null = Get-DbaPbmObjectSet -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append -BatchSeparator $BatchSeparator
                $null = Get-DbaPbmPolicy -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append -BatchSeparator $BatchSeparator
                Get-ChildItem -ErrorAction Ignore -Path $filePath
                if (-not (Test-Path $filePath)) {
                    $fileCounter--
                }
            }

            if ($exportObjects -contains 'ResourceGovernor') {
                $fileCounter++
                if ($OutputStyle -eq 'NestedByDate') {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "$fileCounter-resourcegov.sql"
                } else {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "16-resourcegov.sql"
                }
                Write-Message -Level Verbose -Message "Exporting Resource Governor"
                Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Exporting Resource Governor"
                $null = Get-DbaResourceGovernor -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append:$Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                $null = Get-DbaRgClassifierFunction -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                $null = Get-DbaRgResourcePool -SqlInstance $server | Where-Object Name -notin 'default', 'internal' | Export-DbaScript -FilePath $filePath -Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                $null = Get-DbaRgWorkloadGroup -SqlInstance $server | Where-Object Name -notin 'default', 'internal' | Export-DbaScript -FilePath $filePath -Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                $null = Add-Content -Value "ALTER RESOURCE GOVERNOR RECONFIGURE" -Path $filePath
                Get-ChildItem -ErrorAction Ignore -Path $filePath
                if (-not (Test-Path $filePath)) {
                    $fileCounter--
                }
            }

            if ($exportObjects -contains 'ExtendedEvents') {
                $fileCounter++
                if ($OutputStyle -eq 'NestedByDate') {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "$fileCounter-extendedevents.sql"
                } else {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "17-extendedevents.sql"
                }
                Write-Message -Level Verbose -Message "Exporting Extended Events"
                Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Exporting Extended Events"
                $null = Get-DbaXESession -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append:$Append -BatchSeparator 'GO'
                Get-ChildItem -ErrorAction Ignore -Path $filePath
                if (-not (Test-Path $filePath)) {
                    $fileCounter--
                }
            }

            if ($exportObjects -contains 'AgentServer') {
                $fileCounter++
                if ($OutputStyle -eq 'NestedByDate') {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "$fileCounter-sqlagent.sql"
                } else {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "18-sqlagent.sql"
                }
                Write-Message -Level Verbose -Message "Exporting job server"
                Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Exporting job server"
                $null = Get-DbaAgentJobCategory -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append:$Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                $null = Get-DbaAgentAlertCategory -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                $null = Get-DbaAgentOperator -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                $null = Get-DbaAgentAlert -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                $null = Get-DbaAgentProxy -SqlInstance $server | Export-DbaScript  -FilePath $filePath -Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                $null = Get-DbaAgentSchedule -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                $null = Get-DbaAgentJob -SqlInstance $server | Export-DbaScript -FilePath $filePath -Append -BatchSeparator $BatchSeparator -ScriptingOptionsObject $ScriptingOption -NoPrefix:$NoPrefix
                Get-ChildItem -ErrorAction Ignore -Path $filePath
                if (-not (Test-Path $filePath)) {
                    $fileCounter--
                }
            }

            if ($exportObjects -contains 'ReplicationSettings') {
                $fileCounter++
                if ($OutputStyle -eq 'NestedByDate') {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "$fileCounter-replication.sql"
                } else {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "19-replication.sql"
                }
                Write-Message -Level Verbose -Message "Exporting replication settings"
                Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Exporting replication settings"
                $null = Export-DbaRepServerSetting -SqlInstance $instance -SqlCredential $SqlCredential -FilePath $filePath
                Get-ChildItem -ErrorAction Ignore -Path $filePath
                if (-not (Test-Path $filePath)) {
                    $fileCounter--
                }
            }

            if ($exportObjects -contains 'SysDbUserObjects') {
                $fileCounter++
                if ($OutputStyle -eq 'NestedByDate') {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "$fileCounter-userobjectsinsysdbs.sql"
                } else {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "20-userobjectsinsysdbs.sql"
                }
                Write-Message -Level Verbose -Message "Exporting user objects in system databases (this can take a minute)."
                Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Exporting user objects in system databases (this can take a minute)."
                $null = Get-DbaSysDbUserObjectScript -SqlInstance $server | Out-File -FilePath $scriptPath -Append:$Append
                Get-ChildItem -ErrorAction Ignore -Path $scriptPath
                if (-not (Test-Path $scriptPath)) {
                    $fileCounter--
                }
            }

            if ($exportObjects -contains 'AvailabilityGroups') {
                $fileCounter++
                if ($OutputStyle -eq 'NestedByDate') {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "$fileCounter-DbaAvailabilityGroups.sql"
                } else {
                    $filePath = Join-DbaPath -Path $scriptPath -Child "21-DbaAvailabilityGroups.sql"
                }
                Write-Message -Level Verbose -Message "Exporting availability group"
                Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Exporting availability groups"
                $null = Get-DbaAvailabilityGroup -SqlInstance $server -WarningAction SilentlyContinue | Export-DbaScript -FilePath $filePath -Append:$Append -BatchSeparator $BatchSeparator #-ScriptingOptionsObject $ScriptingOption
                Get-ChildItem -ErrorAction Ignore -Path $filePath
                if (-not (Test-Path $filePath)) {
                    $fileCounter--
                }
            }

            Write-Progress -Activity "Performing Instance Export for $instance" -Completed
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