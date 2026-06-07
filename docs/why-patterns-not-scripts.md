# Why Patterns, Not Scripts

When engineers share solutions to endpoint security problems, the default artifact
is a script. A PowerShell file gets posted, copied, and run. If it works, it gets
adopted. If it breaks six months later in a slightly different environment, the
person who finds it has nothing to go on except the code itself.

This repository is structured differently, and that choice is intentional.

## The real problem with scripts as the unit of sharing

A script encodes a decision, but it doesn't explain it. It tells you *what* was
done. It doesn't tell you *why that approach was chosen*, what platform behavior
it depends on, or what will silently break if one of those dependencies isn't
present.

Consider the BitLocker-to-Go escrow pattern in this repository. The core of the
solution is about forty lines of PowerShell. But the script is not the hard part.
The hard part is understanding:

- Why native Intune escrow fails silently on Hybrid Entra joined devices and
  produces no policy error
- Which event log channel actually captures failure events, and why the channel
  name found in most documentation is wrong
- Why the trigger needs a 30-second delay before the script runs
- Why a recency guard is necessary to prevent the task from acting on events
  replayed after a machine resumes from sleep

None of that is in the script. It can't be. A script that explained its own
context in inline comments would be longer than the code. And even then, the
comments would be read once and forgotten.

The pattern document is where that reasoning lives. It exists so that the person
operating this in a production environment — or adapting it for a different one —
understands what they're relying on, not just what the script does.

## Enterprise environments break scripts in ways labs don't

In a test environment, a script either works or it doesn't. In an enterprise
environment, it works in the lab, works in pilot, and then silently does nothing
for twenty percent of production devices because of co-management state, GPO
tattoo from a previous policy, a scoped deployment that missed a device group, or
a security baseline that strips the execution policy setting the script depends on.

Scripts don't surface these conditions. Patterns, when written well, name them.

Each pattern in this repository includes environment assumptions. Not as a
disclaimer, but as a precision statement: *this approach was validated against
Hybrid Entra joined devices running Windows 10 22H2 and Windows 11, managed
through standalone Intune, with Group Policy infrastructure present*. If your
environment matches that, the approach should hold. If it doesn't, you know
exactly which variable to examine.

That specificity is more useful than a generic "your environment may vary" note
at the bottom of a README.

## Decisions that aren't visible in code

Some of the most important engineering decisions in this repository are about what
*wasn't* done.

The BTG escrow pattern doesn't introduce a new infrastructure component, a
management server, a monitoring agent, or a database. It uses the Windows event
log, the native scheduled task engine, and an API call that Windows already knows
how to make. The entire pattern runs on the endpoint using components that are
already present, already auditable, and already within the enterprise's change
control boundary.

That constraint — *no new infrastructure* — shaped every design decision. It's
not obvious from reading the script. It only makes sense if you understand that
in most enterprise environments, adding infrastructure has a cost that dwarfs the
cost of the security gap it's solving. The pattern document explains that
trade-off. The script just implements one side of it.

## Patterns age better than scripts

A script is tied to a moment in time. An API changes, a cmdlet is deprecated, a
platform update changes how an event is structured, and the script breaks.

A pattern is more durable because it separates the *approach* from the
*implementation*. When the implementation needs to change, the design intent is
preserved. The person making the change understands what they're trying to
preserve, not just what they're trying to fix.

This matters in endpoint security specifically because the platform — Windows,
Intune, Entra ID — is not static. Behavior that is undocumented today gets
documented, sometimes as a fix and sometimes as a breaking change. Patterns give
you the context to evaluate those changes. Scripts just break.

---

None of this means scripts aren't valuable. Every pattern in this repository
includes one. But the script is the illustration. The pattern is the point.

If you understand the design well enough to adapt it to your environment, the
scripts will make sense. If you only have the scripts, you're guessing.
