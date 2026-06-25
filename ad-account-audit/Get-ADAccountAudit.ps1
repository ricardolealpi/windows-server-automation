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

    $LogFile   = "$PSScriptRoot\audit.log"
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogLine   = "[$Timestamp] [$Level] $Message"

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

    $Domain     = Get-ADDomain
    $DomainDN   = $Domain.DistinguishedName
    $DomainName = $Domain.DNSRoot
    Write-Log -Message "Domain detected: $DomainName ($DomainDN)" -Level "INFO"
}
catch {
    Write-Log -Message "Failed to load AD module or detect domain. Error: $($_.Exception.Message)" -Level "ERROR"
    Exit
}

# --- STEP 2: Define Audit Parameters ---
$InactiveDaysThreshold = 90
$InactiveCutoffDate    = (Get-Date).AddDays(-$InactiveDaysThreshold)
$DisabledDaysThreshold = 30
$DisabledCutoffDate    = (Get-Date).AddDays(-$DisabledDaysThreshold)
$AuditResults          = [System.Collections.Generic.List[PSObject]]::new()

Write-Log -Message "Audit started. Inactive threshold: $InactiveDaysThreshold days | Disabled threshold: $DisabledDaysThreshold days." -Level "INFO"

# ==============================================================================
# CATEGORY 1 — Inactive Accounts (no login in 90+ days)
# Detects enabled accounts with no login activity within the threshold.
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

# ==============================================================================
# COMMIT 2 — CATEGORY 2: Password Never Expires
# Enabled accounts with PasswordNeverExpires = $true are a direct violation
# of password rotation policies and a common finding in security audits.
# RiskLevel is HIGH because these accounts are often service or admin accounts
# with elevated privileges that are never rotated.
# ==============================================================================
Write-Log -Message "Scanning for accounts with password set to never expire..." -Level "ACTION"

try {
    $NeverExpiresUsers = Get-ADUser -Filter {
        Enabled -eq $true -and PasswordNeverExpires -eq $true
    } -Properties PasswordNeverExpires, PasswordLastSet, Department, Title, DistinguishedName

    foreach ($User in $NeverExpiresUsers) {
        $LastSet = if ($User.PasswordLastSet) {
            $User.PasswordLastSet.ToString('yyyy-MM-dd')
        } else {
            "Never set"
        }

        $AuditResults.Add([PSCustomObject]@{
            SamAccountName = $User.SamAccountName
            DisplayName    = $User.Name
            Department     = $User.Department
            Title          = $User.Title
            RiskCategory   = "Password Never Expires"
            RiskLevel      = "High"
            Detail         = "Password last set: $LastSet"
            DN             = $User.DistinguishedName
        })
    }

    Write-Log -Message "Accounts with non-expiring password found: $($NeverExpiresUsers.Count)" -Level "INFO"
}
catch {
    Write-Log -Message "Failed to query password-never-expires accounts. Error: $($_.Exception.Message)" -Level "ERROR"
}

# ==============================================================================
# COMMIT 2 — CATEGORY 3: Stale Disabled Accounts
# Accounts disabled for 30+ days should be reviewed for permanent removal.
# Leaving disabled accounts in AD indefinitely creates noise and potential
# reactivation risk if access controls are misconfigured.
# ==============================================================================
Write-Log -Message "Scanning for stale disabled accounts (disabled for $DisabledDaysThreshold+ days)..." -Level "ACTION"

try {
    $DisabledUsers = Get-ADUser -Filter {
        Enabled -eq $false
    } -Properties LastLogonDate, Modified, Department, Title, DistinguishedName |
    Where-Object {
        $_.Modified -ne $null -and $_.Modified -lt $DisabledCutoffDate
    }

    foreach ($User in $DisabledUsers) {
        $LastLogin = if ($User.LastLogonDate) {
            $User.LastLogonDate.ToString('yyyy-MM-dd')
        } else {
            "Never logged in"
        }

        $AuditResults.Add([PSCustomObject]@{
            SamAccountName = $User.SamAccountName
            DisplayName    = $User.Name
            Department     = $User.Department
            Title          = $User.Title
            RiskCategory   = "Stale Disabled Account"
            RiskLevel      = "Low"
            Detail         = "Disabled since: $($User.Modified.ToString('yyyy-MM-dd')) | Last login: $LastLogin"
            DN             = $User.DistinguishedName
        })
    }

    Write-Log -Message "Stale disabled accounts found: $($DisabledUsers.Count)" -Level "INFO"
}
catch {
    Write-Log -Message "Failed to query disabled accounts. Error: $($_.Exception.Message)" -Level "ERROR"
}

# --- SUMMARY ---
Write-Log -Message "Audit scan complete. Total findings: $($AuditResults.Count)" -Level "SUCCESS"
Write-Log -Message "CSV and HTML export coming in next iterations.`n" -Level "INFO"