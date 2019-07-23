function Get-DbaServerRole {
    <#
    .SYNOPSIS
        Gets the list of server-level roles.

    .DESCRIPTION
        Gets the list of server-level roles for SQL Server instance.
        Prior to SQL Server 2012 only fixed server-level roles existed

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER ServerRole
        Server-Level role to filter results to that role only.

    .PARAMETER ExcludeServerRole
        Server-Level role to exclude from results.

    .PARAMETER ExcludeFixedRole
        Filter the fixed server-level roles. Only useful for SQL Server 2012+ that supports creation of user defined server-level roles.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message. This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting. Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: ServerRole, Security
        Author: Shawn Melton (@wsmelton)

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Get-DbaServerRole

    .EXAMPLE
        PS C:\> Get-DbaServerRole -SqlInstance sql2016a

        Outputs list of server-level roles for sql2016a instance.

    .EXAMPLE
        PS C:\> Get-DbaServerRole -SqlInstance sql2017a -ExcludeFixedRole

        Outputs the server-level role(s) that are not fixed roles on sql2017a instance.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [DbaInstance[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [string[]]$ServerRole,
        [string[]]$ExcludeServerRole,
        [switch]$ExcludeFixedRole,
        [switch]$EnableException
    )

    process {
        foreach ($instance in $SqlInstance) {
            try {
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential
            } catch {
                Stop-Function -Message "Error occurred while establishing connection to $instance" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            $serverroles = $server.Roles

            if ($ServerRole) {
                $serverroles = $serverroles | Where-Object Name -In $ServerRole
            }
            if ($ExcludeServerRole) {
                $serverroles = $serverroles | Where-Object Name -NotIn $ExcludeServerRole
            }
            if ($ExcludeFixedRole) {
                $serverroles = $serverroles | Where-Object IsFixedRole -eq $false
            }

            foreach ($role in $serverroles) {
                $members = $role.EnumMemberNames()

                Add-Member -Force -InputObject $role -MemberType NoteProperty -Name Login -Value $members
                Add-Member -Force -InputObject $role -MemberType NoteProperty -Name ComputerName -value $server.ComputerName
                Add-Member -Force -InputObject $role -MemberType NoteProperty -Name InstanceName -value $server.ServiceName
                Add-Member -Force -InputObject $role -MemberType NoteProperty -Name SqlInstance -value $server.DomainInstanceName

                $default = 'ComputerName', 'InstanceName', 'SqlInstance', 'Name as Role', 'Login', 'IsFixedRole', 'DateCreated', 'DateModified'
                Select-DefaultView -InputObject $role -Property $default
            }
        }
    }
}