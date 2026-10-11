# Windows Endpoint Security Patterns

[![PowerShell Validation](https://github.com/Shirish03/windows-endpoint-security-patterns/actions/workflows/powershell-validation.yml/badge.svg)](https://github.com/Shirish03/windows-endpoint-security-patterns/actions/workflows/powershell-validation.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Platform: Windows 10/11](https://img.shields.io/badge/Platform-Windows%2010%2F11-0078D4?logo=windows)
![Environment: Hybrid Entra ID](https://img.shields.io/badge/Environment-Hybrid%20Entra%20ID-5C2D91?logo=microsoftazure)

Notes from real Windows endpoint security work, written up as patterns. Each one starts with something that broke, went quiet, or had no answer in the standard tooling, and shows how I closed the gap across on-premises Group Policy, Hybrid Entra ID, and Intune. A few cover places where no tooling existed yet and a governed baseline had to be built from scratch.

By Shirish Mistry · Associate Principal, Endpoint Security & Architecture · [LinkedIn](https://www.linkedin.com/in/shirish1)

## Why this exists

Security controls that work fine under one management model often have no clean equivalent under another. You usually find that out in the middle of a modernization project, not before it.

The first pattern in this repo came from exactly that. BitLocker-to-Go recovery keys were supposed to escrow to Entra ID. The policy was correct and Intune reported no errors, yet the Entra ID half of the escrow was failing, and the only place it showed was a Windows event log you had to know to open.

The same kind of gap turns up from other directions. Controls built for Group Policy still have to coexist with Intune. Some environments have no Autopilot and no imaging infrastructure at all. Each pattern here documents one of these gaps and the approach I used to close it, without adding new infrastructure or weakening the platform's security model.

Pattern 06 applies the same thinking to replacing a tool. It covers moving from standalone Sysmon to the version built into Windows 11, in a way that doesn't leave machines unmonitored without anyone noticing.

## Who this is for

If you're an endpoint engineer, SecOps practitioner, or Intune/Entra admin working in a hybrid or in-between Windows environment, this is written for you. That usually means devices that are Entra ID joined but not fully cloud-native, Group Policy and Intune running side by side, and a security gap that won't wait for the next platform update.

## Patterns

| # | Pattern | Problem Solved | Environment |
|---|---------|----------------|-------------|
| 01 | [BitLocker-to-Go Key Escrow](patterns/hybrid-entra-btg-key-escrow-pattern) | Entra ID half of dual-destination escrow fails silently on Hybrid Entra ID joined devices | Hybrid Entra ID + Intune |
| 02 | [Sysmon Registry Deployment](patterns/sysmon-configuration-via-native-policy) | Avoid repeated binary redeployment for config-only updates | GPO / Policy-managed |
| 03 | [Serverless Windows Provisioning](patterns/serverless-windows-provisioning-wicd) | No governed provisioning path exists without Autopilot or imaging infrastructure, so baseline security configuration is left inconsistent | Offline / No infrastructure |
| 04 | [SCEP Certificate Enrollment via Internal NDES](patterns/scep-certificate-enrollment-internal-ndes) | SCEP certificate enrollment for cloud-native Windows & macOS devices, without exposing internal PKI and without relying on `{{OnPremisesSecurityIdentifier}}`, which does not resolve once KB5014754 strong-mapping enforcement is in effect and the device has no on-premises AD computer object | Entra ID Join Only (Windows & macOS) + Intune + Internal PKI + ZTNA/VPN |
| 05 | [Windows Event Forwarding: Categorized Collection](patterns/windows-event-forwarding-categorized-collection) | Mixed-category security, Sysmon, Defender, and firewall events crowd a single forwarded-events channel, complicating SIEM ingestion and scaling | GPO / Policy-managed |
| 06 | [Migrating Standalone Sysmon to Native Windows Sysmon](patterns/sysmon-migration-standalone-to-native) | Gated cutover from Sysinternals Sysmon to the Windows 11 native optional feature, with no monitoring gap that goes unnoticed | Windows 11 24H2+ / Server 2025, packaged for endpoint deployment |

Every pattern is written in four layers, so you can stop reading at the depth you need. The Strategic Overview gives risk context and a recommendation for architects and leadership. Architecture & Design explains the technical model and why it was built that way. The Implementation Reference has configuration details and deployment guidance for engineers. Operational Guidance covers monitoring, failure modes, and upkeep for the people running it.

## The thinking behind each pattern

Each pattern started from a technical situation where the standard approach didn't hold. This is the reasoning behind each one.

[Pattern 01, BitLocker-to-Go key escrow](patterns/hybrid-entra-btg-key-escrow-pattern). The requirement was dual-destination escrow: recovery keys backed up to Entra ID as well as Active Directory on Hybrid Entra ID joined devices. It worked for fixed drives like C: and D: but not for removable ones, and a range of policies and settings made no difference. That pointed to a gap in the platform itself. Windows does log the failure, as Event ID 846, in a channel most monitoring setups never read, so the design retries off that event instead of polling. Intune Remediations were ruled out because the shortest schedule is 15 minutes and the device has to be online when the script runs. The retry happens once per event, on purpose, so it can't loop.

[Pattern 02, Sysmon configuration through policy](patterns/sysmon-configuration-via-native-policy). When Sysmon's configuration is bundled with its binary, every small tuning change means repackaging and redeploying the whole package, and each change inherits the lead time of the software deployment process. Detection tuning happens far more often than binary updates, so the two shouldn't share a release cycle. Sysmon reads its compiled rules from a registry value at runtime, which means the configuration can be delivered on its own through Group Policy or Intune as a registry setting. Updates then arrive at the next policy refresh. The cost is that every change sends the full compiled ruleset instead of a diff. I accepted that in exchange for one artifact that can be hashed, compared, and audited.

[Pattern 03, serverless Windows provisioning](patterns/serverless-windows-provisioning-wicd). Some environments rule out on-premises deployment infrastructure entirely: no SCCM, no Windows Deployment Services, nothing built on MDT. This pattern asks what Windows can do offline with native tooling. Windows Imaging and Configuration Designer offered a supported route to a bootable USB drive that combines the Windows image, applications, and scripts. Booting a bare-metal machine from it runs the whole process: enrollment into Entra ID and Intune, a small set of baseline applications, and BitLocker key backup. The operating system installation took about 11 minutes in the lab. I built it when Autopilot was still in development and tested the flow repeatedly in the lab on Windows 10 version 1607, so I document it as a validated lab design and not a current recommendation. Where devices can use Autopilot, that remains the preferred path, as the pattern itself says. It doesn't manage the device afterward, and the pattern recommends Intune enrollment for ongoing management.

[Pattern 04, SCEP through an internal NDES](patterns/scep-certificate-enrollment-internal-ndes). A common way to make Intune SCEP work is to put NDES in a DMZ and expose it to the internet, which places a CA-adjacent service on the public attack surface and ties issued certificates to wherever that server sits. The requirement here was to issue certificates from the internal issuing CA, for Mac devices that needed them for Wi-Fi authentication, without exposing NDES. The Intune Certificate Connector only makes outbound calls to Intune, so NDES can stay fully internal with its DNS registered locally. Remote devices reach it through a ZTNA broker. The design work was making enrollment behave correctly inside that boundary: SCEP rather than PKCS so the private key never leaves the device, and two independent gates, one from Intune policy and one from an address that only resolves internally. Because Entra ID Join Only devices and Macs have no AD computer object, the pattern also documents how certificate mapping differs for them, including why the on-premises SID variable doesn't resolve and what KB5014754 strong mapping changes.

[Pattern 05, Windows Event Forwarding with categorized collection](patterns/windows-event-forwarding-categorized-collection). A single collector serving thousands of endpoints needed regular restarts just to stay functional. The first fix was capacity: splitting collection across several collectors by OU, each carrying a share of the fleet, which stopped the instability. The second fix was data organization. With every event type flowing through one common subscription into one log, ingestion into the SIEM was uneven and parsing was hard. Splitting that into subscriptions by event type, each writing to its own event channel, moves classification to collection time. That costs more to maintain, including a manifest and a compiled DLL for the channels, and the pattern lists those costs. The two fixes solve different problems, and adding servers only addressed the first.

[Pattern 06, migrating standalone Sysmon to native](patterns/sysmon-migration-standalone-to-native). The first version of the script simply removed standalone Sysmon, enabled the native feature, and installed the config. On a Windows 11 23H2 machine that failed, because the optional feature doesn't exist before 24H2 with the March 2026 cumulative update. That turned it into a gated script: confirm the OS has the feature, confirm the right config file is in the package, make sure no restart is pending, and only then uninstall standalone. The gate wasn't enough on its own. On a physical Windows 11 25H2 test machine every check passed, and then the standalone uninstall crashed partway through on a PowerShell error-handling bug. The machine sat unmonitored for roughly 8 to 15 minutes, nothing alerted, and it was only noticed because someone was watching the console. That showed the risky part comes after standalone removal starts. So the script now labels every failure after that point as a gap state with its own exit code, and things were broken deliberately in testing to see what each one looks like. A config that native Sysmon rejects installs nothing and leaves the machine with no Sysmon. A rules blob from the wrong version lets native Sysmon look healthy until the next reboot, when the service exits and stops logging while the driver still appears to be running. Those cases are why the gating, the gap-state reporting, and the recovery steps are in the pattern.

## Whitepapers

Some patterns have a longer whitepaper. You can read them here in the repo, or download a formatted PDF from GitHub Releases.

| Whitepaper | Read Online | PDF |
|---|---|---|
| BitLocker-to-Go Recovery Key Escrow via Event-Driven Retry | [View](docs/whitepapers/btg-escrow-hybrid-entra-id-v1.4.md) | [Download](https://github.com/Shirish03/windows-endpoint-security-patterns/releases/tag/whitepaper-btg-v1.4) |
| SCEP Certificate Enrollment via Internal NDES | [View](docs/whitepapers/scep-zero-trust-certificate-infrastructure-v1.2.md) | [Download](https://github.com/Shirish03/windows-endpoint-security-patterns/releases/tag/whitepaper-scep-v1.2) |
| Migrating Standalone Sysmon to Native Windows Sysmon | [View](docs/whitepapers/sysmon-native-migration-v1.0.md) | [Download](https://github.com/Shirish03/windows-endpoint-security-patterns/releases/tag/whitepaper-sysmon-v1.0) |

## How I approach these

A few habits shape most of the patterns here.

I'd rather react to a real signal than poll on a schedule. Windows event logs, API failure codes, and observable state changes are what trigger a script, so it runs when a verified condition exists.

I care more about the reasoning than the script. Each pattern says why the approach was chosen, which platform behavior it depends on, and what it costs operationally. The scripts show how the idea works. They aren't the point.

Change control, limited endpoint agents, audit requirements, and Group Policy sharing space with Intune are part of the environment, so the patterns are written to work inside them.

The longer argument is in [docs/why-patterns-not-scripts.md](docs/why-patterns-not-scripts.md).

## Environment assumptions

These patterns were developed and validated against:

- Windows 10 22H2 and Windows 11
- Hybrid Entra ID joined devices (on-premises AD + Entra ID)
- Intune-managed, with co-management or standalone Intune policy
- PowerShell 5.1+ (scripts do not require PowerShell 7)
- Group Policy infrastructure present (required for the Sysmon and WEF patterns)

Three patterns step outside that list.

Pattern 04 targets Entra ID Join Only Windows and macOS devices, which have no on-premises AD computer object. Its README covers the scope in detail.

Pattern 06 needs Windows 11 24H2+ or Windows Server 2025 with the March 2026 cumulative update. It was validated and packaged for delivery through a general-purpose software deployment tool rather than Group Policy or Intune directly. See its README for scope.

Pattern 03 targets offline, no-infrastructure provisioning, where Hybrid Entra ID join and Intune enrollment haven't happened yet by design. It was tested on Windows 10 version 1607. Its README has the details.

These patterns may work in other setups, but I haven't validated them outside the environments above.

## Using this repository

Each pattern lives in its own folder under `patterns/` and is self-contained:

- `README.md`: background, problem statement, and solution overview
- `docs/`: detailed architecture and design documentation
- `scripts/`: PowerShell implementation where applicable
- `examples/`: sanitized samples and illustrative output where applicable
- `tests/`: Pester unit tests where applicable

Start with a pattern's README for the design context before you open the scripts. You'll need to adapt any of this to your environment, including paths and policy targeting, and test it somewhere controlled before it goes near production.

## Tried one? Tell me how it went

If you've used a pattern, hit a case it doesn't cover, or think I got something wrong, I'd like to hear about it. Open an issue on this repo or message me on [LinkedIn](https://www.linkedin.com/in/shirish1). A couple of lines is plenty.
