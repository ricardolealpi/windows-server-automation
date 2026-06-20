# ==============================================================================
# Script Name: create-users.ps1
# Description: Automated Corporate Onboarding System for Windows Server 2022, 2019, 2016, and 2012 R2 Active Directory environments. This script reads employee data from a CSV file and creates corresponding user accounts in Active Directory.
# Author: Ricardo Leal
# ==============================================================================

# --- STEP 1: Define Parameters and Paths ---
# We need to tell the script where the CSV file is located.

# --- STEP 2: Import Active Directory Module ---
# Ensure the server has the Active Directory tools loaded.

# --- STEP 3: Load and Read the CSV File ---
# Read the employee data row by row.

# --- STEP 4: Process Each Employee (Loop) ---
# For each employee in the CSV:
#  a. Check if the Department OU exists. If not, create it.
#  b. Generate a secure, unique sAMAccountName (username).
#  c. Check if the user already exists (Idempotency).
#  d. Create the new AD User with properties (Title, Office, Email).