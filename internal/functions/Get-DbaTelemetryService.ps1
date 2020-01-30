function Get-DbaTelemetryService {
    <#
    .SYNOPSIS
        Gets the SQL Server CEIP Telemetry Services on a computer.

    .DESCRIPTION
        Gets the SQL Server CEIP Telemetry Sservices on one or more computers.

        Requires Local Admin rights on destination computer(s).

        https://docs.microsoft.com/en-au/sql/sql-server/usage-and-diagnostic-data-configuration-for-sql-server
        https://blog.dbi-services.com/sql-server-tips-deactivate-the-customer-experience-improvement-program-ceip/

    .PARAMETER ComputerName
        The target server(s) to check for SQL Server CEIP Telemetry Sservices .

    .PARAMETER Credential
        Credential object used to connect to the computer as a different user.

    .PARAMETER ServiceName
        Can be used to specify service names explicitly, without looking for service types

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Service, SqlServer, Telemetry
        Author: Patrick Flynn (@sqllensman)

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Get-DbaTelemetryService

    .EXAMPLE
        PS C:\> Get-DbaTelemetryService -ComputerName sqlserver2014a

        Gets the SQL CEIP Telemetry Services on computer sqlserver2014a.

    .EXAMPLE
        PS C:\> $cred = Get-Credential WindowsUser
        PS C:\> Get-DbaTelemetryService -ComputerName sql1,sql2 -Credential $cred  | Out-GridView

        Gets the SQL CEIP Telemetry Services on computers sql1 and sql2 via the user WindowsUser, and shows them in a grid view.

    .EXAMPLE
        PS C:\> $MyServers =  Get-Content .\servers.txt
        PS C:\> Get-DbaTelemetryService -ComputerName $MyServers -ServiceName SQLTELEMETRY,SSISTELEMETRY

        Gets the SQL CEIP Telemetry Services with ServiceName SQLTELEMETRY or SSISTELEMETRY for all the servers that are stored in the file. Every line in the file can only contain one hostname for a server.

    #>
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline, Position = 1)]
        [Alias("cn", "host", "Server")]
        [DbaInstanceParameter[]]$ComputerName = $env:COMPUTERNAME,
        [PSCredential]$Credential,
        [string[]]$ServiceName,
        [ValidateSet('SQLTELEMETRY', 'SSASTELEMETRY', 'SSISTELEMETRY')]
        [switch]$EnableException
    )
    begin {
        $ceipTelemetry = @()
        if ($ServiceName) {
            foreach ($item in $ServiceName) {
                $ceipTelemetry += $item 
            }
        } else {
            $ceipTelemetry += "SQLTELEMETRY"
            $ceipTelemetry += "SSASTELEMETRY"
            $ceipTelemetry += "SSISTELEMETRY"
        }

    }
    process {
        foreach ($Computer in $ComputerName.ComputerName) {
            $Server = Resolve-DbaNetworkName -ComputerName $Computer -Credential $Credential
            if ($Server.FullComputerName) {
                $computer = $server.FullComputerName
                
                foreach ($ceip in $ceipTelemetry) {
                    $serviceName = $ceip + '%'
                    $service = Get-InternalService -ComputerName $computer -Name $serviceName -Credential $Credential -DoNotUse None

                    if ($service) {
                        Add-Member -Force -InputObject $service -MemberType NoteProperty -Name ComputerName -Value $computer     
                        Add-Member -Force -InputObject $service -MemberType NoteProperty -Name ServiceType -Value 'CEIP'

                        if ($service.Name.indexof('$') -gt 0) {
                            $instance = $service.Name.split('$')[1]
                        } else {
                            $instance = ""
                        }
                        Add-Member -Force -InputObject $service -MemberType NoteProperty -Name Instance -Value $instance

                        $service | Select-DefaultView -Property ComputerName, Instance, Name, ServiceType, DisplayName, StartName, State, StartMode
                    }
                } 
            } else {
                Stop-Function -EnableException $EnableException -Message "Failed to connect to $Computer" -Continue
            }
        } 
    }
}