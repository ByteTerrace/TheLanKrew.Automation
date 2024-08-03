function Install-MicrosoftVisualCPlusPlus2017Redistributable {
    $tempFilePath = "$([IO.Path]::GetTempPath())$(New-Guid).exe";

    Invoke-WebRequest `
        -OutFile $tempFilePath `
        -Uri 'https://aka.ms/vs/17/release/vc_redist.x64.exe' |
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

Install-MicrosoftVisualCPlusPlus2017Redistributable;
