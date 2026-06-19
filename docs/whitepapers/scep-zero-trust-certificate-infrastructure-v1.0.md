# Zero Trust Certificate Infrastructure
## Secure device certificate enrollment via SCEP and Intune without exposing internal PKI

---

| | |
|---|---|
| **Version** | 1.0 |
| **Author** | Shirish Mistry |
| | Associate Principal, Endpoint & Security Architecture |
| **Domain** | Endpoint Security, Identity, Cloud Workplace |
| **Date** | June 2026 |
| **Repository** | github.com/Shirish03/windows-endpoint-security-patterns |

---

## Executive Summary

Intune-managed Windows devices use SCEP to request certificates from an
on-premises Certificate Authority. Standard guidance-driven deployments
place the NDES server, the CA-adjacent component that handles enrollment
requests, on the internet so the Intune cloud service can reach it. The
consequence is an internet-facing endpoint one step from the
organisation's internal PKI: a server that, if compromised, can be used
to request certificates trusted by the environment's own authentication
systems.

The recommended architecture removes this exposure entirely by enforcing
two independent gates rather than one. The **policy gate**: only
Intune-enrolled, compliant devices ever receive a SCEP profile. The
**network gate**: the SCEP URL delivered in that profile is an internal
DNS alias that resolves only inside the organisation's network and does
not exist in public DNS, so the URL is useless to a host outside the
perimeter even if it were obtained by other means. The Microsoft Intune
Certificate Connector v2 acts as the outbound-only relay that makes this
possible, carrying certificate requests from the Intune cloud service to
an NDES server with no internet connectivity. Remote, off-network devices
reach the same internal endpoint through a ZTNA broker session rather
than a published endpoint, and the DMZ in this architecture is
deliberately empty. NDES additionally validates a one-time challenge
password for each request, the Domain Controller authenticates both NDES
and the Issuing CA independently, and the CA applies its own template
policy as a further check. No inbound firewall rules are required and
the internal PKI remains fully inside the network perimeter.

---

## 1. Background and Problem Context

### The Certificate Infrastructure Gap

Device certificates are a foundational component of modern enterprise
security. They authenticate devices to Wi-Fi networks, VPN gateways, and
cloud services. They enable conditional access policies that verify device
identity before granting access. In a Zero Trust architecture, the device
certificate is one of the primary signals confirming that a device is
what it claims to be.

Intune delivers device certificates to managed Windows devices using SCEP
(Simple Certificate Enrollment Protocol), working in conjunction with an
on-premises Certificate Authority. For Intune to issue certificates from
an on-premises CA, it must reach NDES (Network Device Enrollment Service),
which acts as the SCEP protocol handler between the Intune cloud service
and the CA.

NDES must be reachable by the Intune cloud service, which operates from
Microsoft's infrastructure. The path of least resistance described in most
deployment documentation is to expose NDES to the internet: place it in
a DMZ, open the HTTPS port, and let Intune reach it directly. This works.
It also places a CA-adjacent server on the internet attack surface.

### Why This Creates a Structural Risk

NDES does not issue certificates itself, but it brokers requests to the
CA. It validates that each incoming request carries a valid challenge
password, and if it does, it forwards the certificate signing request to
the CA for issuance. A compromised or abused NDES service can be used to
submit fraudulent certificate requests against the organisation's own PKI.

Certificates issued this way carry the full trust of the CA. They are not
distinguishable from legitimately enrolled device certificates. In
environments where certificates authenticate devices to Wi-Fi, VPN, or
cloud services, a fraudulently obtained certificate grants real access.

NDES has a documented history of vulnerabilities. Placing it on the
internet is not a theoretical risk: it is a known attack surface against
what should be one of the most protected components of the environment.

### Scale and Prevalence

This architecture choice is common because it is what standard deployment
documentation leads to. Any organisation following guidance-driven Intune
SCEP deployment without specifically evaluating the network exposure of
NDES is likely operating an internet-exposed PKI-adjacent service. The
risk is not in the configuration; it is in the architecture.

### Why Standard Security Reviews Miss It

The configuration appears correctly deployed from the outside. NDES is
accessible, Intune is issuing certificates, devices are enrolling. There
is no policy error, no missing configuration item, and no failed
compliance report. The risk is structural: the architecture places a
sensitive component in an exposed position, and that exposure is not
visible through standard configuration audit processes unless the scope
explicitly includes network exposure of PKI-adjacent services.

---

## 2. Risk and Compliance Implications

### Attack Surface Against Certificate Infrastructure

An internet-exposed NDES server creates a CA-adjacent attack surface
reachable by any internet host. Exploitation of the service (through
vulnerability, misconfiguration, or credential abuse) can result in
fraudulent certificate issuance against the organisation's internal PKI.
Certificates issued this way inherit the trust of the CA and cannot be
distinguished from legitimately enrolled device certificates without a
forensic review of CA issuance records.

The organisation's PKI is a trust anchor for authentication. Compromising
that trust anchor through NDES has cascading effects across every system
that relies on certificate-based authentication.

### Certificate-Based Authentication Integrity

Certificates authenticate devices to Wi-Fi networks, VPN gateways, and
cloud services. The certificate infrastructure is therefore a dependency
of connectivity itself. Disruption of NDES (through attack or operational
failure) blocks enrollment and renewal for the entire managed device
population. In environments where device certificates are required for
Wi-Fi authentication, an NDES outage can prevent managed devices from
connecting to the corporate network at all.

The internet-exposed architecture amplifies this risk: a service targeted
by an availability attack, or taken offline as a consequence of a broader
incident, produces the same enrollment failure as an internal outage, but
with less control and less notice.

### Zero Trust Alignment

A core principle of Zero Trust architecture is that only verified,
compliant, enrolled devices should be able to obtain credentials. An
internet-exposed NDES weakens this principle. The enrollment endpoint is
reachable by any internet host, and the strength of the control depends
on a single-use challenge password mechanism. While the challenge password
is a meaningful control, the architecture places the outer security
boundary at the NDES layer rather than at the Intune compliance gate.

Routing enrollment through the Certificate Connector v2 restores this
boundary. Only the connector, operating inside the trusted network
perimeter, communicates with NDES. Intune's compliance enforcement becomes
the outermost gate: a device must be enrolled and compliant before a
certificate request enters the enrollment chain at all.

### Framework Alignment

Several widely adopted frameworks address the requirement that access
credentials are issued only to verified, authorised entities:

- **NIST CSF Protect function (PR.AC)** addresses access control and
  identity management, including the requirement that only authorised
  devices and users obtain credentials. An internet-exposed NDES
  undermines this: the enrollment endpoint is reachable before device
  compliance is verified.
- **NIST SP 800-207** (Zero Trust Architecture) establishes the principle
  that access decisions should incorporate full context of device
  compliance and identity. Certificate enrollment available to any internet
  host is inconsistent with this principle.
- **ISO/IEC 27001 Annex A 8.20** (Networks security) requires that access
  to sensitive network services is restricted based on verified identity
  and authorisation. A CA-adjacent service with internet exposure
  represents a gap against this control.

This document does not constitute legal or compliance advice; organisations
should assess applicability to their specific obligations.

---

## 3. Architecture Overview

### How the Architecture Works

The solution routes all Intune certificate enrollment requests through the
Microsoft Intune Certificate Connector v2, installed on a domain-joined
server inside the corporate network perimeter. NDES remains on an internal
network segment with no inbound internet connectivity, and the DMZ in
this architecture is intentionally empty: there is no published endpoint
for an attacker to find.

Two independent gates protect every enrollment, enforced by different
mechanisms:

**Gate 1: Policy.** Only Intune-enrolled, compliant devices receive the
SCEP profile in the first place. Intune evaluates compliance before
issuing the SCEP URL and a one-time challenge password.

**Gate 2: Network.** The SCEP URL is not a public endpoint. It is an
internal DNS alias, a CNAME pointing at the Certificate Connector, that
is registered only in the organisation's internal DNS zone and does not
exist in public DNS. A device that obtained the URL without going
through Intune would still be unable to resolve it from the internet.

For on-network devices, the alias resolves directly and the SCEP request
reaches the Connector over the LAN or corporate Wi-Fi. For remote,
off-network devices, the request reaches the Connector through a ZTNA
broker (such as Zscaler Private Access) and a paired App Connector
running inside the network; the remote device never receives an IP
address on the internal network and cannot reach anything beyond the one
scoped endpoint. See [A Note on ZTNA](#a-note-on-ztna) below.

The Connector maintains an outbound-only HTTPS connection to the Intune
service; it validates each request against Intune, forwards it to the
internal NDES server, and returns the issued certificate to the device.
No inbound firewall rules are required at any point in the chain.

![SCEP NDES Architecture](images/scep-ndes-architecture.png)

| Flow | Description |
|---|---|
| ① | Intune → all devices: MDM profile + internal SCEP URL |
| ② | On-prem device → Certificate Connector: direct SCEP request |
| ②a / ②b / ②c | Remote device → ZTNA broker → App Connector → Certificate Connector |
| ③ & ⑨ / ④ | Certificate Connector ↔ Intune: outbound validation and approval |
| ⑤ / ⑦ | NDES / Issuing CA → Domain Controller: Kerberos/LDAP authentication |
| ⑥ / ⑧ | NDES ↔ Issuing CA: certificate request and return (RPC/DCOM) |
| ⑩ | Certificate Connector → device: certificate delivered, reversing ② / ②c |
| — | Root CA ↔ Issuing CA: PKI trust chain / CRL distribution (always active) |

### A Note on ZTNA

ZTNA (Zero Trust Network Access) is a category of technology that allows
remote devices to reach internal applications without connecting to the
corporate network as a whole. Traditional VPN gives a remote device a
foothold on the internal network; ZTNA instead connects the device to a
cloud broker, which stitches the session to a paired connector inside
the network, scoped to one specific application. The remote device never
gets an internal IP address and cannot browse the network freely.

For this pattern, ZTNA lets a remote device reach the Certificate
Connector as if it were on the corporate network, without exposing NDES
or any other internal infrastructure to the internet. If an organisation
has no ZTNA product, a corporate VPN serves the same structural purpose;
ZTNA is preferred because it grants application-level access rather than
full network access.

### How Enrollment Is Secured

Beyond the two gates described above, two further independent checks
apply once a request reaches the internal network:

**NDES challenge password.** Each enrollment request must carry a
one-time password issued by Intune within its validity window. The
password is single-use and time-limited. A request that arrives without
a valid password is rejected unconditionally.

**Domain Controller authentication.** Both NDES and the Issuing CA
independently authenticate to the Domain Controller over Kerberos/LDAP
before acting. This confirms that the services participating in the
chain are themselves trusted, domain-joined services, a check that is
separate from the device's own compliance status.

**CA template policy.** The CA validates each certificate signing
request against the configured template. Key size, algorithm, permitted
attributes, and service account permissions are checked independently of
the SCEP layer. A request that passes NDES validation can still be
rejected by the CA if it does not conform to the template.

No single control failure authorises issuance. Each layer operates
independently, and the network gate in particular means there is no
internet-reachable endpoint for an attacker to attack in the first place.

### Component Roles

| Component | Location | Role |
|---|---|---|
| Microsoft Entra ID | Microsoft cloud | Device identity and join/registration; prerequisite for Intune enrollment |
| Intune Service | Microsoft cloud | Compliance gate, challenge password issuance, certificate delivery |
| ZTNA broker | Cloud (e.g. Zscaler ZPA) | Brokers remote device sessions into the internal network, scoped to one endpoint |
| Managed Device | Endpoint (on-prem or remote) | Key pair generation, CSR construction, certificate installation |
| App Connector | Internal network | Pairs with the ZTNA broker; relays remote SCEP traffic internally |
| Certificate Connector v2 | Internal network, domain-joined server | Outbound-only relay between Intune and NDES |
| NDES | Internal network | SCEP protocol handling, challenge password validation |
| Domain Controller | Internal network | Kerberos/LDAP authentication for NDES and the Issuing CA |
| Issuing CA | Internal network | Template-based certificate issuance |
| Root CA | Internal network | PKI trust anchor; signs the Issuing CA, publishes CRL |

---

## 4. Design Rationale

### Outbound Relay Over Internet-Exposed NDES

The connector model eliminates the internet-facing attack surface on the
PKI entirely rather than reducing it through perimeter controls. The
common alternative, placing NDES in a DMZ with IP restriction to
Microsoft's Intune service IP ranges, has two weaknesses: Microsoft's
cloud service IP ranges are broad and change over time, making precise
restriction difficult to maintain reliably; and a misconfiguration or
IP range expansion can silently re-open the attack surface without
triggering a visible alert. The connector eliminates the inbound exposure;
there is no surface to misconfigure.

### Certificate Connector v2 Over the Legacy Connector

Microsoft deprecated the legacy Intune Certificate Connector. The v2
connector handles SCEP, PKCS, and PFX certificate types from a single
installation. It uses Entra ID app registration for authentication rather
than a service account, eliminating a credential management dependency
and aligning with modern identity practices. Organisations still running
the legacy connector should treat migration as a priority; it no longer
receives feature updates and will reach end of support.

### SCEP Over PKCS for Device Identity Certificates

PKCS certificate delivery generates the key pair on the server side,
meaning the private key is transmitted to the device over the network.
For device authentication certificates, this is a weaker security posture
than SCEP, where the private key is generated on the endpoint and never
transmitted. SCEP with an internal NDES is the appropriate model for
device identity certificates used in authentication scenarios.

### Internal PKI Over Cloud PKI

Microsoft Cloud PKI is a viable path for organisations building fully
cloud-managed environments with no on-premises infrastructure dependency.
For organisations with an existing CA, established certificate templates,
and hybrid infrastructure, the internal NDES pattern preserves the PKI
investment and avoids a CA migration. Both models can achieve equivalent
security posture; the choice is an infrastructure strategy decision. This
pattern assumes a functioning on-premises CA is already present.

---

## 5. Operational Considerations

Full operational guidance is documented in the
[Operational Guidance section](https://github.com/Shirish03/windows-endpoint-security-patterns/tree/main/patterns/scep-certificate-enrollment-internal-ndes#operational-guidance)
of the GitHub pattern. The following are the primary signals and
maintenance considerations for production operations.

### Connector Health

The Certificate Connector v2 is the single internal component that bridges
the Intune cloud service and the PKI. Connector health is the first signal
to check for any enrollment failure. The Intune admin center reports
connector status (Active, Error, or Inactive). An unhealthy connector
blocks all certificate enrollment and renewal across the managed device
population until resolved.

### Certificate Renewal

SCEP certificates renew automatically when the device reaches the
configured renewal threshold. Renewal follows the same flow as initial
enrollment; the device must be enrolled, compliant, and able to reach
Intune. Devices that are offline at the point of renewal may miss the
window. A device whose certificate expires while offline must reconnect
and trigger a manual Intune sync to re-enroll from scratch.

### PKI Team Coordination

This architecture creates a dependency between Intune operations and the
on-premises PKI team. Changes to certificate templates, CA configuration,
or CRL distribution points can affect enrollment without producing an
obvious error in Intune. Establish a coordination process so that template
changes and SCEP profile configuration changes are aligned before
deployment.

A circular dependency can emerge in environments where device certificates
are required for network authentication: if the CA's CRL distribution
points become unreachable, devices may fail authentication, which can
block the connectivity the device needs to reach those same endpoints.
Plan CRL distribution point URLs to be accessible before network
authentication is established.

### Primary Operational Signals

- **Connector status** in the Intune admin center: should show Active at
  all times; any other status requires immediate investigation
- **SCEP profile deployment status** per device: a Failed status requires
  investigation of the error code in the Intune device report
- **CA Failed Requests**: any entry represents a request the CA rejected;
  the denial reason is logged and should be reviewed promptly
- **CRL validity**: an expired CRL can block authentication independently
  of the enrollment infrastructure; monitor CRL expiry as a separate
  operational signal

---

## 6. Recommendation

Organisations operating Windows devices in Hybrid Entra ID joined,
Intune-managed configurations with an on-premises Certificate Authority
should deploy NDES on an internal network segment with no internet
connectivity and route all Intune certificate enrollment through the
Certificate Connector v2. This architecture eliminates the internet-facing
attack surface against the PKI entirely, preserves the existing CA
investment, and enforces a three-layer validation model (Intune compliance
gate, NDES challenge password, CA template policy) that aligns with Zero
Trust principles. The change requires no modification to the CA or to
existing certificate templates, and no new PKI infrastructure. Connector
health is visible in the Intune admin center, enrollment status is
reported per device, and the CA provides an authoritative audit trail of
all certificate activity. Given that device certificates are a trust
anchor for authentication to Wi-Fi, VPN, and cloud services, eliminating
internet exposure of the CA-adjacent enrollment service should be treated
as a baseline security requirement rather than an optional hardening
measure.

---

## 7. Further Reading

**GitHub pattern: full SCEP enrollment implementation reference**
The complete implementation (environment requirements, NDES prerequisites,
connector installation, SCEP profile configuration, validation steps, and
operational guidance) is available at:
github.com/Shirish03/windows-endpoint-security-patterns/tree/main/patterns/scep-certificate-enrollment-internal-ndes

**Microsoft documentation**
- Microsoft Learn: Configure and use SCEP certificate profiles with Intune
- Microsoft Learn: Certificate Connector for Microsoft Intune
- Microsoft Learn: Network Device Enrollment Service (NDES) in Active
  Directory Certificate Services
- NIST SP 800-207: Zero Trust Architecture

*Reference Microsoft documentation at learn.microsoft.com. Content and
URLs are subject to change; search by topic rather than direct URL.*

---

## 8. Disclaimer

This whitepaper is provided as reference material and architectural
guidance. The architecture described has been developed against specific
Hybrid Entra ID and Intune-managed environment configurations with
on-premises Active Directory Certificate Services and may require
adaptation for other configurations.

There is no guarantee that this approach will function identically in
all environments. Administrators should review, test, and validate
behaviour in a controlled setting before any production use.

This document does not constitute legal or compliance advice. Framework
references (NIST CSF, NIST SP 800-207, ISO/IEC 27001) are provided for
context only. Organisations should assess applicability to their specific
regulatory and contractual obligations independently.

Use at your own discretion.
