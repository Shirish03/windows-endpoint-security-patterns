# Windows Event Forwarding: Categorized Collection

---

**Jump to section:** [Strategic Overview](#strategic-overview) · [Architecture & Design](#architecture--design) · [Implementation Reference](#implementation-reference) · [Operational Guidance](#operational-guidance)

---

## Strategic Overview

### Who Should Read This

This document serves two audiences. Security architects and IT leadership will find the strategic context, the design reasoning, and the architectural recommendation in this section and the next. Engineers responsible for building and operating the collection tier should continue to [Implementation Reference](#implementation-reference) for the manifest, subscription, and Group Policy mechanics, and [Operational Guidance](#operational-guidance) for validation, failure handling, and change control.

### The Problem in Plain Terms

Windows Event Forwarding (WEF) is the native mechanism for collecting security-relevant event logs from a fleet of Windows endpoints to one or more Windows Event Collector (WEC) servers, without installing a third-party agent on every device. The most common deployment follows the path of least resistance: a single collector, a single broad subscription, and all forwarded events landing in the built-in Forwarded Events log, which a downstream SIEM connector then reads and sorts out.

That model works until it doesn't. As the endpoint population grows and the range of telemetry widens, fundamentally different classes of event, authentication auditing, process and script activity, application-control decisions, endpoint-protection alerts, firewall filtering, all compete for the same collector CPU, the same disk throughput, the same single log, and the same downstream ingestion path. The result is a collection tier that is difficult to scale, difficult to troubleshoot, and difficult to reason about. When something goes wrong, the operator stops asking "is security event collection healthy?" and starts asking "what inside Forwarded Events is causing today's problem?" That shift is the signal that the bottleneck has become architectural rather than a matter of tuning.

This pattern describes a categorized collection architecture that addresses the problem at the level where it actually lives: it separates telemetry at collection time, so that scaling, retention, troubleshooting, and downstream ingestion can each be managed independently per category, using only native Windows capabilities.

### How This Architecture Emerges

A categorized collection tier is rarely designed all at once. It tends to emerge as the answer to a sequence of distinct problems, and the value of the pattern is as much in recognizing that these are *different* problems as in the final architecture itself.

The typical starting point is a single collector with a single broad subscription. As the fleet grows, the first pressure that appears is raw **capacity**: one collector cannot keep up, and the instinct is to scale hardware. Before doing that, there is usually volume to reclaim at the source, suppressing verified low-value events at the subscription level. Because suppression decides what security data is never collected, those decisions are made together with the people who consume the telemetry for detection, not by the collection tier alone. This is a real fix, but it does not resolve the underlying limit on its own.

A second problem often hides alongside the first, and mistaking it for the same problem is a common error. It is a **delivery-mechanism** problem rather than a volume one: a telemetry source such as Sysmon requires frequent configuration tuning, but if its configuration is coupled to its binary, every tuning change forces a full repackage-and-redeploy cycle. The fix is unrelated to collector capacity, decoupling configuration delivery from the binary so tuning changes flow without redeployment (documented separately as the [Sysmon configuration pattern](../sysmon-configuration-via-native-policy)).

With noise reduced and delivery decoupled, a **distribution** problem usually remains: one collector still cannot reliably serve the whole fleet. The deliberate answer is horizontal scaling by policy, multiple collectors, each addressed by its own Group-Policy-delivered Subscription Manager configuration scoped to a different portion of the fleet. At this stage the collectors are still splitting the *same* undifferentiated data across more infrastructure.

The final shift is a **data-organization** problem, and it is often surfaced by an unrelated architectural change, which presents a choice between replicating the existing model as-is or using the moment to address a deeper limitation. A single common subscription per collector makes downstream parsing and triage imprecise, because everything arriving through a collector is a mixed stream. The answer is category-based subscriptions writing to dedicated custom channels, so that each telemetry class is organized at collection time rather than sorted out downstream.

Each of these four, capacity, delivery mechanism, distribution, and data organization, is a separate root cause with a separate correct fix. The failure mode this pattern guards against is treating all of them as one problem and applying a single reflexive response, "add more servers," uniformly across all four.

### The Core Idea

The design principle that explains almost every decision in this pattern is a single one: **move classification, ownership, and operational control as far upstream in the telemetry pipeline as possible.** Rather than collecting everything into one shared log and sorting it out downstream, the architecture separates telemetry at the point of collection, so that each category has its own subscription, its own destination channel, and a clear place in the pipeline that can be scaled and operated on its own.

### Architectural Recommendation

Deploy WEF using **source-initiated subscriptions**, where endpoints discover their collectors through Group Policy rather than the collectors maintaining explicit device lists. Separate telemetry into **dedicated custom event channels** on the collectors, one channel per telemetry category, rather than allowing all forwarded events to accumulate in the shared Forwarded Events log. Distribute the collection tier across **multiple collectors grouped by telemetry domain**, so that a volume spike or a maintenance action in one category does not affect unrelated categories. Point each subscription at its category-specific channel, and let the downstream collection agent subscribe to named channels rather than post-filtering one mixed stream.

This architecture is built entirely on native Windows components, WEF, WEC, WinRM, the Windows Event Log provider framework, and Group Policy, and introduces no additional agents or third-party infrastructure on endpoints beyond whatever the downstream SIEM already requires on the collectors.

---

## Architecture & Design

### Background

Windows Event Forwarding operates in one of two modes. In **collector-initiated** mode, the collector reaches out to each source, requests events, and maintains the list of sources it manages. In **source-initiated** mode, endpoints are told, through policy, where their collectors are; they discover the collectors, retrieve the subscriptions that apply to them, and push matching events. This pattern uses source-initiated collection throughout, for reasons developed under [Design Trade-offs](#design-trade-offs-and-alternatives-considered) below.

By default, a WEC server has only the same event channels any Windows server has for its own logs, plus the built-in Forwarded Events log. Everything forwarded to it lands there unless the collector is extended with additional destinations. Extending the collector with **custom event channels**, registered through the Windows Event Log provider framework using an instrumentation manifest, gives each telemetry category its own log file, with its own size and retention settings, its own I/O path, and its own name that a SIEM can target directly.

### Solution Overview

The architecture moves events from policy distribution through to downstream monitoring in a defined sequence. The diagram below shows the full flow; the numbered stages correspond to the event-flow steps beneath it.

![Windows Event Forwarding: Categorized Collection architecture diagram, showing Group Policy distributing WEC server addresses to Windows endpoints, two WEC server farms each hosting category-based subscriptions, dedicated event channels per category, and a SIEM collection agent reading those channels into the SIEM.](docs/wec-architecture-diagram.png)

**Event flow:**

① Group Policy distributes the Subscription Manager configuration (the WEC server address and settings) to Windows endpoints.
② Endpoints register with their assigned WEC servers and retrieve their subscriptions using WinRM with Kerberos authentication.
③ Endpoints forward the matching events to their WEC server, based on the subscriptions they retrieved.
④ The WEC server writes the collected events to dedicated event channels.
⑤ The SIEM collection agent monitors the designated event channels and collects the forwarded events.
⑥ The agent securely transmits the collected events to the SIEM for centralized monitoring, analysis, and retention.

### Two Axes of Separation

Telemetry can be separated along two independent axes, and a mature design uses both:

- **By category (what kind of event).** Authentication auditing, process activity, script execution, application control, endpoint protection, and network filtering each behave differently in volume, value, and retention needs. Giving each its own subscription and channel lets each be tuned on its own terms.
- **By collector group (which set of collectors).** Grouping collectors by telemetry domain, so that one group handles one set of categories and another group handles a different set, creates fault boundaries between domains. A volume spike in one domain consumes that group's resources, not the whole collection tier's.

Using both axes together produces a design that is neither a single overloaded collector nor an unmanageable sprawl of one-collector-per-category. It is a deliberate middle ground: a small number of collector groups, each owning a coherent set of telemetry categories, each category in its own channel.

One tension is worth naming here, because it shapes the grouping in practice. Category is one axis, but raw volume is another, and they do not always align. Telemetry categories differ in throughput by more than an order of magnitude: process, script, network, and firewall telemetry are typically far heavier than application-control, print, or endpoint-protection status events. Grouping purely by category can therefore place two very heavy categories on the same collector group and leave another group lightly loaded. A sound grouping is volume-aware: it keeps categories coherent where it can, but it does not put two of the heaviest categories on the same group without planning for the combined load. In practice the category axis organizes the design and the volume axis constrains it.

### Why Dedicated Channels Rather Than Forwarded Events

Using the built-in Forwarded Events log is by far the simplest option: no manifest, no compiled resource DLL, no channel registration. The reason this pattern accepts that extra work is that **downstream filtering happens too late.** With a single shared log, a high-volume category (process or script telemetry, for example) and a low-volume but high-value category (authentication or application-control events, for example) arrive in the same repository, are processed by the same collector, and are handed to the SIEM as one mixed stream. The collector still carries the mixed workload; the SIEM still receives it; troubleshooting still happens against it.

Dedicated channels move classification earlier in the pipeline, from *collect, then store, then classify downstream* to *collect, classify, then store*. That single change is what makes independent scaling, per-category retention, fault isolation, and clean SIEM onboarding possible. The concrete benefits:

| Design concern | Shared Forwarded Events log | Dedicated custom channels |
|---|---|---|
| Telemetry separation | All categories mixed in one log | Each category in a distinct destination |
| SIEM onboarding | Downstream must separate mixed classes | Agent subscribes to explicitly named channels |
| Retention | One size and policy for everything | Size and retention tuned per category |
| Troubleshooting | Backlog and ingestion issues hard to isolate | Affected subscription or channel investigated on its own |
| Noise management | High-volume sources obscure low-volume security events | High-volume telemetry isolated and tuned separately |
| Fault isolation | A noisy or malformed source affects the shared log | A problem category stays contained to its own channel |

### Noise Reduction at the Source

Separation is only half of the volume story. The other half is suppressing verified benign activity at the subscription level, before it is ever collected, rather than filtering it downstream. Each subscription follows a **select broadly, suppress precisely** pattern: define the potentially valuable event population with selection logic, then remove specific, baselined, known-benign activity with targeted suppression logic bound to specific event IDs and named event fields. Suppression is treated as security-relevant configuration: each exclusion is baselined, documented with a reason and an owner, peer-reviewed, and revalidated after significant operating-system, agent, or application changes. The mechanics are covered in [Implementation Reference](#implementation-reference).

### Relationship to Configuration Delivery

A recurring theme in this pattern is decoupling things that change often from things that change rarely. The same principle applies to the telemetry sources feeding the pipeline. Where an endpoint telemetry source such as Sysmon is in use, delivering its configuration separately from its binary, so that frequent detection-tuning changes do not require redeploying the binary each time, removes a recurring source of operational churn upstream of the forwarding tier. That configuration-delivery approach is documented on its own in the [Sysmon configuration pattern](../sysmon-configuration-via-native-policy) and is referenced here rather than repeated; it pairs naturally with categorized collection because both decouple a fast-changing concern from a slow-changing one.

### Design Trade-offs and Alternatives Considered

**Why not simply add more general-purpose collectors?** Adding more identical collectors that each receive every category improves raw capacity but not architecture. The problem being solved is not only scale; it is operational, workload, troubleshooting, and ingestion isolation. With undifferentiated collectors, a noisy category still affects every collector, and a change to one category's collection still touches all of them. Aligning collector responsibility with telemetry domains creates the fault boundaries that raw capacity alone does not.

**Why not continue using Forwarded Events with downstream filtering?** This is the simplest model, and it is a legitimate one: many mature deployments write everything to the default Forwarded Events log and let the downstream collection agent or SIEM separate event types by subscription name or rendered content. It avoids the manifest, the compiled resource DLL, and the channel-registration and drift concerns that custom channels bring. This pattern takes the other road, and the reasoning is worth stating plainly rather than dismissing the alternative.

This is a lesson I learned during a SIEM platform migration. A WEF deployment built on the default Forwarded Events log can work adequately for one downstream platform and prove limiting under another. With all telemetry funneled into a single collection point, ingestion efficiency, event parsing, tuning, troubleshooting, and operational visibility all became harder. Rather than reproduce the existing design on the new platform, I redesigned the collection tier to separate telemetry into dedicated channels aligned to event categories. Pre-segmenting the streams at the collection layer reduced downstream processing complexity and gave clear operational boundaries between telemetry types, and in practice produced more reliable ingestion, simpler parser and content management, easier troubleshooting, and better per-stream health visibility. The manifest and channel-registration overhead is real, and it is accepted deliberately because, for this pipeline, moving classification upstream was judged worth more than the implementation cost. A deployment whose downstream platform cleanly separates a shared log by subscription may reasonably weigh that trade-off differently.

**Why source-initiated rather than collector-initiated?** Source-initiated collection scales better with endpoint count and fits an environment that already uses Group Policy as a control plane. Endpoints discover collectors through policy; devices that join, leave, or are rebuilt require no collector-side reconfiguration; and the collector maintains no explicit endpoint list. Collector-initiated collection is workable in small environments but pushes lifecycle management onto the collector as the fleet grows.

**Why a small number of collector groups rather than one, or many?** One group recreates the original shared-workload problem with no meaningful separation. A large number of single-purpose groups maximizes isolation but multiplies servers, subscriptions, monitoring, failover design, and documentation, collector sprawl with diminishing returns. A small number of groups, each owning a coherent set of telemetry categories, achieves meaningful isolation and independent scaling while remaining operable by a support team rather than only its designers.

**Why Group Policy for collector discovery?** Group Policy already provides configuration, targeting, lifecycle management, and refresh as a single native mechanism, with no additional software, custom code, or third-party dependency. The design leverages the control plane already present rather than introducing a new one.

### Key Trade-offs Accepted

A design that only lists benefits is describing an advertisement, not an architecture. This pattern knowingly accepts several costs in exchange for its isolation and scalability:

- **More moving parts.** Instead of one shared log, the design maintains custom channels, multiple subscriptions, collector groups, manifest registration, and per-channel configuration.
- **Manifest maintenance.** The instrumentation manifest, its compiled resource DLL, and the channel definitions are artifacts that must be version-controlled and maintained; this cost does not exist with Forwarded Events.
- **Configuration consistency.** Every collector within a group must remain identical, the same channels, the same subscription definitions, the same retention settings. Drift between collectors in a group produces unpredictable behavior and is a real operational risk to manage.
- **More testing surface.** Adding or changing a subscription now touches the collector, the channel, the agent, and the SIEM, rather than a single shared log, so validation effort is higher.
- **Documentation becomes part of the solution.** The architecture is no longer self-explanatory from a single log; the subscription-to-channel-to-collector mapping must be documented to remain operable.

### Constraints That Shaped the Design

The architecture reflects several common enterprise constraints, named here as classes rather than specifics:

- **A preference for native platform capability** over introducing additional endpoint agents, which is why the design is built on WEF, WEC, WinRM, Group Policy, and the event-logging framework.
- **An existing centralized policy infrastructure**, which the design assumes can be used as the control plane for collector discovery and distribution.
- **Operability by support teams, not only engineers**, which favored a bounded number of collector groups and explicit, traceable configuration over maximal segregation.
- **Downstream SIEM ingestion requirements**, which shaped the channel-separation strategy: the architecture was designed for the whole pipeline through to the monitoring platform, not for forwarding in isolation.
- **Change-control requirements**, which favored structures that are explicit, traceable, repeatable, and auditable, since in these environments a telemetry change is an operational change.

---

## Implementation Reference

This section covers the mechanics: defining custom channels through an instrumentation manifest, compiling and registering them, writing category-based subscriptions with precise suppression, and distributing collector discovery through Group Policy. The examples use generic channel names and standard, publicly documented Windows event IDs; adapt both to the telemetry your own environment collects.

### Subscriptions and Channels Are Different Objects

Before the mechanics, one distinction that the rest of this section depends on. A **subscription** defines *what* is collected: the source log, the event IDs, and the suppression logic. A **channel** defines *where* collected events land: a dedicated log on the collector. They are named consistently so the mapping is obvious (a Security event subscription writing to a Security-Events channel, for example), but they are distinct objects created through different mechanisms. The subscription is authored with `wecutil`; the channel is defined in a manifest and registered with `wevtutil`. A subscription targets a channel as its destination; the channel does not know or care which subscription feeds it.

### Defining Custom Event Channels

Custom channels are declared in an **instrumentation manifest**, an XML file (`.man`) that describes a provider and the channels it owns. The manifest is compiled into a resource-only DLL, and the DLL is registered with the operating system so the channels appear in Event Viewer under Applications and Services Logs and can be targeted as subscription destinations.

A minimal manifest defines one provider and its channels. The following illustrates the structure with generic channel names, using a shared `Collected-` prefix so the channels group under a single parent node in Event Viewer:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<instrumentationManifest xmlns="http://schemas.microsoft.com/win/2004/08/events">
  <instrumentation>
    <events xmlns="http://schemas.microsoft.com/win/2004/08/events">
      <provider name="CollectedEventChannels"
                guid="{PROVIDER-GUID-HERE}"
                symbol="CollectedEventChannels"
                resourceFileName="C:\Windows\System32\CollectedEventChannels.dll"
                messageFileName="C:\Windows\System32\CollectedEventChannels.dll">

        <channels>
          <importChannel name="System" chid="C1"/>
          <channel name="Collected-Security"   chid="Collected-Security"   symbol="COLLECTED_SECURITY"   type="Operational" enabled="true"/>
          <channel name="Collected-Sysmon"     chid="Collected-Sysmon"     symbol="COLLECTED_SYSMON"     type="Operational" enabled="true"/>
          <channel name="Collected-PowerShell" chid="Collected-PowerShell" symbol="COLLECTED_POWERSHELL" type="Operational" enabled="true"/>
          <channel name="Collected-System"     chid="Collected-System"     symbol="COLLECTED_SYSTEM"     type="Operational" enabled="true"/>
        </channels>

        <events>
          <event value="100" version="0" channel="Collected-Security" symbol="DUMMY_EVENT"/>
        </events>

      </provider>
    </events>
  </instrumentation>
</instrumentationManifest>
```

Several details in that manifest are worth calling out, because they are the parts that are easy to get wrong or to misread:

**`importChannel` versus `channel`.** These do two different things. `<channel name="Collected-Security" .../>` **defines a new** channel; the name is yours to choose. `<importChannel name="System" chid="C1"/>` **references an existing, built-in** channel by its real name; it does not create anything. The imported name must be exactly `System` because it is a reference to the operating system's own System log, not a label you are free to change. This is why a categorized design can show two entries that both read "System" in Event Viewer without conflict: the imported built-in `System` log (under Windows Logs) and a separately defined custom channel such as `Collected-System` (under the provider's own parent node) are different objects. The import is a reference; the defined channel is new.

**The parent node in Event Viewer.** Channels whose names share a prefix before the hyphen (`Collected-Security`, `Collected-System`, and so on) are grouped by Event Viewer under a single `Collected` parent under Applications and Services Logs, which is what produces the clean per-provider folder of category channels.

**The placeholder ("dummy") event.** A provider manifest requires at least one event definition to compile, even when the provider itself never writes events. In this architecture the custom channels only ever hold *forwarded* events written by subscriptions, not events the provider generates itself, so a single minimal placeholder event exists purely to satisfy the manifest requirement. It is never emitted. Without it, the manifest will not compile; with it, the channels register correctly and stand ready to receive forwarded events.

**Channel naming convention.** The visible channel `name` uses hyphens (`Collected-Security`); the `symbol` uses underscores (`COLLECTED_SECURITY`). This is a manifest requirement, not a style choice: symbols are C identifiers and cannot contain hyphens.

> **Note on the channel limit.** A single provider in an instrumentation manifest supports a maximum of **eight channels**, counting both channels you define and any channels you import together. In the example above, one imported channel (System) plus four defined channels is five, within the limit. In practice, a convention of capping at **seven** channels per provider is common; this originated from a limitation in the now-deprecated `ecmangen` manifest-authoring tool rather than from the schema itself, so hand-authored or script-generated manifests can use the full eight. To scale beyond eight channels, define **multiple providers** within the manifest (or across multiple manifests), each with its own GUID and its own set of up to eight channels. There is no practical limit on the number of providers, so total channel capacity scales by adding providers, not by trying to exceed the per-provider ceiling. This limit is one of the real forces that shapes a categorized, multi-provider design: a single environment collecting many telemetry categories will cross the eight-channel line and must split its channels across providers, which aligns naturally with splitting collection across collector groups by category.

### Compiling and Registering the Manifest

The manifest is turned into a registered, resource-only DLL through a four-step build using tools from the Windows SDK and the Visual C++ toolchain. Each step consumes the output of the previous one:

```
:: 1. Compile the manifest into a header and a resource script.
::    Produces CollectedEventChannels.h and CollectedEventChannels.rc
::    (plus the message and template BIN resources).
mc.exe CollectedEventChannels.man

:: 2. Compile the resource script into a binary resource.
::    Produces CollectedEventChannels.res
rc.exe CollectedEventChannels.rc

:: 3. Link the compiled resource into a resource-only DLL.
::    /NOENTRY marks it as having no executable entry point;
::    /DLL and /MACHINE match the target platform.
link.exe /DLL /NOENTRY /MACHINE:X64 /OUT:CollectedEventChannels.dll CollectedEventChannels.res

:: 4. Copy the DLL to the path declared in the manifest, then
::    register the provider and its channels with the OS.
copy CollectedEventChannels.dll C:\Windows\System32\
wevtutil im CollectedEventChannels.man
```

After `wevtutil im` (install manifest) completes, the custom channels appear in Event Viewer under Applications and Services Logs and can be set as subscription destinations. To remove them, `wevtutil um CollectedEventChannels.man` (uninstall manifest) unregisters the provider and its channels. The DLL is resource-only: it contains no code, only the channel and message definitions the event log service reads, which is why it is linked with `/NOENTRY`.

Each collector in a group runs the same manifest and DLL, so that every collector in the group exposes an identical set of channels. Keeping that manifest under version control, and treating any change to it as a change that must be applied uniformly across the group, is what prevents the configuration drift called out in the trade-offs.

### Writing Category-Based Subscriptions

Each subscription is a source-initiated subscription that selects one category of telemetry and writes it to the matching channel. Subscriptions are authored as XML and registered with `wecutil cs` (create subscription). The essential elements are the query (what to collect and what to suppress), the destination channel (`LogFile`), the delivery mode, and the target endpoints.

The query follows a **select broadly, suppress precisely** structure: a `Select` clause defines the potentially valuable event population, and one or more `Suppress` clauses remove specific, verified-benign activity.

The query examples below are shown in their raw, readable form, the same way a query appears when copied directly from a subscription or authored in the Event Viewer query editor. When a query is embedded inside a full subscription definition file, its markup is stored either escaped or wrapped in a CDATA section; the query logic is identical in every case, so the raw form is used here for clarity. Values such as process paths are shown as generic placeholders.

The following illustrates a subscription that selects a set of events and writes them to a dedicated channel:

```xml
<Subscription xmlns="http://schemas.microsoft.com/2006/03/windows/events/subscription">
  <SubscriptionId>Category-Events-Subscription</SubscriptionId>
  <SubscriptionType>SourceInitiated</SubscriptionType>
  <Description>Collects a category of events from Windows endpoints</Description>
  <Enabled>true</Enabled>
  <Uri>http://schemas.microsoft.com/wbem/wsman/1/windows/EventLog</Uri>
  <ConfigurationMode>Custom</ConfigurationMode>

  <Delivery Mode="Push">
    <Batching>
      <MaxItems>50</MaxItems>
      <MaxLatencyTime>30000</MaxLatencyTime>
    </Batching>
    <PushSettings>
      <Heartbeat Interval="60000"/>
    </PushSettings>
  </Delivery>

  <Query>
    <QueryList>
      <Query Id="0" Path="<source-log>">
        <!-- Select broadly: the events of interest -->
        <Select Path="<source-log>">
          *[System[(EventID=<id-1> or EventID=<id-2> or EventID=<id-3>)]]
        </Select>
        <!-- Suppress precisely: a verified-benign, high-volume case -->
        <Suppress Path="<source-log>">
          *[System[(EventID=<id-3>)]]
          and
          *[EventData[Data[@Name="<field-name>"]="<benign-value>"]]
        </Suppress>
      </Query>
    </QueryList>
  </Query>

  <!-- Destination: the dedicated custom channel -->
  <LogFile>Category-Events</LogFile>

  <ReadExistingEvents>false</ReadExistingEvents>
  <TransportName>HTTP</TransportName>
  <ContentFormat>RenderedText</ContentFormat>
  <Locale Language="en-US"/>
</Subscription>
```

The `LogFile` element is where categorized collection actually happens: instead of the default `ForwardedEvents`, the subscription names a dedicated custom channel as its destination. Each category's subscription names its own channel the same way.

Representative event IDs per category, all standard and publicly documented, that a category-based design commonly separates:

| Category | Source log | Representative event IDs |
|---|---|---|
| Security | Security | 4624 (logon), 4634 (logoff), 4672 (special privileges), 4688 (process creation), 4673 (privileged service) |
| Sysmon | Microsoft-Windows-Sysmon/Operational | 1 (process create), 3 (network connect), 7 (image load), 11 (file create), 13 (registry set) |
| PowerShell | Microsoft-Windows-PowerShell/Operational | 4103 (module logging), 4104 (script block logging) |
| Endpoint protection | Microsoft-Windows-Windows Defender/Operational | 1116 (malware detected), 1117 (action taken), 5001 (real-time protection disabled), 5007 (exclusion changed) |
| Firewall | Security | 5152 (packet blocked), 5156 (connection allowed), 5157 (connection blocked) |

### Suppression Patterns

Suppression removes verified-benign activity before it is collected. Three patterns cover most cases:

**Suppress a specific event by an attribute value.** Remove a high-volume event only when a named field matches a known-benign value. The `Select` and `Suppress` clauses target the same event ID; the suppression does not drop the event type, it drops the subset where a named field matches a verified-benign value, keeping the event for every other case:

```xml
<QueryList>
  <Query Id="0" Path="<source-log>">
    <!-- Select broadly: collect all events of this ID -->
    <Select Path="<source-log>">
      *[System[(EventID=<id>)]]
    </Select>
    <!-- Suppress precisely: drop only the known-benign, high-volume subset -->
    <Suppress Path="<source-log>">
      *[System[(EventID=<id>)]]
      and
      *[EventData[Data[@Name="<field-name>"]="<benign-value>"]]
    </Suppress>
  </Query>
</QueryList>
```

The `and` combined with the `EventData` field match is what makes the suppression precise: only events whose named field equals the benign value are removed; every other instance of the same event ID is still collected. The field matched on is whichever attribute cleanly identifies the benign activity, commonly a process identity or a network destination (for example `Image`, `CommandLine`, `ParentCommandLine`, or `DestinationIp`), depending on the event and the noise being removed.

**Suppress across multiple values.** Combine conditions to remove several known-benign variants of an event in one clause, rather than writing a separate subscription for each.

**Suppress by source attributes for network, registry, or file events.** For high-volume telemetry such as network connections or registry writes, suppress on the attribute that identifies the benign source (a specific signed process, a specific expected destination) rather than dropping the event ID wholesale, so that the same event ID is still collected for everything not on the verified-benign list.

Every suppression is security-relevant configuration. Because a suppression decides what security data is never collected at all, each one should be baselined against real data before it is applied, documented with the reason it exists and who owns it, reviewed by the people who consume the telemetry for detection, and revalidated after significant operating-system, agent, or application changes that could alter the field values the suppression matches on.

### Group Policy: Collector Discovery and Distribution

Source-initiated collection is driven by a single Group Policy setting that tells endpoints where their collectors are. The setting is:

```
Computer Configuration
  > Administrative Templates
    > Windows Components
      > Event Forwarding
        > Configure target Subscription Manager  →  Enabled
```

Its value is one or more **SubscriptionManager** strings, each naming a collector, the transport port, and a refresh interval. Over the default WinRM HTTP transport with Kerberos authentication:

```
Server=http://<collector-fqdn>:5985/wsman/SubscriptionManager/WEC,Refresh=60
```

Multiple entries can be listed so endpoints have more than one collector to register with. Over HTTPS (certificate-authenticated transport, WinRM port 5986) the form is:

```
Server=https://<collector-fqdn>:5986/wsman/SubscriptionManager/WEC,Refresh=60
```

**Horizontal distribution across collector groups** is achieved by scoping different Subscription Manager policies to different portions of the fleet. Rather than pointing every endpoint at every collector, separate Group Policy Objects, each carrying a different SubscriptionManager value, are linked to different organizational units, so that each OU's endpoints register with a specific collector or collector group. This load-balances the fleet across the collection tier by policy, and it is the point at which the *category* axis (subscriptions and channels) and the *collector-group* axis (which OUs point at which collectors) come together: one group of collectors, targeted by one set of OUs, hosts one coherent set of category subscriptions and their channels.

Endpoints also need WinRM running and reachable on the collectors, and, for the default transport, the collectors' computer accounts resolvable through Kerberos. These are the standard WEF source-initiated prerequisites and are not specific to this pattern.

---

## Operational Guidance

### Capacity and Channel Sizing

Collector capacity is bounded by three things: the number of source endpoints a collector serves, the complexity and number of its subscriptions, and the I/O the channel volume can sustain. A collection tier is sized against all three, not against endpoint count alone. The Windows Event Collector service has practical limits on concurrent sources per collector that are reached well before raw hardware limits, and those limits move depending on subscription complexity, so capacity planning is done per deployment rather than assumed.

Channels are sized per category according to expected volume, not uniformly. This matters because telemetry categories differ in throughput by more than an order of magnitude: high-volume categories such as process, script, network, and firewall telemetry can dwarf low-volume categories such as application-control, print, or endpoint-protection status events. Giving every channel the same maximum size would either waste space on the light categories or starve the heavy ones. Each channel's maximum size and its retention or rollover behavior are set to match how fast that category actually produces events and how long its events must remain available on the collector before the downstream agent has consumed them.

The downstream side has to keep up with the upstream side. If the collection agent draining a channel falls behind the rate at which events arrive, the channel fills and begins to roll over, and events can be lost before they are ingested. This backpressure is monitored directly: a channel filling faster than it is being drained is a signal to investigate, not something the runtime status of a subscription will reveal on its own. Healthy ingestion is confirmed by validating end-to-end event flow through the channel and into the downstream platform, not by subscription status alone (see below).

### Validating the Pipeline End to End

Because the architecture has more moving parts than a single shared log, validation checks each stage of the flow rather than only the final destination:

**At the endpoint.** Confirm the endpoint has received the Subscription Manager policy and has registered. `Microsoft-Windows-Eventlog-ForwardingPlugin/Operational` on the endpoint records subscription retrieval and forwarding activity, and is the first place to look when an endpoint is not forwarding. Confirm WinRM is running and the collector is reachable on the configured port.

Event IDs in the forwarding and WinRM operational logs can vary across Windows versions, so validate against the actual events on a current endpoint rather than relying on a fixed list.

**At the collector.** Confirm each subscription is active and shows source endpoints. `wecutil gs <subscription-id>` (get subscription) and `wecutil gr <subscription-id>` (get runtime status) report a subscription's configuration and its active sources. In Event Viewer, the subscription's runtime status shows connected source computers and any errors.

**At the channel.** Confirm forwarded events are landing in the correct dedicated channel, not in the default ForwardedEvents log. Each category's events should appear in its own named channel; events arriving in ForwardedEvents instead usually mean a subscription's `LogFile` destination is not set to the custom channel.

**At the SIEM.** Confirm the collection agent is reading the named channels and events are reaching the platform, with the kind of separation the design is meant to deliver: each category distinguishable downstream rather than arriving as one mixed stream.

### Failure Modes and What They Indicate

| Symptom | Likely cause | Where to look |
|---|---|---|
| An endpoint is not forwarding at all | Subscription Manager policy not applied, or WinRM not running / not reachable | Endpoint forwarding operational log; `gpresult`; WinRM service and connectivity to the collector port |
| Events arrive, but in ForwardedEvents instead of the custom channel | Subscription `LogFile` not pointing at the dedicated channel | Subscription XML `LogFile` element; re-register with the corrected destination |
| A subscription shows no source computers | Endpoints not registering with this collector, scoping or Kerberos issue | Subscription runtime status; the OU-to-collector policy mapping; Kerberos name resolution for the collector |
| Custom channels missing from Event Viewer | Manifest not registered, or DLL not at the declared path | Confirm `wevtutil im` succeeded and the DLL is at the `resourceFileName` path in the manifest |
| One collector behaves differently from others in its group | Configuration drift, manifest, channels, or subscriptions differ between collectors | Compare manifest version, registered channels, and subscription definitions across the group |
| A high-volume category degrades collection | Insufficient suppression, or a category sharing a collector group with another heavy category | Subscription suppression clauses; the category-to-collector-group allocation |

The failure mode that most directly drove this architecture was the first-order one: collector performance degradation and instability when a large volume of telemetry was funneled through a single, common collection path. Expanding the collector tier, splitting subscriptions by category, and directing them into dedicated channels resolved the performance and stability problems that the common-path design had produced.

A separate operational lesson is worth stating on its own, because it is easy to get wrong: a subscription's runtime status is not, by itself, proof of healthy ingestion. A subscription can report active sources while events are not actually reaching the downstream platform. Ingestion health is confirmed by validating the full path, endpoint to channel to agent to SIEM, rather than trusting runtime status alone.

Beyond these, the broader community documents several WEF failure modes that are worth monitoring for even if they do not drive the initial design: subscriptions going inactive after a collector reboot, sources silently dropping out of a subscription over time, runtime-status source counts that do not match reality, and a single malformed subscription affecting a collector. These are known concerns to watch operationally; they are noted here for completeness rather than presented as the primary drivers of this particular architecture, which was shaped mainly by performance, manageability, event segregation, and downstream ingestion reliability.

### Change Control for Subscriptions and Suppression

In this architecture a telemetry change is an operational change, and treating it that way is part of the design. Adding or modifying a subscription touches the collector, the channel, the agent, and the SIEM, so changes are validated across that whole path rather than assumed from the subscription alone. Suppression changes carry additional weight because they decide what security data is never collected: each is baselined, documented with a reason and an owner, reviewed with the telemetry's consumers, and revalidated after significant platform or application changes. The subscription-to-channel-to-collector mapping is documented and kept current, because, unlike a single shared log, this architecture is not self-explanatory from inspection alone, and its operability depends on that mapping being written down.

### Lifecycle and Maintenance

The manifest, its resource DLL, and the subscription definitions are versioned artifacts. Any change to the manifest (adding a channel, adding a provider to cross the eight-channel boundary) is applied uniformly across every collector in a group to prevent drift. When a collector is rebuilt, the manifest is re-registered and the subscriptions re-created as part of the build, so a rebuilt collector re-enters its group with an identical channel and subscription set. Because collection is source-initiated and driven by Group Policy, endpoints require no per-device reconfiguration as they join, leave, or are rebuilt; they receive the Subscription Manager policy and register on their own.

---

## Related Patterns

- **[Sysmon configuration pattern](../sysmon-configuration-via-native-policy)**: decoupling Sysmon configuration delivery from binary redeployment, the same decoupling philosophy this pattern applies to telemetry collection, and a natural upstream companion where Sysmon is one of the collected categories.

## Disclaimer

This document is provided as reference material and architectural guidance. The design described has been shaped in specific environments and may require adaptation for others. Command syntax, event IDs, log channel names, and tool behavior vary across Windows versions and toolchains; validate in a controlled setting before production use. Standard Windows event IDs are cited as representative examples and should be confirmed against the actual events observed in your environment.
