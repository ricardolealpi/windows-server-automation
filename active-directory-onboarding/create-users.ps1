# ==============================================================================
# Script Name: create-users.ps1
# Description: Automated Corporate Onboarding System for Windows Server environments.
#              Generates secure random passwords, ensures strict idempotency,
#              and maintains centralized persistent logging.
# Author: Ricardo Leal
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
$DomainSuffix = "DC=corp,DC=local" 
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
    $FirstName  = $Employee.FirstName.Trim()
    $LastName   = $Employee.LastName.Trim()
    $Department = $Employee.Department.Trim()
    $Title      = $Employee.Title.Trim()
    $Office     = $Employee.Office.Trim()

    $sAMAccountName = "$FirstName.$LastName".ToLower()
    $TargetOU = "OU=$Department,$BaseOU"

    # 4a. Check if the Department OU exists
    if (-Not (Get-ADOrganizationalUnit -Filter "Name -eq '$Department'" -SearchBase $BaseOU -ErrorAction SilentlyContinue)) {
        Write-Log -Message "Department OU '$Department' not found. Creating it..." -Level "WARN"
        New-ADOrganizationalUnit -Name $Department -Path $BaseOU -ProtectedFromAccidentalDeletion $false
    }

    # 4b. Idempotency Check
    $ExistingUser = Get-ADUser -Filter {sAMAccountName -eq $sAMAccountName} -ErrorAction SilentlyContinue

    if ($ExistingUser) {
        Write-Log -Message "User $sAMAccountName already exists. Skipping creation." -Level "SKIP"
    } else {
        # 4c. Create the new User
        Write-Log -Message "Provisioning new user account: $sAMAccountName" -Level "ACTION"
        
        $PlainPassword = New-SecurePassword
        $Password = ConvertTo-SecureString $PlainPassword -AsPlainText -Force

        New-ADUser -Name "$FirstName $LastName" `
                   -GivenName $FirstName `
                   -Surname $LastName `
                   -sAMAccountName $sAMAccountName `
                   -UserPrincipalName "$sAMAccountName@corp.local" `
                   -Path $TargetOU `
                   -Title $Title `
                   -Office $Office `
                   -AccountPassword $Password `
                   -ChangePasswordAtLogon $true `
                   -Enabled $true

        Write-Log -Message "Temporary password for ${sAMAccountName}: $PlainPassword" -Level "INFO"
    }
}

Write-Log -Message "Corporate Onboarding Script completed.`n" -Level "SUCCESS"