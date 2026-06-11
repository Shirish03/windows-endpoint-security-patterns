# SCEP Profile Sample — Illustrative Configuration

All values in this document are illustrative examples only. They must be
reviewed and adapted for the target environment before use. No value
should be applied in production without verification against the
organisation's PKI policy, certificate templates, and Intune
configuration.

---

## Profile Settings

### Certificate Type

```
Certificate type: Device
```

**Why:** A Device certificate binds the certificate identity to the
managed device object in Entra ID rather than to a user. This is required
for authentication scenarios where the certificate must be present
regardless of who is logged in — Wi-Fi authentication at machine startup,
VPN pre-logon, or device identity assertions to conditional access
policies. A User certificate is only available after user sign-in and is
scoped to the user's certificate store.

---

### Subject Name Format

```
Subject name format: CN={{DeviceName}}
```

**Why:** `CN=DeviceName` encodes the Intune-managed device name into the
certificate subject, making the certificate identifiable in CA audit logs
and revocation records. An issued certificate can be traced to a specific
device without reference to Intune. Some RADIUS servers and NPS policies
use the CN field for device identity matching; using the device name keeps
that matching deterministic. The Intune Device ID belongs in the SAN (see
below), where it functions as a machine-readable identifier rather than a
human-readable label.

---

### Subject Alternative Name (SAN)

```
Subject alternative name:
  Type:  URI
  Value: IntuneDeviceId://{{DeviceId}}
```

**Why:** The Intune Device ID URI in the SAN provides a machine-readable,
globally unique device identifier that survives device rename. Intune
populates `{{DeviceId}}` with the device's Intune object ID at profile
deployment time. This SAN format is recognised by NPS extensions and
Microsoft services for device-based conditional access enforcement. The
URI type is used because the device ID is not a DNS hostname or user
principal — encoding it as a DNS SAN or UPN creates ambiguity and may
cause validation failures.

---

### Key Size

```
Key size (bits): 2048
```

**Why:** 2048-bit RSA is the current minimum for authentication
certificates under NIST SP 800-57 guidance and provides an appropriate
security margin for certificate lifetimes of one to two years. If the
organisation's PKI policy mandates 4096-bit or ECDSA, the profile must
match the certificate template's key requirements exactly — a mismatch
will cause the CA to reject the request at issuance time.

---

### Hash Algorithm

```
Hash algorithm: SHA-2
```

**Why:** SHA-1 is deprecated for certificate signing and is rejected by
modern operating systems. SHA-2 (SHA-256) is the baseline for all new
certificate issuance. Ensure the CA certificate template is also
configured for SHA-256 — if the template specifies SHA-1, issued
certificates may be rejected by clients even when the CSR requested
SHA-2.

---

### Renewal Threshold

```
Renewal threshold (%): 20
```

**Why:** A 20% renewal threshold means Intune will attempt renewal when
20% of the certificate lifetime remains. For a one-year certificate this
is approximately 73 days before expiry — a window wide enough to
accommodate devices that are offline, have intermittent connectivity, or
miss MDM sync cycles. A threshold that is too low leaves insufficient
time for recovery if renewal fails; a threshold that is too high results
in unnecessary certificate churn. 20% is Microsoft's recommended default
for most enterprise scenarios.
