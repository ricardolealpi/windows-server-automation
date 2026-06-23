# ==============================================================================
# Script Name: Get-ADAccountAudit.ps1
# Description: Active Directory Security Audit Tool for Windows Server environments.
#              Scans the domain for common identity security risks and generates
#              detailed reports in CSV and HTML format.
# Author: Ricardo Leal
# Version: 1.0.0
# ==============================================================================

# --- FUNCTION: Centralized Logging Mechanism ---
function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [String]$Message,
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "ACTION", "SUCCESS", "ERROR", "WARN")]
        [String]$Level = "INFO"
    )

    $LogFile  = "$PSScriptRoot\audit.log"
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogLine  = "[$Timestamp] [$Level] $Message"

    Add-Content -Path $LogFile -Value $LogLine

    switch ($Level) {
        "SUCCESS" { Write-Host $LogLine -ForegroundColor Green }
        "ACTION"  { Write-Host $LogLine -ForegroundColor Yellow }
        "ERROR"   { Write-Warning $LogLine }
        "WARN"    { Write-Warning $LogLine }
        default   { Write-Host $LogLine -ForegroundColor Cyan }
    }
}

# --- STEP 1: Import Module & Auto-Detect Domain ---
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Log -Message "Active Directory module loaded successfully." -Level "SUCCESS"

    $Domain       = Get-ADDomain
    $DomainDN     = $Domain.DistinguishedName
    $DomainName   = $Domain.DNSRoot
    Write-Log -Message "Domain detected: $DomainName ($DomainDN)" -Level "INFO"
}
catch {
    Write-Log -Message "Failed to load AD module or detect domain. Error: $($_.Exception.Message)" -Level "ERROR"
    Exit
}

# --- STEP 2: Define Audit Parameters ---
$InactiveDaysThreshold = 90
$InactiveCutoffDate    = (Get-Date).AddDays(-$InactiveDaysThreshold)
$AuditResults          = [System.Collections.Generic.List[PSObject]]::new()

Write-Log -Message "Audit started. Inactive threshold: $InactiveDaysThreshold days." -Level "INFO"

# ==============================================================================
# COMMIT 1: CATEGORY 1 — Inactive Accounts (no login in 90+ days)
# Detects enabled user accounts that have not logged in within the threshold.
# LastLogonDate is replicated across DCs; reliable for audit purposes.
# ==============================================================================
Write-Log -Message "Scanning for inactive accounts (no login in $InactiveDaysThreshold+ days)..." -Level "ACTION"

try {
    $InactiveUsers = Get-ADUser -Filter {
        Enabled -eq $true -and LastLogonDate -lt $InactiveCutoffDate
    } -Properties LastLogonDate, Department, Title, DistinguishedName |
    Where-Object { $_.LastLogonDate -ne $null }

    foreach ($User in $InactiveUsers) {
        $AuditResults.Add([PSCustomObject]@{
            SamAccountName = $User.SamAccountName
            DisplayName    = $User.Name
            Department     = $User.Department
            Title          = $User.Title
            RiskCategory   = "Inactive Account"
            RiskLevel      = "Medium"
            Detail         = "Last login: $($User.LastLogonDate.ToString('yyyy-MM-dd'))"
            DN             = $User.DistinguishedName
        })
    }

    Write-Log -Message "Inactive accounts found: $($InactiveUsers.Count)" -Level "INFO"
}
catch {
    Write-Log -Message "Failed to query inactive accounts. Error: $($_.Exception.Message)" -Level "ERROR"
}

# --- SUMMARY ---
Write-Log -Message "Audit scan complete. Total findings: $($AuditResults.Count)" -Level "SUCCESS"
Write-Log -Message "Audit engine ready. CSV and HTML export coming in next iterations.`n" -Level "INFO"