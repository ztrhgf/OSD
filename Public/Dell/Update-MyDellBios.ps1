function Update-MyDellBios {
    [CmdletBinding()]
    param (
        [switch]$Silent,
        [switch]$Reboot
    )
    #===================================================================================================
    #   Require Admin Rights
    #===================================================================================================
    if ((Get-OSDGather -Property IsAdmin) -eq $false) {
        Write-Warning "$($MyInvocation.MyCommand) requires Admin Rights ELEVATED"
        Break
    }
    #===================================================================================================
    $GetMyDellBios = Get-MyDellBios

    $SourceUrl = $GetMyDellBios.Url
    $DestinationFile = $GetMyDellBios.FileName
    $OutFile = Join-Path $env:TEMP $DestinationFile

    if (-NOT (Test-Path $OutFile)) {
        Write-Verbose "Downloading using BITS $SourceUrl" -Verbose
        Save-OSDDownload -BitsTransfer -SourceUrl $SourceUrl -DownloadFolder $env:TEMP -ErrorAction SilentlyContinue | Out-Null
    }
    if (-NOT (Test-Path $OutFile)) {
        Write-Verbose "BITS didn't work ..."
        Write-Verbose "Downloading using WebClient $SourceUrl" -Verbose
        Save-OSDDownload -SourceUrl $SourceUrl -DownloadFolder $env:TEMP -ErrorAction SilentlyContinue | Out-Null
    }

    if (-NOT (Test-Path $OutFile)) {Write-Warning "Unable to download $SourceUrl"; Break}

    Write-Verbose "Checking for BitLocker" -Verbose
    #http://www.dptechjournal.net/2017/01/powershell-script-to-deploy-dell.html
    #https://github.com/dptechjournal/Dell-Firmware-Updates/blob/master/Install_Dell_Bios_upgrade.ps1
    $GetBitLockerVolume = Get-BitLockerVolume | Where-Object { $_.ProtectionStatus -eq "On" -and $_.VolumeType -eq "OperatingSystem" }
    if ($GetBitLockerVolume) {
        Write-Verbose "Suspending BitLocker for 1 Reboot"
        Suspend-BitLocker -Mountpoint $GetBitLockerVolume -RebootCount 1
        if (Get-BitLockerVolume -MountPoint $GetBitLockerVolume | Where-Object ProtectionStatus -eq "On") {
            Write-Warning "Couldn't suspend Bitlocker"
            Break
        }
    } else {
        Write-Verbose "BitLocker was not enabled" -Verbose
    }

    $BiosLog = Join-Path $env:TEMP 'Update-MyDellBios.log'
    $Arguments = "/l=`"$BiosLog`""
    if ($Silent) {
        $Arguments = $Arguments + " /s"
    }
    if ($Reboot) {
        $Arguments = $Arguments + " /r"
    }

    Write-Verbose "Starting BIOS Update" -Verbose 
    Write-Verbose "$OutFile $Arguments" -Verbose
    Start-Process -FilePath $OutFile -ArgumentList $Arguments -Wait
}