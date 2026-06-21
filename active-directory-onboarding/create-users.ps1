# ==============================================================================
# Script Name: create-users.ps1
# Description: Automated Corporate Onboarding System for Windows Server environments.
#              Generates secure random passwords, ensures strict idempotency,
#              handles naming collisions, and maintains centralized persistent logging.
# Author: Ricardo Leal
# Version: 2.0.0
# Changelog:
#   v2.0.0 - Replaced deprecated System.Web password generator with RNGCryptoServiceProvider
#           - Removed dead else block (duplicate user creation logic)
#           - Wrapped AD write operations in try/catch for graceful error handling
#           - Added null/empty guards for optional CSV fields (Title, Office)
#           - Domain and UPN suffix now auto-detected from Active Directory
#           - Added security notice on plaintext password logging
# ==============================================================================

# --- FUNCTION: Centralized Logging Mechanism ---
function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [String]$Message,
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "ACTION", "SKIP", "SUCCESS", "ERROR", "WARN")]
        [String]$Level = "INFO"
    )

    $LogFile  = "$PSScriptRoot\onboarding.log"
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogLine  = "[$Timestamp] [$Level] $Message"

    Add-Content -Path $LogFile -Value $LogLine

    switch ($Level) {
        "SUCCESS" { Write-Host $LogLine -ForegroundColor Green }
        "ACTION"  { Write-Host $LogLine -ForegroundColor Yellow }
        "SKIP"    { Write-Host $LogLine -ForegroundColor DarkGray }
        "ERROR"   { Write-Warning $LogLine }
        "WARN"    { Write-Warning $LogLine }
        default   { Write-Host $LogLine -ForegroundColor Cyan }
    }
}

# --- FUNCTION: Generate Cryptographically Secure Password ---
# Uses RNGCryptoServiceProvider — compatible with PS 5.1, PS 7, and Server Core.
# Replaces the deprecated System.Web.Security.Membership.GeneratePassword() method.
function New-SecurePassword {
    $Chars  = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*'
    $Length = 16
    $Rng    = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $Bytes  = New-Object byte[] $Length
    $Rng.GetBytes($Bytes)
    $Password = -join ($Bytes | ForEach-Object { $Chars[$_ % $Chars.Length] })
    $Rng.Dispose()
    return $Password
}

# --- STEP 1: Define Script-Scope Paths ---
$CSVPath = "$PSScriptRoot\employees-template.csv"

# --- STEP 2: Import Active Directory Module & Auto-Detect Domain ---
# Domain detection is placed here intentionally: Get-ADDomain requires the
# ActiveDirectory module to be loaded first. Calling it before Import-Module
# would silently fail or throw in a clean session.
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Log -Message "Active Directory module loaded successfully." -Level "SUCCESS"

    $DomainSuffix = (Get-ADDomain).DistinguishedName   # e.g. DC=tecnofacil,DC=es
    $UPNSuffix    = (Get-ADDomain).DNSRoot             # e.g. tecnofacil.es
    $BaseOU       = "OU=Usuarios,$DomainSuffix"
    Write-Log -Message "Domain detected: $UPNSuffix ($DomainSuffix)" -Level "INFO"
}
catch {
    Write-Log -Message "Failed to load AD module or detect domain. Error: $($_.Exception.Message)" -Level "ERROR"
    Exit
}

# --- STEP 3: Load and Validate the CSV File ---
if (-Not (Test-Path $CSVPath)) {
    Write-Log -Message "The CSV file was not found at: $CSVPath" -Level "ERROR"
    Exit
}

$Employees = Import-Csv -Path $CSVPath
Write-Log -Message "Successfully loaded $($Employees.Count) employees from CSV." -Level "INFO"

# --- STEP 4: Process Each Employee ---
foreach ($Employee in $Employees) {

    # 1. Validate mandatory fields before doing any AD work
    if ([String]::IsNullOrWhiteSpace($Employee.FirstName) -or
        [String]::IsNullOrWhiteSpace($Employee.LastName)  -or
        [String]::IsNullOrWhiteSpace($Employee.Department)) {

        Write-Log -Message "Skipping row: Missing mandatory fields for: $($Employee.FirstName) $($Employee.LastName)" -Level "ERROR"
        continue
    }

    # 2. Sanitize all fields — optional fields default to empty string to avoid
    #    NullReferenceException when Title or Office are absent from the CSV row.
    $FirstName  = $Employee.FirstName.Trim()
    $LastName   = $Employee.LastName.Trim()
    $Department = $Employee.Department.Trim()
    $Title      = if (-not [String]::IsNullOrWhiteSpace($Employee.Title))  { $Employee.Title.Trim()  } else { "" }
    $Office     = if (-not [String]::IsNullOrWhiteSpace($Employee.Office)) { $Employee.Office.Trim() } else { "" }

    # 3. AD compliance check: sAMAccountName cannot start or end with a dot
    $sAMAccountName = "$FirstName.$LastName".ToLower()
    if ($sAMAccountName.StartsWith(".") -or $sAMAccountName.EndsWith(".")) {
        Write-Log -Message "Skipping row: Generated username '$sAMAccountName' is non-compliant (starts or ends with dot)." -Level "ERROR"
        continue
    }

    $TargetOU = "OU=$Department,$BaseOU"

    # 4a. Ensure the Department OU exists — create it if not.
    #     Wrapped in try/catch so a permission error on one department does not
    #     abort the entire batch; the affected department is skipped gracefully.
    if (-Not (Get-ADOrganizationalUnit -Filter "Name -eq '$Department'" -SearchBase $BaseOU -ErrorAction SilentlyContinue)) {
        Write-Log -Message "Department OU '$Department' not found. Creating it..." -Level "WARN"
        try {
            New-ADOrganizationalUnit -Name $Department -Path $BaseOU -ProtectedFromAccidentalDeletion $false
            Write-Log -Message "OU '$Department' created successfully." -Level "SUCCESS"
        }
        catch {
            Write-Log -Message "Failed to create OU '$Department'. Error: $($_.Exception.Message)" -Level "ERROR"
            continue
        }
    }

    # 4b. Idempotency & Collision Handling
    #     - If the user exists in the same OU: skip (already provisioned).
    #     - If the username exists in a different OU: increment counter and retry.
    $BaseAccountName        = "$FirstName.$LastName".ToLower()
    $sAMAccountName         = $BaseAccountName
    $DisplayName            = "$FirstName $LastName"
    $Counter                = 1
    $UserAlreadyProvisioned = $false

    while ($true) {
        $ExistingUser = Get-ADUser -Filter { sAMAccountName -eq $sAMAccountName } -ErrorAction SilentlyContinue

        if ($null -eq $ExistingUser) {
            break  # Username is available — proceed with creation
        }
        elseif ($ExistingUser.DistinguishedName -match [regex]::Escape("OU=$Department,$BaseOU")) {
            $UserAlreadyProvisioned = $true
            break  # Same employee, same OU — already provisioned
        }
        else {
            # Naming collision with a different employee — increment and retry
            $sAMAccountName = "$BaseAccountName$Counter"
            $DisplayName    = "$FirstName $LastName $Counter"
            $Counter++
        }
    }

    if ($UserAlreadyProvisioned) {
        Write-Log -Message "User '$sAMAccountName' in '$Department' already exists. Skipping." -Level "SKIP"
        continue
    }

    # 4c. Provision the new user account
    Write-Log -Message "Provisioning new user account: $sAMAccountName ($Department)" -Level "ACTION"

    $PlainPassword  = New-SecurePassword
    $SecurePassword = ConvertTo-SecureString $PlainPassword -AsPlainText -Force

    try {
        New-ADUser -Name              $DisplayName `
                   -DisplayName       $DisplayName `
                   -GivenName         $FirstName `
                   -Surname           $LastName `
                   -Department        $Department `
                   -sAMAccountName    $sAMAccountName `
                   -UserPrincipalName "$sAMAccountName@$UPNSuffix" `
                   -Path              $TargetOU `
                   -Title             $Title `
                   -Office            $Office `
                   -AccountPassword   $SecurePassword `
                   -ChangePasswordAtLogon $true `
                   -Enabled           $true

        Write-Log -Message "User '$sAMAccountName' created successfully." -Level "SUCCESS"

        # SECURITY NOTE: Temporary password is written to onboarding.log in plaintext
        # so the IT team can communicate it to the new hire via a controlled channel.
        # PRODUCTION RECOMMENDATION: Replace with a secure delivery mechanism such as
        # Azure Key Vault, encrypted email via Microsoft Graph API, or a PAW clipboard.
        Write-Log -Message "Temporary password for ${sAMAccountName}: $PlainPassword" -Level "INFO"
    }
    catch {
        Write-Log -Message "Failed to create user '$sAMAccountName'. Error: $($_.Exception.Message)" -Level "ERROR"
    }
}

Write-Log -Message "Corporate Onboarding Script completed.`n" -Level "SUCCESS"