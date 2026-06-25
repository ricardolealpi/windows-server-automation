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

    Write-Log -Message "Inactive accounts found: $(@($InactiveUsers).Count)" -Level "INFO"
}
catch {
    Write-Log -Message "Failed to query inactive accounts. Error: $($_.Exception.Message)" -Level "ERROR"
}

# ==============================================================================
# CATEGORY 2 — Password Never Expires
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

    Write-Log -Message "Accounts with non-expiring password found: $(@($NeverExpiresUsers).Count)" -Level "INFO"
}
catch {
    Write-Log -Message "Failed to query password-never-expires accounts. Error: $($_.Exception.Message)" -Level "ERROR"
}

# ==============================================================================
# CATEGORY 3 — Stale Disabled Accounts (disabled for 30+ days)
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

    Write-Log -Message "Stale disabled accounts found: $(@($DisabledUsers).Count)" -Level "INFO"
}
catch {
    Write-Log -Message "Failed to query disabled accounts. Error: $($_.Exception.Message)" -Level "ERROR"
}

# ==============================================================================
# COMMIT 3 — CATEGORY 4: Users Without Group Membership
# Enabled accounts that belong to no security or distribution group beyond
# the default "Domain Users" are invisible to RBAC policies and permission
# structures. This is a governance gap, not necessarily a security risk.
# RiskLevel: Medium — the account exists but has no controlled access scope.
# ==============================================================================
Write-Log -Message "Scanning for users with no group membership beyond Domain Users..." -Level "ACTION"

try {
    $AllUsers = Get-ADUser -Filter { Enabled -eq $true } -Properties MemberOf, Department, Title, DistinguishedName

    $NoGroupUsers = $AllUsers | Where-Object {
        # MemberOf only lists explicitly assigned groups — Domain Users is implicit
        # so an empty MemberOf means the account has no assigned groups at all
        ($_.MemberOf -eq $null -or @($_.MemberOf).Count -eq 0)
    }

    foreach ($User in $NoGroupUsers) {
        $AuditResults.Add([PSCustomObject]@{
            SamAccountName = $User.SamAccountName
            DisplayName    = $User.Name
            Department     = $User.Department
            Title          = $User.Title
            RiskCategory   = "No Group Membership"
            RiskLevel      = "Medium"
            Detail         = "Account has no explicitly assigned groups (Domain Users only)"
            DN             = $User.DistinguishedName
        })
    }

    Write-Log -Message "Users with no group membership found: $(@($NoGroupUsers).Count)" -Level "INFO"
}
catch {
    Write-Log -Message "Failed to query group membership. Error: $($_.Exception.Message)" -Level "ERROR"
}

# ==============================================================================
# COMMIT 3 — CATEGORY 5: Users Without UPN Configured
# A missing or malformed UPN (UserPrincipalName) breaks modern authentication
# flows including Azure AD Connect sync, ADFS, and Microsoft 365 SSO.
# This is critical in hybrid environments — accounts without a valid UPN
# cannot be synced to Entra ID.
# RiskLevel: High in hybrid environments, Medium in on-premises only.
# ==============================================================================
Write-Log -Message "Scanning for users with missing or malformed UPN..." -Level "ACTION"

try {
    $NoUPNUsers = Get-ADUser -Filter { Enabled -eq $true } -Properties UserPrincipalName, Department, Title, DistinguishedName |
    Where-Object {
        [String]::IsNullOrWhiteSpace($_.UserPrincipalName) -or
        $_.UserPrincipalName -notmatch '^[^@]+@[^@]+\.[^@]+$'
    }

    foreach ($User in $NoUPNUsers) {
        $UPNValue = if ([String]::IsNullOrWhiteSpace($User.UserPrincipalName)) {
            "Not configured"
        } else {
            "Malformed: $($User.UserPrincipalName)"
        }

        $AuditResults.Add([PSCustomObject]@{
            SamAccountName = $User.SamAccountName
            DisplayName    = $User.Name
            Department     = $User.Department
            Title          = $User.Title
            RiskCategory   = "Missing or Malformed UPN"
            RiskLevel      = "High"
            Detail         = $UPNValue
            DN             = $User.DistinguishedName
        })
    }

    Write-Log -Message "Users with missing or malformed UPN found: $(@($NoUPNUsers).Count)" -Level "INFO"
}
catch {
    Write-Log -Message "Failed to query UPN status. Error: $($_.Exception.Message)" -Level "ERROR"
}

# --- FINAL SUMMARY ---
$HighRisk   = @($AuditResults | Where-Object { $_.RiskLevel -eq "High"   }).Count
$MediumRisk = @($AuditResults | Where-Object { $_.RiskLevel -eq "Medium" }).Count
$LowRisk    = @($AuditResults | Where-Object { $_.RiskLevel -eq "Low"    }).Count

Write-Log -Message "Audit scan complete. Total findings: $($AuditResults.Count) | High: $HighRisk | Medium: $MediumRisk | Low: $LowRisk" -Level "SUCCESS"
Write-Log -Message "CSV and HTML export coming in next iterations.`n" -Level "INFO"