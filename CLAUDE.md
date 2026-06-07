# Project Context for Claude Code

## Repository
windows-endpoint-security-patterns
Endpoint security automation patterns for hybrid Entra ID
and cloud-managed Windows environments.

## Purpose
Portfolio repository demonstrating real-world endpoint security
engineering judgment. Target roles: Endpoint Security Engineer,
Intune/Entra specialist, Infrastructure Security Engineer.

## Session Start Protocol
When starting a new session, ask which pattern or task we are
working on before doing anything else. Do not make file changes
without confirming first.

## Completed
- [x] Repository renamed from redesigned-adventure
- [x] Root README rewritten — professional, philosophy-driven
- [x] BTG pattern scripts updated:
      [CmdletBinding()], exit codes, recency guard, log name fix,
      $LASTEXITCODE check, Copy-Item try/catch, Install logging
- [x] Evidence artifacts added (event-id-846-sample.md, sample-event.json)
- [x] Architecture flow documentation (architecture-flow.md)
- [x] GitHub Actions workflow moved to correct location (root .github/)
- [x] PSScriptAnalyzer workflow fixed (install step, severity filtering)
- [x] Task XML event channel corrected to BitLocker-API/Management
- [x] Task XML execution timeout reduced from PT72H to PT5M
- [x] All pattern diagrams updated to Mermaid
- [x] Pattern 03 README duplicate H1 removed
- [x] Decision matrix added to Pattern 03 README
- [x] Pester 5 test suite for BTG escrow retry script

## Pending
- [x] CHANGELOG.md
- [x] CONTRIBUTING.md
- [x] docs/why-patterns-not-scripts.md (engineering philosophy essay)
- [ ] Pattern 02: extract PowerShell helper script for registry extraction
- [ ] GitHub repo topics set (via GitHub UI, not code)
- [x] README badges (lint status, license)
- [x] Sample XML in examples/ populated with real structure

## Code Standards
- All scripts use [CmdletBinding()]
- Structured logging to C:\ProgramData\BitLocker\Logs\
- try/catch/finally on all execution paths
- exit 0 / exit 1 instead of bare return at script scope
- PSScriptAnalyzer clean at Error severity
- Event log channel: Microsoft-Windows-BitLocker-API/Management

## Last Updated
2026-06-07

## Current Focus
[update at start of each session]
