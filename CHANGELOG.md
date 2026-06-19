# Changelog

All notable changes to this repository are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

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
