function Install-MicrosoftDirectXJune2010Redistributable {
    $tempExpandPath = "$([IO.Path]::GetTempPath())$(New-Guid)";
    $tempFilePath = "$tempExpandPath.exe";

    Invoke-WebRequest `
        -OutFile $tempFilePath `
        -Uri 'https://download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe' |
        Out-Null;

    $process = Start-Process `
        -ArgumentList @(
            '/Q',
            "/T:`"$tempExpandPath`""
        ) `
        -FilePath $tempFilePath `
        -NoNewWindow `
        -PassThru `
        -Wait;
    $exitCode = $process.ExitCode;

    if (0 -ne $exitCode) {
        Write-Error "Unknown error while installing DirectX redistributable (exit code: $exitCode).";
    }

    $process = Start-Process `
        -ArgumentList @(
            '/silent'
        ) `
        -FilePath "$tempExpandPath/DXSETUP.exe" `
        -NoNewWindow `
        -PassThru `
        -Wait;
    $exitCode = $process.ExitCode;

    if (0 -ne $exitCode) {
        Write-Error "Unknown error while installing DirectX redistributable (exit code: $exitCode).";
    }
}
function Install-MicrosoftVisualCPlusPlus2013Redistributable {
    $tempFilePath = "$([IO.Path]::GetTempPath())$(New-Guid).exe";

    Invoke-WebRequest `
        -OutFile $tempFilePath `
        -Uri 'https://aka.ms/highdpimfc2013x64enu' |
        Out-Null;

    $process = Start-Process `
        -ArgumentList @(
            '/install',
            '/norestart',
            '/quiet'
        ) `
        -FilePath $tempFilePath `
        -NoNewWindow `
        -PassThru `
        -Wait;
    $exitCode = $process.ExitCode;

    if (0 -ne $exitCode) {
        Write-Error "Unknown error while installing MSVC++ redistributable (exit code: $exitCode).";
    }
}

Install-MicrosoftVisualCPlusPlus2013Redistributable;
Install-MicrosoftDirectXJune2010Redistributable;
