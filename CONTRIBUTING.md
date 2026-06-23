# Contributing

This is a solo practitioner portfolio demonstrating endpoint security
patterns from real-world environments. It is not a maintained open source
project; there is no roadmap, no issue SLA, and no guarantee of response
time. That said, practical contributions grounded in real environment
experience are welcome.

## Reporting that a pattern did not work

This is the most valuable contribution. If you tried a pattern and it
behaved differently in your environment, open an issue and include:

- Windows version and build number
- Entra join type (Hybrid Entra ID joined, Entra ID joined, or Entra registered)
- Intune management state (co-managed, standalone, or unmanaged)
- What you expected to happen and what actually happened

Vague reports are not actionable. Specific ones are.

## Suggesting a new pattern

Open an issue describing:

- The security control gap or operational problem it addresses
- The environment it applies to (OS version, management platform)
- Whether you have validated the approach, and in what context

Pattern suggestions without a clear problem statement will not be prioritised.

## Code standards for script contributions

- `[CmdletBinding()]` on all scripts
- Structured logging to a consistent path; no `Write-Host` as the sole output
- `exit 0` / `exit 1` instead of bare `return` at script scope
- `try/catch/finally` wrapping all execution paths
- PSScriptAnalyzer clean at Error severity
- No hardcoded tenant identifiers, device names, or environment-specific paths

## Documentation standard

Each pattern should include a clear problem statement (what breaks and why
it breaks silently), design rationale, environment requirements, and a
validation disclaimer noting where the approach has and has not been tested.
