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

# Ensure registry path exists
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

# Set registry values individually
Set-ItemProperty -Path $regPath -Name "SecureBoot" -Value ([int]$secureBootEnabled) -Type DWord -Force
Set-ItemProperty -Path $regPath -Name "TPMPresent" -Value ([int]$tpm.TpmPresent) -Type DWord -Force
Set-ItemProperty -Path $regPath -Name "TPMEnabled" -Value ([int]$tpm.TpmEnabled) -Type DWord -Force
Set-ItemProperty -Path $regPath -Name "TPMActivated" -Value ([int]$tpm.TpmActivated) -Type DWord -Force
Set-ItemProperty -Path $regPath -Name "TPMReady" -Value ([int]$tpm.TpmReady) -Type DWord -Force

# Output current status to console
Write-Host "`nStatus Report:"
Write-Host "---------------"
Write-Host "Secure Boot Enabled:`t" ($secureBootEnabled -eq $true)
Write-Host "TPM Present:`t`t" $tpm.TpmPresent
Write-Host "TPM Enabled:`t`t" $tpm.TpmEnabled
Write-Host "TPM Activated:`t`t" $tpm.TpmActivated
Write-Host "TPM Ready:`t`t" $tpm.TpmReady