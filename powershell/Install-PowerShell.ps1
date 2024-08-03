$ErrorActionPreference = 'Stop';
$ProgressPreference = 'SilentlyContinue';

$tempFilePath = "$([IO.Path]::GetTempPath())$(New-Guid).msi";

Invoke-WebRequest `
    -OutFile $tempFilePath `
    -Uri 'https://github.com/PowerShell/PowerShell/releases/download/v7.4.4/PowerShell-7.4.4-win-x64.msi' |
    Out-Null;

$process = Start-Process `
    -ArgumentList @(
        '/norestart',
        "/package `"$((Get-Item -Path $tempFilePath).FullName)`"",
        '/quiet'
    ) `
    -FilePath 'msiexec' `
    -NoNewWindow `
    -PassThru `
    -Wait;
$exitCode = $process.ExitCode;

if (0 -ne $exitCode) {
    Write-Error "Unknown error while installing PowerShell (exit code: $exitCode).";
}
else {
    Write-Output 'Successfully installed PowerShell.';
}

exit $exitCode;
