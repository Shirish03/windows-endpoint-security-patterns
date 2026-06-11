# SCEP Certificate Enrollment — Internal NDES (Hybrid Entra ID)

---
**Jump to section:**
[Strategic Overview](#strategic-overview) ·
[Architecture & Design](#architecture--design) ·
[Implementation Reference](#implementation-reference) ·
[Operational Guidance](#operational-guidance)

---

## Strategic Overview

### Who Should Read This

This document serves two audiences. Security architects and IT leadership
will find the strategic context, risk framing, and architectural
recommendation in this section. Engineers responsible for deploying and
operating the solution should proceed to
[Architecture & Design](#architecture--design) for design rationale,
[Implementation Reference](#implementation-reference) for deployment
steps, and [Operational Guidance](#operational-guidance) for monitoring
and failure handling.

---

### The Problem in Plain Terms

Intune delivers certificates to managed Windows devices using SCEP — the
Simple Certificate Enrollment Protocol. To issue those certificates from
an on-premises Certificate Authority, the CA-adjacent service that handles
enrollment requests, NDES (Network Device Enrollment Service), must be
reachable by the Intune cloud service. The path of least resistance in
most deployment guides is to expose NDES directly to the internet.

The consequence of that choice is an internet-facing endpoint that sits
one step from the organisation's certificate infrastructure. NDES does not
issue certificates itself, but it does broker requests to the CA. A
compromised or abused NDES service can be used to request certificates
against the organisation's PKI — potentially enabling fraudulent
authentication, lateral movement, or persistent access using certificates
that are trusted by the environment's own systems.

The failure mode is not hypothetical. NDES has a documented history of
vulnerabilities, and an internet-exposed instance provides an
unauthenticated attack surface against what should be one of the most
protected components of the environment. The risk is amplified in
organisations that rely on certificate-based authentication for Wi-Fi,
VPN, or device identity — where a certificate issued to an unauthorised
party grants real access.

---

### Risk and Compliance Implications

**Attack surface against certificate infrastructure**
An internet-exposed NDES server creates a CA-adjacent attack surface with
no dependency on corporate network access. Exploitation of the service —
whether through vulnerability, misconfiguration, or credential abuse —
can result in fraudulent certificate issuance against the organisation's
internal PKI. Certificates issued this way inherit the trust of the CA
and are not distinguishable from legitimately enrolled device certificates.

**Certificate-based authentication failure risk**
Many organisations rely on certificates for authentication to Wi-Fi
networks, VPN, and cloud services. The certificate infrastructure is
therefore a dependency of network access itself. Disruption or compromise
of NDES — whether through an attack or through operational failure — can
result in enrollment failures across the managed device population, with
downstream impact on connectivity and productivity.

**Zero Trust alignment**
A core principle of Zero Trust architecture is that only verified,
compliant, enrolled devices should be able to obtain credentials. An
internet-exposed NDES weakens this principle: the enrollment endpoint is
reachable by any internet host, and the strength of the control depends
entirely on the robustness of the challenge password mechanism. Routing
enrollment through the Intune Certificate Connector on an internal host
restores the boundary — only the connector, operating within the trusted
perimeter, communicates with NDES, and Intune enforces compliance posture
before any certificate is issued.

**Framework alignment**
NIST CSF Protect function (PR.AC) addresses access control and identity
management, including the requirement that only authorised devices and
users obtain credentials. NIST SP 800-207 (Zero Trust Architecture)
establishes the principle that access decisions should be made with full
context of device compliance and identity — a principle undermined when
certificate enrollment is available to any internet host. This document
does not constitute legal or compliance advice; organisations should
assess applicability to their specific obligations.

---

### Architectural Recommendation

Deploy NDES on an internal network segment with no inbound internet
connectivity. Route Intune certificate requests through the Microsoft
Intune Certificate Connector v2, installed on a domain-joined server
inside the perimeter. The connector establishes an outbound connection to
the Intune service, receives certificate requests on behalf of enrolled
devices, forwards them to the internal NDES server, and returns the
issued certificate — without requiring any inbound firewall rules or
internet-exposed endpoints.

This architecture eliminates the internet-facing attack surface against
the PKI entirely. Intune remains the policy enforcement and compliance
validation layer: no certificate request reaches NDES unless it
originates from an enrolled, compliant device that has satisfied Intune's
policy conditions. The CA itself remains on the internal network,
unreachable from the internet, with NDES equally protected.

---
