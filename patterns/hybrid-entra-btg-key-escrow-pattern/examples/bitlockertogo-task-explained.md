# BitLocker-to-Go Escrow – Example Artifacts

This directory contains example artifacts that illustrate the
event-driven BitLocker-to-Go recovery key escrow pattern.
These files are provided for structural and educational purposes only.

---

## 1. Event-Triggered Scheduled Task (XML)

**File:** `BitLockerToGo-Escrow-Retry.sample.xml`

This XML is an annotated example of a scheduled task definition
configured to trigger on a BitLocker API failure event.

### Key Characteristics

- **Trigger**
  - Event-based trigger
  - Log: `Microsoft-Windows-BitLocker/BitLocker Management`
  - Event ID: `846`

- **Action**
  - Executes a PowerShell script
  - Used to retry recovery key escrow after an initial failure

This task enables an immediate and deterministic response
to BitLocker-to-Go escrow failures without relying on user interaction.

---

## 2. Sample BitLocker Failure Event

**File:** `sample-event.json`

This JSON file represents a sanitized example of the BitLocker
API event used by the solution to identify removable drive details.

### What the Event Provides

- Event ID indicating escrow failure
- Log source identifying BitLocker API
- Message content containing the removable drive letter

### Why This Matters

The drive letter extracted from this event is used to:
- Identify the affected removable volume
- Query BitLocker key protectors programmatically
- Initiate a recovery key backup retry

This event acts as the primary signal driving the automation flow.
