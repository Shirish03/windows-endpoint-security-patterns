# Windows Endpoint Security Patterns

[![PowerShell Validation](https://github.com/Shirish03/windows-endpoint-security-patterns/actions/workflows/powershell-validation.yml/badge.svg)](https://github.com/Shirish03/windows-endpoint-security-patterns/actions/workflows/powershell-validation.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Platform: Windows 10/11](https://img.shields.io/badge/Platform-Windows%2010%2F11-0078D4?logo=windows)
![Environment: Hybrid Entra ID](https://img.shields.io/badge/Environment-Hybrid%20Entra%20ID-5C2D91?logo=microsoftazure)

A practitioner's reference for endpoint security automation in hybrid Entra ID
and cloud-managed Windows environments.

## Why This Exists

During enterprise endpoint modernization, several security controls that worked
reliably in on-premises AD environments either broke silently or had no supported
equivalent in Hybrid Entra ID and Intune-managed configurations. BitLocker-to-Go
recovery key escrow was one such control — policy was correctly configured, no
errors surfaced in Intune, and failures were only visible if you knew which
Windows event log to watch. This repository documents those gaps and the
event-driven, operationally practical approaches used to close them without
introducing new infrastructure or weakening the platform's security model.

## Who This Is For

Endpoint engineers, SecOps practitioners, and Intune/Entra administrators
operating in hybrid or transitional Windows environments — where devices are
Entra joined but not fully cloud-native, where Group Policy and Intune coexist,
and where the answer to a security gap is not always "wait for a platform update."

## Patterns

| # | Pattern | Problem Solved | Environment |
|---|---------|----------------|-------------|
| 01 | [BitLocker-to-Go Key Escrow](patterns/hybrid-entra-btg-key-escrow-pattern) | Native escrow fails silently on Hybrid Entra joined devices | Hybrid Entra ID + Intune |
| 02 | [Sysmon Registry Deployment](patterns/sysmon-configuration-via-native-policy) | Avoid repeated binary redeployment for config-only updates | GPO / Policy-managed |
| 03 | [Serverless Windows Provisioning](patterns/serverless-windows-provisioning-wicd) | Provision securely without Autopilot or imaging infrastructure | SMB / Offline / Labs |

## Engineering Philosophy

- **Event-driven over polling.** Platform signals — Windows event logs, API
  failure codes, observable state changes — are the trigger point. Scripts run
  in response to verified conditions, not on a schedule.
- **Patterns and design decisions over turnkey scripts.** Each entry documents
  why a particular approach was taken, what platform behavior it relies on, and
  what the operational trade-offs are. The scripts illustrate the pattern; they
  are not the point.
- **Enterprise constraints are the baseline assumption.** Change control,
  limited endpoint agents, audit requirements, and coexistence between Group
  Policy and Intune are treated as constants, not edge cases.

## Environment Assumptions

These patterns were developed and validated against:

- Windows 10 22H2 and Windows 11
- Hybrid Entra ID joined devices (on-premises AD + Entra ID)
- Intune-managed, with co-management or standalone Intune policy
- PowerShell 5.1+ (scripts do not require PowerShell 7)
- Group Policy infrastructure present (required for the Sysmon pattern)

Patterns may apply in broader configurations but have not been validated
outside this context.

## Using This Repository

Each pattern lives in its own folder under `patterns/` and is self-contained:

- **README.md** — background, problem statement, and solution overview
- **docs/** — detailed architecture and design documentation
- **scripts/** — PowerShell implementation where applicable
- **examples/** — sanitized samples and illustrative output where applicable

Start with the pattern README to understand the design context before reading
the scripts. Each implementation will require adaptation — environment-specific
paths, policy targeting, and validation in a controlled environment before
production use.
