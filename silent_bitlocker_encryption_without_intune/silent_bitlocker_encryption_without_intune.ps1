# Start transcript for logging
Start-Transcript -Path "C:\Temp\BitLockerStartupLog.txt" -Append

# Check TPM status
$tpm = Get-Tpm

# Check Secure Boot status
try {
    $secureBootEnabled = Confirm-SecureBootUEFI -ErrorAction Stop
} catch {
    $secureBootEnabled = $false
}

# Registry path
$regPath = "HKLM:\SOFTWARE\BitLocker"

# Ensure registry path exists and set all properties at once
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

Set-ItemProperty -Path $regPath -Type DWord -Force -Property @{
    SecureBoot   = [int]$secureBootEnabled
    TPMPresent   = [int]$tpm.TpmPresent
    TPMEnabled   = [int]$tpm.TpmEnabled
    TPMActivated = [int]$tpm.TpmActivated
    TPMReady     = [int]$tpm.TpmReady
}

# Abort if TPM or Secure Boot check fails
if (-not ($secureBootEnabled -and $tpm.TpmPresent -and $tpm.TpmEnabled -and $tpm.TpmActivated -and $tpm.TpmReady)) 
{
    Write-Output "TPM or Secure Boot check failed. Aborting operation."
    Stop-Transcript
    exit
}

try {
    $BitLockerEnabled = (Get-ItemProperty -Path $regPath -Name "BitLockerEnabled" -ErrorAction SilentlyContinue).BitLockerEnabled

    if ($BitLockerEnabled -eq 1) {
        Write-Output "BitLocker is already enabled with recovery password. Skipping all steps."
    } 
    else {
        $BitLockerStatus = Get-BitLockerVolume -MountPoint "C:"

        if ($BitLockerStatus.ProtectionStatus -eq 'On' -or $BitLockerStatus.VolumeStatus -eq 'EncryptionInProgress') 
        {
            Write-Output "BitLocker is either protecting or encrypting the C: drive."

            $RecoveryProtectors = $BitLockerStatus.KeyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}

            if ($RecoveryProtectors.Count -eq 0) {
                Add-BitLockerKeyProtector -MountPoint "C:" -RecoveryPasswordProtector
                Write-Output "Recovery password protector added successfully."
            } 
            else {
                Write-Output "Recovery password protector already exists."
                foreach ($protector in $RecoveryProtectors) 
                {
                    Backup-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $protector.KeyProtectorId
                    Write-Output "Recovery password with ID $($protector.KeyProtectorId) backed up to AD."
                }
            }

            Set-ItemProperty -Path $regPath -Name "BitLockerEnabled" -Value 1 -Type DWORD -Force | Out-Null
            Write-Output "Registry key and value created successfully."
        } 
        else {
            $FvePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\FVE"
            if (-not (Test-Path $FvePolicyPath)) {
                New-Item -Path $FvePolicyPath -Force | Out-Null
            }
            Set-ItemProperty -Path $FvePolicyPath -Name "OSEncryptionType" -Value 1 -Type DWord
            Write-Output "OSEncryptionType registry key set to 1 (full encryption)."

            Enable-BitLocker -MountPoint "C:" -RecoveryPasswordProtector -SkipHardwareTest -EncryptionMethod XtsAes256 -ErrorAction Stop
            Write-Output "BitLocker enabled successfully."

            Set-ItemProperty -Path $regPath -Name "BitLockerEnabled" -Value 1 -Type DWORD -Force | Out-Null
            Write-Output "Registry key and value created successfully."
        }

        Unregister-ScheduledTask -TaskName "Enable Bitlocker C:" -Confirm:$false
        Write-Output "Scheduled task deleted successfully."

        Stop-Transcript
        Remove-Item -Path "C:\Temp\BitLockerStartupLog.txt" -Force
    }
} 
catch {
    Write-Output "Error enabling BitLocker: $_"
    Set-ItemProperty -Path $regPath -Name "BitLockerEnabled" -Value 0 -Type DWORD -Force | Out-Null
    Write-Output "Registry key created with BitLockerEnabled set to 0 due to error."
    Stop-Transcript
}