$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-Command $CommandName).Parameters.Keys | Where-Object {$_ -notin ('whatif', 'confirm')}
        [object[]]$knownParameters = 'SqlInstance','Database','SqlCredential','NoRecovery','EnableException','Force','InputObject','Delay'
        $knownParameters += [System.Management.Automation.PSCmdlet]::CommonParameters
        It "Should only contain our specific parameters" {
            (@(Compare-Object -ReferenceObject ($knownParameters | Where-Object {$_}) -DifferenceObject $params).Count ) | Should Be 0
        }
    }
}

Describe "$commandname Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        $dbname = "dbatoolsci_logshipping"
        $null = mkdir C:\temp\logshipping\backup
        $null = New-DbaDatabase -SqlInstance $script:instance2 -Name $dbname
    }
    AfterAll {
        Remove-DbaDatabase -Confirm:$false -SqlInstance $script:instance2, $script:instance3 -Database $dbname
        Get-ChildItem -Recurse C:\temp\logshipping | Remove-Item -Force
    }

    It "returns success" {
        $null = Invoke-DbaDbLogShipping -SourceSqlInstance $script:instance2 -DestinationSqlInstance $script:instance3 -Database $dbname -BackupNetworkPath C:\temp -BackupLocalPath "C:\temp\logshipping\backup" -GenerateFullBackup -CompressBackup -SecondaryDatabaseSuffix "_LS" -Force
        $results = Invoke-DbaLogShippingRecovery -SqlInstance $script:instance3 -Database $dbname
    }
}