# Automated Corporate Onboarding System for Windows Server 2022

An automated, production-ready PowerShell solution designed to streamline user onboarding in Active Directory environments. This script dynamically provisions organizational structures and user accounts directly from corporate CSV data, applying industry-standard security and architectural practices.

---

## 🚀 Project Overview & Business Value

In traditional IT environments, creating user accounts and managing organizational structures manually is slow and prone to errors. This project solves that problem by introducing an automated pipeline. 

### Key Features:
* **Dynamic OU Creation:** The script inspects the Active Directory structure and automatically creates missing Department Organizational Units (OUs) on the fly.
* **Strict Idempotency:** It can run multiple times without generating errors or duplicating accounts. If a user already exists, the script safely skips them.
* **Standardized Identity Management:** Automatically generates unique usernames (`firstname.lastname`) and configures core AD attributes (`Title`, `Office`, `UPN`).
* **Enhanced Security:** Assigns a temporary password and enforces the standard policy: **"User must change password at next logon"**.

---

## 🛠️ Tech Stack & Requirements

* **Operating System:** Windows Server 2022 (Tested on Server Core)
* **Automation Engine:** PowerShell 5.1 / PowerShell 7
* **Modules:** Official Microsoft `ActiveDirectory` module
* **Data Format:** Standard CSV (Comma-Separated Values)

---

## 📁 Repository Structure

* `create-users.ps1`: The core automation script containing error handling and provisioning logic.
* `employees-template.csv`: The data template used by Human Resources or IT to list new hires.
* `README.md`: Project documentation and architecture guide.

---

## 🔧 How to Use

1. Clone this repository to your management machine or Domain Controller:
   ```bash
   git clone [https://github.com/ricardolealpi/windows-server-automation.git](https://github.com/ricardolealpi/windows-server-automation.git)
   ```