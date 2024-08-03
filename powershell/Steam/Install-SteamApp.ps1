<#
    References:
        - https://ark.wiki.gg/wiki/Dedicated_server_setup
        - https://ark.wiki.gg/wiki/Server_configuration
        - https://developer.valvesoftware.com/wiki/Dedicated_Servers_List
        - https://developer.valvesoftware.com/wiki/SteamCMD
        - https://developer.valvesoftware.com/wiki/7_Days_to_Die_Dedicated_Server
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Arguments,
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    [Parameter(Mandatory = $true)]
    [string]$SteamAppId,
    [Parameter(Mandatory = $true)]
    [string]$SteamCmdBasePath
)

function Expand-SystemDrive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ulong]$MaximumSize = 0
    )

    $driveLetter = ${Env:SystemDrive}[0];

    if (0 -eq $MaximumSize) {
        $MaximumSize = ((Get-PartitionSupportedSize -DriveLetter $driveLetter).SizeMax - 256000000);
    }

    if ((Get-Partition -DriveLetter $driveLetter).Size -lt $MaximumSize) {
        Resize-Partition `
            -DriveLetter $driveLetter `
            -Size $MaximumSize |
            Out-Null;
    }
}
function Install-SteamCmd {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Force,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $tempFilePath = "$([IO.Path]::GetTempPath())$(New-Guid).zip";

    Invoke-WebRequest `
        -OutFile $tempFilePath `
        -Uri 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip' |
        Out-Null;

    Expand-Archive `
        -DestinationPath $Path `
        -Force:$Force `
        -Path $tempFilePath |
        Out-Null;
}
function Install-TrustedRootCertificates {
    [CmdletBinding()]
    param()

    $sstFilePath = "$([IO.Path]::GetTempPath())$(New-Guid).sst";

    certutil.exe -generateSSTFromWU $sstFilePath | Out-Null;

    if (0 -ne $LASTEXITCODE) {
        exit $LASTEXITCODE;
    }

    certutil.exe -dump $sstFilePath | Out-Null;

    if (0 -ne $LASTEXITCODE) {
        exit $LASTEXITCODE;
    }

    Import-Certificate `
        -CertStoreLocation 'Cert:/LocalMachine/Root' `
        -FilePath $sstFilePath |
        Out-Null;
}

$ErrorActionPreference = 'Stop';
$ProgressPreference = 'SilentlyContinue';

$steamScriptPath = "$([IO.Path]::GetTempPath())$(New-Guid).txt";
$steamScriptValue = @"
@ShutdownOnFailedCommand 1
@NoPromptForPassword 1
login anonymous
app_update $SteamAppId $Arguments
quit
"@;

Expand-SystemDrive;

Install-TrustedRootCertificates;

Install-SteamCmd `
    -Force:$Force `
    -Path $SteamCmdBasePath;

Push-Location -Path $SteamCmdBasePath;

try {
    New-Item `
        -ItemType 'File' `
        -Path $steamScriptPath `
        -Value $steamScriptValue |
        Out-Null;

    $process = Start-Process `
        -ArgumentList @(
            '+runscript',
            $steamScriptPath
        ) `
        -FilePath './steamcmd.exe' `
        -NoNewWindow `
        -PassThru `
        -Wait;
    $exitCode = $process.ExitCode;

    if (7 -eq $exitCode) {
        Write-Output 'SteamCmd exited with error code 7.';

        $exitCode = 0;
    }

    exit $exitCode;
}
finally {
    Pop-Location;
}
