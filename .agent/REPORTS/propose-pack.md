<!-- GENERATED-BY: propose/propose.sh on 2026-09-09T19:51:34Z -->
<!-- Pairings dir: /Users/stephen/.dotagent/pairings -->

# Pair Proposal — Interview Pack

You are conducting a short, structured interview to help the user
select **pairings** for a project. A pairing is a domain-specialized
rendition of the user's principles in a specific area (a language,
framework, methodology, hardware domain, or skill). The user runs
this pack at project bootstrap (or when revisiting an existing
project) to figure out which existing pairings fit and where gaps
remain.

Read the **Available pairings** catalog below, then conduct the
interview as described in the **Interview** section, then produce a
recommendation in the **Output format** the user expects.

---

## Available pairings

### `accessibility`

- **Title:** Accessibility (Non-Default Modality as an Engineering Surface)
- **Pairs with:** Building and demonstrating web interfaces that are **operable and comprehensible through a modality other than the one the author develops in** — screen reader, keyboard only, magnification and 400%-equivalent reflow, voice control, forced-colors/high-contrast palettes, reduced motion. It owns the *computed accessibility tree* as the real output surface, the keyboard graph as a complete graph (focus placement on route change, dialog open/close, async insertion, and node removal), programmatic labelling and error linkage, contrast and target-size thresholds, live-region announcement policy, and the **conformance model itself** — what a WCAG level claims, what it does not, and how each claim is demonstrated rather than asserted. Not the visual-design side (how the eye parses a screen, hierarchy, rhythm), not the interaction-behavior side (timing, feedback choreography, state over time), not the layout-resilience side (how a grid survives hostile content).
- **Touches principles:** #1, #2, #4, #5, #6, #7, #9, #10, #12, #13, #15, #17, #18, #19, #20
- **Preamble:** Every other frontend defect announces itself in the medium you are working in: a broken layout is visible, a thrown exception is in the console, a wrong number is on the screen. Accessibility defects are **invisible by construction to the person who caused them**, and for a structural reason. The artifact the user consumes is not the artifact you authored — the browser computes an **accessibility tree** from DOM plus CSS plus ARIA, the platform accessibility API exposes that tree, and the assistive technology renders it with its own heuristics. Three derivations sit between your source and the user, none of them shown in a diff and none of them shown on screen. Then the safety net leaks: on the tool vendor's own published measurement, automation catches **57.38%** of issues by volume, and the traditional figure for *success criteria* that are machine-decidable is 20–30%. So the default state of this domain is a silent failure in a derived surface, consumed through a modality nobody on the team is running, guarded by a checker that is right about a minority of it. Every principle below specializes around that: **make the derived surface observable, make the non-default modality something a machine actually drives, and never let a green checker stand in for a claim.**

### `admin-dashboards`

- **Title:** Admin Interfaces & Dashboards
- **Pairs with:** admin/operational interface design as an organizational discipline — the information architecture of data-dense back-office UIs: navigation systems derived from operator jobs, entity collection→detail structure, dashboard composition (overview first, zoom and filter, details on demand), tables/filters/bulk actions, and role-scoped organization. Covers *how the product is organized* — where things live, how screens relate, what the operator sees first. Out of scope: the general visual layer (typography, spacing scales, design-system tokens) — except the instrument register under #24, whose token, readout and reflow rules this pairing owns because they are what makes N rows one register — the cognitive layer (mental-model formation, recognition vs. recall), and the interaction-behavior layer (feedback timing, microinteractions, latency budgets).
- **Touches principles:** #1, #2, #4, #6, #7, #8, #9, #10, #13, #24
- **Preamble:** Admin interfaces are the UIs where **organization is the product**. A consumer app can win on a single polished flow; an admin tool wins or loses on whether an operator can find the entity, judge its state, and act on it — hundreds of times a day, across thousands of records. The failure mode is never one ugly screen; it is *accretion*: screens added one request at a time until the navigation is an archaeology of the backlog, the dashboard is a parking lot for widgets, and every list reimplements its own filters. This pairing colors the principles for that terrain — where the load-bearing design artefact is the organizational scheme, not any individual screen.

### `agent-memory`

- **Title:** Agent Memory
- **Pairs with:** any store an autonomous or semi-autonomous agent writes to and later reads back as fact about a world it cannot re-observe — conversational memory, user profiles and preference stores, scratchpads and working notes, retrieval corpora built from prior sessions, summaries of truncated context, learned heuristics, cached tool results, handoff artifacts between agents, and the system-prompt material assembled from any of these. Covers what may be written, what may enter the working set, and what may be asserted from it. Out of scope: the retrieval mechanism itself (an information-retrieval concern), model behavior given a context (a modeling concern), and the storage substrate (an infrastructure concern).
- **Touches principles:** #2, #7, #9, #12, #13, #15, #17, #18, #21, #22
- **Preamble:** Memory is what makes an agent useful across time and what makes it confidently wrong. Both come from the same property: a remembered fact is asserted without being re-checked, because not re-checking is the entire point.

### `agile-methodologies`

- **Title:** Agile Methodologies
- **Pairs with:** Agile software project management — the value system and its four working traditions (Scrum, Kanban, XP, Lean) as a *methodology family*, not one framework.
- **Touches principles:** #1, #2, #3, #6, #7, #9, #10, #11, #12, #13, #14, #16, #17
- **Preamble:** Agile is not a process you install; it is a bet that **value emerges fastest through short feedback loops over a working increment**, and that the plan is a living artifact you inspect and adapt rather than a contract you execute. The four traditions emphasize different loops — Scrum a *time-boxed cadence* and empirical control (transparency → inspection → adaptation), Kanban *continuous flow* under work-in-progress limits, XP *engineering feedback* (tests, pairing, small releases), Lean *waste elimination* and deferring commitment to the last responsible moment — but they share one spine: reality is discovered by shipping, so optimize the loop that exposes it. The principles below show where that spine already lives inside this collection's framing, and where agile sharpens a principle the collection states more generally.

### `android`

- **Title:** Android
- **Pairs with:** native Android development — Kotlin, Jetpack Compose, the lifecycle and process model, coroutines/Flow, the official app-architecture layering (UI / domain / data), background-work scheduling, the permission model, and the realities of an OS that kills your process, fragments across API levels and OEMs, and meters your battery use. Covers the platform layer: how Android's execution model shapes design. Out of scope: cross-platform wrappers (Flutter/RN/Capacitor have their own pairings if needed), Play Store release operations, and visual design language (Material is referenced only where it is architecture).
- **Touches principles:** #2, #4, #6, #7, #8, #9, #10, #13
- **Preamble:** Android's defining fact is that **your process is a guest**. The OS recreates your UI on rotation, kills your process in the background and resurrects it expecting yesterday's state, defers your scheduled work to save battery, and runs your code on thousands of device/OS/OEM permutations you will never see. Designs that treat the happy path — app foregrounded, process alive, permission granted, network up — as *the* path aren't simplified; they're wrong, and they fail in the field where you can't attach a debugger. Every principle below is the general principle bent around that fact.

### `arch-linux`

- **Title:** Arch Linux
- **Pairs with:** Arch Linux and Arch-derived rolling distributions (developed on CachyOS; nothing here is CachyOS-specific). Applies to any project that *configures a machine* — dotfiles repos, system-provisioning scripts, declarative `/etc` + `~` management — on a pacman/ALPM base.
- **Touches principles:** #2, #5, #6, #7, #8, #9, #13, #14
- **Preamble:** Arch gives you a bare, rolling, *unopinionated* base: no distro-blessed config layer, no `dconf`-style central store, no "the distro will reconcile it for you." Whatever shape your machine has, **you** imposed it, and a rolling release means the ground moves under that shape continuously. The principles below specialize for the two facts that dominate Arch system-config: there is no authority but yours (so reproducibility is a build artifact, not a given), and the package manager owns a large slice of the filesystem you are tempted to edit (so boundaries are not negotiable — pacman will win).

### `audio-circuitry`

- **Title:** Audio Circuitry (Analog + Digital)
- **Pairs with:** Audio signal-chain design end-to-end — analog (signal levels, impedance, gain staging, filtering, op-amp circuits, grounding/shielding) and digital (ADC/DAC, sample rate, bit depth, clock domains, I²S/TDM framing, anti-aliasing/reconstruction). Applies to any project with an audio input or output stage, from a single line-out to a full multi-channel mixer.
- **Touches principles:** #4, #5, #6, #7, #8, #9, #13
- **Preamble:** The audio signal chain is mixed-signal end-to-end. Analog and digital are not separate worlds — they are stages of one path, and the worst failure modes happen at the boundaries between them (the codec, the power-supply rails feeding both domains, the ground topology). The principles below treat the chain as a single engine with substages, and call out the analog/digital boundary as the most failure-prone point in the entire signal path.

### `azure-app-service`

- **Title:** Azure App Service
- **Pairs with:** Azure App Service for hosting Node.js web applications (SvelteKit with adapter-node, Express, Fastify, and similar). Covers deployment, scaling, authentication, networking, diagnostics, and operational concerns.
- **Touches principles:** #1, #2, #4, #5, #7, #8, #9, #10, #13
- **Preamble:** Azure App Service is a managed PaaS hosting layer. It handles TLS termination, identity, health probing, deployment orchestration, scaling, and networking — your application handles business logic and its own internal state. The line between what the platform owns and what your code owns is sharp, well-documented, and routinely crossed by applications that don't know where it is. This pairing maps the principles onto that boundary.

### `azure-communication-services`

- **Title:** Azure Communication Services
- **Pairs with:** Azure Communication Services (ACS) as a **security surface** — the trust boundary of an app that sends through ACS, with emphasis on **Email Communication Services**: the data-plane authentication model (access-key/connection-string vs Microsoft Entra managed identity, `disableLocalAuth`), the sender-domain trust chain (Azure-managed vs custom verified domains, SPF/DKIM/DMARC, the verify-then-`linkedDomains` anti-spoof gate, MailFrom sender usernames), the blast radius of a leaked ACS credential, per-subscription rate limits and managed/custom suppression, engagement-tracking privacy, data-location/residency, the (evolving) network-lockdown levers, and the observability surface (diagnostic settings, Event Grid delivery/engagement events). Covers "who can send as this domain, what a stolen ACS key unlocks, and how tenants stay isolated on a shared sending resource." Out of scope: the ACS Calling/Chat real-time-comms model (user-access-token security is its own concern) except where it shares the key blast radius, and the hosting/identity substrate ACS runs on (`azure-infra`, `entra-id`).
- **Touches principles:** #1, #2, #4, #5, #7, #9, #10, #13
- **Preamble:** ACS is a *credential-fronted public endpoint*: its data plane is reachable from the internet and gated by whatever authenticates the request — historically a symmetric access key, and that key is a bearer credential for the **entire resource**. The security of an ACS deployment is therefore three questions, decided together: *how does the app authenticate to ACS* (a static key is a long-lived secret that sends as every linked domain; an Entra managed identity is not), *who is allowed to send as this domain* (ACS proves domain ownership and requires an explicit link, but does not know your tenants), and *how are tenants kept from spending each other's reputation and quota* (a single ACS resource has **no** internal tenant boundary — isolation comes from how many resources you carve). The recurring failure is treating "we send through Azure" as a deliverability-and-done integration and inheriting a static key, a shared resource, and an unmonitored bounce rate — three separate ways to burn a domain's reputation or hand an attacker an authenticated mail cannon. This pairing maps the principles onto that boundary.

### `azure-fleet-control-plane`

- **Title:** Azure Fleet Control Plane (Multi-Tenant Resource-Group Access)
- **Pairs with:** Building an **external control plane that reads across a fleet of isolated, per-tenant Azure resource groups** — one resource group per customer instance, each its own blast radius (own VNet, no peering, private data plane), observed from a single control-plane app that sits *outside* every instance. Covers how that control plane **discovers, reaches into, and reads** each instance's resource group: the coordinate source (a metadata registry vs. live ARM/Resource-Graph discovery), the identity/RBAC *reach* into N resource groups, programmatic Azure Monitor / ARM access via a managed identity, and per-resource-group independent degradation. This is the **fleet read-access** axis — distinct from standing the footprint up (`azure-infra`, `terraform`), hosting one app (`azure-app-service`), and single-subscription CLI reporting (`azure-resource-management`). Where `azure-resource-management` reports on *one* subscription via `az`, this owns a *control plane* reaching programmatically into *many* isolated resource groups it provisioned.
- **Touches principles:** #1, #2, #4, #5, #6, #7, #9, #10, #13
- **Preamble:** A fleet control plane has one defining property that drives every principle below: **the resource group is simultaneously the isolation unit and the access unit.** The same per-instance resource group that makes one customer's outage structurally unable to touch another's (no peering, private endpoints, own RBAC scope) is *also* the boundary the control plane must reach across to read N instances at once — and it must do so without ever becoming a route *between* instances or a data path *into* one. The control plane therefore reads each resource group on its own identity, on its own coordinate, with its own independent failure — and the whole skill is keeping "how I find the resource group," "how I'm allowed to reach it," and "what I read from it" on three separate axes, while being honest that "I can see the fleet" only ever means the union of the resource groups my identity is actually granted and the metrics each one actually emits.

### `azure-infra`

- **Title:** Azure Infrastructure (Provisioning Architecture)
- **Pairs with:** Architecting **declarative Azure infrastructure** — Container Apps (and Container Apps Environments), managed identity, Key Vault references, private endpoints / VNet isolation, ACR, AAD-auth'd storage backends. The **"how the resources are shaped, identified, secured, and isolated"** side of Azure — independent of the IaC tool that applies them (`terraform`, Bicep, ARM) and independent of the read/report (`azure-resource-management`), classic-host/deploy (`azure-app-service`), identity-provider (`entra-id`), and M365 (`microsoft-graph`) surfaces. Where those cover *talking to* Azure, this covers *standing up* a secure, isolated, identity-first Azure footprint.
- **Touches principles:** #1, #2, #4, #5, #6, #7, #9, #10, #11, #13
- **Preamble:** Azure's provisioning model has one property that drives every principle below: **identity, secrets, and network are three separate planes that must be wired together, and the seams between them are where security and reliability are won or lost.** A managed identity is useless without a role assignment; a role assignment is useless until it propagates; a Key Vault reference is useless without the identity that reads it; a private endpoint silently breaks reachability if DNS isn't wired. The platform gives you primitives that *compose into* a secure footprint — but it does not enforce that you compose them correctly. This pairing is about keeping those three planes on their own axes and being honest about Azure's asynchronous, eventually-consistent control plane.

### `azure-rbac-delegation`

- **Title:** Azure RBAC Delegation (Constrained Role-Assignment Management)
- **Pairs with:** Designing and operating **delegated role-assignment management** on Azure — a principal that holds `Microsoft.Authorization/roleAssignments/write` under an **ABAC condition** that constrains which role definitions it may assign, to which principals, of which type ("constrained delegation"), and the automation that runs *under* that constraint (Terraform, Bicep, ARM, `az`). This is the **authorization plane governing the grantor**: not what a workload is allowed to do, but what the thing handing out permissions is allowed to hand out. Independent of the IaC tool that applies it, of the resource-shaping surface that decides *which* grants a footprint needs, of the identity-provider surface that mints the principals, and of the read/report surface that enumerates them.
- **Touches principles:** #1, #2, #4, #6, #7, #9, #10, #13, #17, #18, #19, #20
- **Preamble:** Every other Azure surface fails *loudly and reversibly*: a bad SKU is rejected, a missing DNS record is a lookup failure, a wrong connection string throws on first use. Constrained role-assignment delegation is different in one specific, expensive way: **the authorization decision happens per-request, mid-apply, on a resource whose every argument forces replacement.** A role assignment cannot be updated in place — change the role, the principal, or the scope and the platform destroys the old assignment and creates a new one. If the create is the request the condition refuses, you do not get a failed apply that rolls back. You get a deleted grant, no replacement, and a workload that has lost an access path it had five seconds ago. *ForceNew plus a refused create is an outage, not a rollback.* Every principle below specializes around that one asymmetry: the condition is a **policy engine evaluated at request time**, the automation is a **planner that cannot see it**, and the only place those two can be reconciled cheaply is *before the plan runs*.

### `azure-resource-management`

- **Title:** Azure Resource Management (Query & Reporting)
- **Pairs with:** Reading from and reporting on an Azure environment via the Azure CLI (`az`) and the underlying ARM / Cost Management / Monitor APIs — resource enumeration, cost/billing retrieval, and performance metrics. The **read/control-plane reporting** side of Azure: "what do I have, what does it cost, how is it performing," not deploying or hosting. Complements rather than overlaps the deployment-hosting (App Service), identity (Entra ID), and M365 (Graph) surfaces.
- **Touches principles:** #1, #2, #4, #5, #6, #7, #9, #10, #13
- **Preamble:** "Azure" is not one API. A tool that reports on a subscription is talking to at least three distinct backends — the **ARM control plane** (what resources exist), **Cost Management** (what they cost), and **Azure Monitor** (how they perform) — each with its own data model, latency, consistency guarantees, and quirks. The Azure CLI papers them over into one `az` command surface, which is convenient and a trap: the uniform front hides per-service differences that decide correctness. The principles below specialize for keeping those three engines on separate axes and being honest about what each one can and cannot tell you.

### `backup-restore-assurance`

- **Title:** Backup & Restore Assurance (Recoverability as a Provable Property)
- **Pairs with:** Designing and operating the **recovery control** of a stateful system — the backup artifacts, the restore path that consumes them, and the rehearsal that proves the second one works. Covers RPO/RTO as stated and measured bounds; the difference between a backup job that exited zero and a restore that produced a usable system; scheduled restore drills; verification of the *restored artifact* (row counts, manifests, schema/migration version, application-level smoke) rather than the dump's existence; point-in-time-recovery mechanics and what the recovery window actually costs; retention and its interaction with legal/compliance holds and immutability; encryption of backups and key availability; backup of the whole recoverable unit rather than the database alone; and partial/selective restore. This is **recoverability as a provable property** — not relational-database operations generally (schema design, query patterns, migration authoring, transaction semantics are a different axis), and not infrastructure provisioning (standing the platform up is the neighbouring surface; being able to put the *data* back into it is this one).
- **Touches principles:** #1, #2, #4, #6, #7, #9, #10, #11, #13, #14, #17, #18, #19, #20
- **Preamble:** Every other property of a running system is exercised by the traffic that uses it: a broken login fails at login, a bad index shows up as a slow query, a wrong connection string throws on first use. Recoverability is the one property whose **only consumer is a scenario that has never run**. The producing half — the dump job, the WAL shipper, the snapshot schedule — runs nightly and emits an exit code; the consuming half runs never and emits nothing. All the observability therefore accumulates on the half that is not load-bearing, and the failure modes concentrate on the half that produces no signal at all: a dump written to a container filesystem that evaporated with the replica, a manifest carrying no table data, a listing error reported as an empty archive, a role that was never in the dump, a key that lived only inside the thing that died. Cause and symptom are separated by an unbounded interval, and the symptom arrives during an incident, when the cost of learning is highest. Every principle below specializes around that single fact: **evidence about recovery has to be manufactured on a schedule, because production will never generate it.** "The backup job exited zero" is a claim about a producer whose consumer has never been run.

### `c`

- **Title:** C
- **Pairs with:** The C language (C11/C17/C23 — C23 published as ISO/IEC 9899:2024, default in GCC 15+; freestanding or hosted)
- **Touches principles:** #4, #5, #6, #7, #8, #13, #14
- **Preamble:** C gives you exactly the rope you ask for. Most of the discipline that other languages provide via type systems or runtimes, C requires you to provide via convention. The principles below show where C demands explicit choices to maintain orthogonality.

### `cloud-pentest-azure`

- **Title:** Cloud Pentest (Azure)
- **Pairs with:** Azure cloud configuration and secrets attack testing (skill / domain) — testing the deployment substrate beneath an application: platform authentication boundaries, secret exposure, managed-identity and service-principal blast radius, over-privileged credentials, and container / supply-chain exposure. Assumes an authorized context with explicit cloud scope.
- **Touches principles:** #2, #7, #9, #10, #13
- **Preamble:** An application's real trust boundary includes the cloud it runs in: the platform feature that fronts it, the environment that holds its secrets, and the identity it uses to call other services. Application code routinely assumes that substrate is safe — that the platform auth layer can't be bypassed, that environment variables are private, that the service principal it authenticates with is narrowly scoped. Cloud configuration testing checks those assumptions. The principles below specialize for the deployment trust edges rather than the application's request surface.

### `cloudflare-pages-workers`

- **Title:** Cloudflare Pages & Workers
- **Pairs with:** Hosting web applications on Cloudflare's edge — Cloudflare Pages and the Workers runtime, including `wrangler` (project config, deploy, secrets), the Workers execution model (V8 isolates, not Node), bindings (D1, KV, R2, Queues, Durable Objects, service bindings, env vars/secrets), `@sveltejs/adapter-cloudflare`, and the edge-platform services a site composes with (Cloudflare Web Analytics, Turnstile, the CDN/cache, TLS). Covers the *hosting and runtime* layer: how the edge execution model shapes application design. Out of scope: the application framework itself (SvelteKit/Svelte have their own pairings), and Cloudflare's network-security products (WAF, Zero Trust, Access) except where a site directly depends on them.
- **Touches principles:** #1, #2, #4, #5, #7, #8, #9, #10, #13
- **Preamble:** Cloudflare's edge is a managed runtime, not a server you rent. Your code runs as a V8 *isolate* spun up near the visitor in one of hundreds of locations — it boots in single-digit milliseconds, holds no durable memory between requests, runs under a CPU-time budget, and has no filesystem and no Node.js standard library unless you opt in. The platform owns TLS, the CDN, routing, DNS, static-asset serving, and a menu of *bindings* (D1, KV, R2, Queues, Durable Objects) that are the only sanctioned places to keep state. Your code owns request handling and business logic. The line between "the platform does this" and "my code does this" is sharper than on a classic VM host, and the most common failures come from writing Node-server code — in-memory caches, a local SQLite file, a background timer — that the isolate model silently breaks. This pairing maps the principles onto that boundary.

### `cloudflare-pro`

- **Title:** Cloudflare Pro Plan
- **Pairs with:** Operating zones on Cloudflare's **Pro plan tier** — the plan-entitlement axis of a Cloudflare deployment: which security and delivery capabilities the tier actually grants (WAF managed rulesets, custom-rule and rate-limit quotas, Super Bot Fight Mode, leaked-credential detection, zone lockdown, Page Shield script monitoring, security-event retention), which are must-enable versus on-by-default, which sit above the tier (Business/Enterprise-only), and which are plan-orthogonal add-ons (Advanced Certificate Manager, Turnstile, Zero Trust). Covers the *capability envelope* of a Pro zone — designing a posture from what the tier really enforces and exhausting what the tier is already paying for. Out of scope: what each security product does internally and how to configure it well (its own concern), and the hosting/runtime layer.
- **Touches principles:** #1, #2, #4, #5, #9, #10, #13
- **Preamble:** A Cloudflare plan tier is a *capability envelope*, not a switch: upgrading a zone to Pro changes what the zone **may** enforce, and almost nothing about what it **does** enforce. Nearly every security entitlement the tier adds is must-deploy or must-enable — the paid managed rulesets, Super Bot Fight Mode, leaked-credential detection, rate-limit rules, zone lockdown all ship dark. The two recurring failures are mirror images. **Designing above the tier:** generic Cloudflare guidance silently assumes Enterprise (Logpush, Bot Management scores, regex rules, long log retention), so a remediation plan written from the docs' full menu prescribes controls the zone cannot buy at its tier. **Operating below the tier:** a zone upgraded for one feature (commonly certificates) keeps its old free-tier posture, and the security entitlements the upgrade also bought sit unused — paid for, protecting nothing. This pairing maps the principles onto the envelope: derive the posture from the tier's actual contents, spend all of it, and claim nothing beyond it.

### `cloudflare-saas`

- **Title:** Cloudflare for SaaS
- **Pairs with:** Cloudflare for SaaS — running a **multi-tenant platform on custom hostnames**: tenants bring their own (vanity) domains and CNAME them onto the provider's zone, which terminates TLS and routes them to the platform. Covers the custom-hostname object and its two validation tracks (hostname ownership vs certificate DCV), DCV methods (HTTP, TXT, delegated), per-hostname edge certificates and their renewal, the fallback origin and per-hostname custom origins, hostname-priority routing and its takeover consequences, the tenant onboarding/offboarding lifecycle, orange-to-orange (tenant domain also on Cloudflare), and the operational surface (validation statuses, backoff, webhooks, API rate limits). Covers the *tenant-domain trust boundary* — what the platform's zone can do in the tenant's name, and what routes where when tenancy changes. Out of scope: the zone's general edge-security products (WAF, bot, rate limiting — their own concern) and the hosting/runtime layer.
- **Touches principles:** #1, #2, #4, #7, #9, #10, #13
- **Preamble:** Cloudflare for SaaS inverts the usual trust picture: the platform's zone terminates TLS **for domains it does not own**. Each active custom hostname is a standing grant from a tenant — "answer for my name" — and the grant's mechanics outlive intent: an exact-match custom hostname on a SaaS zone *beats the tenant's own zone DNS* whenever their traffic transits Cloudflare, delegated DCV lets the provider mint certificates for the tenant's apex and wildcard indefinitely, and none of it expires when the *relationship* does. So the load-bearing design decision is the hostname **lifecycle**, not the happy-path onboarding: every hostname the platform ever claimed must be provably released when tenancy ends, or the platform keeps receiving a stranger's traffic with a valid certificate. The engine is genuinely good — dual validation tracks, auto-renewal, webhooks for every transition — but it automates *issuance* aggressively and *cleanup* not at all. This pairing maps the principles onto that asymmetry.

### `cloudflare-security`

- **Title:** Cloudflare Security
- **Pairs with:** Cloudflare's network- and application-security product layer — the controls that sit *in front of* an origin on Cloudflare's edge: the WAF (managed + custom rulesets, rate-limiting rules, the OWASP core ruleset), DDoS protection, Bot Management / Turnstile, API Shield (schema validation, mTLS, JWT validation), Zero Trust — Access (application policies, identity providers, service tokens, device posture), Gateway, and Tunnels — plus the origin-protection primitives (Authenticated Origin Pull, Origin CA certificates, IP allowlisting, Zone Lockdown), TLS/edge-certificate posture, secrets and scoped API-token management, and the audit surface (Logpush, audit logs). Covers the *security posture and trust boundary* of an application fronted by Cloudflare — how the edge's security engine is configured, what it does and does not protect, and where the boundary can be bypassed. Out of scope: the Workers/Pages *runtime and hosting* model (its own pairing), and the application framework's own request handling.
- **Touches principles:** #1, #2, #4, #5, #7, #9, #10, #13
- **Preamble:** Cloudflare's security products are an *edge engine* that inspects, authenticates, rate-limits, and filters traffic before it ever reaches your origin — but only for traffic that actually goes through the edge, and only for the rules you configured. The recurring failure is treating "we're behind Cloudflare" as a security property in itself. It is not: an origin whose real address is reachable directly bypasses every edge control at once; a WAF in "log" mode blocks nothing; an Access application with a fail-open policy or an over-broad `Everyone` rule authenticates no one. The edge is a real security boundary exactly to the degree that (a) all traffic is forced through it, (b) the rules are in enforcing mode, and (c) the origin trusts *only* the edge. This pairing maps the principles onto that boundary — the configured controls, the bypass paths, and the honest blast radius of a Cloudflare credential.

### `container-apps`

- **Title:** Azure Container Apps
- **Pairs with:** Running a workload on **Azure Container Apps** — the *runtime and execution* surface of the platform: the environment → app → revision → replica hierarchy and which of its settings are irreversible after creation; the KEDA-backed scaling engine, its rule types and its **fixed, non-configurable timing constants**; the replica sizing case-space (the allowed vCPU/memory pairs, workload-profile ceilings, vertical-scaling absence); the three health probes as the contract by which the app tells the platform what "alive," "started," and "ready for traffic" mean; cold start as a budget you spend on every scale-out and every revision; ingress behavior at runtime (fixed request timeout, session affinity, client certificates, traffic splitting); **jobs** as the finite-duration execution shape beside always-on apps; and the revision-scope/application-scope split that decides whether a change is even visible to a running container. This is the **"how the platform behaves while your code is running"** axis — not how the resources are shaped, secured, identified, or networked at provisioning time (a neighbouring surface that treats replica counts as the platform's business), not the IaC tool that applies them, not the topology question of how many copies of the whole system exist, and not a different host's runtime (App Service's Always On, ARR affinity, and `/home` CIFS mount are a different platform's physics).
- **Touches principles:** #1, #2, #4, #5, #6, #7, #9, #13, #14, #17, #19, #20
- **Preamble:** Container Apps hides Kubernetes and hands back a small, opinionated set of dials — and the discipline of this domain is knowing **which dials exist, which are fixed, and which can never be changed again after creation**. Three facts organise everything else. First, the **revision is immutable**: you never mutate a running app, you produce a new snapshot, which makes the deploy/serve boundary a platform property rather than a convention you maintain. Second, **the platform is the engine and the probes are how you talk to it**: liveness, readiness, and startup are not monitoring, they are the app's declaration of its own lifecycle, and every "mysteriously restarting container" story is that declaration being wrong or absent. Third, **the scaling engine's timing constants are not yours** — polling interval, cooldown, stabilisation windows, and step sizes are fixed by the platform, so your only levers are the thresholds, the replica floor and ceiling, and how fast your container starts. Most Container Apps performance work is therefore not tuning the autoscaler; it is shortening cold start and choosing a floor, because those are the two things you actually control.

### `copy-truth`

- **Title:** Copy Truth
- **Pairs with:** user-facing instructional text as a verification surface — every helper line, tooltip, placeholder, empty state, confirmation prompt, error message, badge title, and onboarding hint a product shows its users. Each one is a *claim about behavior*, and this pairing treats the full set as an auditable contract: instruction must match function. Covers the truthfulness and synchronization of in-product copy. Out of scope: visual presentation of text (a perceptual concern), vocabulary architecture (which words name which concepts — a mental-model concern), and developer-facing comments/docs (covered by code-level doc-drift discipline).
- **Touches principles:** #2, #7, #9, #12, #13
- **Preamble:** Instructional copy is the one part of the system users actually read, and the one part no compiler checks. A tooltip that says "never invoiced" while the engine invoices anyway isn't a typo — it's a false statement of behavior delivered at the exact moment of a decision, with the product's full authority behind it. Code that drifts from comments wastes developers' time; copy that drifts from function makes *users* wrong, and they have no way to debug the discrepancy. The discipline: every instructional string is a claim; claims get verified against the code path they describe, and re-verified when that path changes.

### `cosmic-comp`

- **Title:** cosmic-comp (adopting a compositor you didn't write)
- **Pairs with:** Building *on top of* COSMIC's `cosmic-comp` — System76's
- **Touches principles:** #4, #5, #6, #7, #9, #10, #13, #16, #23
- **Preamble:**   production Rust/Smithay Wayland compositor — as the foundation for a   desktop or shell you did **not** author the compositor for: hosting your   own layer-shell clients (panels, notifications, lockers) on it, driving it   through the `cosmic-config` RON schema, and deciding how much of the COSMIC   ecosystem (session, settings-daemon, crate graph) you take with it. Sits   beside `hyprland` (wlroots, bare drawing engine) and `iced` (the toolkit   your clients are written in); applies whenever the compositor is a   *pre-built, opinionated, ecosystem-coupled* one you adopt rather than a   bare engine you configure or a native one you build.   (pop-os, master, mid-2026); `cosmic-config` on-disk RON layout;   `cosmic-ctl` + `configurator` (cosmic-utils); cosmic-comp issues #1590   (layer-shell teardown), #1915 (hybrid GPU offload), #2424 (xdg-decoration   v2); GPL-3.0-or-later LICENSE; foyer research report   `2026-07-04-cosmic-comp-adoption.md`; opinion.

### `css`

- **Title:** CSS
- **Pairs with:** CSS the language — selectors, cascade, layout, typography, color, motion, custom properties, modern modules (cascade layers, container queries, `:has()`, nesting, view transitions, color spaces, `@property`, scope). Framework-agnostic; applies whether the surface is vanilla CSS, CSS modules, Svelte scoped styles, Tailwind, or any combination.
- **Touches principles:** #4, #6, #7, #8, #9, #10
- **Preamble:** CSS has been doing more for fewer lines every year. The post-2022 baseline — cascade layers, container queries, `:has()`, native nesting, OKLCH, view transitions, `@property`, `@scope` — has changed what "modern CSS" means more in three years than the prior decade. The principles below specialize the design rules for CSS's specific texture: a declarative cascade where order, specificity, and scope all decide who wins, and where the same visual result can be produced by very different cascade strategies.

### `deployment-stamps`

- **Title:** Deployment Stamps
- **Pairs with:** Architecting a system whose **unit of scale and of deployment is a complete, independent copy of itself** — a *stamp* (also *cell*, *scale unit*, *service unit*), each serving a named subset of tenants. Covers the founding topology split (what is global, what is regional, what is in the stamp), the stamp definition as a single parameterized engine, the **tenant→stamp map** and the routing layer that consumes it, capacity as a measured number and the scale-out policy that reads it, bin packing against account/subscription quotas, sameness across copies (drift as the characteristic failure), and the stamp lifecycle — stand up, seal, drain, move a tenant, retire. This is the **topology axis**: *how many copies of the system exist, what is inside one, and which customers live in which*. Not the change axis (how a release moves across the copies once they exist — rings, waves, bake, skew), not the resource-shaping axis (how any one resource is secured, networked, and identified), not the IaC tool's own apply semantics (state, plan, drift-as-diff), not row-level tenancy inside a shared store, and not recoverability of the data a stamp holds.
- **Touches principles:** #1, #2, #4, #5, #6, #7, #8, #9, #10, #13, #14, #17, #18, #19, #20
- **Preamble:** A stamp is a whole working copy of the solution — compute, data, secrets, networking — that serves some of your customers and none of anyone else's. The pattern's single defining move is that **you scale by cloning the unit rather than by growing any component inside it**, and everything else follows from that. Two things you get for free: capacity becomes a *countable* number ("this stamp holds N tenants"), and a blast radius becomes a *named set of customers* rather than a probability. Two things you buy along with it, which the single-instance world simply does not have: **placement** — the fact of which tenant lives in which stamp, now a first-class piece of data that something must own, project, and route on — and **drift**, because the pattern's core property is that the copies are identical, and identical is not a property that survives being unattended. So the discipline is three facts kept honest: *the unit* (what is inside a stamp, decided before anything is automated), *the map* (tenant→stamp, one writer, many projections), and *the sameness* (measured against a declaration, never assumed). Most stamp-architecture pain traces to one of the three being implicit.

### `derived-surfaces`

- **Title:** Derived Surfaces
- **Pairs with:** data generated from other data and then read as if it were the source — rendered queues and boards, generated indexes and tables of contents, materialized views, caches, search indexes, denormalized summaries, dashboards, roll-ups, exported manifests, any `GENERATED-BY` file. Covers the relationship between a derivation and the source it stands for: how they come apart, how that is detected, and who is authoritative when they disagree. Out of scope: the correctness of the source itself, the performance of the derivation, and presentation of the result to a human.
- **Touches principles:** #2, #7, #9, #12, #13, #18, #21
- **Preamble:** A derivation is built to be *believed instead of* its source. That is the whole value — nobody wants to re-read the corpus to learn what is in it — and it is exactly why the failure is expensive: when a derived surface is wrong, nothing looks wrong. It renders. It is complete, sorted, well-formed and confident. Every downstream consumer behaves as though the claim were true, because the point of the derivation was to spare them from checking.

### `display-manager`

- **Title:** Display Manager (Wayland login)
- **Pairs with:** The login-manager / display-manager layer on Linux — `greetd` (+ `ReGreet`/`gtkgreet`/`tuigreet`), and the same reasoning applies to SDDM, GDM, `plasma-login-manager`, and `ly`. Applies to any project that *configures, themes, or switches* the program that owns the pre-session screen: the greeter, the `greeter`/`plasmalogin`/`sddm` system user, the VT/seat it claims, and the handoff into the chosen session.
- **Touches principles:** #1, #2, #4, #5, #6, #7, #9, #13, #14
- **Preamble:** A display manager is the one program that runs **before there is a user session** and decides which session begins. That single fact dominates the domain: the greeter executes as an unprivileged *system* user (`greeter`, `sddm`, `plasmalogin`) with no access to any human's `$HOME`, no running session bus of its own to inherit theme from, and sole ownership of a VT and a seat. It is also the component with the **worst failure mode in the stack** — a broken greeter config doesn't degrade gracefully, it locks you out of the GUI entirely, and there is no windowed preview to test against. The principles below specialize for those two facts: the greeter is a sandbox that must carry its own assets, and the only real test is the switch itself, so reversibility is a design requirement, not a nicety.

### `e2e`

- **Title:** End-to-End Testing
- **Pairs with:** End-to-end (system / acceptance) testing — verifying a whole system through the same surface a real user touches (methodology)
- **Touches principles:** #1, #4, #5, #6, #7, #9, #10, #12, #13
- **Preamble:** An end-to-end test makes one promise: *a real user, on the assembled system, can do this and see the right result.* The promise is only kept if the test exercises the system **through the surface the user actually touches** and asserts **the outcome the user can actually observe**. Every failure mode in this domain is a way that promise quietly breaks while the bar stays green — a test that drives a mock instead of the system, that asserts a `data-testid` exists instead of that the value is right, that checks a 200 instead of the rendered total, that passes because it asserted nothing at all. The discipline of e2e is not "click through the app"; it is **refusing the proxy** — assert the thing the user sees, in the integrated system, or admit you didn't test it. A green e2e suite that asserts proxies is the most expensive lie in a codebase, because it buys false confidence at the exact layer where confidence is supposed to be earned.

### `electronics`

- **Title:** Electronics
- **Pairs with:** Analog and digital circuit design — component selection, schematic capture, PCB layout, bring-up.
- **Touches principles:** #4, #6, #7, #8, #9, #10, #13, #14
- **Preamble:** Hardware is physics with deadlines. Most failures in the field trace to assumptions that worked on the bench under nominal conditions and broke under voltage, temperature, EMI, or aging. The principles below specialize for designing circuits that survive contact with the real world.

### `enforcement-surfaces`

- **Title:** Enforcement Surfaces
- **Pairs with:** anything a system runs *against itself* to decide whether something is allowed, correct, or healthy — linters, type checks, CI gates, pre-commit hooks, schema validators, admission controllers, policy engines, health probes, alerts, budget guards, rate limiters, feature-flag kill switches, monitors, and the automated remediations attached to any of them. Covers the design of the check itself: what it claims, what it does when it fires, how it is verified, and how it retires. Out of scope: the correctness of the thing being checked (that is the domain's own concern), the pipeline mechanics of running checks (a build concern), and the presentation of results to a human (a perceptual concern).
- **Touches principles:** #2, #4, #7, #9, #12, #13, #17, #18, #21, #22
- **Preamble:** An enforcement surface is a claim about a system, plus the authority to act on it. Both halves matter, and most design mistakes come from treating one as though it were the other.

### `entra-id`

- **Title:** Microsoft Entra ID
- **Pairs with:** Microsoft Entra ID (formerly Azure AD) — identity platform for OIDC/OAuth2 authentication, authorization, directory services, and Microsoft Graph API access. Covers app registrations, token flows, RBAC, service principals, managed identities, and conditional access.
- **Touches principles:** #1, #2, #4, #6, #7, #8, #9, #10, #12, #13
- **Preamble:** Entra ID is three systems wearing one trenchcoat: an identity provider (OIDC tokens), an authorization engine (app roles, group claims, conditional access), and a directory service (Graph API). Most integration bugs come from treating it as one thing. The principles below are about keeping those axes separate, anticipating the full state space of token-based auth, and being honest about what Entra ID does and does not guarantee.

### `entra-pim`

- **Title:** Entra Privileged Identity Management (Just-in-Time Privileged Access)
- **Pairs with:** Designing, migrating to, and proving **just-in-time privileged access** — the discipline of splitting one grant into *eligibility* (the right to hold a privilege) and *activation* (holding it, briefly, on purpose). Covers PIM for Microsoft Entra roles, PIM for Azure resource roles, and PIM for Groups — three different APIs and three different object models over one idea — plus the activation ceremony (justification, ticket field, MFA / Conditional Access authentication context, approval), assignment types (permanent/time-bound × eligible/active), role-management policies, access reviews, PIM alerts, and the census discipline that proves no standing privilege survived the migration. This is the **eligibility lane**: what a principal is *allowed to become*. Not the identity-provider surface that mints and authenticates the principal, and not the condition attached to a *standing* grant — a constrained active assignment is a narrower privilege held permanently, which is the opposite axis from a full privilege held for forty minutes.
- **Touches principles:** #1, #2, #4, #6, #7, #9, #10, #12, #13, #14, #17, #18, #19, #20
- **Preamble:** Every neighbouring access-control surface fails at the point of use: a missing role assignment is a 403 the first time someone tries. PIM is different, and the difference is the whole document: **an eligibility is never exercised until the standing fallback is gone, and until then a dead eligibility is indistinguishable from a live one at every surface that reports on it.** Creating an eligible assignment returns success whether or not any human can ever activate it. The portal lists it. An audit exports it. A compliance dashboard counts it. The one thing that would falsify it — a real activation by a real person — is exactly what nobody does while the standing grant still works. So a JIT migration has one additive, reversible, *evidence-free* half (add eligibility) and one destructive, lockout-capable half (remove standing), and the platform gives no signal at all distinguishing "ready" from "about to strand every administrator outside the tenant." Compounding it: once activated, an eligible assignment **materializes as an ordinary role assignment** — "there's no difference in the access given to someone with a permanent versus an eligible role assignment" — so the census that is supposed to prove zero standing privilege cannot, without cross-referencing schedule instances, tell an activation from the thing it was sent to find. Every principle below specializes around that: **eligibility is an untested claim, activation is the only evidence, and the measuring instrument is ambiguous by default.**

### `envelope-encryption`

- **Title:** Envelope Encryption (The Key Hierarchy Plane)
- **Pairs with:** Designing and operating the **key hierarchy that protects data at rest** — data encrypted under a per-object data-encryption key (DEK), that DEK wrapped by a key-encryption key (KEK) held in a vault, HSM, or KMS that never releases it, and the wrap/unwrap calls that are the only place the KEK is ever exercised. It owns the *lifecycle* of that hierarchy: key versions and the binding of each stored wrapped DEK to one of them; the two genuinely different rotations (rewrap every DEK vs. re-encrypt the corpus); the online, resumable rewrap migration; per-tenant key partitioning and cryptographic erasure; soft-delete and purge protection; caching of unwrapped DEKs; and the reachability of the wrap/unwrap endpoint. It is **not** secrets storage and reference — a vault holding a connection string that gets injected as config is a different plane, one that hands you a *value* where this one hands you an *operation*. Nor is it transport security, nor the authorization model that decides who gets granted the wrap role, nor the record-level access control sitting above the plaintext.
- **Touches principles:** #1, #2, #3, #4, #6, #7, #9, #10, #12, #13, #17, #18, #19, #20
- **Preamble:** Every other component of a system is rebuildable from source. The KEK is the one object you have *deliberately engineered yourself to be unable to read, copy, or reconstruct* — that inability is the entire security claim — and the corpus's readability is not stored in the corpus. Each sealed row carries a durable, immutable **reference** to a key version living in a foreign system with its own firewall, its own throttle, its own RBAC, and its own delete button; nothing inside the data can repair a broken reference. So this domain has two failure classes that look nothing like each other. Either the KEK becomes **unreachable** — every read fails while every byte is intact, loud, recoverable, a pure availability event that will be misdiagnosed as a permission bug — or the referenced key version is **destroyed**, and the ciphertext is now permanently indistinguishable from random, silently, in proportion to how much of the corpus pointed at it. Purge protection is the single control that converts the second class into the first, and on the vault platforms checked here it is **not enabled by default**. The same structure that makes destruction fatal is what makes rotation cheap: the corpus is bound to the KEK only through small wrapped DEKs, so re-keying the KEK rewrites two columns per field and never touches a byte of ciphertext. Every principle below specializes around that pair — *keep the reference always repairable while the key lives, and make destroying the key require a deliberate, authorized, delayed act*.

### `esp-idf`

- **Title:** ESP-IDF
- **Pairs with:** ESP-IDF (Espressif IoT Development Framework) for ESP32-family microcontrollers. Current line is v5.x (long-term) and v6.x (latest stable as of mid-2026). Targets the full ESP32 family: original ESP32 / S2 / S3 (Xtensa) and C2 / C3 / C5 / C6 / C61 / H2 / H4 / P4 (RISC-V).
- **Touches principles:** #3, #4, #6, #7, #8, #11, #13, #14
- **Preamble:** ESP-IDF is opinionated infrastructure on top of FreeRTOS and a C SDK. Most of its idioms exist because microcontrollers have constraints desktop code doesn't — limited RAM, no MMU, interrupts you must service, tasks competing for cycles. The principles below specialize for those constraints.

### `executable-invariants`

- **Title:** Executable Invariants (Architectural Rules as Build-Failing Checks)
- **Pairs with:** The discipline of turning a convention, an architectural rule, or a hard-won lesson into a **check that fails the build** — deciding when a rule earns a checker and when it doesn't, what signal the detector keys on, where it runs (type system, test tier, custom lint rule, structural query, dependency-graph rule, commit hook, CI job), how pre-existing debt is carried without blocking work (the ratchet/baseline), how a legitimate exception escapes, and how the checker itself is verified. This is the **universal-quantifier** side of quality: rules of the form *nowhere in this repo does X*, which no unit test can hold because the assertion ranges over the file set rather than over one unit's behavior. Not the style side (formatting is mechanically fixable, carries no judgment and no debt), not the behavioral side (a test asserts what one unit does with one input), and not any single linter's rule catalogue.
- **Touches principles:** #1, #2, #4, #5, #6, #7, #9, #10, #11, #12, #13, #17, #18, #20
- **Preamble:** Every other artifact in a build fails toward noise; a check fails toward silence. A broken test tells you something. A check that reports nothing tells you exactly the same thing whether the rule holds everywhere, the detector quietly stopped matching the shapes people actually write, or the scanner has been walking a directory the code moved out of six weeks ago. That is the asymmetry the domain turns on: **a checker's product is a negative claim over an open set, and negative claims decay invisibly in both directions.** Tighten the detector and it silently stops seeing violations. Loosen it and it blocks legitimate work — at which point someone waives it, re-baselines it, or deletes the hook, and you arrive at the identical destination by the other road. Both roads end at *a rule you believe you have*: convention documented, build green, violation shipping weekly. Worse, the one artifact that makes adoption possible against an existing codebase — the committed baseline of grandfathered violations — is the same artifact that switches the rule off in a single command, under a commit message that reads like housekeeping. Every decision below (what the detector keys on, where it runs, what it prints, how it is escaped, how debt is carried, whether the checker is itself tested) is one decision about keeping that negative claim honest.

### `field-service-orchestration`

- **Title:** Field Service Orchestration
- **Pairs with:** Software that runs the path from an inbound service request to a completed on-site visit and beyond. Covers intake (phone, web form, SMS, email, returning-customer portal, EDI), triage and qualification, scheduling and dispatch, technician assignment, en-route tracking, on-site execution, completion / closeout, post-visit follow-up, and the **communications fabric** that touches every actor (customer ↔ dispatcher ↔ technician ↔ supervisor ↔ back office) at every stage. Industry-agnostic — trades (HVAC, plumbing, electrical), IT field services / MSP, healthcare home visits, courier and light delivery, locksmiths, appliance repair, property management.
- **Touches principles:** #2, #4, #6, #7, #8, #9, #10, #13, #14
- **Preamble:** Field-service work is operational software with a body in motion. Unlike pure-digital order pipelines, a job here ends in a human being arriving at a physical address, doing skilled work in conditions nobody fully knows in advance, and leaving with a billable result the customer can dispute. Three things connect the stages: a **lifecycle state machine** that's enforceable end-to-end, a **communications fabric** that keeps every actor aligned without becoming a side-channel for state, and an **audit trail** of who said what and when. The principles below specialize for keeping these three on **orthogonal axes** while keeping the invariants (one source of truth per actor's status, every commitment to a customer is on-the-record, every state change is attributable) intact under the conditions field work actually runs in — partial connectivity, missed appointments, parts shortages, customer not home, and exceptions running 20–30% of the day's jobs.

### `fleet-release-engineering`

- **Title:** Fleet Release Engineering
- **Pairs with:** Release engineering for fleets of dedicated per-tenant instances (domain / methodology) — the day-2 **change axis** of instance-per-tenant SaaS: how a release moves across a fleet where the unit of exposure is a whole tenant, not a request. Covers rings and waves, bake-and-promote policy, the per-tenant upgrade saga, schema changes under version skew, the deploy/release split, and rollout observability. Not day-1 provisioning (a different axis), and not within-cluster traffic-splitting canaries (a different exposure unit).
- **Touches principles:** #1, #2, #4, #5, #6, #7, #9, #10, #11, #13, #14, #17, #18
- **Preamble:** When every customer runs a dedicated instance, a deploy is a 0%-or-100% event *for that customer* — there is no "5% of traffic" to one tenant's instance. The percentage knob the shared-service world reaches for becomes "percentage of tenants," which means **at fleet scope, tenant-granularity canarying and ring deployment are the same mechanism.** Everything in this domain follows from that identity and from its corollary: a fleet mid-rollout is *normally* running two versions at once, so version skew is not an accident to prevent but a state to design for. The discipline is three separable machines — a **policy** that decides who gets a release when, a **saga** that upgrades one tenant safely, and a **ledger** that knows what actually happened — and most fleet incidents trace to one of the three being improvised instead of built.

### `freertos`

- **Title:** FreeRTOS
- **Pairs with:** FreeRTOS — Real-Time Operating System kernel for microcontrollers. Versions ≥ v10 targeted, with v11.x (the upstream-SMP line; current is V11.3.0, March 2026) as the canonical reference; vendor variants (ESP-IDF FreeRTOS with its earlier Espressif SMP extension, Zephyr's compat layer, etc.) inherit most guidance but diverge in specific extensions. The FreeRTOS LTS releases (202xxx.xx versioning, latest 202604 LTS at time of writing) are the stable-API choice for long-running production.
- **Touches principles:** #4, #5, #6, #7, #8, #9, #13
- **Preamble:** FreeRTOS is a kernel, not a framework. It gives you tasks, queues, timers, mutexes, semaphores, event groups, and stream/message buffers — and nothing else. Drivers, networking, file systems, and application logic are all supplied by you. The principles below are about getting the kernel's primitives to express the project's concurrency model cleanly, rather than letting concurrency leak through every module as ad-hoc shared state and ad-hoc priority choices.

### `gpu-performance`

- **Title:** GPU Performance (Linux desktop)
- **Pairs with:** GPU acceleration and desktop responsiveness tuning on Linux — Mesa drivers, the Wayland/KWin compositing path, kernel DRM (`i915`/`xe`, `amdgpu`), and power/thermal trade-offs. Calibrated on Intel Iris Xe / Tiger Lake (the laptop-iGPU case); the reasoning generalizes to any Mesa-on-Wayland desktop. Applies whenever the goal is *measurable* snappiness, not more eye candy.
- **Touches principles:** #1, #2, #4, #9, #13, #16
- **Preamble:** GPU/perf work is where vibes go to lie. "It feels faster" is the single most expensive sentence in the domain — it justifies changes that do nothing, re-open side channels, or trade battery for a frame nobody sees. The principles below specialize for one discipline: **a perf change is a claim, and a claim needs a number, a case-space, and an honest bound.** On an integrated GPU especially, the binding constraint is usually memory bandwidth, thermals, and the compositor's always-on cost — not raw shader throughput — so the tuning that matters is rarely the tuning that's exciting.

### `hyprland`

- **Title:** Hyprland (wlroots compositor + layer-shell)
- **Pairs with:** Configuring Hyprland — both as a full desktop session and as a minimal greeter/kiosk compositor — and the `wlr-layer-shell` surfaces that live on it (wallpapers, bars, launchers, lock screens, greeters). Calibrated on Hyprland; the reasoning is `wlroots`-general and carries to Sway, river, and Wayfire (the config *syntax* differs, the layer-shell *model* is identical). Sits beside `kde-plasma` (which owns the KWin/Plasma compositing path) and applies whenever the compositor is *not* KWin.
- **Touches principles:** #1, #4, #5, #6, #7, #8, #9, #13
- **Preamble:** Hyprland (and any wlroots compositor) is a **bare drawing engine with no opinions**: unlike Plasma/KWin it ships no desktop, no panel, no settings daemon, no theme cascade — it draws windows and runs the programs you tell it to via `exec-once`, and everything else (wallpaper, bar, notifications, idle, lock) is a *separate* layer-shell client you compose on top. Two facts dominate: the desktop is an assembly of independent surfaces with explicit *layer roles* (background / bottom / top / overlay) rather than one integrated shell, and the config is plain declarative text read once at launch — what it can do is fixed by the engine, and the config only sequences it. The principles below specialize for composing those surfaces correctly and for not assuming any of KWin's batteries-included behavior is present.

### `identity-pentest`

- **Title:** Identity Pentest
- **Pairs with:** Authentication and authorization attack testing (skill / domain) — testing identity trust boundaries: token, claim, and header trust; session handling; role-based access control enforcement; privilege boundaries; and shared-secret-protected endpoints. Assumes an authorized context.
- **Touches principles:** #4, #5, #7, #12, #13
- **Preamble:** An authentication system is a stack of trust claims: *this header came from the platform, this token is one we issued, this role grants this action.* Identity testing attacks each claim at the point where it is trusted but not actually verified. The most dangerous bugs live where the application trusts an upstream component — a reverse proxy, a platform authentication layer, an injected header — that an attacker can sometimes reach around or speak to directly. The principles below specialize for finding the gap between "trusted" and "verified."

### `injection-pentest`

- **Title:** Injection Pentest
- **Pairs with:** Injection and data-layer attack testing (skill / domain) — SQL injection, ORM-misuse injection, and other untrusted-data-into-interpreter flaws in the persistence and data-handling layer. Assumes an authorized context.
- **Touches principles:** #4, #6, #7, #13
- **Preamble:** Injection is what happens when data crosses into an interpreter without a boundary between "this is content" and "this is code." A modern data-access layer (an ORM, a query builder, parameterized statements) promises that boundary by default — which is exactly why injection testing focuses on the seams where a developer stepped *outside* the default: raw query fragments, dynamically chosen identifiers, string-built clauses, and data that was stored safely but later re-used unsafely. The principles below specialize for finding those seams.

### `interaction-design`

- **Title:** Interaction Design
- **Pairs with:** The behavior layer of interface work — what the system *does* over time when the user acts. Direct manipulation, feedback loops and their timing budgets, microinteractions (triggers, rules, feedback, modes/loops), gesture and modality, state coverage across an interaction's life (idle → triggered → active → resolved / aborted / errored), error prevention and recovery, animation as communication (not decoration), reversibility, and the laws of motor and decision time (Fitts, Hick, Tesler, Doherty). Out of scope: the cognitive layer (mental-model formation, signifiers, learnability) and the architectural-visual layer (structure, hierarchy, typography, design systems).
- **Touches principles:** #2, #4, #6, #7, #8, #9, #13
- **Preamble:** An interaction is not a moment, it's a small life: the user tries something, the system responds, the user adjusts, the system responds again. Each step has timing, has state, has the possibility of failure, and contributes to whether the interaction feels alive or feels broken. This pairing is about designing that life as a deliberate engine — every interaction's full state-space, the feedback the user receives at each transition, the timing budgets the system honors, and the recovery paths when something goes wrong. The behavior-over-time axis is where the user actually touches the system; many interfaces that look fine at rest fall apart in motion because this layer was not designed deliberately.

### `ios`

- **Title:** iOS
- **Pairs with:** native iOS development — Swift, SwiftUI (UIKit where it still owns the job), the scene/app lifecycle, Swift structured concurrency (actors, `@MainActor`, Sendable), state ownership in a value-semantics world, background execution under iOS's strict budget, APNs push, the permission/privacy model, and memory pressure (jetsam). Covers the platform layer: how iOS's execution model and Apple's review/privacy regime shape design. Out of scope: cross-platform wrappers, App Store release operations and ASO, and visual design language (the HIG is referenced only where it is architecture — navigation idiom, Dynamic Type, safe areas).
- **Touches principles:** #2, #4, #6, #7, #8, #9, #10, #13
- **Preamble:** iOS's defining fact is **scarcity enforced from above**: background time is a budget measured in seconds, memory is reclaimed by killing you without a crash log a user can see (jetsam), the only reliable wake-up from outside is a push, and capabilities ship gated behind a permission and review regime that treats every access as a privacy claim. Where Android's process is a guest, iOS's is a guest on a timer. Designs that assume "the app will get a chance to finish this later" are wrong by construction — the platform's answer is *persist now, reconcile on next foreground*, and most of this pairing is that answer applied per principle.

### `jobs-to-be-done`

- **Title:** Jobs to Be Done
- **Pairs with:** Product and feature work seen through the *user's lived perspective* — the jobs-to-be-done lens and its companions (personas, goal-directed design, mental models). A reasoning discipline for *which feature, and for whom*, not a UI surface-design method.
- **Touches principles:** #1, #2, #6, #7, #10, #12
- **Preamble:** A feature is never the thing the user wants; it is the mechanism you hope serves the thing they want. The job-to-be-done lens forces a slowdown before any mechanism gets built: a product is *hired* to make **progress in a circumstance**, so the design starts from the **job and the person's lived context** — who they are, what progress they are reaching for, and what a domain word means *to them* — not from the feature you were about to ship. The discipline's sharpest single move is naming **who** the user is (including the user who wears **two roles at once**) and then watching for a **domain word that means two different things** to that user: an overloaded term is the tell that two jobs — or two roles — have been quietly collapsed onto one axis. The principles below show where that lens already lives in this collection, and where reasoning from the user's side catches an axis you cannot see from the feature's side.

### `kde-plasma`

- **Title:** KDE Plasma
- **Pairs with:** The KDE Plasma 6 desktop (Wayland-first) and its configuration substrate — KConfig (`kdeglobals`, `*rc` files), kded modules, KWin, and the `plasma-apply-*` / `kwriteconfig6` tooling. Applies to any project that *configures or extends* a Plasma desktop declaratively.
- **Touches principles:** #1, #4, #5, #6, #7, #8, #9
- **Preamble:** Plasma's configuration is a **cascade of `INI`-shaped KConfig files** read live by long-running daemons (kded, KWin, plasmashell), not a static dotfile read once at login. Two facts dominate: a setting can be written three ways (a file, `kwriteconfig6`, or a `plasma-apply-*` helper) with different reload semantics, and almost everything is *layered* — system defaults under `/usr`, user overrides under `~/.config`, with immutability flags and `[$i]` markers in between. Get the layer and the reload right and Plasma is wonderfully scriptable; get them wrong and your change is either ignored, shadowed, or clobbered on next login.

### `laravel`

- **Title:** Laravel
- **Pairs with:** The Laravel framework (versions 9.x and later, through Laravel 13.x — current stable since March 2026; 13.6.0 at time of writing). Applies to any project where Laravel is the application framework — web apps, APIs, CLI tools built on Artisan, queue-driven workers. Note: Laravel has not shipped an LTS major since Laravel 6 (2019); the support window is 18 months bug-fix + 2 years security per release.
- **Touches principles:** #1, #2, #4, #5, #6, #7, #8, #9, #11, #13, #14
- **Preamble:** Laravel is a sequencer wrapped around a set of engines: the IoC container, the request lifecycle, Eloquent's query builder, the database schema engine, the queue worker, the scheduler, Blade. Each engine has a well-defined range; the framework's job is to make those engines easy to reach from a thin instruction layer (routes, controllers, jobs, commands). The principles below specialize for keeping that separation honest — controllers stay thin, engines stay engines, and the framework's conveniences don't become the project's load-bearing architecture.

### `layout-resilience`

- **Title:** Layout Resilience
- **Pairs with:** layout as an engineering surface — whether a composition survives *real content* at *every viewport*: overflow and wrapping mechanics (flex/grid shrink rules, truncation that actually truncates), choosing the right display form (table / list row / card / grid) for the data and the task, breakpoint coherence, and density appropriateness. Covers the mechanical robustness and form-selection layer of layout. Out of scope: visual hierarchy and perception (a perceptual concern), design-system token consistency (a structural concern), and interaction states (a behavioral concern). This is the layer those lenses each assume is already working: that the boxes themselves hold.
- **Touches principles:** #2, #4, #6, #9, #13
- **Preamble:** Layouts fail emergently: the markup looks fine, the demo content fits, and then a real customer is named "Cellco Partnership DBA Verizon Wireless – IL" on a 390px screen and the buttons leave the card. No single class is wrong — the *composition* is wrong, and only under content × viewport combinations nobody rendered. Audits that read markup for class-level signals (contrast ratios, missing labels) sail past this, because resilience isn't a property of any one element; it's a property of how a container negotiates with unknown content. This pairing makes that negotiation auditable: the failure patterns are finite, greppable, and fixable by construction.

### `led-display`

- **Title:** LED Display
- **Pairs with:** Driving LED displays (addressable strips, matrix panels, multiplexed arrays) as a graphics **output target** — putting a prepared frame onto the pixels faithfully: wire protocol, color depth, perceptual encoding, channel order, and the visual artifacts that are specific to LEDs.
- **Touches principles:** #2, #4, #6, #7, #8, #9, #13, #14
- **Preamble:** LEDs are quantized light sources with a nonlinear perceptual response and protocol-timed addressing — qualities a file-format renderer never faces. This pairing covers putting a *prepared* frame onto LED pixels so it looks the way it was meant to: the wire protocol, color depth and perceptual encoding, channel order, and the visual artifacts (flicker, banding, color drift) specific to LEDs. Two adjacent concerns are deliberately out of scope: **powering** the array (current, supply, thermal) is an electrical problem, and the **bus/DMA mechanism** that clocks the bitstream out is a firmware problem. This pairing assumes a frame exists and a transport exists; its job is that the frame is *encoded and addressed* faithfully.

### `local-trade-marketing`

- **Title:** Local Trade Marketing
- **Pairs with:** Marketing a **local, trust-dependent trade or services business** — a locksmith, alarm/security installer, safe dealer, electrician, plumber, HVAC, roofer, or similar. The buyer is choosing someone to come into their home or business and be trusted with their safety, money, or property; the purchase is high-consideration, locally bounded, and won on credibility rather than price or novelty. This is the *demand-side* discipline — positioning, audience segmentation, proof, local discoverability, and lead conversion. Out of scope: the *construction* of the visual layer — layout, hierarchy, type, tokens, componentry and design-system architecture (a UI concern), and the perceptual science of why a rendering reads as it does (a visual-perception concern); the truthfulness mechanics of individual strings (a copy-discipline concern); and the product/feature-selection lens (a jobs-to-be-done concern). **In scope, however: which imagery earns or destroys trust, and what an image asserts by appearing where it does** — the credibility hierarchy below already ranks imagery, and a discipline that ranks a thing cannot disclaim responsibility for choosing it.
- **Touches principles:** #1, #2, #9, #10, #12, #13
- **Preamble:** A local trade business does not win the way a SaaS product or a national brand wins. The prospect has a *circumstance* — a break-in down the street, a lockout, a new building to secure, a safe to move — and is looking, locally and often urgently, for someone competent and trustworthy. They cannot inspect the work before buying, so they buy **signals of credibility**: years in business, real credentials and manufacturer authorizations, a real address and phone, a recognizable local name, and proof that real neighbors trust them. Marketing here is the disciplined assembly of *true* signals into a path that ends in a call or a quote request. The discipline's spine: every persuasive claim is a credibility claim, every credibility claim must be real and verifiable, and the whole funnel is judged by leads, not applause.

### `mental-models`

- **Title:** Mental Models
- **Pairs with:** The cognitive layer of interface work — how users form a working theory of "what this system is and how it behaves," and how the interface either supports or breaks that theory. Norman's three-model framework (designer's conceptual model, the system image emitted by the interface, the user's mental model assembled from the system image plus prior experience), affordances and signifiers, metaphor and analogy, recognition vs. recall, cognitive load, learnability, onboarding as initial model formation, discoverability. "Intuitive" reduced to its useful operational definition: the user's mental model matches the system's actual behavior closely enough that prediction succeeds.
- **Touches principles:** #1, #4, #5, #6, #8, #9, #13
- **Preamble:** A user doesn't reason about your system from a spec sheet. They build a working theory of it from whatever they can perceive — the labels, the layout, the responses to their actions, what changed when they did the last thing, what reminds them of something else they already know. That working theory is the mental model, and every prediction the user makes about your system runs through it. When their model matches your system's actual behavior, the experience feels intuitive; when it diverges, the experience feels broken — *even when the system is working exactly as designed*.

### `microsoft-graph`

- **Title:** Microsoft Graph API
- **Pairs with:** Microsoft Graph API — the unified REST API surface for Microsoft 365 services (Entra ID, Outlook mail/calendar, SharePoint, OneDrive, Teams, Planner, users, groups). Covers v1.0 and beta endpoints, Microsoft Graph SDKs, and the authentication/authorization model via Microsoft Identity Platform (MSAL).
- **Touches principles:** #1, #2, #4, #5, #7, #8, #9
- **Preamble:** Microsoft Graph is a single endpoint (`https://graph.microsoft.com`) that federates dozens of backend services, each with its own consistency model, throttling behavior, and permission granularity. The principles below address the fact that "one API" is a convenient lie — the unified surface hides per-service differences that matter for correctness, performance, and authorization. Treating Graph as uniform invites the kind of reactive patching Principle 2 warns against.

### `midi-cv`

- **Title:** MIDI / CV / Sync
- **Pairs with:** MIDI 1.0 and 2.0 protocols, analog CV/Gate, and hardware sync standards (DIN Sync 24, Korg sync, Pocket Operator sync, MTC). Applies to any project that sends or receives time-critical musical control signals between hardware devices.
- **Touches principles:** #4, #5, #6, #7, #8, #9
- **Preamble:** MIDI and CV are deceptively simple at the surface and unforgiving at the edges. Note On / Note Off is a one-page concept; running-status optimization, RPN/NRPN parameter trees, SysEx negotiation, MTC quarter-frame messages, MIDI 2.0 UMP packets, and the dance of multiple devices sharing one cable are not. Analog CV looks even simpler — a voltage and a gate — but voltage standards (1V/oct vs. Hz/V vs. Buchla 1.2V/oct), calibration drift, gate level conventions, and sync-pulse standards all hide here. The principles below are about respecting that gap.

### `monorepo`

- **Title:** Monorepo
- **Pairs with:** Multi-package repositories sharing a single version-control root and a workspace-aware package manager (npm workspaces, pnpm workspaces, Yarn workspaces, Cargo workspaces, Go workspaces, Bazel, Nx, Turborepo, Rush). Applies regardless of language — the pairing is about boundary discipline between co-located packages, not about a specific tool.
- **Touches principles:** #2, #6, #7, #8, #11, #14
- **Preamble:** A monorepo bundles multiple packages into one repository. The bundling buys atomic cross-package changes, shared tooling, and discoverability — but it also lets every package's internals become every other package's dependency unless boundaries are kept explicit. The principles below are about preserving package-level orthogonality without losing the bundling's value.

### `music-theory`

- **Title:** Music Theory
- **Pairs with:** Music theory as a body of domain knowledge — pitches, intervals, scales, modes, harmony, voice leading, rhythm, meter, form. Applies to any project that generates, analyzes, transforms, or reasons about musical material.
- **Touches principles:** #1, #4, #5, #6, #8, #9
- **Preamble:** Music theory is unusually well-suited to software because it is, at root, a system of rules about discrete objects (pitches, intervals, durations) under operations (transposition, inversion, retrograde, modulation). It is also unusually treacherous: every rule in the common-practice tradition has well-cited exceptions, every "consonance" depends on cultural and stylistic context, and "musical" is not a property the rules can fully predict. The principles below are about staying honest with that gap — building engines that capture what theory describes crisply, sequencing them as instructions for specific styles, and never claiming the engine produces "musicality" when it produces well-formed sequences.

### `network-sync`

- **Title:** Network Sync (Ableton Link, LTC/MTC, OSC, ArtNet, PTP)
- **Pairs with:** Software that keeps two or more independent devices in coherent musical or media time across a network or wire. Covers Ableton Link (peer-to-peer tempo/beat over UDP + mDNS), SMPTE Linear Timecode (LTC over an audio line), MIDI Time Code (MTC quarter-frame and full-frame over MIDI), Open Sound Control time-tagged bundles, ArtNet TimeCode and ArtSync (for lighting consoles), and the underlying NTP / PTP (IEEE 1588) clock infrastructure these protocols ride on. Applies to DAW companions, performance instruments, lighting rigs, multi-machine installations, generative-art systems, and any device that must agree with peers on "what time is it, musically."
- **Touches principles:** #2, #4, #5, #6, #7, #8, #9, #10
- **Preamble:** Distributed musical timing looks like a transport problem and is actually a clock problem. The hard part is not "send a beat over the wire"; it's that every participating device has its own oscillator drifting at its own rate, its own audio (or render) buffer adding its own latency, its own network path with its own jitter, and its own idea of what "now" means. A correct design starts by separating the clock domains — wall clock, audio clock, beat clock, frame clock — and refuses to confuse them. Ableton Link is the most rigorous live protocol in the space because it is peer-to-peer (no single master to lose), it exposes phase (not just tempo), and it solves the consensus problem deterministically across joins, leaves, and partitions. LTC / MTC / SMPTE are the answers when video is the anchor and timecode is the contract. OSC time-tagged bundles and ArtNet TimeCode are the answers when timing must drive non-audio targets (lighting, generative visuals, robotics). The principles below are about respecting the gap between "sending timing information" and "achieving timing coherence."

### `node-graph-ui`

- **Title:** Node-Graph UI
- **Pairs with:** Node-graph / patching interfaces — environments where the
- **Touches principles:** #1, #4, #5, #6, #7, #8, #21
- **Preamble:**   user builds behavior by wiring discrete processing nodes (modules,   devices, operators) into a signal/data flow, where a node can be an opaque   container that opens to reveal the sub-graph that constitutes it, and where   "the patch" is itself a first-class, inspectable, editable object. Covers   the modular-synth / visual-dataflow family: virtual cables and ports,   sub-patch encapsulation, macro controls, polyphony/voice expansion,   modulation routing, signal-rate vs. control-rate distinctions.   documentation); Native Instruments, *Reaktor 6* (Core / Primary / Blocks   manuals); Cycling '74, *Max* documentation (the patcher, subpatch/`bpatcher`   encapsulation); Miller S. Puckette, *The Theory and Technique of Electronic   Music* (World Scientific, 2007 — Pure Data lineage); VCV, *VCV Rack Manual*;   W. W. Wadge & E. A. Ashcroft, *Lucid, the Dataflow Programming Language*   (Academic Press, 1985); general node-based-editor convention; opinion.

### `notation-design`

- **Title:** Notation Design
- **Pairs with:** The design of **composable visual notations** — block / box-and-wire / dataflow authoring surfaces where a user assembles a result from named primitive pieces (visual programming languages, node editors, modular-synth and pedalboard signal chains, spreadsheet-like grids, block languages). The discipline of making a *notation* legible: can a newcomer read what a piece is, see how pieces combine, predict the result, and assemble without producing nonsense. "Intuitive" reduced to its operational test for notations: the visible structure of the notation matches the structure of the thing being built, so reading the layout *is* understanding the program. Out of scope: the rendered artifact's own visual design (that's the domain the notation produces), and general screen/layout/typography craft.
- **Touches principles:** #1, #2, #5, #6, #7, #8, #9, #10, #13
- **Preamble:** A notation is not the program; it is the *clothing* the program wears so a human can read and edit it. The same engine can wear a notation that reads like assembly or one that reads like a recipe. The Cognitive Dimensions framework names the independent axes along which a notation succeeds or fails — and crucially, they are *trade-offs*, not a checklist to max out: tightening one (say, error-proofing) usually loosens another (say, freedom of expression). Design is choosing where on each axis this notation should sit, given who reads it. The cardinal sin, and the one that makes a composable system feel incomprehensible, is the **hidden dependency**: a piece silently relies on something not visible in the notation, so the layout lies about how the thing actually works.

### `offensive-security`

- **Title:** Offensive Security
- **Pairs with:** Authorized penetration testing and offensive security engagements (methodology) — rules of engagement, scoping, threat modeling, evidence handling, proof-of-concept discipline, severity rating, and reporting. Assumes a legitimate, authorized context (signed engagement, CTF, internal assessment of a system you own or are permitted to test).
- **Touches principles:** #1, #2, #9, #10, #11, #13, #14
- **Preamble:** Offensive testing is design discipline pointed backwards. You reason about a system's trust boundaries the way its builder should have — except your output is not the system, it's a verified account of where its claims break. Three things make this a methodology rather than ad-hoc poking: the rules of engagement are the scope contract, the proof-of-concept is the demonstrability gate, and the report is the durable artifact. The principles below are about keeping those honest under the pressure to find more, find it faster, and overstate what was found.

### `ordering-logistics-reporting`

- **Title:** Ordering, Logistics, and Reporting
- **Pairs with:** Operational business software — order entry and lifecycle, inventory and stock movement, scheduling and fulfillment (pickup / delivery / shipping), and the reports and dashboards built on top. Applies regardless of vertical (food service, retail, light manufacturing, B2B distribution) and regardless of storefront (phone-in, in-person, web, EDI).
- **Touches principles:** #2, #4, #6, #7, #8, #9, #10, #13, #14
- **Preamble:** Operational software runs the business: every order taken, every item moved, every report a stakeholder reads to decide what to do tomorrow. The three concerns are inseparable — orders mutate inventory and fulfillment commitments; logistics consumes those commitments and produces actuals; reports project the whole history into decisions. The principles below specialize for keeping these three on **orthogonal axes** while preserving the invariants that connect them (inventory conservation, time ordering, monetary reconciliation).

### `php`

- **Title:** PHP
- **Pairs with:** PHP, the language (versions 8.0+; 8.5 is the current stable as of late 2025 / early 2026, adding the pipe operator `|>`, clone-with, and `array_first`/`array_last`). Applies to any project where PHP is the authored language — framework code, library code, scripts, CLI tools.
- **Touches principles:** #2, #4, #5, #6, #7, #8, #9, #13
- **Preamble:** PHP grew up as a templating language with a stdlib bolted on, then spent two decades growing a real type system, real OOP, real error handling, and real package management on top of the same runtime. The result is a language with two coexisting dialects: the loose, weakly-typed, request-scoped scripting language of the 2000s, and the strict, typed, contract-oriented language of 2026. The principles below assume the modern dialect — strict types, exceptions over return-code errors, declared shapes over array bags — and treat the older dialect as a hazard to navigate around when touching legacy code.

### `plasma-theming`

- **Title:** Plasma Theming (Kvantum + Qt/KDE + GTK fallback)
- **Pairs with:** Building a *cohesive, toolkit-spanning* desktop theme on Plasma — the full System Settings → Appearance surface (color scheme, Plasma Style, Application Style, Window Decoration, icons, cursors, splash) across Qt-native, Kvantum-styled Qt, and GTK applications, with day/night awareness. Sits below `kde-plasma` (mechanism) and applies whenever the deliverable is *the look*.
- **Touches principles:** #1, #4, #5, #6, #7, #8, #9, #10
- **Preamble:** A Linux desktop has no single styling authority — it has *toolkits*, each with its own theming engine, that you must coax into agreement. Qt apps follow KColorScheme + a widget style (Breeze or Kvantum); GTK apps follow their own GTK theme; Chromium/Electron follow almost nothing. "Theming Plasma" is really *making N independent rendering stacks agree on one palette and read consistent in both light and dark*. The principles below specialize for that coordination problem: one source of color truth, fanned out to each toolkit through the bridge it actually reads, with the toolkits nobody can fully reach named honestly.

### `playwright`

- **Title:** Playwright
- **Pairs with:** Playwright — the browser-automation / end-to-end test runner (tool / skill)
- **Touches principles:** #2, #4, #5, #7, #9, #12, #13
- **Preamble:** Playwright is the engine that drives a real browser as a user would and observes what the browser actually renders. Used well, it closes the exact gap that lets a test suite stay green while the UI is broken — because its native idioms (user-facing locators, web-first retrying assertions, traces) are built to assert *the user's observable reality* rather than the DOM's internal shape. Used carelessly, it reproduces every false-green in a faster, more confident-looking wrapper: a `waitForTimeout` that hides a race, a CSS-selector locator coupled to markup, a `toBeVisible()` taken as proof the layout is right. The tool's defaults pull toward honesty; the failures come from fighting them.

### `postgres`

- **Title:** PostgreSQL
- **Pairs with:** PostgreSQL (versions 14–17) as the relational database in application projects. Covers schema design, query patterns, indexing, migrations, transactions, JSONB, full-text search, connection management, and operational concerns. Includes Drizzle ORM conventions where relevant, as a common TypeScript schema-definition and query layer.
- **Touches principles:** #1, #2, #4, #6, #7, #8, #9, #10, #13, #14
- **Preamble:** PostgreSQL is a full engine in the principles' sense — it owns ACID transactions, concurrency control, constraint enforcement, indexing, and query planning. The schema is the vision artifact: it declares what data exists, how it relates, and what invariants hold. Getting the schema right is vision work (#1); everything downstream — queries, indexes, migrations — sequences that engine's capabilities (#5). Most Postgres problems in application code stem from treating the database as a dumb store rather than engaging the engine's actual range.

### `powershell`

- **Title:** PowerShell & Windows Automation Scripting
- **Pairs with:** PowerShell as an automation language — Windows PowerShell 5.1 (the in-box, .NET-Framework-bound version that ships in WinPE and every Windows install) and PowerShell 7+ (pwsh, .NET, cross-platform) — plus its interop with classic `cmd`/batch and its behavior in constrained hosts (WinPE, Server Core, Constrained Language Mode). Covers writing robust, legible automation; not a specific framework.
- **Touches principles:** #4, #5, #6, #7, #8, #9, #13, #14
- **Preamble:** PowerShell is two things at once: a shell (terse, interactive, native-command-friendly) and a .NET object pipeline (typed, structured, programmable). Most bad PowerShell comes from using one when the job wanted the other — parsing text out of an object stream, or building a brittle string when an object was right there. The principles below specialize for keeping the shell-convenience and the object-rigor on their proper axes, and for surviving the hostile hosts (WinPE, locked-down endpoints) where this language earns its keep.

### `processor-memory`

- **Title:** Processor & Memory
- **Pairs with:** CPU scheduling, threading, memory layout, cache, allocators, and performance optimization across user-space and kernel boundaries.
- **Touches principles:** #2, #4, #7, #8, #9, #10, #13, #14
- **Preamble:** Performance is structural, not local. The biggest wins come from data layout, threading model, and allocation strategy — chosen before code exists, not patched in after. Profiling reveals where you are; choices made upfront determine where you can go. The principles below specialize for designing systems that meet a performance budget by construction.

### `prose-craft`

- **Title:** Prose Craft
- **Pairs with:** any prose a human reads — emails, announcements, release notes, README and docs prose, marketing and landing copy, in-product paragraphs longer than a label, commit/PR descriptions, reports. The unit is the *sentence and the paragraph*, judged as English: grammar, mechanics, rhythm, structure, and readability. This pairing owns whether the writing is **well-formed and clear**, independent of whether its claims are **true** — that truthfulness axis belongs to `copy-truth`. A sentence can be true and unreadable (this pairing's job) or grammatical and false (copy-truth's job); the two are orthogonal and a good piece of writing passes both. Out of scope: truth of behavioral claims (copy-truth), the *visual* presentation of text — type, spacing, hierarchy (a perceptual concern), and which words *name product concepts* — vocabulary architecture (a mental-model concern).
- **Touches principles:** #1, #2, #6, #7, #8
- **Preamble:** Prose is the one artifact whose defects no linter catches and every reader feels. A clumsy sentence doesn't error — it just quietly costs the reader attention: a buried point, a pronoun with no antecedent, four bullets that start four different ways, a paragraph that makes the reader hold five clauses in their head to reach a verb. None of it is "wrong" the way a bug is wrong, so it ships. The discipline is to treat writing structurally — the same orthogonality, boundaries, and consistency the principles demand of code apply to clauses, sentences, and sections — and to revise against that structure, because first-draft prose is reactive-patched by default: each thought stapled to the one before it in the order it occurred to the writer, not the order the reader needs.

### `pwa`

- **Title:** Progressive Web Apps
- **Pairs with:** Progressive Web Apps — service workers, web app manifest, installability, offline patterns, cache management, push notifications, background sync, and mobile-first delivery.
- **Touches principles:** #1, #2, #4, #7, #9, #10, #13
- **Preamble:** A PWA sits between a website and a native app. The gap between those two things is where every hard decision lives: how much offline capability to promise, which platform APIs actually work, how aggressively to cache, how to handle updates when the user hasn't closed a tab in three weeks. The service worker is a powerful engine — it intercepts every network request — but it runs in a lifecycle the developer does not fully control, on platforms with wildly different support. The principles below keep that complexity from collapsing into hand-waved "it works offline" claims.

### `python`

- **Title:** Python
- **Pairs with:** Python the language (3.11–3.14; 3.14 is current stable — free-threaded builds officially supported per PEP 779, deferred annotation evaluation per PEP 649/749, t-strings per PEP 750). Applies to any project where Python is the primary authored language — libraries, CLIs, services, scripts, and data/automation glue.
- **Touches principles:** #1, #2, #4, #5, #6, #7, #8, #9, #13
- **Preamble:** Python will let you write almost anything almost any way — that flexibility is the whole appeal and the whole hazard. The discipline other languages enforce through a compiler, Python defers to convention, tooling, and you. The principles below specialize for the places where Python's "it'll run" must be turned into "it's correct": typed boundaries, a real exception model, and the package structure that decides what's engine and what's caller.

### `raster-graphics`

- **Title:** Raster Graphics
- **Pairs with:** Producing intended visuals on 1D (linear pixel arrays) and 2D (pixel grids) raster surfaces — coordinate systems, framebuffers, rasterization, compositing, color synthesis, and animation craft, independent of the output device.
- **Touches principles:** #2, #4, #6, #7, #8, #9, #13, #14
- **Preamble:** Raster graphics is the craft of turning intent into a grid of colored samples. The trap is that the pipeline has many points where the math and the perceived image diverge: compositing with straight alpha fringes edges, blending in gamma-encoded space muddies midtones, integer-only coordinates alias and stutter, and at low resolution a single pixel's position is load-bearing. The output is empirical — you judge it by looking, not by reading the code — so "the code is correct" and "the image is right" are different claims. Dimensionality is a coordinate choice, not a separate discipline: a 1D strip is a 1×N grid, and the same framebuffer → rasterizer → compositor → animator layering serves both.

### `realtime-graphics`

- **Title:** Real-Time Graphics
- **Pairs with:** The rendering layer of browser interfaces — the work of producing a correct, smooth frame every ~16ms across a wide range of hardware. requestAnimationFrame frame loops and the vsync clock; the browser compositor and its layer model; GPU paths (WebGL/WebGL2 fragment & vertex shaders, Canvas2D, CSS transform/opacity compositing); per-frame budgets; GPU context and resource lifecycle; capability detection and tiered graceful degradation (a workstation GPU down to a Raspberry-Pi-class SoC); and the measurement of smoothness itself. Out of scope: the *behavior* layer (what an interaction means over time — interaction-design), visual/typographic structure and hierarchy (ui-ux), and styling tokens/theming (css). This pairing is about pixels-per-frame, not meaning-per-action.
- **Touches principles:** #2, #4, #5, #6, #7, #9, #13
- **Preamble:** A frame is a hard deadline that arrives sixty times a second and never slips. Everything in this domain is shaped by that fact: the renderer is an engine that must produce one finished, correct image inside a fixed budget, then do it again, forever, on hardware whose capability spans two orders of magnitude. "Smooth" is not an aesthetic — it is the measurable property that no frame missed its deadline. The failures here are specific and recurring: two animation loops that beat against each other, a clock that isn't the display's clock, a capability check that fires on noise, a GPU context that leaks until the browser refuses a new one, a "downgrade" that is permanent and trips on a transient. Designing the rendering engine deliberately — its clock, its budget, its degradation ladder, its resource lifecycle — is what separates butter from jank.

### `secret-custody`

- **Title:** Secret Custody (The Vault as a Configured Boundary)
- **Pairs with:** Designing and operating **the vault itself as a security boundary** — the container that holds secrets, keys, and certificates, and every setting that decides who can reach it, from where, under which permission model, and what happens when someone deletes it. It owns the *configuration* plane: the permission model choice and the migration between models; the network surface (firewall default action, IP and virtual-network rules, private endpoints, public-access disablement, trusted-service bypass); soft-delete and purge protection and the retention interval that can only be chosen once; the vault-topology decision (one vault per app, per environment, per tenant, or one shared vault with object-scoped grants); the officer/user/reader separation and the control-plane escalation path that undermines it; expiry and rotation as *cadence you must enforce yourself*; break-glass credential custody; and the census that proves any of it is still true. It is **not** the key hierarchy — wrapping, unwrapping, rewrap migrations, and which algorithm protects what are a different plane, one that hands you an *operation* where this one hands you a *container*. Nor is it the identity provider that mints the principals, the just-in-time elevation system that decides when a standing grant becomes an active one, the constrained-delegation policy governing what a grantor may hand out, or the application-level authorization sitting above a retrieved value.
- **Touches principles:** #1, #2, #4, #6, #7, #9, #10, #11, #13, #15, #18, #19, #20
- **Preamble:** A vault is the one component in a system whose **configuration is the security claim**. Everywhere else, a control either works or visibly fails: a closed port refuses a connection, a missing role throws 403, a bad certificate breaks the handshake. A vault's controls fail *in a third way* — they apply to a narrower surface than their name suggests, and the vault reports itself hardened either way. The firewall governs the data plane and **not** the control plane, so a deployment template writes secrets straight past a vault whose portal reads "selected networks only." Disabling public network access **does not** suppress the trusted-services bypass. An expiry date on a secret is **informational**; the `get` succeeds after it passes. Object-scope role assignments look like per-team isolation and are explicitly documented not to be one. Every one of those is a documented, intended behavior, and every one of them turns a green posture screen into a false claim — which means **a vault's security posture cannot be read off its settings; it has to be derived from which plane each setting actually governs.**

### `service-conformance`

- **Title:** Service Conformance
- **Pairs with:** Software whose job is to prove that what an organization **delivered** matches what it **committed** — and to surface the gap when it doesn't. The discipline is "say what you do, do what you say, prove it": a **commitment** side (obligations derived from a contract, SOW, service catalog, SLA, or internal policy — what was promised, by when, measured how), an **evidence** side (recorded actuals — attestations of what was actually done, with provenance), and a **reconciliation** that compares the two and names the drift. Industry-agnostic — MSP customer onboarding and managed-service delivery, professional-services SOW fulfillment, SLA/SLO conformance, internal QMS conformity (ISO-9001-style), vendor/supplier obligation tracking, any "did we actually do what we sold?" surface. This is **internal conformance** (delivery vs. promise), not external regulatory attestation to an outside authority — see #10.
- **Touches principles:** #2, #4, #5, #6, #7, #8, #9, #10, #12, #13, #14
- **Preamble:** Conformance software lives between two records that are written by different people at different times for different reasons: the **promise** (written when the deal closed — a contract, a SOW, a service-catalog selection, an onboarding checklist someone agreed to) and the **delivery** (written as work happens — tickets closed, users provisioned, baselines applied, reviews performed). Its entire value is the **reconciliation** of those two records and the honest naming of where they disagree. That disagreement runs in *both directions*: "we promised X and there's no evidence we did it" (a delivery gap) and "we did Y but it maps to no promise / a different promise" (a recording or scope gap). Three things must stay on **orthogonal axes**: the **commitment register** (what we owe), the **evidence store** (what we can prove), and the **reconciliation engine** (the verdict). The invariants are: every conformance claim is backed by evidence with provenance (no claim from recollection); every obligation traces to a source (no invented or orphaned promises); and drift is *surfaced for adjudication*, never silently resolved in either party's favor. Collapse any two of the three axes and the system stops being able to answer the only question it exists to answer — *did we do what we said?* — and becomes a second, prettier copy of the operational system that already can't.

### `svelte`

- **Title:** Svelte
- **Pairs with:** Svelte the language and compiler (versions 3–5, with the runes-based reactivity model as the canonical model in Svelte 5). Component-authoring concerns: reactivity primitives, props, snippets, lifecycle, scoped styles, transitions, actions, component-level state.
- **Touches principles:** #4, #5, #6, #7, #8
- **Preamble:** Svelte compiles components to imperative DOM operations rather than diffing a virtual DOM at runtime. That shifts where the work lands: more decisions move to author-time and compile-time, fewer to render-time. The principles below show where Svelte's compilation model and reactivity primitives change how axes get drawn. This pairing covers **the component language only** — framework concerns (routing, load, adapters, hooks, env) are out of scope.

### `sveltekit`

- **Title:** SvelteKit
- **Pairs with:** SvelteKit the application framework (2.x, v2.57.x as of May 2026). Routing, load functions, adapters, server/universal split, `$env`, hooks, form actions, remote functions, prerendering, error boundaries, `$app/state`, service workers, link previews, page options.
- **Touches principles:** #1, #4, #5, #7, #8, #14
- **Preamble:** SvelteKit is the application framework around Svelte the component language. It covers everything that turns components into an app: where a route lives, when its data loads, where its code runs (server, client, or both), how its environment is read, how its errors are handled, how it ships. These are the decisions a "use Svelte" choice doesn't make for you, and they accumulate fast. This pairing covers framework concerns only — component-authoring concerns (reactivity primitives, props, snippets, scoped styles) are out of scope.

### `tdd`

- **Title:** TDD
- **Pairs with:** Test-Driven Development (methodology)
- **Touches principles:** #1, #3, #4, #5, #6, #7, #9, #10, #13, #14
- **Preamble:** TDD's central move — write the test before the code — is itself an enactment of orthogonality: the test is the use-case axis, the code is the capability axis, and the red-green-refactor cycle keeps them honest by changing only one at a time. The principles below show where TDD already sits inside this collection's framing.

### `technical-seo`

- **Title:** Technical SEO
- **Pairs with:** The **machine-readable surface a site presents to crawlers and answer engines**, and the architecture that keeps it coherent over time. Covers URL and canonical architecture (route shape, trailing-slash and case policy, parameter and facet handling); crawl control and index control as two separate axes; structured data as a typed, derived emission rather than hand-authored markup; the `robots.txt` and sitemap surface; internal linking as a graph the crawler traverses; the **migration contract** that carries accrued signal across a URL change; duplicate and near-duplicate URL families; and the measurement surface (field data vs. lab data, and what each can honestly claim). Out of scope, in two kinds — the distinction matters, because one is a disavowal and the other is a hand-off you will need. **A different discipline:** the *demand* side of search (positioning, audience segmentation, which claims persuade, credibility signals, lead conversion) is marketing, not engineering; **content quality and authorship** — whether the copy is good, original, or worth ranking; and **paid search**. **The same discipline, an adjacent axis, owned elsewhere:** the **performance engineering** that meets a Core Web Vitals threshold — rendering strategy, image delivery, bundle budgets. This pairing owns *what the threshold is, how it is assessed, and what may honestly be claimed about it*; the work of hitting it is a performance-engineering axis, deliberately carved out rather than absorbed (#3, #6), and a reader who needs it should expect to look outside this file rather than conclude it does not matter.
- **Touches principles:** #2, #4, #5, #6, #7, #8, #9, #10, #11, #12, #13, #15, #17, #18, #19, #20, #21
- **Preamble:** Every other engineering surface tells you whether it worked. A failed request returns a status code, a broken build fails, a wrong value is on the screen. Technical SEO's output is consumed by **a machine you cannot inspect, on a schedule you do not control, which reports back in an aggregate that lags the change by weeks and is confounded by everything else that moved in the meantime.** And almost nothing in the domain is a directive. A canonical link is "a strong signal," not a command — the engine "will decide which pages (if any) are duplicates, based on similarity of content," and may pick a different one. Correct structured data earns *eligibility*: "Google does not guarantee that your structured data will show up in search results, even if your page is marked up correctly." Even a permanent redirect only transfers signal on the crawler's timetable, over weeks. So the characteristic failure here is **a change that is correct, deployed, and verifiably present in the markup, and simply not honored** — and at deploy time that is indistinguishable from a change that worked.

### `tenant-data-isolation`

- **Title:** Tenant Data Isolation (Application-Layer Row Scoping)
- **Pairs with:** Building and operating the **per-row tenancy guarantee** inside a shared-store application — where the tenant scope is derived (from the authenticated session, never from a client-supplied parameter), how it reaches every read and write (a data-access layer with no unscoped method, a database session variable feeding row-level security, a builder that refuses an unscoped predicate), which surfaces legitimately cross the boundary, and how the crossing is proven impossible rather than assumed. This is the narrow question: *given a legitimate, authenticated, non-malicious-looking user, can any code path return another tenant's row.* Not infrastructure isolation (a network, cluster, resource group, or database per tenant — a different guarantee with different economics), not edge/hostname tenancy resolution (which decides *which* tenant a request claims, upstream of this), and not authorization generally (what a *role* may do — orthogonal: the role check can pass and the row still cross).
- **Touches principles:** #1, #2, #4, #5, #6, #7, #9, #10, #13, #16, #17, #18, #19, #20
- **Preamble:** Every other correctness property in an application announces its own violation. A failed authorization check produces a 403 and a support ticket. A bad migration throws. A wrong join returns nothing and someone sees the empty page. A dropped tenant predicate does none of that: it returns **HTTP 200, faster than the correct query**, to a real authenticated user who was fully entitled to ask the question — with *more* rows in the result than there should have been. Every signal the system watches reads green: no error, no denial, no anomalous auth event, no latency regression. And the defect is an **omission** — a predicate that is not there — so there is no token to grep for, no stack frame it appears in, and no line in the diff that looks wrong. Both halves of that asymmetry point the same way: a guarantee whose violation is invisible in production and unsearchable in source cannot be maintained by *remembering* to write it, and cannot be validated by watching. It has to be made structurally impossible to omit, and it has to be proven by tests that deliberately attempt the crossing and assert it fails — because the happy-path test passes, byte-identically, on the broken code.

### `terraform`

- **Title:** Terraform (Infrastructure as Code)
- **Pairs with:** Declarative infrastructure provisioning with Terraform / OpenTofu (HCL) against any provider (Azure `azurerm`, AWS, GCP, Cloudflare, etc.). The **desired-state / apply** side of infrastructure: "describe what should exist, let the engine converge reality to it" — not imperative `az`/`aws`/`gcloud` scripting (that's a different axis), and not runtime configuration management (Ansible/Chef). Covers state, modules, the plan/apply lifecycle, drift, and the boundary between what Terraform can own and what it cannot.
- **Touches principles:** #1, #2, #4, #5, #6, #7, #8, #9, #10, #11, #13, #14
- **Preamble:** Terraform is the rare tool whose entire model *is* the principles made literal. Its **state file is "state lives in files" (#14) as a hard runtime fact** — the recorded reality the engine diffs against. Its **plan/apply split is "done means demonstrable" (#13)** — a plan is a claim, an apply is the demonstration, and `plan` showing no changes is the machine-checkable evidence. Its **declarative core is "honest bounds" (#9)**: the config asserts a desired end-state, and everything the config *doesn't* assert is, by omission, a claim that Terraform doesn't manage it. The traps in this domain are all about that last point — the gap between what the HCL *says* is managed and what *actually* is.

### `token-economy`

- **Title:** Token & Context Economy
- **Pairs with:** designing and operating LLM agent / prompt systems so the context window is spent where it earns fidelity and nowhere else — system-prompt and tool-description budgeting, retrieval-vs-inline trade-offs, per-turn injection, prompt-cache layout, and the cost/latency/attention axes they trade against. Applies whenever the goal is *measurable* economy — fewer tokens, faster turns, or cleaner attention — not "feels tighter."
- **Touches principles:** #1, #2, #4, #7, #9, #13, #16
- **Preamble:** Context engineering is where vibes go to lie, the same way perf tuning is. "This is leaner" is the single most expensive sentence in the domain — it justifies cuts that save nothing, drop load-bearing fidelity, or trade a per-session token for a per-turn one and net-lose. The principles below specialize for one discipline: **a token spend is a claim, and a claim needs a number, a frequency, and an honest bound.** The binding constraint is rarely raw size — it is usually *frequency* (what's paid every turn vs once a session), *duplication* (the same fact billed in three places), and *attention dilution* (the window so full the model stops reading the middle) — so the economy that matters is rarely the cut that's satisfying to make.

### `typescript`

- **Title:** TypeScript
- **Pairs with:** TypeScript (versions 4.x, 5.x, and 6.x). 6.0 shipped March 2026 as the last JavaScript-implemented release; `strict` is now the default, `target` defaults to `ES2025`, `module` to `esnext`, and `target: es5` is deprecated. TypeScript 7.0 will be a Go-native compiler rewrite. Applies to any project where TypeScript is the primary authored language — pure-library packages, application code, and codebases that transpile to JavaScript for runtime.
- **Touches principles:** #4, #5, #6, #7, #8, #13
- **Preamble:** TypeScript's job is to make the engine surface (function signatures, exported types, public APIs) checkable before runtime. The principles below are about treating the type system as a real engine layer with its own range — not as documentation, not as decoration, and not as an obstacle to opt out of with `any`.

### `ui-ux`

- **Title:** UI/UX
- **Pairs with:** UI design as architectural discipline — vision and journey to screens, single-purpose screens, components as bounded units, design systems, visual hierarchy and typography, accessibility basics, and usability testing as the verification surface. Covers the structural and visual layer of UI work. Out of scope: the cognitive layer (mental-model formation, signifiers, recognition vs. recall, cognitive load) and the interaction-behavior layer (microinteractions, feedback timing, error recovery, gesture and modality, latency budgets).
- **Touches principles:** #1, #2, #6, #7, #8, #9, #10, #13
- **Preamble:** UI work has three layers that pull on different design muscles: the **architectural and visual surface** (how the product is structured, how screens compose, what the design system says), the **cognitive layer** (how users build a working model of the system in their heads), and the **interaction-behavior layer** (what happens over time when the user acts). This pairing covers the first. It is about UI as architecture — vision, structure, component boundaries, design systems, visual hierarchy, accessibility surface. Get the architecture right and the other two layers have somewhere coherent to live.

### `visual-perception`

- **Title:** Visual Perception
- **Pairs with:** the perceptual layer of interface and information design — how the human visual system actually parses a screen before and during conscious reading: pre-attentive processing, gestalt grouping, visual scan behavior, color science and color psychology (with its evidentiary limits), shape semantics, typography legibility, motion perception, and the empirical interaction laws (Fitts, Hick) that govern target and choice design. Covers the *perception science* under layout, color, and shape decisions. Out of scope: the structural/design-system layer (screen composition, component boundaries, token architecture), the cognitive layer (mental-model formation), and the interaction-behavior layer (feedback timing, error recovery) — this pairing explains *why a rendering reads the way it does*, not how to architect the product around it.
- **Touches principles:** #2, #6, #8, #9, #10, #13
- **Preamble:** A screen is parsed twice: once by the visual system in the first ~200ms — involuntary, parallel, pre-attentive — and only then by deliberate reading. Layout, color, size, and shape decisions program the first parse whether the designer intends to or not. This pairing treats that first parse as an engineered surface with measurable properties: contrast ratios compute, target sizes measure, grouping distances compare, choice counts enumerate. Where the science is strong (pre-attentive channels, gestalt grouping, Fitts/Hick, legibility metrics, contrast perception) it gives numbers. Where the science is weak or popularly overstated (most color-emotion claims) it says so explicitly — an honest perceptual claim beats a confident decorating myth.

### `web-app-pentest`

- **Title:** Web Application Pentest
- **Pairs with:** Web application and server-rendered application penetration testing (skill / domain) — testing HTTP request/response surfaces, server-side request handlers, business-logic flaws, and input handling. Assumes an authorized context.
- **Touches principles:** #2, #4, #6, #7, #13
- **Preamble:** A web application's security posture is a claim: every request handler validates its inputs and authorizes its caller correctly, across the entire space of requests an attacker can send. Web app testing probes that claim from the request edge — the one boundary the attacker fully controls. The principles below specialize for systematically mapping the request space and finding the handlers whose claims don't hold across it.

### `web-frontend`

- **Title:** Web Frontend
- **Pairs with:** Browser-based UIs (HTML, CSS, JavaScript or TypeScript). Applies to any project whose user surface runs in a web browser, regardless of framework choice.
- **Touches principles:** #4, #5, #6, #7, #8, #14
- **Preamble:** Browser UIs sit between two unforgiving environments: the network on one side (latency, failure, partial loads) and the user's hardware on the other (variable performance, input modalities, viewport sizes, accessibility constraints). The principles below are about staying coherent in the middle without leaning toward any particular framework.

### `windows-debugging`

- **Title:** Windows Servicing & Boot Recovery (offline / WinPE)
- **Pairs with:** Debugging and repairing unbootable Windows 10/11 (CBS/CSI component servicing, WinRE/Reset, DISM, BCD, kernel bugchecks) from an offline WinPE environment. Targets modern builds (Win11 24H2/25H2, build 26100/26200) with the checkpoint-cumulative-update + forward/reverse-differential servicing model.
- **Touches principles:** #2, #4, #9, #10, #13, #14, #15, #17
- **Preamble:** Offline Windows repair is unusually punishing because the system lies to you: logs name files that aren't the cause, "success" exit codes precede a box that still won't boot, version numbers that *look* wrong are often correct, and an edit you make can be silently reverted on next boot. The principles below specialize for a domain where **the only ground truth is "did it boot," and everything upstream of that is a claim to verify.**

---

## Prior context — read this first

This is **Phase 1** of the bootstrap flow: pairing selection. The
project's vision was already elicited and locked in Phase 0 and written
to `.agent/REPORTS/project-brief.md`.

**Before asking anything, read `.agent/REPORTS/project-brief.md` in
full.** It carries the vision, stack, user-facing surface, methodology,
constraints, expertise needed, and gaps. It is your **input** — your job
here is to map it onto the pairing catalog, not to re-elicit what it
already establishes (Principle 14 — don't re-ask what's already in a
file).

If no brief exists (e.g. `vision/` was skipped), fall back to a short
elicitation: ask only the few questions you need to recommend pairings —
vision in one sentence, stack/platforms, user-facing surface, committed
methodology, hard constraints — then proceed. Do **not** write the brief
file yourself in this fallback; that's Phase 0's job. Note the gap to the
user.

## Interview

Keep this short — the heavy elicitation already happened in Phase 0.

1. **Confirm the brief.** State back, in 2–3 sentences, what the brief
   establishes about the project (vision, stack, surface). Ask the user
   to confirm or correct. Correct the brief in conversation if needed,
   but the brief file is Phase 0's artifact — don't rewrite it here.
2. **Targeted follow-ups only.** Ask a question **only** when a
   pairing-relevant dimension is genuinely unclear from the brief —
   e.g. the brief says "embedded" but doesn't name the framework, and
   the framework decides between two candidate pairings. One good
   question, not a survey. If the brief is clear enough to recommend
   from, skip straight to the recommendation.

## Output format

Read the **Available pairings** catalog above, map the brief against it,
and produce the three sections below.

### Recommended pairings

For each pairing you recommend, give:

- **`<pairing-name>`** — one or two sentences on *why* it fits this
  project. Tie it to a specific thing in the brief (or the user's
  confirmation/correction of it).

Group recommendations into **core** (essential — without them the
project's pairings are incomplete) and **supporting** (relevant but
optional — pick up if bandwidth allows).

**Standing rule — graphical-UI projects get the user-perspective lens.**
If the brief's *user-facing surface* is **graphical** (a screen UI),
recommend **`jobs-to-be-done`** as a **core** pairing by default — the lens
that designs from the person and their job, models multi-role users, and
catches overloaded domain terms (a word that means two things to two roles).
Then confirm the brief carries a **Personas / roles** section; if it
doesn't, flag the gap so it gets added (that section is what the
seat-walkthrough design tool reads). Scale this down honestly: a
single-user tool needs one persona line, not a cast; a purely
programmatic / CLI surface doesn't need the lens at all.

### Gaps — domains not covered by existing pairings

For each domain the project needs that has no existing pairing, give:

- **`<proposed-name>`** — what the pairing would cover, why no existing
  pairing fits, and which sources the user could draw from.

Be honest about gaps. The user wants to know what's missing as much as
what's present. If there are no gaps, say so.

### Suggested `PROJECT-SCOPE.md` snippet

Produce a ready-to-paste markdown snippet for the "Pairings (optional)"
section of the project's `.agent/PROJECT-SCOPE.md`:

````markdown
## Pairings (optional)

- <pairing-name> — <reason from the brief>
- <pairing-name> — <reason>
````

This is advisory. The user commits the final selection by hand.

### Next step

Tell the user: once they've picked pairings, proceed to **Phase 2 —
scope elicitation** by running, from this directory:

```
bootstrap-project.sh <pairing1> <pairing2> ...
```

with the chosen pairing names. That generates the scope-interview pack
(which also reads the brief) and replaces the bootstrap `CLAUDE.md`.
