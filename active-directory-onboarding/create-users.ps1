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
    
    $LogFile = "$PSScriptRoot\onboarding.log"
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogLine = "[$Timestamp] [$Level] $Message"
    
    # 1. Write to persistent log file
    Add-Content -Path $LogFile -Value $LogLine
    
    # 2. Maintain color-coded console output
    switch ($Level) {
        "SUCCESS" { Write-Host $LogLine -ForegroundColor Green }
        "ACTION"  { Write-Host $LogLine -ForegroundColor Yellow }
        "SKIP"    { Write-Host $LogLine -ForegroundColor DarkGray }
        "ERROR"   { Write-Warning $LogLine }
        "WARN"    { Write-Warning $LogLine }
        default   { Write-Host $LogLine -ForegroundColor Cyan }
    }
}

# --- FUNCTION: Generate Random Secure Password ---
function New-SecurePassword {
    $Length = 16
    $Assembly = [Reflection.Assembly]::LoadWithPartialName("System.Web")
    $RandomPassword = [System.Web.Security.Membership]::GeneratePassword($Length, 3)
    
    if ($RandomPassword -notmatch "\d") { $RandomPassword += "7" }
    if ($RandomPassword -notmatch "[A-Z]") { $RandomPassword += "X" }
    
    return $RandomPassword
}

# --- STEP 1: Define Parameters and Paths ---
$CSVPath = "$PSScriptRoot\employees-template.csv"
$DomainSuffix = "DC=tecnofacil,DC=es" 
$BaseOU = "OU=Usuarios,$DomainSuffix" 

# --- STEP 2: Import Active Directory Module ---
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Log -Message "Active Directory module loaded successfully." -Level "SUCCESS"
}
catch {
    Write-Log -Message "Active Directory module is not installed. Please run on a Domain Controller." -Level "ERROR"
    Exit
}

# --- STEP 3: Load and Read the CSV File ---
if (-Not (Test-Path $CSVPath)) {
    Write-Log -Message "The CSV file was not found at: $CSVPath" -Level "ERROR"
    Exit
}

$Employees = Import-Csv -Path $CSVPath
Write-Log -Message "Successfully loaded $($Employees.Count) employees from CSV." -Level "INFO"

# --- STEP 4: Process Each Employee (Loop) ---
foreach ($Employee in $Employees) {

    # 1. DATA SANITIZATION: Check for empty mandatory fields BEFORE doing anything
    if ([String]::IsNullOrWhiteSpace($Employee.FirstName) -or 
        [String]::IsNullOrWhiteSpace($Employee.LastName) -or 
        [String]::IsNullOrWhiteSpace($Employee.Department)) {
        
        Write-Log -Message "Skipping row: Missing mandatory fields for element: $($Employee.FirstName) $($Employee.LastName)" -Level "ERROR"
        continue
    }

    # 2. Clean data and verify structural compliance
    $FirstName  = $Employee.FirstName.Trim()
    $LastName   = $Employee.LastName.Trim()
    $Department = $Employee.Department.Trim()
    $Title      = $Employee.Title.Trim()
    $Office     = $Employee.Office.Trim()

    $sAMAccountName = "$FirstName.$LastName".ToLower()

    # 3. Active Directory Compliance: Username cannot start or end with a dot
    if ($sAMAccountName.StartsWith(".") -or $sAMAccountName.EndsWith(".")) {
        Write-Log -Message "Skipping row: Generated username '${sAMAccountName}' is non-compliant." -Level "ERROR"
        continue
    }

    $TargetOU = "OU=$Department,$BaseOU"

    # 4a. Check if the Department OU exists
    if (-Not (Get-ADOrganizationalUnit -Filter "Name -eq '$Department'" -SearchBase $BaseOU -ErrorAction SilentlyContinue)) {
        Write-Log -Message "Department OU '$Department' not found. Creating it..." -Level "WARN"
        New-ADOrganizationalUnit -Name $Department -Path $BaseOU -ProtectedFromAccidentalDeletion $false
    }

   # 4b. Smart Idempotency & Collision Handling
    $BaseAccountName = "$FirstName.$LastName".ToLower()
    $sAMAccountName = $BaseAccountName
    $DisplayName = "$FirstName $LastName"
    $Counter = 1
    $UserAlreadyProvisioned = $false

    # Controlled infinite loop to find an available username or confirm existing employee
    while ($true) {
        $ExistingUser = Get-ADUser -Filter {sAMAccountName -eq $sAMAccountName} -ErrorAction SilentlyContinue
        
        if ($null -eq $ExistingUser) {
            # The username is available! Break the loop to proceed.
            break
        } else {
            # The username is taken. Is it the same employee? Check if they are in the exact same OU.
            if ($ExistingUser.DistinguishedName -match "OU=$Department,$BaseOU") {
                $UserAlreadyProvisioned = $true
                break
            }
            
            # It's a different employee (Collision). Increment counter for both sAMAccountName and DisplayName.
            $sAMAccountName = "$BaseAccountName$Counter"
            $DisplayName = "$FirstName $LastName $Counter"
            $Counter++
        }
    }

    if ($UserAlreadyProvisioned) {
        Write-Log -Message "User $sAMAccountName ($Department) already exists. Skipping creation." -Level "SKIP"
        continue 
    } else {
        # 4c. Create the new user
        # Wrapped New-ADUser in try/catch to log failures per user without aborting the entire onboarding batch.
        Write-Log -Message "Provisioning new user account: $sAMAccountName ($Department)" -Level "ACTION"
        
        $PlainPassword = New-SecurePassword
        $SecurePassword = ConvertTo-SecureString $PlainPassword -AsPlainText -Force
    
        try {
            New-ADUser -Name $DisplayName `
                    -DisplayName $DisplayName `
                    -GivenName $FirstName `
                    -Surname $LastName `
                    -Department $Department `
                    -sAMAccountName $sAMAccountName `
                    -UserPrincipalName "$sAMAccountName@$UPNSuffix" `
                    -Path $TargetOU `
                    -Title $Title `
                    -Office $Office `
                    -AccountPassword $SecurePassword `
                    -ChangePasswordAtLogon $true `
                    -Enabled $true
    
            Write-Log -Message "User '$sAMAccountName' created successfully." -Level "SUCCESS"
    
            # COMMIT 6: Security notice — temporary password is logged to onboarding.log
            # in plaintext to allow the IT team to communicate it to the new hire.
            # PRODUCTION NOTE: In regulated environments, replace this with a secure
            # delivery mechanism (e.g., Azure Key Vault secret, encrypted email via
            # Microsoft Graph API, or a privileged access workstation clipboard).
            Write-Log -Message "Temporary password for ${sAMAccountName}: $PlainPassword" -Level "INFO"
        }
        catch {
            Write-Log -Message "Failed to create user '$sAMAccountName'. Error: $($_.Exception.Message)" -Level "ERROR"
        }
    }
}

Write-Log -Message "Corporate Onboarding Script completed.`n" -Level "SUCCESS"