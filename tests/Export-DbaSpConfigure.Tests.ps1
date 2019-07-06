$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-Command $CommandName).Parameters.Keys | Where-Object {$_ -notin ('whatif', 'confirm')}
        [object[]]$knownParameters = 'SqlInstance', 'SqlCredential', 'Path', 'FilePath', 'Encoding', 'Passthru', 'BatchSeparator', 'NoPrefix', 'NoClobber', 'Append', 'EnableException'
        $knownParameters += [System.Management.Automation.PSCmdlet]::CommonParameters
        It "Should only contain our specific parameters" {
            (@(Compare-Object -ReferenceObject ($knownParameters | Where-Object {$_}) -DifferenceObject $params).Count ) | Should Be 0
        }
    }
}

Describe "$commandname Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        $DefaultExportPath = Get-DbatoolsConfigValue -FullName path.dbatoolsexport
        $AltExportPath = "$env:USERPROFILE\Documents"
        try {
            $server = Connect-DbaInstance -SqlInstance $script:instance2
            $server.Configuration.ShowAdvancedOptions.ConfigValue = $false
            $server.Configuration.Alter($true)
        } catch {
            $_
        }
    }
    AfterAll {
        $ExportedFile = Get-ChildItem $DefaultExportPath, $AltExportPath | Where-Object { $_.Name -match "spConfigure.sql|Dbatoolsci_spConfigure.sql" }
        $null = Remove-Item -Path $($ExportedFile.FullName) -ErrorAction SilentlyContinue
    }

    Context "works as expected" {
        $script:results = Export-DbaSpConfigure -SqlInstance $script:instance2 -Passthru
        It "should export some text matching EXEC sp_configure" {
            $script:results -match "EXEC sp_configure"
        }
        It "should include BatchSeparator based on the Formatting.BatchSeparator configuration" {
            $script:results -match "(Get-DbatoolsConfigValue -FullName 'Formatting.BatchSeparator')"
        }

        $script:results = Export-DbaSpConfigure -SqlInstance $script:instance2 -Passthru -BatchSeparator "MakeItSo"
        It "should include the defined BatchSeparator" {
            $script:results -match "MakeItSo"
        }
    }
    Context "Exports file to random and specified paths" {
        It "Should export file to the configured path" {
            $file = Export-DbaSpConfigure -SqlInstance $script:instance2 -WarningAction SilentlyContinue
            $results = $file.DirectoryName
            $results | Should Be $DefaultExportPath
        }
        It "Should export file to custom folder path" {
            $file = Export-DbaSpConfigure -SqlInstance $script:instance2 -Path $AltExportPath -WarningAction SilentlyContinue
            $results = $file.DirectoryName
            $results | Should Be $AltExportPath
        }
        It "Should export file to custom file path" {
            $file = Export-DbaSpConfigure -SqlInstance $script:instance2 -FilePath "$AltExportPath\Dbatoolsci_spConfigure.sql" -WarningAction SilentlyContinue
            $results = $file.Name
            $results | Should Be "Dbatoolsci_spConfigure.sql"
        }
        It "Should export file to custom file path and Append" {
            $file = Export-DbaSpConfigure -SqlInstance $script:instance2 -FilePath "$AltExportPath\Dbatoolsci_spConfigure.sql" -Append -WarningAction SilentlyContinue
            $file.CreationTimeUtc.Ticks | Should BeLessThan $file.LastWriteTimeUtc.Ticks
        }
        It "Should not export file to custom file path with NoClobber" {
            $file = Export-DbaSpConfigure -SqlInstance $script:instance2 -FilePath "$AltExportPath\Dbatoolsci_spConfigure.sql" -NoClobber -WarningVariable warnVar -WarningAction SilentlyContinue
            $file | Should be $null
            $warnVar -match "File already exists. If you want to overwrite it remove the -NoClobber parameter"
        }
    }

}