# Automated Corporate Onboarding System for Windows Server 2022

An automated, production-ready PowerShell solution designed to streamline user onboarding in Active Directory environments. This script dynamically provisions organizational structures and user accounts directly from corporate CSV data, applying industry-standard security and architectural practices.

---

## 🚀 Project Overview & Business Value

In traditional IT environments, creating user accounts and managing organizational structures manually is slow and prone to errors. This project solves that problem by introducing an automated pipeline. 

### Key Features:
* **Dynamic OU Creation:** The script inspects the Active Directory structure and automatically creates missing Department Organizational Units (OUs) on the fly.
* **Strict Idempotency:** It can run multiple times without generating errors or duplicating accounts. If a user already exists, the script safely skips them.
* **Standardized Identity Management:** Automatically generates unique usernames (`firstname.lastname`) and configures core AD attributes (`Title`, `Office`, `UPN`).
* **Enhanced Security (Zero Hardcoding):** Dynamically generates a unique, cryptographically secure 16-character temporary password for each user in real-time, completely removing hardcoded credentials from the source code. It also enforces the standard policy: **"User must change password at next logon"**.

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

   ---

# Sistema de Incorporación Corporativa Automatizada para Windows Server 2022

Una solución automatizada en PowerShell diseñada para optimizar el aprovisionamiento de usuarios en entornos de Active Directory. Este script gestiona dinámicamente estructuras organizativas y cuentas de usuario a partir de datos en formato CSV, aplicando estándares de seguridad y buenas prácticas de arquitectura de sistemas.

## 🚀 Descripción General y Valor de Negocio

En entornos de IT tradicionales, la creación manual de cuentas y la gestión de estructuras de departamentos es un proceso lento y propenso a errores de transcripción. Este proyecto resuelve ese problema introduciendo un flujo de trabajo automatizado.

### Características Clave:
* **Creación Dinámica de OUs:** El script inspecciona la estructura de Active Directory y crea automáticamente las Unidades Organizativas (OUs) de los departamentos faltantes sobre la marcha.
* **Idempotencia Estricta:** Puede ejecutarse múltiples veces consecutivas sin generar errores en el servidor ni duplicar cuentas. Si un usuario ya existe, el script lo salta de forma segura.
* **Gestión de Identidad Estandarizada:** Genera automáticamente nombres de usuario únicos con el formato `nombre.apellido` y configura atributos esenciales de AD (`Puesto`, `Oficina`, `UPN`).
* **Seguridad Reforzada (Sin Credenciales Expuestas):** Genera dinámicamente una contraseña temporal única y criptográficamente segura de 16 caracteres para cada usuario en tiempo de ejecución, eliminando por completo las contraseñas escritas en texto plano dentro del código fuente. Aplica la directiva estándar: **"El usuario debe cambiar la contraseña en el próximo inicio de sesión"**.

## 🛠️ Tecnologías y Requisitos

* **Sistema Operativo:** Windows Server 2022 (Probado en versión Server Core)
* **Motor de Automatización:** PowerShell 5.1 / PowerShell 7
* **Módulos:** Módulo oficial de Microsoft `ActiveDirectory`
* **Formato de Datos:** CSV estándar (valores separados por comas)

## 🧠 Perspectiva de Arquitectura (Contexto para el Portafolio)

Este proyecto demuestra competencias clave requeridas en la administración de sistemas moderna y la **Arquitectura de Nube Híbrida**:
1. **Ausencia de Hardcoding:** Las raíces del dominio y las rutas de datos están completamente parametrizadas utilizando variables de entorno como `$PSScriptRoot`.
2. **Programación Defensiva:** Implementa bloques `Try/Catch` para verificar la disponibilidad del módulo de Active Directory antes de la ejecución, deteniendo el proceso limpiamente si faltan requisitos.
3. **El Puente hacia la Nube:** Dominar la automatización de identidades en Active Directory local es el requisito fundamental para la posterior sincronización de estructuras hacia la nube mediante Microsoft Entra Connect (Azure AD Connect).