# Changelog

All notable changes to this repository are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

### Added
- Mermaid diagrams for all three patterns replacing ASCII art
- Decision matrix for WICD pattern (When to Use This Pattern section)
- CLAUDE.md project context and session protocol
- Pester 5 test suite for BTG escrow retry script
- README badges for lint status and license
- `docs/why-patterns-not-scripts.md` engineering philosophy essay
- `Export-SysmonRegistryConfig.ps1` helper script: extracts compiled Sysmon config
  from registry as a `.reg` deployment artifact with SHA-256 hash and GPO field values

### Fixed
- GitHub Actions workflow moved to correct root `.github/workflows/` location
- PSScriptAnalyzer workflow corrected: installs module before use, filters by severity
- Scheduled task XML event channel corrected to `Microsoft-Windows-BitLocker-API/Management`
- Task execution timeout reduced from PT72H to PT5M
- BTG README and architecture-flow: removed `manage-bde` references (script uses
  `Get-BitLockerVolume` only); added `tests/` to Repository Contents
- BTG architecture-flow: rewrote Architectural Takeaway to close on design decisions
- BTG examples: corrected "simplified" to "annotated example" in task-explained.md;
  standardised TracId GUID placeholder to `xxxxxxxx` format in sample-event.json
- BTG tests: fixed flaky recency-guard boundary test (`-gt 10` not `-ge 10`);
  updated context description to "more than 10 minutes old"
- Sysmon docs restructured: removed content duplicated from README, added script
  usage examples and GPO deployment field values table
- WICD README: replaced "Why This Project Exists" with "Background", folded
  "Core Challenge" section into prose, added Disclaimer
- WICD docs restructured: removed academic scaffolding and README-duplicated sections;
  added per-component `.ppkg` runtime behavior descriptions
- Root README: pattern environment labels corrected; `tests/` added to folder list
- CONTRIBUTING: `try/catch/finally` added to code standards; fixed British spellings
- Terminology: "Hybrid Entra joined" → "Hybrid Entra ID joined" throughout

---

## [0.2.0] - 2026-06-07

### Added
- `[CmdletBinding()]` and `param()` to BTG escrow retry script
- Recency guard: events older than 10 minutes are skipped to prevent acting on stale data
- Structured logging in installer script with dedicated `Install.log`
- Event ID 846 reference documentation (`event-id-846-sample.md`) with XML view,
  message view, field extraction annotation, and normal-vs-failure comparison
- Root README rewritten with engineering philosophy, pattern index table,
  environment assumptions, and navigation guide

### Fixed
- Event log channel corrected from non-existent `Microsoft-Windows-BitLocker/BitLocker Management`
  to `Microsoft-Windows-BitLocker-API/Management` in both the script and task XML
- Bare `return` statements replaced with explicit `exit 0` / `exit 1` for scheduled task monitoring
- `$LASTEXITCODE` check added after `schtasks.exe` in installer
- `Copy-Item` wrapped in `try/catch` in installer
- Redundant second `Test-Path` check removed from installer
- Sysmon pattern README expanded from a single implementation note to full pattern documentation
- WICD provisioning flow broken screenshot placeholder removed
- Root README title and sysmon folder reference corrected after repository rename

---

## [0.1.0] - 2026-01-24

### Added
- Initial three patterns: BTG escrow, Sysmon registry deployment, WICD provisioning
- BTG pattern: PowerShell escrow retry script, installer, event-triggered scheduled task XML
- BTG pattern: architecture flow documentation and sanitized example artifacts
- Sysmon pattern: registry-based configuration deployment documentation
- WICD pattern: serverless provisioning flow documentation
- Root README with engineering philosophy and environment assumptions
- MIT license
