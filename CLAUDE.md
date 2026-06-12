# Project Context for Claude Code

## Repository
windows-endpoint-security-patterns
Endpoint security automation patterns for hybrid Entra ID
and cloud-managed Windows environments.

## Purpose
Portfolio repository demonstrating enterprise endpoint 
security engineering at both practitioner and architect 
level. Target roles: Endpoint Security Architect, 
Digital Workspace Architect, Infrastructure Security.

## Session Start Protocol
When starting a new session, ask which pattern or task 
we are working on before doing anything else.
Do not make file changes without confirming first.
Work one file at a time and show output before writing.

## Document Structure — Option B
Each pattern README has four clearly labelled sections:

1. Strategic Overview
   Audience: security architects, IT leadership, CISOs
   Content: problem context, risk, compliance 
   implications, recommendation statement

2. Architecture & Design
   Audience: architects and senior engineers
   Content: diagrams, components, design principles,
   trade-offs, alternatives considered

3. Implementation Reference
   Audience: engineers deploying the solution
   Content: scripts, configuration, validation steps,
   environment requirements

4. Operational Guidance
   Audience: operations and support teams
   Content: monitoring, failure modes, renewal,
   maintenance, dependencies

Each README starts with a navigation block linking
to all four sections.

## Patterns Status
- [x] Pattern 01 BTG Escrow — Option B restructure
- [x] Pattern 01 BTG Escrow — fine-tuning fixes (portal paths, cross-references, repository table)
- [ ] Pattern 02 Sysmon Registry — Option B retrofit
- [ ] Pattern 03 WICD Provisioning — Option B retrofit
- [x] Pattern 04 SCEP Internal NDES — create from scratch
- [x] Pattern 04 SCEP diagram — ZTNA session terminology, colour coding, PKI trust chain
- [ ] Root README updated for all four patterns
- [ ] Whitepaper 01 BTG — markdown + PDF
- [ ] Whitepaper 02 SCEP — markdown + PDF
- [ ] GitHub Releases for both whitepapers
- [ ] LinkedIn article published

## Code Standards
- All scripts use [CmdletBinding()]
- Structured logging to C:\ProgramData\BitLocker\Logs\
- try/catch/finally on all execution paths
- exit 0 / exit 1 not bare return at script scope
- PSScriptAnalyzer clean at Error severity
- Event log channel: Microsoft-Windows-BitLocker-API/Management

## Known Bugs Still to Fix
- ~~Task XML: event channel name wrong~~
  ~~(Microsoft-Windows-BitLocker/BitLocker Management~~
  ~~should be Microsoft-Windows-BitLocker-API/Management)~~ FIXED
- ~~GitHub Actions workflow location: must be at root~~
  ~~.github/workflows/ not inside pattern folder~~ FIXED
- ~~schtasks.exe needs $LASTEXITCODE check in installer~~ FIXED

## Last Updated
2026-06-11

## Current Session Focus
Patterns 01 and 04 complete — next session: Pattern 02 and 03 Option B retrofits
