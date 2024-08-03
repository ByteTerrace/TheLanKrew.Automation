[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop';
$ProgressPreference = 'SilentlyContinue';

$capabilityName = 'ServerCore.AppCompatibility~~~~0.0.1.0';

try {
    Add-WindowsCapability `
        -Name $capabilityName `
        -Online |
        Out-Null;
}
# TODO: Remove once issue with Windows Server 2022 Datacenter Core is resolved.
catch [Runtime.InteropServices.COMException] {
    if ('The system cannot find the file specified.' -eq ($_.Exception.Message.Trim())) {
        Add-WindowsCapability `
            -Name $capabilityName `
            -Online |
            Out-Null;
    }
}

if ('Installed' -eq (Get-WindowsCapability -Name $capabilityName -Online).State) {
    exit 0;
}
else {
    throw 'Uknown error during installation.';
}
