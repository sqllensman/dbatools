$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-Command $CommandName).Parameters.Keys | Where-Object {$_ -notin ('whatif', 'confirm')}
        [object[]]$knownParameters = 'SqlInstance', 'SqlCredential', 'Database', 'InputObject', 'FileGroup', 'TableName', 'IndexName', 'Operation', 'MaxDOP', 'NoIndex', 'AllErrorMessages', 'NoInformationalMessages', 'PhysicalOnly', 'DataPurity', 'ExtendedLogicalChecks', 'TabLock', 'EstimateOnly', 'OutputScriptOnly', 'EnableException'
        $knownParameters += [System.Management.Automation.PSCmdlet]::CommonParameters
        It "Should only contain our specific parameters" {
            (@(Compare-Object -ReferenceObject ($knownParameters | Where-Object {$_}) -DifferenceObject $params).Count ) | Should Be 0
        }
    }
}

Describe "$CommandName Integration Tests" -Tags "IntegrationTests" {
    Context "Testing DBCC CheckDB" {
        BeforeAll {
            $database = "dbatoolsci_dbcc_$(Get-Random)"
            $server = Connect-DbaInstance -SqlInstance $script:instance2
            $server.Query("CREATE DATABASE $database")
        }
        AfterAll {
            Remove-DbaDatabase -SqlInstance $script:instance2 -Database $database -Confirm:$false
        }
    }
}