function Copy-DbaServerRole {
    <#
    .SYNOPSIS
        Copy-DbaServerRole migrates server roles from one SQL Server to another.

    .DESCRIPTION
        By default, all roles are copied. The -ServerRole parameter is auto-populated for command-line completion and can be used to copy only specific roles.

        If the Role already exists on the destination, it will be skipped unless -Force is used.

    .PARAMETER Source
        Source SQL Server.You must have sysadmin access and server version must be SQL Server version 2000 or greater.

    .PARAMETER SourceSqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Destination
        Destination Sql Server. You must have sysadmin access and server version must be SQL Server version 2000 or greater.

    .PARAMETER DestinationSqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER ServerRole
        The Server Role(s) to process - this list is auto-populated from the server. If unspecified, all Server roles will be processed.

    .PARAMETER ExcludeServerRole
        The Server Role(s) to exclude - this list is auto-populated from the server

    .PARAMETER ExcludeFixedRole
        Filter the fixed server-level roles. Only applies to SQL Server 2017 or higher that support creation of server-level roles.

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER Force
        Drops and recreates the Role if it exists

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Migration, ServerRole
        Author: Chrissy LeMaire (@cl), netnerds.net

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

        Requires: sysadmin access on SQL Servers

    .LINK
        https://dbatools.io/Copy-DbaServerRole

    .EXAMPLE
        PS C:\> Copy-DbaServerRole -Source sqlserver2014a -Destination sqlcluster

        Copies all server roles from sqlserver2014a to sqlcluster, using Windows credentials. If roles with the same name exist on sqlcluster, they will be skipped.

    .EXAMPLE
        PS C:\> Copy-DbaServerRole -Source sqlserver2014a -Destination sqlcluster -ServerRole tg_noDbDrop -SourceSqlCredential $cred -Force

        Copies a single Role, the tg_noDbDrop Role from sqlserver2014a to sqlcluster, using SQL credentials for sqlserver2014a and Windows credentials for sqlcluster. If a Role with the same name exists on sqlcluster, it will be dropped and recreated because -Force was used.

    .EXAMPLE
        PS C:\> Copy-DbaServerRole -Source sqlserver2014a -Destination sqlcluster -WhatIf -Force

        Shows what would happen if the command were executed using force.

    #>
    [CmdletBinding(DefaultParameterSetName = "Default", SupportsShouldProcess, ConfirmImpact = "Medium")]
    param (
        [parameter(Mandatory)]
        [DbaInstanceParameter]$Source,
        [PSCredential]
        $SourceSqlCredential,
        [parameter(Mandatory)]
        [DbaInstanceParameter[]]$Destination,
        [PSCredential]
        $DestinationSqlCredential,
        [string[]]$ServerRole,
        [string[]]$ExcludeServerRole,
        [switch]$IncludeRoleMember,
        [switch]$Force,
        [switch]$EnableException
    )

    begin {
        try {
            $sourceServer = Connect-SqlInstance -SqlInstance $Source -SqlCredential $SourceSqlCredential -MinimumVersion 9
        } catch {
            Stop-Function -Message "Error occurred while establishing connection to $instance" -Category ConnectionError -ErrorRecord $_ -Target $Source
            return
        }
        $serverroles = $sourceServer.roles

        if ($Force) {$ConfirmPreference = 'none'}
    }
    process {
        if (Test-FunctionInterrupt) { return }
        foreach ($destinstance in $Destination) {
            try {
                $destServer = Connect-SqlInstance -SqlInstance $destinstance -SqlCredential $DestinationSqlCredential -MinimumVersion 9
            } catch {
                Stop-Function -Message "Error occurred while establishing connection to $instance" -Category ConnectionError -ErrorRecord $_ -Target $destinstance -Continue
            }
            if ($destServer.VersionMajor -lt $sourceServer.VersionMajor) {
                Stop-Function -Message "Migration from version $($destServer.VersionMajor) to version $($sourceServer.VersionMajor) is not supported."
                return
            }
            $destroles = $destServer.roles

            foreach ($Role in $serverroles) {
                $RoleName = $Role.Name 

                $copyrolestatus = [pscustomobject]@{
                    SourceServer      = $sourceServer.Name
                    DestinationServer = $destServer.Name
                    Name              = $RoleName
                    Type              = "Server Role"
                    Status            = $null
                    Notes             = $null
                    DateTime          = [DbaDateTime](Get-Date)
                }

                if ($ServerRole -and $RoleName -notin $ServerRole -or $RoleName -in $ExcludeServerRole) {
                    continue
                }

                if ($destroles.Name -contains $RoleName) {
                    if ($force -eq $false) {
                        Write-Message -Level Verbose -Message "Server Role $RoleName exists at destination. Use -Force to drop and migrate."

                        $copyrolestatus.Status = "Skipped"
                        $copyrolestatus.Notes = "Already exists on destination"
                        $copyrolestatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                        continue
                    } else {
                        if ($Pscmdlet.ShouldProcess($destinstance, "Dropping server Role $RoleName and recreating")) {
                            try {
                                Write-Message -Level Verbose -Message "Dropping server Role $RoleName"
                                $destServer.roles[$RoleName].Drop()
                            } catch {
                                $copyrolestatus.Status = "Failed"
                                $copyrolestatus.Notes = (Get-ErrorMessage -Record $_)
                                $copyrolestatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject

                                Stop-Function -Message "Issue dropping Role on destination" -Target $RoleName -ErrorRecord $_ -Continue
                            }
                        }
                    }
                }

                if ($Pscmdlet.ShouldProcess($destinstance, "Creating server Role $RoleName")) {
                    try {
                        Write-Message -Level Verbose -Message "Copying server Role $RoleName"
                        $sql = $Role.Script() | Out-String
                        $sql = $sql -replace "CREATE Role", "`nGO`nCREATE Role"
                        $sql = $sql -replace "ENABLE Role", "`nGO`nENABLE Role"
                        Write-Message -Level Debug -Message $sql

                        foreach ($query in ($sql -split '\nGO\b')) {
                            $destServer.Query($query) | Out-Null
                        }

                        $copyrolestatus.Status = "Successful"
                        $copyrolestatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                    } catch {
                        $copyrolestatus.Status = "Failed"
                        $copyrolestatus.Notes = (Get-ErrorMessage -Record $_)
                        $copyrolestatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject

                        Stop-Function -Message "Issue creating Role on destination" -Target $RoleName -ErrorRecord $_
                    }
                }
            }
        }
    }
}