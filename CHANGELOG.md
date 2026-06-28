# Changelog

All notable changes to this repository are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

---

## [0.7.0] - 2026-06-28

### Fixed
- Event log channel name corrected across BTG escrow script, both task XML
  files, and supporting documentation: `Microsoft-Windows-BitLocker-API/Management`
  → `Microsoft-Windows-BitLocker/BitLocker Management`, confirmed via live
  device testing (raw event XML and wevtutil both identify the correct channel)
- BTG escrow script (v1.2): exit-code handling defects resolved. `return`
  statements bypassed standalone `exit $ExitCode`; outer and inner catch blocks
  did not set `$ExitCode = 1`; drive letter extraction failure branch was also
  missing `$ExitCode = 1`; script effectively always exited 0 regardless of outcome
- Installer (Install-BTGRecoveryKeyEscrow.ps1): elevation check added before all
  operations; `Unregister-ScheduledTask` wrapped in `try/catch` for consistent
  error handling
- Event ID 846 severity corrected to Error-level in event-id-846-sample.md and
  BTG pattern README; corrected explanation applied: Error-level but logged to the
  `Microsoft-Windows-BitLocker/BitLocker Management` channel that most default
  SIEM and monitoring configurations do not watch. Channel placement, not severity,
  explains why it is easy to miss

### Changed
- Mermaid flowchart in BTG pattern README replaced with polished flowchart image
  (btg-dual-destination-flow.png)

### Added
- Dual-destination escrow and RBAC section added to BTG pattern README
  (Architecture & Design) and architecture-flow.md: documents Active Directory
  and Entra ID as separate escrow destinations for Hybrid Entra ID joined devices,
  Active Directory's limitation for removable drives (no drive-type labeling), and
  Entra ID's drive-type labeling and RBAC delegation for helpdesk recovery access
  without broader AD permissions
- Screenshots embedded in BTG pattern README illustrating Active Directory's
  unlabeled recovery password view and Entra ID's drive-type-labeled recovery key
  view (btg-ad-recovery-no-drive-type.png, btg-entra-id-recovery-drive-type.png)

---

## [0.6.0] - 2026-06-20

### Changed
- Whitepaper v1.1: macOS scope correction — Executive Summary, Section 1,
  and Section 6 updated to explicitly state macOS as always Entra ID Join
  Only when managed through Intune, as macOS has no Windows-style Hybrid
  Entra ID Join equivalent
- Whitepaper v1.2: device scope phrasing correction — consistent parallel
  phrasing for both target device populations (Intune-managed Windows
  devices that are Entra ID Join Only, and macOS devices) applied across
  Executive Summary, Section 1, and Section 6; Hybrid Entra ID joined
  Windows explicitly identified as out of scope, as it uses ADCS
  auto-enrollment via Group Policy or SCCM; whitepaper markdown in repo
  renamed from v1.0 to v1.2
- Pattern 04 README: title updated from "(Hybrid Entra ID)" to "(Entra ID
  Join Only)"; Environment Requirements device management row corrected to
  "Entra ID Join Only"; disclaimer updated to match corrected scope

### Added
- Pattern 04 README: implementation note on SAN configuration and strong
  certificate mapping for Entra ID Join Only Windows devices and macOS —
  explains why `{{OnPremisesSecurityIdentifier}}` does not resolve without
  an on-premises AD computer object, references KB5014754 strong mapping
  enforcement on domain controllers, documents the `X509IssuerSerialNumber`
  / `altSecurityIdentities` requirement for on-premises certificate-based
  authentication, and requires a separate SCEP profile from any Hybrid
  Entra ID joined Windows profile

---

## [0.5.0] - 2026-06-19

### Added
- CONTRIBUTING.md
- CHANGELOG.md
- Finalized SCEP NDES architecture diagram (PNG) replacing earlier draft Mermaid version across pattern README, architecture-flow.md, and whitepaper
- Two-gate security model documented: Intune policy gate and internal DNS alias network gate, across pattern README, architecture-flow.md, and whitepaper markdown
- ZTNA hop breakdown (steps 2a/2b/2c) and Domain Controller Kerberos/LDAP steps (5/7) added to architecture-flow.md
- Component tables expanded to include Microsoft Entra ID, ZTNA broker, App Connector, Domain Controller, and Root CA
- GitHub Releases published for whitepaper-btg-v1.0 and whitepaper-scep-v1.0
- Root README.md download links updated to point to GitHub Release assets for both whitepapers

### Fixed
- Root README.md Published Reference Architectures table: removed dead GitHub Release link

---

## [0.4.0] - 2026-06-14

### Changed
- All four pattern READMEs restructured to Option B four-layer format
- Strategic Overview and Operational Guidance added to all patterns
- Em dashes replaced with appropriate punctuation across all documentation

### Added
- Pattern 04: SCEP certificate enrollment via internal NDES
- Simplified architecture diagrams for all patterns
- ZTNA terminology corrected across Pattern 04 (broker-mediated session, not tunnel)

---

## [0.3.0] - 2026-06-12

### Added
- GitHub Actions PSScriptAnalyzer workflow

### Fixed
- Workflow moved to correct root location
- Task XML event channel name corrected
- Task execution timeout reduced to PT5M

---

## [0.2.0] - 2026-06-07

### Added
- CmdletBinding, exit codes, recency guard in BTG scripts
- Evidence artifacts: event-id-846-sample.md, sample-event.json
- Architecture flow documentation

---

## [0.1.0] - 2026-01-24

### Added
- Initial three patterns
