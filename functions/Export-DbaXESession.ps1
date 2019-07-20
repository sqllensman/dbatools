function Export-DbaXESession {
    <#
    .SYNOPSIS
        Exports advanced sp_configure global configuration options to sql file.

    .DESCRIPTION
        Exports advanced sp_configure global configuration options to sql file.
        Will require SysAdmin rights if needs to set 'show advanced options'

    .PARAMETER SqlInstance
        The target SQL Server instance or instances. This can be a collection and receive pipeline input.
        You must have sysadmin access if needs to set 'show advanced options' to 1 and server version must be SQL Server version 2005 or higher.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER InputObject
        A SQL Management Object - Microsoft.SqlServer.Management.XEvent.Session such as the one returned from Get-DbaXESession

    .PARAMETER XeSession
        The Extended Event Session(s) to process. This list is auto-populated from the server. If unspecified, all Extended Event Sessions will be processed.

    .PARAMETER ExcludeXeSession
        The Extended Event Session(s) to exclude. This list is auto-populated from the server.

    .PARAMETER Path
        Specifies the directory where the file or files will be exported.

    .PARAMETER FilePath
        Specifies the full file path of the output file.

    .PARAMETER Encoding
        Specifies the file encoding. The default is UTF8.

        Valid values are:
        -- ASCII: Uses the encoding for the ASCII (7-bit) character set.
        -- BigEndianUnicode: Encodes in UTF-16 format using the big-endian byte order.
        -- Byte: Encodes a set of characters into a sequence of bytes.
        -- String: Uses the encoding type for a string.
        -- Unicode: Encodes in UTF-16 format using the little-endian byte order.
        -- UTF7: Encodes in UTF-7 format.
        -- UTF8: Encodes in UTF-8 format.
        -- Unknown: The encoding type is unknown or invalid. The data can be treated as binary.

    .PARAMETER Passthru
        Output script to console

    .PARAMETER BatchSeparator
        Batch separator for scripting output. Uses the value from configuration Formatting.BatchSeparator by default. This is normally "GO"

    .PARAMETER NoPrefix
        If this switch is used, the scripts will not include prefix information containing creator and datetime.

    .PARAMETER NoClobber
        Do not overwrite file

    .PARAMETER Append
        Append to file

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: ExtendedEvent, XE, XEvent
        Author: Patrick Flynn (@sqllensman)

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Export-DbaXESession

    .INPUTS
        A DbaInstanceParameter representing an array of SQL Server instances.

    .OUTPUTS
        Creates a new file for each SQL Server Instance

    .EXAMPLE
        PS C:\> Export-DbaXESession -SqlInstance sourceserver -Passthru

        Exports the SPConfigure settings on sourceserver to the console
        Will include prefix information containing creator and datetime. and uses the default value for BatchSeparator value from configuration Formatting.BatchSeparator

    .EXAMPLE
        PS C:\> Export-DbaXESession -SqlInstance sourceserver

        Exports the SPConfigure settings on sourceserver. As no Path was defined - automatically determines filename based on the Path.DbatoolsExport configuration setting, current time and server name like Servername-YYYYMMDDhhmmss-sp_configure.sql
        Will include prefix information containing creator and datetime. and uses the default value for BatchSeparator value from configuration Formatting.BatchSeparator

    .EXAMPLE
        PS C:\> Export-DbaXESession -SqlInstance sourceserver -FilePath C:\temp

        Exports the SPConfigure settings on sourceserver to the directory C:\temp using the default name format of Servername-YYYYMMDDhhmmss-sp_configure.sql
        Will include prefix information containing creator and datetime. and uses the default value for BatchSeparator value from configuration Formatting.BatchSeparator

    .EXAMPLE
        PS C:\> $cred = Get-Credential sqladmin
        PS C:\> Export-DbaXESession -SqlInstance sourceserver -SqlCredential $cred -FilePath C:\temp\sp_configure.sql -BatchSeparator "" -NoPrefix -NoClobber

        Exports the SPConfigure settings on sourceserver to the file C:\temp\sp_configure.sql.
        Will exclude prefix information containing creator and datetime and does not include a BatchSeparator
        Will not overwrite file if it already exists

    .EXAMPLE
        PS C:\> 'Server1', 'Server2' | Export-DbaXESession -Path C:\temp

        Exports the SPConfigure settings for Server1 and Server2 using pipeline. As more than 1 Server adds prefix of Servername and date to the file name and saves to file like  C:\temp\Servername-MMDDYYYYhhmmss-configure.sql

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [Microsoft.SqlServer.Management.XEvent.Session[]]$InputObject,
        [string[]]$XeSession,
        [string[]]$ExcludeXeSession,
        [string]$Path = (Get-DbatoolsConfigValue -FullName 'Path.DbatoolsExport'),
        [Alias("OutFile", "FileName")]
        [string]$FilePath,
        [ValidateSet('ASCII', 'BigEndianUnicode', 'Byte', 'String', 'Unicode', 'UTF7', 'UTF8', 'Unknown')]
        [string]$Encoding = 'UTF8',
        [switch]$Passthru,
        [string]$BatchSeparator = (Get-DbatoolsConfigValue -FullName 'Formatting.BatchSeparator'),
        [switch]$NoPrefix,
        [switch]$NoClobber,
        [switch]$Append,
        [switch]$EnableException
    )
    begin {
        $null = Test-ExportDirectory -Path $Path
        $outsql = @()
        $executingUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $commandName = $MyInvocation.MyCommand.Name
    }
    process {
        if (Test-FunctionInterrupt) { return }

        if (-not $InputObject -and -not $SqlInstance) {
            Stop-Function -Message "You must pipe in a Credential or specify a SqlInstance"
            return
        }

        if ($SqlInstance) {
            $InputObject += Get-DbaXESession -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Session $XeSession
        }


        foreach ($session in $InputObject) {
            $server = $session.Parent
            $serverName = $server.Name.Replace('\', '$')

            $scriptPath = Get-ExportFilePath -Path $PSBoundParameters.Path -FilePath $PSBoundParameters.FilePath -Type sql -ServerName $serverName
            
            if ($NoPrefix) {
                $prefix = $null
            } else {
                $prefix = "/*`n`tCreated by $executingUser using dbatools $commandName for objects on $($instance) at $(Get-Date -Format (Get-DbatoolsConfigValue -FullName 'Formatting.DateTime'))`n`tSee https://dbatools.io/$commandName for more information`n*/"
            }

            $outsql = $session.ScriptCreate().GetScript()s
            if ($BatchSeparator) {
                $sql = $outsql -join "`r`n$BatchSeparator`r`n"
                #add the final GO
                $sql += "`r`n$BatchSeparator"
            } else {
                $sql = $outsql -join "`r`n"
            }

            if ($Passthru) {
                if ($null -ne $prefix) {
                    $sql = "$prefix`r`n$sql"
                }
                $sql
            } else {
                if ($null -ne $prefix) {
                    $sql = "$prefix`r`n$sql"
                }
                if ((Test-Path -Path $scriptPath) -and $NoClobber) {
                    Stop-Function -Message "File already exists. If you want to overwrite it remove the -NoClobber parameter. If you want to append data, please Use -Append parameter." -Target $scriptPath -Continue
                }
                $sql | Out-File -Encoding $Encoding -LiteralPath $scriptPath -Append:$Append -NoClobber:$NoClobber
                Get-ChildItem -Path $scriptPath
            }
        }
    }
}