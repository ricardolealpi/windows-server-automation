# Windows Server & Enterprise Automation Portfolio

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![Platform](https://img.shields.io/badge/Platform-Windows%20Server%202022-0078D4?logo=windows)
![Active Directory](https://img.shields.io/badge/Active%20Directory-Hybrid%20Identity-0078D4?logo=microsoft)
![Status](https://img.shields.io/badge/Status-Active-brightgreen)

Production-ready automation scripts for Windows Server and Active Directory environments, built as part of my infrastructure portfolio. Each project targets real-world enterprise scenarios — identity management, systems administration, and hybrid cloud integration — on the path toward Azure Cloud Architecture.

---

## 📂 Projects

| Project | Description | Stack |
|---|---|---|
| [Active Directory Corporate Onboarding](./active-directory-onboarding) | Bulk user provisioning from CSV with idempotency, secure password generation, dynamic OU creation, and persistent audit logging | PowerShell · AD DS · Windows Server 2022 |

> More scripts being added regularly. Each one targets a real sysadmin scenario with production-grade error handling and documentation.

---

## 🧰 Tech Stack

- **Automation:** PowerShell 5.1 / 7
- **Directory Services:** Active Directory Domain Services (AD DS)
- **Cloud Bridge:** Microsoft Entra ID (Azure AD), Entra Connect
- **Infrastructure:** Windows Server 2022 Core, VMware Fusion
- **Management:** RSAT, Group Policy, DNS, DHCP

---

## 🎯 Roadmap

Upcoming projects planned for this repository:

- `ad-account-audit/` — Report on stale accounts, never-expiring passwords, and inactive users
- `disk-space-report/` — Multi-server disk usage report exported to HTML/CSV via CIM
- `gpo-backup/` — Automated Group Policy Object backup with timestamped versioning
- `entra-id-provisioning/` — Cloud-native user provisioning via Microsoft Graph API (PS module)

---

<details>
<summary>🌐 <b>Versión en Español</b></summary>
<br>

# Portafolio de Automatización de Windows Server y Entornos Empresariales

Scripts de automatización listos para producción en entornos de Windows Server y Active Directory, desarrollados como parte de mi portafolio de infraestructura. Cada proyecto aborda escenarios empresariales reales — gestión de identidades, administración de sistemas e integración con la nube híbrida — en el camino hacia la Arquitectura Cloud en Azure.

---

## 📂 Proyectos

| Proyecto | Descripción | Stack |
|---|---|---|
| [Incorporación Corporativa en Active Directory](./active-directory-onboarding) | Aprovisionamiento masivo de usuarios desde CSV con idempotencia, generación segura de contraseñas, creación dinámica de OUs y registro de auditoría persistente | PowerShell · AD DS · Windows Server 2022 |

---

## 🧰 Stack Tecnológico

- **Automatización:** PowerShell 5.1 / 7
- **Servicios de Directorio:** Active Directory Domain Services (AD DS)
- **Puente a la Nube:** Microsoft Entra ID (Azure AD), Entra Connect
- **Infraestructura:** Windows Server 2022 Core, VMware Fusion
- **Gestión:** RSAT, Group Policy, DNS, DHCP

---

## 🎯 Hoja de Ruta

Próximos proyectos planificados para este repositorio:

- `ad-account-audit/` — Reporte de cuentas inactivas, contraseñas que nunca caducan y usuarios obsoletos
- `disk-space-report/` — Reporte de espacio en disco en múltiples servidores exportado a HTML/CSV vía CIM
- `gpo-backup/` — Backup automatizado de objetos de directiva de grupo con versionado por timestamp
- `entra-id-provisioning/` — Aprovisionamiento nativo en la nube mediante Microsoft Graph API (módulo PS)

</details>

---

*Maintained by Ricardo Leal — Senior Systems Administrator | Cloud & Hybrid Infrastructure | Azure · AD DS · PowerShell · ITIL*