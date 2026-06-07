# windows-endpoint-security-patterns

A collection of endpoint security automation patterns and design explorations
for modern, cloud-managed and hybrid Windows environments.

This repository serves as a workspace for documenting real-world security
control gaps encountered during endpoint modernization, along with
event-driven and operationally practical approaches used to address them.

The focus is not on turnkey tooling, but on **patterns, behavior, and design
decisions** that emerge in complex enterprise environments.

---

## Documented Patterns

### Hybrid Entra ID – BitLocker-to-Go Key Escrow

**Folder:** `patterns/hybrid-entra-btg-key-escrow-pattern`

Documents an event-driven approach to handling BitLocker-to-Go recovery key
escrow failures on Hybrid Entra ID joined Windows devices, where native
Intune and policy-based behavior may be inconsistent.

**Key concepts explored:**
- Observing BitLocker API failure events (Event ID 846)
- Event-triggered remediation via scheduled tasks
- Programmatic recovery key identification via `manage-bde` and PowerShell
- Retrying escrow without relying on end-user action

---

### Registry-Based Sysmon Configuration Deployment

**Folder:** `patterns/sysmon-configuration-via-native-policy`

Provides a method to **deploy and update Sysmon configurations** centrally using
registry-backed policies, removing the need for repeated package deployments.

**High-Level Approach:**

```text
       +---------------------------+
       | Validated Sysmon XML      |
       | configuration imported on |
       | reference system          |
       +------------+--------------+
                    |
                    v
       +---------------------------+
       | Registry value extracted  |
       | from:                     |
       | HKLM\SYSTEM\...\Rules     |
       +------------+--------------+
                    |
                    v
       +---------------------------+
       | Policy object created     |
       | with binary registry      |
       | value (GPO / Policy)      |
       +------------+--------------+
                    |
                    v
       +---------------------------+
       | Target systems receive    |
       | configuration via policy  |
       | refresh cycles            |
       +---------------------------+
```

## Benefits
- Centralized, repeatable deployment of Sysmon rules
- Eliminates reliance on package-based delivery
- Works at scale across endpoints

## Considerations
- Large configurations may slow policy refresh cycles
- Only tested configurations should be applied to avoid unintended behavior

---

### Serverless Windows Provisioning Using WICD

**Folder:** `patterns/serverless-windows-provisioning-wicd`

Documents a **serverless, infrastructure-free Windows provisioning pattern**
using Windows Imaging and Configuration Designer (WICD).

This pattern is intentionally scoped for scenarios where modern provisioning
platforms (e.g. Autopilot + Intune) are unavailable, unnecessary, or
intentionally avoided.

**Typical use cases include:**
- Small offices with a limited number of workstations
- Training labs or classroom environments
- Temporary or disposable devices
- Offline or restricted-network deployments
- Workgroup-based systems requiring baseline security and configuration

The approach focuses on **cost-free provisioning**, minimal dependencies,
and predictable outcomes using native Windows tooling only.

**Key concepts explored:**
- Serverless OS provisioning without imaging infrastructure
- Use of provisioning packages (`.ppkg`) for configuration and app setup
- Security-first provisioning (BitLocker, baseline hardening)
- User-driven setup without persistent management services
- Clear boundaries where modern cloud provisioning *does* and *does not* apply

This pattern is not presented as a replacement for Autopilot, but as a
**complementary design option** for constrained or transitional environments.

---

## Repository Philosophy
- Focus on **design patterns**, not just scripts
- Prefer **event-driven automation** over polling
- Assume **enterprise constraints** (change control, audits, limited agents)
- Avoid embedding tenant-specific or sensitive information

## Disclaimer
All content in this repository is provided as reference material and design guidance.
While every effort has been made to ensure accuracy, implementations may require
adaptation based on environment, configuration, and operational requirements.

Scripts and configurations are provided **as-is**. They may not work in all environments,
and you should validate behavior in a controlled test environment before production use.
