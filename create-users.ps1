# ==============================================================================
# Script Name: create-users.ps1
# Description: Automated Corporate Onboarding System for Windows Server environments.
#              Generates secure random passwords and ensures strict idempotency.
# Author: Ricardo Leal
# ==============================================================================

# --- FUNCTION: Generate Random Secure Password ---
function New-SecurePassword {
    $Length = 16
    # Load required assembly for web membership utilities
    $Assembly = [Reflection.Assembly]::LoadWithPartialName("System.Web")
    $RandomPassword = [System.Web.Security.Membership]::GeneratePassword($Length, 3)
    
    # Enforce standard complexity policies (digits and uppercase letters)
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
    Write-Host "[INFO] Active Directory module loaded successfully." -ForegroundColor Green
}
catch {
    Write-Warning "[ERROR] Active Directory module is not installed. Please run on a Domain Controller."
    Exit
}

# --- STEP 3: Load and Read the CSV File ---
if (-Not (Test-Path $CSVPath)) {
    Write-Warning "[ERROR] The CSV file was not found at: $CSVPath"
    Exit
}

$Employees = Import-Csv -Path $CSVPath
Write-Host "[INFO] Successfully loaded $($Employees.Count) employees from CSV." -ForegroundColor Cyan

# --- STEP 4: Process Each Employee (Loop) ---
foreach ($Employee in $Employees) {
    # Clean up trailing spaces from the CSV data
    $FirstName  = $Employee.FirstName.Trim()
    $LastName   = $Employee.LastName.Trim()
    $Department = $Employee.Department.Trim()
    $Title      = $Employee.Title.Trim()
    $Office     = $Employee.Office.Trim()

    # Generate a unique sAMAccountName (Format: firstname.lastname)
    $sAMAccountName = "$FirstName.$LastName".ToLower()
    
    # Define the exact OU path for this department
    $TargetOU = "OU=$Department,$BaseOU"

    # 4a. Check if the Department OU exists. If not, create it dynamically.
    if (-Not (Get-ADOrganizationalUnit -Filter "Name -eq '$Department'" -SearchBase $BaseOU -ErrorAction SilentlyContinue)) {
        Write-Host "[ACTION] Department OU '$Department' not found. Creating it..." -ForegroundColor Yellow
        New-ADOrganizationalUnit -Name $Department -Path $BaseOU -ProtectedFromAccidentalDeletion $false
    }

    # 4b. Idempotency Check: Does the user already exist?
    $ExistingUser = Get-ADUser -Filter {sAMAccountName -eq $sAMAccountName} -ErrorAction SilentlyContinue

    if ($ExistingUser) {
        # Skip to prevent system execution errors
        Write-Host "[SKIP] User $sAMAccountName already exists. Skipping creation." -ForegroundColor DarkGray
    } else {
        # 4c. Create the new User
        Write-Host "[ACTION] Provisioning new user account: $sAMAccountName" -ForegroundColor Green
        
        # Generate and convert unique secure credentials
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

        # Display transient provisioning credential for administrative Handover
        Write-Host "[CREDENTIAL] Temporary password for $sAMAccountName: $PlainPassword" -ForegroundColor Yellow
    }
}

Write-Host "`n[SUCCESS] Corporate Onboarding Script completed." -ForegroundColor Green