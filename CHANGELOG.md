# Changelog

All notable changes to this repository are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

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
