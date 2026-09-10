<!-- GENERATED-BY: scope/scope.sh on 2026-09-09T19:54:25Z -->
<!-- Source: /Users/stephen/.dotagent/scope -->

# Scope Elicitation — Interview Pack

You are conducting a structured interview to populate a project's
`.agent/PROJECT-SCOPE.md`. The user opens this pack inside the
target project. Your job is to ask the questions in the **Interview**
section, one section at a time, and at the end emit a populated scope
file that follows the **Scope Template** structure exactly.

This is advisory. You produce the populated scope file as a final
markdown block; the human reviews and commits it. Do not write the
file yourself.

The **Principles** below are the source of truth the project will be
measured against. The **Scope Template** is the structure the
populated file must match. Optional **Additional context** sections
(included via `--include`) give domain background — typically a
pairings bundle the user has already selected.

---

# Principles (source of truth)

The text below is the canonical content of `personal/PERSONAL-PRINCIPLES.md`.
Reference principles by number when asking questions or producing the
populated scope.

# Personal Working Principles

These are the principles I apply across all projects I build. Individual
projects can extend, override, or de-prioritize these in their own
`PROJECT-SCOPE.md`, but in the absence of project-specific guidance, these
apply.

These principles are about *how to design and reason* — they do not
dictate implementation choices (language, runtime, framework, stack,
storage). Language and stack choices belong in `PROJECT-SCOPE.md` per
project, where they can be debated against specific requirements. If an
agent reads these and infers a specific implementation constraint
(e.g., "must be bash," "must be TypeScript"), that's a misread —
escalate it back to the project's scope file.

## Orthogonality

The spine. Two things are orthogonal when they sit on independent axes —
changes to one don't ripple into the other, and the same fact is never
represented in two places. The three subsections below establish axes,
keep engines and instructions on separate ones, and preserve axis
separation across modules.

### Establishing axes

1. **Vision down to detail.** Start from the overall picture, even if it's
   wild or only partially formed. The vision is what tells you which axes
   exist. Share specifics where I have conviction; leave the rest loose
   for the design to discover. Don't build detail-up without a vision.

2. **Upfront anticipation over reactive patching.** Enumerate the
   possibilities each axis must handle *before* building it, not after.
   Reactive patches couple by default — the new case gets stapled to
   whatever's nearest. This applies to scope, naming, module boundaries,
   and especially to engines (see #4). Anticipation means *enumerating
   the case-space and naming the undecided cases as parked forks* — not
   resolving them all upfront (that deferral is #3's job). Enumerate the
   axes; park the details.

3. **Modularity absorbs ambiguity within axes.** Identifying which axes
   exist is upfront work (#1, #2, #4). What lives on each axis can be
   deferred: when a detail is undecided, carve out a module to own it
   later rather than guessing or hardcoding. A module boundary is a
   deferred-decision marker — it isolates the unknown from everything
   around it. A deferred-decision marker should be *named and written* —
   a stub module, an address with no children yet, an `Open` fork — not
   left implicit. An empty-but-named boundary is valid and resolvable
   later. When the axis itself is unclear, you're still in vision work
   (#1), not yet in design.

### Engines and instructions as orthogonal layers

*"Engine" here is a role — the thing that handles a job's full
case-space within its module boundary. It is **not** an implementation
choice. A shell script, TypeScript module, Rust binary, SQL query, or
hosted service can each be the engine for the job they own. Per-project
scope decides implementation; the principles do not.*

4. **Engines are built to handle every possibility they could have to deal
   with, from the start — as much as possible.** Design the engine
   against the full range of what it might be asked to do, not just
   today's use case. A case discovered later shouldn't require changing
   the engine; if it does, use-case has coupled to engine internals and
   the upfront thinking was incomplete. This is a design *target*, not a
   claim of completed coverage — claims about coverage are governed
   by #9. An engine covers the *union* of cases across all anticipated
   use-sites; each site opts into a *subset*. Capabilities a site doesn't
   need stay optional and degrade silently (same engine, different
   subset).

5. **Instructions sequence engine capabilities; they don't extend them.**
   Engine and instructions live on orthogonal axes: the engine exposes
   capability, instructions sequence it for a use case. Specifics,
   sequencing, and use-case logic live in instructions written against
   the engine's exposed surface. If an instruction needs to reach past
   the engine, or asks for something the engine can't do, that's a
   coupling violation — fix the engine, don't paper over it. A derived
   view/projection is an instruction too: it reads and presents engine
   output but never authors back into the canonical store. A view that
   needs to write is the same coupling violation — fix the surface, not
   the view.

### Structural orthogonality

6. **Modules do one job.** Each component owns a single, well-named
   responsibility. If something feels like "two things glued together,"
   split it. One axis per module. The test for "two things glued
   together": do they change together (same axis — keep) or vary
   independently (different axes — split)? Independent variation is the
   split signal.

7. **Clean boundaries, owned state.** Components own their own state and
   controls. No reaching into siblings. The boundary is the contract;
   one fact lives in one place. When a fact must appear in a second place
   (a view, board, index, cache), it's a *derived projection* of the one
   canonical place — never a re-authored copy. Derivation preserves
   single-source; duplication breaks it.

8. **Architectural consistency.** Once a category, pattern, or convention
   exists, new items that fit it go there. Scattered parallels are
   duplicate representations of one concept — the same idea on multiple
   axes when it belongs on one. If the existing pattern is wrong, name
   it and propose replacing it before adding to it. Before extending a
   pattern, verify what it actually is *at source* — not from memory —
   and that you're extending the canonical instance, not a stale copy
   (links to #15).

## Scope and rigor

9. **Honest bounds over universal claims.** A claim like "this covers
   everything in domain X" must come with a definition of X and a
   constructive argument for the coverage. "Probably covers most cases"
   is not a finished thought. And when a claim *can't* yet be supported,
   state the gap and name precisely what would close it — an unprovable
   claim becomes a *named gap with a closing condition*, not a hand-wave
   and not a fake pass. (#9 — in-scope rigor — and #10 — naming what's
   out — are the two halves of honest scope.)

10. **Explicit exclusions over vague coverage.** What's NOT in scope
    should be named and justified. "We don't do X because Y" is a
    finished design decision; "we cover everything" is a hand-wave. An
    exclusion that *might* return should name its re-entry condition —
    "out now because Y; revisit when Z" — turning a static exclusion into
    a *tracked deferral* rather than a permanent no. (The negative half of
    honest scope; #9 is the positive half.)

11. **Scope decisions are durable.** Once captured in a decision file,
    a scope decision stands until explicitly superseded by a new dated
    decision. Implementation work cannot quietly expand scope. A change to
    durable scope comes as a new dated decision that **names its
    relationship to the prior** — *supersedes / amends / extends* —
    explicitly, never a silent edit and never left ambiguous.

12. **Surface conflicts, never resolve silently.** When two prior
    decisions disagree, or a new request contradicts an old decision,
    name the conflict and force an explicit choice. Silent resolution
    is how projects drift. The chosen resolution is then recorded durably
    (which way was chosen, and why), so the conflict stays resolved and
    doesn't resurface. Surfacing forces the choice; capturing keeps it.

## Execution

13. **Done means demonstrable, not reported.** If I can't point to it in
    a file or see the behavior, it doesn't exist yet. Roll-ups,
    milestone reports, and research summaries are inputs to verify —
    not evidence. This covers both *outcome* claims ("this was done")
    and *factual* claims ("X is defined at file:line, the value is N"):
    any concrete cite echoed without checking the source is hearsay.
    Where the demonstrable thing can be pointed at mechanically,
    *mechanize the check*: a done-claim carries a machine-resolvable
    evidence pointer (a passing test, an existing artifact, a Binding
    decision), and the verification itself becomes a *test*, not only a
    human reading a diff — "demonstrable" graduates from "a human *can*
    verify" to "the system *enforces*." Its document-review case —
    verifying cited claims in a doc before acting on it — is the corollary
    at #15. Verification protocol in `CLAUDE-OPERATING-MANUAL.md`
    operationalizes this rule.

14. **State lives in files, not conversations.** The chat is volatile;
    the repo is durable. Design rules, decisions, and milestones get
    written down — that's how they survive across sessions and automated
    runs. Durable state includes the *links between files* (provenance
    pointers), not just their contents — kept bidirectional so a fact's
    lineage is traversable from either end. The chain is state too.

15. **Verify cites — the document-review corollary of #13.** When
    reviewing a document with cited technical claims (file:line, "zero
    readers of X", "function does Y"), verify the load-bearing claims at
    source *before* pressure-testing the recommendation. Treat the doc's
    claims as claims-to-verify, not facts-to-paraphrase. Applies
    recursively to subagent reports. Verify the *verification* itself,
    too: confirm your check actually exercised the case it claims to — a
    check that "passes" without running the path it was meant to test is
    false confidence, worse than no check. When verification surfaces a
    finding the doc missed, name it — don't fold it silently into the
    next edit. Skip when the doc is descriptive (changelog, postmortem
    narrative) rather than recommendation-bearing.

16. **Lead architectural choices with capability data.** Before asking
    me to pick "unify vs keep both" / "refactor vs accept" / "implement
    vs delete metadata" — read both implementations, list each side's
    capabilities explicitly, name divergences as bug vs intentional,
    identify side-effects blocking direct merge, sketch the zero-loss
    migration path with effort estimate, and name residual losses
    honestly. Only then pose the question with the unification path
    concretely described. This applies to *greenfield* design forks too,
    not only existing-implementation comparisons: when neither option is
    built yet, the capability data is each direction's *projected*
    capabilities + trade-offs, laid out before the choice. The analysis
    is your job; my job is the architectural decision.

17. **Repeated failure indicts the model, not the attempt — but
    distinguish looping from iterating.** When the *same approach* fails
    the *same way* with *no new information*, treat the repeat as evidence
    of an unaccounted-for assumption, not a prompt to retry harder: stop,
    enumerate what both attempts silently took for granted, and hunt the
    hidden variable they shared. The trigger is *absence of information
    gain, not a failure count* — a path that fails *differently* each
    time, or narrows the problem with each miss, is iterating honestly;
    let it run. And the response is to *escalate the search to the frame,
    not abandon the path* — finding the missing variable often *rescues*
    it; dropping the path is only one possible outcome, and on a
    direction I chose it's a checkpoint to raise (Interaction-Style #4),
    not a unilateral give-up. (The self-directed complement of
    Interaction-Style #7: there *I* reframe a wrong frame; here *you* must,
    because two like failures are the signal your own frame is wrong.
    Distinct from #15 — that's false confidence in one check; this is
    false confidence across attempts.)

18. **Removal needs authorization, never absence.** An action that
    deletes, replaces, or contradicts a *load-bearing established
    structure* — a ratified decision, a data model, a spine an earlier
    body of work stood up — is a **Critical conflict by definition**, not
    a severity judgment call. It may proceed only by *citing the decision
    that authorizes it* (a supersede/amend, #11). "It wasn't in the
    inventory," "it looked unused," or "I assumed that's what you meant"
    is **never** authorization. Absence from a list is a *review
    trigger*, not a delete warrant — and the list may be stale (#15), so
    the authorizing cite is checked against the **decision register, not
    the inventory**. The default for removing load-bearing structure is
    **stop and surface** (#12), because destruction is asymmetric: a
    wrong build is edited, a wrong delete is rebuilt from nothing. The
    costliest context loss is not forgetting a fact — it is *acting
    against accumulated work*. (The destructive specialization of #11 and
    #12; its conversational reflex is Interaction-Style #10, its
    mechanical backstop the pre-commit removal gate.)

19. **Right the first time over ship-then-patch.** On *load-bearing
    axes* — architecture, data shape, module boundaries, engines —
    default to building the durable, long-term form up front, even when
    a thinner version would ship sooner. A stub that later gets torn out
    and rebuilt costs more than the time it saved, and it *couples*
    whatever got built on top of it in the interim (the #18 asymmetry: a
    wrong build is edited, a wrong shortcut is unwound from under
    everything that leaned on it). This is a **default tie-breaker** for
    when "ship something now" and "build it right" genuinely conflict —
    **not** a mandate to gold-plate. It governs the load-bearing spine,
    not undecided details *within* an axis: those still defer under #3
    (name the module, don't guess its contents), and trivial or
    mechanical work still just gets built with no added ceremony. A
    project that genuinely needs MVP-first cadence overrides this in its
    `PROJECT-SCOPE.md` (#11) — the override is durable and named, not a
    silent per-task exception.

20. **Vendor truth for versions and command surfaces.** Any claim about
    an external dependency's *current* state — a package's latest
    version, a CLI's flags or subcommands, an API's endpoints or schema,
    an install/upgrade incantation, a config-file format — is checked
    against the **vendor-defined resource** (the official docs, the
    registry itself, the tool's own `--help`/changelog) *at time of use*,
    never emitted from recall. Model memory of a fast-moving vendor
    surface is a stale cache that presents exactly like knowledge — it
    compiles confidence out of an old snapshot, and it has burned enough
    sessions to earn permanent tape. Mechanically: before writing a
    version pin, handing over a runnable command (the Interaction-Style
    #8/#9 blocks), or authoring doc prose that names a vendor surface,
    fetch or run the canonical source and cite it; if the source can't
    be reached, say so and mark the claim **unverified** (#9's named gap)
    rather than filling the hole with a guess. The outward
    specialization of #13/#15: those verify *our* artifacts and cites;
    this verifies the *world's* — the vendor's docs are the decision
    register for the vendor's surface (#18's logic, pointed outward).

21. **Born with its preflight.** A unit of code ships from its *first
    commit* with its preconditions — the required env, identities,
    inputs, invariants — declared **as data in one place**; every
    enforcement surface (the runtime refusal, the gate measurement,
    the deploy stamp) *derives* from that declaration, never
    hand-copies it. A missing precondition then surfaces as a **named
    refusal at the boundary** — "X is required and absent" — not as
    downstream wheel-spin hours later in a symptom that names nothing.
    Adding a requirement is one edit; all consumers follow. The
    payoff is asymmetric and proven: the first time a gate *derived*
    its checks from a declared list instead of hand-checking, it
    immediately caught a requirement no hand-written check had ever
    named — the same absence that had previously cost hours of
    unexplained failure. Hand-copied check lists drift the moment a
    second consumer copies them (#7's one-fact rule, violated at the
    enforcement layer). Specializes #2/#4/#7 into build discipline:
    enumeration (#2) must be *executable*, the case-space an engine
    handles (#4) has one declared home (#7), and the checks exist
    *before the first consumer needs them* — prevention at birth,
    where #17 is the recovery posture after the spin this principle
    exists to make impossible.

22. **Rigor proportional to stakes.** Every other principle in this
    file pushes toward *more* — more anticipation (#2), more
    completeness (#4), more durability (#19), more authorization (#18),
    more preflight (#21). **None of them caps.** This one is the
    governor: the *grade* of rigor a piece of work gets is set by the
    consequence of getting it wrong, not by the ceiling the other
    principles can reach. Load-bearing axes — architecture, data shape,
    module boundaries, an engine, anything future work must conform to
    — get the full treatment. Throwaway and easily-reversed work ships
    throwaway-grade: no decision record, no engine, no preflight, no
    ratification ceremony. The test is the same "which lens am I in"
    question that separates a *new model* from *tuning a dial*: **will
    something durable have to conform to this, or is it a one-off I can
    redo for free?** Conform → full rigor. One-off → minimum that
    ships. The failure mode this exists to stop is the one that makes a
    governance engine *heavy* instead of *right*: applying
    framework-builder virtues (anticipate every case, handle the whole
    case-space, build the durable form, authorize every removal) to
    solo throwaway work, where they are pure overhead with no consumer
    to protect. Right-sizing *down* is not sloppiness — it is #1's
    "vision tells you which axes exist" applied to effort itself: rigor
    is an axis, and spending it where nothing bears the load is the
    same waste as building a module for an axis that has only one case.
    This is the promotion of #19's MVP-cadence override from a
    per-project opt-in to a standing default: rigor is always
    proportional; the load-bearing axes are simply where the proportion
    runs high. It never *licenses* skipping rigor on load-bearing work —
    that inverts it; the whole point is that the stakes, measured
    honestly, decide, and understating stakes to dodge the work is the
    failure it names in the other direction.

23. **Existence is checked before construction.** Every principle above
    governs how *we* build; none of them asks whether the thing should
    be built by us at all. Before standing up an engine, sweep what
    already exists **outside** this repo — an open-source project, a
    commercial product, a vendor primitive, a protocol — and cite what
    the sweep found in the artifact that proposes the build, including
    an explicit "nothing found" when it comes back empty. This is the
    inward prior-art sweep aimed outward: the record answers *what have
    we already ruled*, this answers *what has the world already built*,
    and both are asked before the first line because both stop the same
    waste. **Rebuild must beat adopt on stated grounds** — fit against
    the real case-space (#4), lock-in, blast radius, and the
    maintenance an engine costs for as long as it lives — and it never
    wins by nobody having asked. "Ours would be cleaner" is a
    preference, not a ground; "it covers 80% and the missing 20% is our
    entire reason to exist" is a ground. Adopting is not the automatic
    answer either: a dependency that fits badly is its own long cost,
    which is why the comparison is *stated* rather than assumed in
    either direction. The failure this exists to stop is the most
    expensive kind of correct work — a well-built engine whose whole
    case-space a mature project already covers, discovered after it
    ships and after everything downstream has coupled to it (#18's
    asymmetry: a wrong build is not free to delete). Governed by #22: a
    one-off script does not earn a landscape sweep; an engine that
    future work must conform to always does. Specializes #15 and #20
    one step further outward — #15 verifies the cites you were handed,
    #20 verifies the surface of a vendor you already chose, and this
    asks whether a vendor should have been chosen at all.

24. **A dashboard is an instrument, not a page.** Any surface whose job
    is "tell me the state of N things" — a fleet register, a queue
    board, a health console, a boot line — is an *instrument*: it is
    built to a **declared standard** — the standard of the best one we
    have built — never to whatever the framework's defaults produce, and
    that standard has **one home** in the pairing layer, which a project
    cites rather than re-deriving. **What is shared is the standard,
    never the asset.** The exemplar is read for the care it took, not
    harvested for its stylesheet; reuse of a token file or a component
    across projects is a separate question with its own trade-off,
    decided where it arises, and answering it by default is how two
    projects end up wearing one face. Every project's instrument should
    look like that project. (2026-09-06, learned the expensive way: a
    second console was asked for this standard of care and got ~1,600
    lines of the exemplar's stylesheet ported into it — 63 of its 124
    class names are referenced nowhere in that project, and it now wears
    the exemplar's face instead of its own.) Five things are true of an
    instrument
    regardless of stack, and each is falsifiable on sight. **The row is
    the unit** — N things are N rows in one register with fixed
    columns, so a value is always in the same place; a card is for one
    thing, never for a list of things. **Severity sorts** — what is
    wrong ranks to the top, and the verdict is carried structurally on
    the row's own edge, so a column of twenty reads as status before a
    word is read. **The absent case is a row** — a thing configured but
    never heard from is the row you most need, so rows join from the
    inventory, never from the events, and anything that belongs to no
    row gets its own section rather than vanishing (#21's named
    refusal, and conservation over agreement, pointed at the surface a
    human reads). **The cause sits beside the thing** — a failing row
    explains itself in place with the real error string, never in a
    panel elsewhere. **A verdict has one vocabulary** — one component
    renders every verdict, and a surface with its own verdict model
    passes its own tone rather than letting the shared component invent
    a mapping for a word it does not know. The visual mechanism —
    tokens, the readout register, reflow order — belongs to the standard
    and to the stack, not to this principle. Governed by #22: a one-off
    status print in a terminal does not earn this; a surface a
    technician will live in does. Specializes #8 — architectural
    consistency aimed at the surface a human reads — and it is not a
    licence to gold-plate an admin form: the standard is about the
    *instrument*, the part that answers "is anything wrong", not about
    every input in the app.

---

# Additional context

The sections below are injected by the caller via `--include` (typically a pairings bundle). Use this as domain context when tailoring interview questions and the populated scope.

<!-- ───── pairing: cloudflare-security ───── -->
<!-- GENERATED-BY: pairings/bundle.sh -->

# Pairing: Cloudflare Security

- **Pairs with:** Cloudflare's network- and application-security product layer — the controls that sit *in front of* an origin on Cloudflare's edge: the WAF (managed + custom rulesets, rate-limiting rules, the OWASP core ruleset), DDoS protection, Bot Management / Turnstile, API Shield (schema validation, mTLS, JWT validation), Zero Trust — Access (application policies, identity providers, service tokens, device posture), Gateway, and Tunnels — plus the origin-protection primitives (Authenticated Origin Pull, Origin CA certificates, IP allowlisting, Zone Lockdown), TLS/edge-certificate posture, secrets and scoped API-token management, and the audit surface (Logpush, audit logs). Covers the *security posture and trust boundary* of an application fronted by Cloudflare — how the edge's security engine is configured, what it does and does not protect, and where the boundary can be bypassed. Out of scope: the Workers/Pages *runtime and hosting* model (its own pairing), and the application framework's own request handling.
- **Sources:** Cloudflare WAF docs (developers.cloudflare.com/waf), Cloudflare Zero Trust / Access docs (developers.cloudflare.com/cloudflare-one), API Shield docs, Cloudflare SSL/TLS and Authenticated Origin Pulls docs, Turnstile and Bot Management docs, Cloudflare API-token scoping model, OWASP Top 10 and OWASP API Security Top 10 (owasp.org), NIST SP 800-115, MITRE ATT&CK; opinion.
- **Date:** 2026-07-03
- **Touches principles:** #1, #2, #4, #5, #7, #9, #10, #13

Cloudflare's security products are an *edge engine* that inspects, authenticates, rate-limits, and filters traffic before it ever reaches your origin — but only for traffic that actually goes through the edge, and only for the rules you configured. The recurring failure is treating "we're behind Cloudflare" as a security property in itself. It is not: an origin whose real address is reachable directly bypasses every edge control at once; a WAF in "log" mode blocks nothing; an Access application with a fail-open policy or an over-broad `Everyone` rule authenticates no one. The edge is a real security boundary exactly to the degree that (a) all traffic is forced through it, (b) the rules are in enforcing mode, and (c) the origin trusts *only* the edge. This pairing maps the principles onto that boundary — the configured controls, the bypass paths, and the honest blast radius of a Cloudflare credential.

## Per-principle commentary

### #1 — Vision down to detail

Decide the security architecture before writing a single WAF rule or Access policy. The overall picture names the axes: *what is public, what is authenticated, and what is origin-only?* A public marketing page, an authenticated app, an API for machine callers, and a cron/webhook endpoint each want a different edge posture — public + bot/rate control; Access-gated with an IdP; API Shield with mTLS or a signed token; an allowlist or service token. Configuring rules bottom-up ("add a rule when something gets abused") produces a pile of overlapping rulesets no one can reason about. Start from the trust map — which hostnames, which paths, which callers — and let each rule fall out of a boundary you drew on purpose.

### #2 — Upfront anticipation over reactive patching

Enumerate the trust edges the edge is supposed to defend, before testing or trusting any of them:

- **Client → edge.** TLS version/cipher floor, the WAF ruleset (managed + custom), rate limits, bot posture, Turnstile challenge points.
- **Edge → origin.** Is the origin reachable *only* from Cloudflare? Authenticated Origin Pull (mTLS from edge to origin), Origin CA cert, firewall/allowlist of Cloudflare IP ranges, or a Tunnel with no public origin at all.
- **Identity → Access.** Which applications are Access-gated, which IdP backs them, how service tokens and device posture gate machine and managed-device access.
- **Caller → API.** Schema validation, JWT/mTLS validation, per-endpoint rate limits (API Shield).
- **Operator → control plane.** API-token scope, account-member roles, who can edit rulesets and DNS.

An edge you never mapped is a control you never verified and a bypass you'll under-report. Reactive patching — adding a block rule after an abuse incident — couples coverage to what already went wrong.

### #4 — Engines handle every possibility

The Cloudflare security stack *is* the engine; know its range so you neither re-implement it in app code nor assume it covers what it doesn't:

- **WAF managed rulesets** — Cloudflare's managed rules + the OWASP core ruleset score and block common injection/exploit patterns. Custom rules express app-specific logic (block a path, geo-fence, require a header). This is the engine for generic request filtering — don't hand-roll a regex firewall in the app for what the managed ruleset already covers.
- **Rate limiting** — edge-enforced request-rate rules keyed by IP, header, or path. This is the engine for brute-force/enumeration/scraping throttling; an in-app counter (especially on an ephemeral edge runtime) is not a substitute.
- **Bot Management / Turnstile** — bot scoring and a privacy-preserving challenge. The engine for automated-abuse and form-spam defense.
- **DDoS protection** — always-on L3/4 and L7 mitigation. The engine for volumetric availability; app code does not participate.
- **API Shield** — schema validation (reject requests that don't match an OpenAPI schema), mTLS client-cert enforcement, and JWT validation at the edge. The engine for machine-caller authentication and input-shape enforcement.
- **Access (Zero Trust)** — identity-aware application gating: an IdP-backed policy in front of an app, service tokens for machines, device-posture requirements. The engine for "who may reach this application at all," evaluated before the origin sees the request.
- **Origin protection** — Authenticated Origin Pull, Origin CA certs, IP allowlists, Tunnels. The engine that makes the edge *un-bypassable* by locking the origin to the edge.

Each app opts into a subset; unused controls protect nothing and fail silently. An app that ships its own IP rate-limiter, its own CAPTCHA, or its own edge-shaped auth header check when the platform provides each is duplicating the engine — but the far more common error is the inverse: *assuming* a control is on when it was never configured.

### #5 — Instructions don't extend engines

Terraform (`cloudflare_ruleset`, `cloudflare_access_policy`, `cloudflare_rate_limit`, …), `wrangler`, and dashboard clicks are *instructions* that sequence the security engine's capabilities. They declare which rules exist, in which phase, in which mode. They do not extend what the edge can enforce, and — critically — a rule that is declared but set to `log`/`allow`/`monitor` mode sequences the engine to *observe*, not to *defend*. Read the mode, not just the presence of the rule. When an instruction seems to need something the edge doesn't offer (per-user business-logic authorization, semantic validation of a request body's meaning), that belongs in the origin app, not in an ever-more-baroque custom ruleset. The dividing line: the edge enforces *shape, rate, identity-to-reach, and pattern*; the app enforces *what this authenticated principal may do with this specific object*.

### #7 — Clean boundaries, owned state

The boundary between what Cloudflare secures and what the origin must still secure:

**Cloudflare (the edge) owns:**
- TLS termination and the public certificate; edge cipher/version floor.
- Filtering, rate-limiting, bot-scoring, and DDoS mitigation of traffic *that traverses the edge*.
- Identity gating at Access (for Access-protected apps) and edge-side mTLS/JWT/schema checks (API Shield).
- The edge → origin authentication material (Authenticated Origin Pull cert, Origin CA).

**The origin app still owns — the edge does NOT do these:**
- **Authorization.** Access answers "may this identity reach the app"; it does not answer "may this user edit *this* record." Object-level authZ (IDOR/BOLA) is entirely the app's job. The edge waves the request through once identity is proven.
- **Not trusting edge-injected headers blindly.** Access injects a signed identity (a `Cf-Access-Jwt-Assertion` / `Cf-Authenticated-User` header). The origin must *verify the JWT signature against Cloudflare's public keys* — an unverified `Cf-Access-*` header is attacker-controllable on any request that reaches the origin directly.
- **Being unreachable except via the edge.** If the origin's real IP is discoverable and its firewall accepts non-Cloudflare traffic, every edge control is optional from the attacker's side.
- **Input validation and output encoding.** The WAF is a pattern net, not a parser; it is defense-in-depth, never the app's only validation.

**Boundary violations to watch for:**
- Origin reachable directly (real IP leaked via DNS history, an unproxied `A`/`AAAA` record, an SSRF-reflected header, a mail/`MX` record on the same host) → edge bypass.
- Origin firewall not restricted to Cloudflare IP ranges, or Authenticated Origin Pull not enforced → anyone who finds the IP is inside.
- App trusting `Cf-Access-*` / `Cf-Connecting-IP` / `X-Forwarded-For` without verifying the signature or that the request actually came from Cloudflare.
- A **grey-clouded** (unproxied, DNS-only) record on a zone that is otherwise proxied — that hostname gets *none* of the edge stack.

### #9 — Honest bounds over universal claims

The severity of a Cloudflare security finding *is* its blast radius, measured, not gestured at:

- **A WAF rule's value is its mode.** "WAF is enabled" is not a finding of safety; a ruleset in `log` mode blocks nothing. State enforce-vs-log per ruleset.
- **An API token's severity is its scope.** A leaked token scoped to a single zone's DNS read is contained; an account-scoped token with `Edit` on Workers/rulesets/DNS is an account compromise — it can disable the WAF, repoint DNS to an attacker origin, or deploy a malicious Worker. Enumerate the token's permission groups and zone/account scope; don't write "token exposed" and stop.
- **An Access policy's strength is its rule set.** "The app is behind Access" understates and overstates until you read the policy: an `Everyone` include, a bypass rule, an email-domain include with self-serve signup, or a policy attached to the wrong path all mean "gated" is a claim, not a fact.
- **Rate-limit and bot posture** have honest bounds too: a rate limit keyed only on IP is bypassed by a rotating-IP botnet; state what the control does and does not stop.

### #10 — Explicit exclusions over vague coverage

Name what Cloudflare's edge security does *not* cover, so absence isn't read as protection:

- **No object-level authorization**, ever — the app owns it (see #7).
- **No protection for bypass traffic** — anything hitting the origin directly gets zero edge controls; if you can't prove the origin is edge-locked, the entire edge stack is out of the *effective* security scope.
- **Grey-clouded / DNS-only records are excluded from the edge** by definition — enumerate them explicitly.
- **The WAF is not a validator or an authenticator** — it is pattern-based defense-in-depth. Don't scope in "the WAF will catch it" for app-logic flaws.
- **Access ≠ authorization and ≠ app session** — it gates reachability; the app still runs its own session/authZ.
- For an *authorized security assessment*: name the ROE lines — the account/zone boundary, other tenants on shared Cloudflare infrastructure, and Cloudflare's own control plane are out of bounds without explicit written authorization, exactly as for any shared-cloud provider.

### #13 — Done means demonstrable, not reported

A Cloudflare security finding shows the gap, it doesn't describe a risky-looking config:

- **Origin bypass:** demonstrate a request reaching the origin directly (by IP / by a non-proxied hostname) that the edge would have blocked — the response proves the bypass, not "the firewall rule looks permissive."
- **WAF gap:** send the payload the ruleset should block and show it reaching the origin (in an authorized, rate-considerate way) — a rule in `log` mode is proven by the request that sailed through, not by reading the dashboard.
- **Access gap:** reach the protected app without satisfying the policy, or forge/replay an unverified `Cf-Access-*` header against an origin that trusts it.
- **Token blast radius:** within ROE, enumerate what the credential's scope actually unlocks (list the zones, read a ruleset, describe a Worker) rather than asserting "over-privileged."

"The configuration looks risky" is a recommendation; the finding is the demonstrated bypass or the enumerated scope, captured and reproducible within the rules of engagement.

## Addenda

### Origin-lockdown checklist (the un-bypassability of the edge)

The single most important Cloudflare security property is that the origin is reachable *only* through the edge. Verify all of: the origin firewall/security group allows inbound *only* from published Cloudflare IP ranges (or the origin has no public inbound at all and is fronted by a Tunnel); Authenticated Origin Pull (mTLS edge→origin) is enforced so the origin rejects connections not bearing Cloudflare's client cert; no DNS record, historical or current, leaks the real IP (check `MX`, `A`/`AAAA` on subdomains, and passive-DNS history); and no service on the origin host answers on the raw IP. Any one gap collapses the whole edge stack.

### Rule mode and phase — read the enforcement, not the existence

For every `cloudflare_ruleset` / WAF rule / rate-limit / Access policy, the load-bearing attributes are *mode* (`block`/`challenge`/`js_challenge`/`managed_challenge` vs `log`/`allow`), *phase* (does it run where it can act on the request?), and *expression* (does the match expression actually cover the traffic, or is it scoped to a path/method that abuse avoids?). A dashboard full of rules in log mode is theater. Rank the review by what is actually enforcing.

### API-token and account-member hygiene

Cloudflare API tokens are the control-plane credential; treat each as a blast radius equal to its permission groups × scope. Prefer zone-scoped, least-permission, expiring tokens with IP-address filters over account-wide `Edit` tokens. Enumerate account members and their roles — a `Super Administrator` or `Administrator` member is full account control including DNS repoint and WAF disable. Tokens belong in a secret store, never in committed Terraform/`wrangler`/CI files or logs; a token in git history is live until revoked.

### Access / Zero Trust policy smells

The high-signal misconfigurations: an `Everyone` or unauthenticated *include* rule; a *bypass* rule that swallows more than intended; an IdP with open self-registration behind an email-domain include; a service token that never expires; a policy attached to the app but not to every hostname/path that reaches the same origin (the un-gated path is the way in); and — on the origin side — trusting the `Cf-Access-Jwt-Assertion` without validating its signature and `aud` against the Access application. Access is only as strong as its weakest attached path and the origin's verification of its assertion.

### TLS / certificate posture

Confirm the edge-to-client TLS floor (disable TLS 1.0/1.1), the SSL/TLS *mode* (Full **Strict** — validating the origin cert — not Flexible, which leaves edge→origin unencrypted or unvalidated), HSTS with a sane max-age, and Origin CA / custom-cert expiry monitoring. `Flexible` mode is a silent downgrade that makes the padlock a lie about the origin leg.

### Turnstile / bot posture verification

If Turnstile fronts a form, the secret-key validation must happen *server-side* on the origin (the widget token is verified via the siteverify API); a client-only widget with no server check is decorative. For Bot Management, know which paths are scored and what action a bot score triggers — a score with no enforcing rule is monitoring, not defense.

### Logpush and audit surface

Security without observability is unverifiable. Confirm Logpush (or equivalent) ships WAF events, Access logs, and firewall events somewhere durable and reviewed, and that account audit logs are retained — both to detect an in-progress bypass and to reconstruct one after the fact. An edge that blocks silently and logs nowhere cannot prove it is working.


<!-- ───── pairing: enforcement-surfaces ───── -->
<!-- GENERATED-BY: pairings/bundle.sh -->

# Pairing: Enforcement Surfaces

- **Pairs with:** anything a system runs *against itself* to decide whether something is allowed, correct, or healthy — linters, type checks, CI gates, pre-commit hooks, schema validators, admission controllers, policy engines, health probes, alerts, budget guards, rate limiters, feature-flag kill switches, monitors, and the automated remediations attached to any of them. Covers the design of the check itself: what it claims, what it does when it fires, how it is verified, and how it retires. Out of scope: the correctness of the thing being checked (that is the domain's own concern), the pipeline mechanics of running checks (a build concern), and the presentation of results to a human (a perceptual concern).
- **Sources:** opinion. No external prior-art sweep has been run for this pairing; the site-reliability literature on alerting (symptom-based paging, alert fatigue), the static-analysis literature on precision/recall trade-offs, and the policy-as-code and admission-control literatures all bear directly on it and should be swept before it is treated as complete. Recorded rather than omitted (Principle 9).
- **Date:** 2026-08-25
- **Touches principles:** #2, #4, #7, #9, #12, #13, #17, #18, #21, #22

An enforcement surface is a claim about a system, plus the authority to act on it. Both halves matter, and most design mistakes come from treating one as though it were the other.

The claim half means a check is only as good as what it can see, and it will be believed beyond that. The authority half means the cost of being wrong is not symmetric with the cost of being right, and that asymmetry — not accuracy — is what should drive the design.

## Per-principle commentary

### #2 — Upfront anticipation over reactive patching

Most checks are born from an incident: something broke, and a check is written so *that* cannot happen again. This is good and it is not enough, because a check written from one instance encodes that instance's shape rather than the class it belongs to. The question to ask at authoring time is what *class* of failure this belongs to, and whether the check catches the class or the anecdote — a check that only recognizes the exact spelling of the original bug will be silently defeated by the second one.

Enumerate the **failure modes of the check itself**, not only of the thing it checks, and do it before shipping rather than after the first bad night:

- **False positive** — it fires when nothing is wrong. Cost: attention, and eventually credibility.
- **False negative** — it stays quiet when something is wrong. Cost: the harm it existed to prevent, plus the false confidence that it was watched.
- **Did not run** — it crashed, timed out, was skipped, or was never wired. Cost: identical to a false negative, but harder to notice, because nothing distinguishes "ran and found nothing" from "never ran" unless the check is built to.
- **Ran against the wrong thing** — stale input, a cached artifact, the wrong environment, an empty set it read as clean.

That last pair is where the real damage lives, and neither is visible in a pass/fail count.

### #4 — Engines handle every possibility from the start

A check has three possible answers, not two: **pass**, **fail**, and **could not determine**. Collapsing the third into either of the others is the single most common design error in this domain.

Collapsed into pass, an unknown becomes a lie: an empty result set, a skipped step, an unparsed file, a timeout — all render as a green tick. Collapsed into fail, it becomes noise that trains people to override the check, which is worse than not having it. **Unknown must be expressible in the output and distinguishable at a glance.**

The same completeness applies to the input side. A check that walks a set must be able to say how many items it examined and how many it refused, and the refusals must be nameable. "No findings" and "no inputs" are opposite facts that look identical in most check output.

### #7 — Clean boundaries, owned state

Two boundaries carry most of the weight here.

**A check must not re-implement the rule it enforces.** The definition of what is legal belongs to whatever defines it — the schema, the grammar, the config, the type — and the check calls that. When a check carries its own copy of the rule, the copy and the definition drift, and the drift is invisible precisely because the check keeps passing. The dangerous direction is asymmetric: a check *stricter* than the definer produces noise, which gets noticed; a check *more permissive* than the definer silently blesses things the system cannot actually represent, which does not. Narrower is a legitimate scoping choice; more permissive is a defect.

**A check must not own state its subject also owns.** A check that caches its own idea of what exists — a list of known files, a snapshot of expected config, a copy of the inventory — has created a second source of truth that will disagree with the first, and its disagreement will be read as a finding about the system rather than about itself.

### #9 — Honest bounds over universal claims

Every check implies a universal: *nothing of this kind is wrong*. Almost none can support it, and the gap between what a check actually examines and what its name promises is where false confidence accumulates.

State the bound in the check's own name and output. "No secrets in committed files" is a claim about every file, every branch, every history rewrite, and every encoding; "no high-entropy strings in the working tree at HEAD" is a claim the check can actually make. The second is less reassuring and more useful.

Coverage claims deserve the same skepticism as any other universal: a percentage is a ratio, and the denominator is a claim in its own right. A check that silently skips what it cannot parse produces a denominator that excludes exactly the unknown cases, so the coverage figure improves *because* of the blind spot.

### #12 — Surface conflicts, never resolve silently

When two enforcement surfaces disagree — a linter allows what a formatter rewrites, a validator accepts what the runtime rejects, one environment's gate passes what another's fails — that is a finding about the *rules*, and it is a stronger signal than either surface disagreeing with the code. It localizes the fault to the definitions rather than the work.

Such conflicts are usually resolved by whoever hits them, locally and invisibly: an inline suppression, a narrowed glob, an environment-specific exception. Each is individually reasonable and collectively a record of unmade decisions. Suppressions deserve the same treatment as any other deferred conflict — a reason attached at the point of suppression, and a way to enumerate all of them. A suppression with no reason is a silent resolution wearing a comment.

### #13 — Done means demonstrable, not reported

**A check that has never fired is indistinguishable from one that cannot fire.** This is the central discipline of the domain. Every check ships with a demonstration that it catches the thing it exists to catch — a fixture that trips it, asserted to trip it — because otherwise the first evidence of a broken check is the incident it was supposed to prevent, and by then the check's whole history of green reads as false reassurance.

The same applies to every *branch*: a check with three findings and one clean path needs the clean path exercised too, or "clean" is an untested claim.

And a green check proves the check ran and found nothing. It does not prove the property holds. Those are different statements, and the difference is exactly the check's blind spot.

### #17 — Repeated failure indicts the model, not the attempt

When the same check keeps firing on things that turn out to be fine, the instinct is to tune the threshold. Do that once. If it recurs with no new information, the threshold is not the problem: the check is measuring a proxy that does not track the thing anyone cares about, and tuning it merely moves the noise around.

The same reading applies to a check that is routinely overridden. A gate that is bypassed as a matter of routine has already stopped being a gate; what remains is the friction without the enforcement. That is data about the rule, not about the people overriding it — either the rule is wrong, its scope is wrong, or the escape hatch is doing the real work and should be designed deliberately rather than tolerated.

### #18 — Removal needs authorization, never absence

An enforcement surface that *acts* — deletes, reverts, rolls back, blocks a release, evicts, revokes — is a different class of object from one that reports, and attaching an action to an existing detector is a **change of class, not a configuration change**.

The reason is the asymmetry: a false positive in a detector costs attention, and a false positive in an actuator costs whatever the action destroys. A predicate that is perfectly acceptable at 90% precision as an advisory becomes unacceptable the moment it is wired to something irreversible, and nothing about the predicate itself changes when it is rewired. So the promotion from detector to actuator is its own decision, with its own justification, its own precision evidence gathered while it ran advisory, and its own answer to what happens when it is wrong.

Prefer actions that are reversible by construction — quarantine over deletion, a new commit that reverts over a rewritten history, a flag flipped over state destroyed, marking over removing. Where an action cannot be made reversible, it needs a human in the loop, and "the check was confident" is not authorization.

### #21 — Born with its preflight

A check's own preconditions belong in the check, declared and refused by name: the tool it shells out to, the file it reads, the environment variable it needs, the credentials, the schema version. A check that silently degrades when its dependency is missing is the "did not run" failure mode, arriving quietly and reading as clean.

The refusal must be **loud and specific** — naming what was missing and where it was looked for — and it must not be the same shape as a pass. "Could not run: no such binary" is a useful sentence; exiting zero because a command was not found is a defect that will not be discovered until the thing it guarded fails.

This extends to how checks are registered. A check that must be manually added to a list will eventually not be, and the omission looks exactly like a clean result. Discover checks from the filesystem or a declared manifest, and make an unregisterable check an error rather than an absence.

### #22 — Rigor proportional to stakes

Not everything deserves a gate. The grade of enforcement should track the cost of the thing going unnoticed, and there is a real ladder here, each rung costing more than the last: **convention** (write it down), **advisory** (report it), **detector** (fail a build), **gate** (block the action), **actuator** (fix or prevent it automatically).

Most things belong on the first two rungs. Reaching for a gate on a low-stakes concern is how a codebase acquires forty checks nobody reads and a culture of routine overriding — and that culture then costs you the gates that mattered.

Cadence is part of the grade. A check that takes minutes cannot run on every keystroke; one that costs pennies per run cannot run on every request. Match the frequency to the cost of the check and the speed at which the thing it watches can actually change, and be honest that a check running less often has a proportionally longer window in which a defect hides.

## Addenda

### The guard that inherits its subject's blind spot

The most expensive verification failure is not a missing check — it is a check that cannot see the failure it was built to catch, because it was built from the same understanding as its subject.

A validator generated from a schema cannot detect that the schema is wrong. A test written from the implementation confirms the implementation. A monitor derived from the same model as the service will go quiet in exactly the failure the model does not represent. In each case the check and its subject agree, and agreement is mistaken for correctness.

The escape is to check against something the check's author does not control: the raw input rather than the parsed form, an independent count, the actual observed behavior, a source of truth outside the system, a person. Where a derived surface must be verified, verify by **conservation** — every input either produced an output or was explicitly refused with a reason — rather than by agreement between two things built from the same reading.

Some claims have no such external source. An assertion about intent, a judgment call, a statement about someone's preference — for these, mechanism runs out, and the honest response is to say so and schedule human review rather than build a check that appears to cover it.

### Silence is the failure mode to design out

A check whose failure mode is silence *will* fail there, because every other failure mode is visible and gets fixed. If the only way a check reports trouble is by emitting something, then a check that dies, hangs, is never invoked, or exits early through an unexamined path is indistinguishable from a healthy system — and it will sit that way for as long as nobody independently suspects it.

The design response is to make silence impossible rather than unlikely: **always emit** — a count, an explicit unknown, an explicit failure — so that absence of output is itself an anomaly. Report a snapshot with its age rather than computing on a latency-critical path, so the check cannot be skipped for being slow. Make the last-run time visible next to the result, because a stale answer and a current one look the same otherwise. And surface *the checker's own health* somewhere: a check that has not run in a month is a finding, and nothing else will notice it.

### Every rule ships with its out-valve

A rule that admits things and never releases them accumulates. The population grows, the signal degrades, and the surface becomes something people scroll past — which is functionally the same as not having it, but with maintenance cost.

So when a rule is written, write down what makes an entry leave: the suppression that expires, the exception that names a condition for its own removal, the finding that can be marked verified, the alert that resolves, the deprecation with a date. The out-valve's trigger should be **an explicit statement** — someone or something saying "this is handled" — rather than a heuristic that infers it, because inferring removal converts an accretion problem into a silent-deletion problem, which is strictly worse.

A finding no available action can clear is the specific case worth watching for. It trains its reader to skip that check, and the skipping generalizes.

### The escape hatch is part of the design

Every gate will be overridden. Designing the override deliberately is better than leaving people to discover the ugly way, because the ugly way is usually to disable the check entirely.

A well-designed escape hatch is **narrow** (this instance, not this check), **attributable** (who, when), **justified** (a reason, refused if empty), **visible** (enumerable — you can ask what is currently waived), and **expiring** where the situation allows. It should also be documented in the refusal message itself: the moment someone is blocked is the moment they will look, and sending them to search for how to proceed is how a check gets deleted instead of waived.

An escape hatch that fails closed — one that cannot be used when the tooling is degraded — is worse than none, because it turns a check's own outage into a total work stoppage.


<!-- ───── pairing: mental-models ───── -->
<!-- GENERATED-BY: pairings/bundle.sh -->

# Pairing: Mental Models

- **Pairs with:** The cognitive layer of interface work — how users form a working theory of "what this system is and how it behaves," and how the interface either supports or breaks that theory. Norman's three-model framework (designer's conceptual model, the system image emitted by the interface, the user's mental model assembled from the system image plus prior experience), affordances and signifiers, metaphor and analogy, recognition vs. recall, cognitive load, learnability, onboarding as initial model formation, discoverability. "Intuitive" reduced to its useful operational definition: the user's mental model matches the system's actual behavior closely enough that prediction succeeds.
- **Sources:** Donald Norman, *The Design of Everyday Things* (Revised and Expanded ed., Basic Books, 2013) and *Emotional Design* (Basic Books, 2004); Steve Krug, *Don't Make Me Think, Revisited* (3rd ed., New Riders, 2014); Yvonne Rogers, Helen Sharp & Jenny Preece, *Interaction Design: Beyond Human-Computer Interaction* (6th ed., Wiley, 2023); John Sweller, Paul Ayres & Slava Kalyuga, *Cognitive Load Theory* (Springer, 2011) and subsequent papers extending the theory (Sweller et al., *Educational Psychology Review*, 2021 / 2023); Kenneth Craik, *The Nature of Explanation* (Cambridge UP, 1943 — origin of "mental models" as a cognitive construct); Philip Johnson-Laird, *Mental Models* (Harvard UP, 1983); Bruce Tognazzini, *First Principles of Interaction Design* (asktog.com, ongoing); James J. Gibson, *The Ecological Approach to Visual Perception* (Houghton Mifflin, 1979 — origin of "affordance" as a perceptual term); opinion.
- **Date:** 2026-05-27
- **Touches principles:** #1, #4, #5, #6, #8, #9, #13

A user doesn't reason about your system from a spec sheet. They build a working theory of it from whatever they can perceive — the labels, the layout, the responses to their actions, what changed when they did the last thing, what reminds them of something else they already know. That working theory is the mental model, and every prediction the user makes about your system runs through it. When their model matches your system's actual behavior, the experience feels intuitive; when it diverges, the experience feels broken — *even when the system is working exactly as designed*.

This pairing is about designing for that gap. The interface is the channel through which the user's mental model gets built; the principles below specialize for keeping that channel honest, narrow enough to fit working memory, and faithful to the system underneath.

## Per-principle commentary

### #1 — Vision down to detail
Mental-model design starts from the user, not the system. The detail-up failure mode is to model the system's internal abstractions in the UI ("here is the schema, here are the CRUD operations") and assume the user will reverse-engineer your mental model from the UI. They will reverse-engineer *something*, but it will be wrong in ways you cannot predict.

The vision question for mental-model work is: *what is the simplest, most accurate model of this system the user needs to hold in their head to use it well?* Once that's named — explicitly, on paper — every UI decision either reinforces it or fights it. A product without a stated user-facing model is a product whose users invent their own, and the support load is measured in "but I thought it would do X" tickets.

The model is not the system. A bank account's user-facing model is "money in, money out, balance"; the underlying system is a ledger with transactions, holds, pending charges, and reconciliation cycles. Both are valid; the user-facing one is what the interface must serve.

### #4 — Engines handle every possibility
The user's mental model needs to remain accurate across the engine's full range — and that means **every state the system can be in must be perceivable from the interface**, not just the happy-path ones. Hidden state is the silent killer of mental models: an upload that's "in progress" but has actually failed, a setting that "was saved" but didn't persist because the user wasn't authenticated, a record that exists in the database but is invisible because of a filter the user forgot was applied. Each of these is the system being in a state the user's model can't account for, because the interface didn't surface it.

The discipline is to enumerate every state and ask: *does the user's mental model contain a slot for this state? If so, does the interface fill that slot truthfully?* If the model has no slot for it, either widen the model (with onboarding, hints, or interface affordances) or change the system so the state cannot occur. Hidden state survives only as long as the user happens not to trigger it.

This is also where **system status visibility** as a heuristic comes from (Nielsen's first heuristic): the interface should always let the user know what's going on, in language they understand, in a timeframe that lets them predict the next step.

### #5 — Instructions don't extend engines
The interface is the *system image* — the externalized depiction of how the system works. It is not the place to invent behavior the system doesn't have. A UI that pretends to delete an item but actually hides it, a "save" button that only validates without persisting, a confirmation dialog for an action that's already irreversible: all of these are the instruction layer (the UI) extending the engine (the system) with fictions the user's mental model then has to absorb.

The honest version: the UI faithfully depicts what the system does. If the system has a soft-delete with a 30-day undo window, the UI says "Items are kept for 30 days after deletion" rather than implying instant permanence. If save validates but doesn't persist until commit, the UI says "Draft saved" rather than "Saved." The mental model the user builds from the truthful interface will hold under stress; the model built from a fictional interface will collapse the first time the fiction fails.

The deeper rule: **the system image should be a projection of the conceptual model, not a different model**. When the designer's conceptual model and the system image diverge, the user's mental model assembles from the system image, drifts away from the designer's intent, and behaves accordingly. Norman's framing is that all three models exist; the design job is to keep the user's model close to the designer's by making the system image faithful and legible.

### #6 — Modules do one job
A signifier signifies one thing. An icon that's a magnifying glass means "search"; the same icon doing duty as "zoom" in one corner of the same app is a violation that costs the user a re-learning every time. The same button shape doing both "primary action" and "destructive action" in different contexts forces the user to read every label before clicking — exactly the cognitive load the visual system is supposed to reduce.

The same applies to language: one label for one concept. If "archive" and "delete" coexist, they must mean genuinely different things, applied consistently, and the user's mental model has a slot for each. If you find yourself writing tooltip explanations to disambiguate two near-synonyms, the system has two labels for one job — collapse them.

Norman's affordance-and-signifier distinction matters here: an **affordance** is what the object actually permits (a button affords being pressed), and a **signifier** is the perceptible cue that communicates the affordance (the button looks pressable). One affordance, one signifier. Multiple signifiers for the same affordance is redundant but usually harmless; one signifier for multiple affordances is a #6 violation that breaks the user's model.

### #8 — Architectural consistency
The same gesture should produce the same kind of result everywhere in the product. The same word should mean the same thing on every screen. The same color should signal the same status. Once the user has learned a pattern, every consistent instance reinforces the mental model and every inconsistent instance forces a re-learn.

Categories where consistency pays the most for the cognitive layer:

- **Action verbs.** "Save" / "Submit" / "Confirm" / "OK" mean different things; pick which means what in your system and use it consistently. Two different verbs for the same action is two labels for one job (Principle 6); the same verb for two different actions is the worse case (one label for two jobs).
- **Confirmation patterns.** Destructive actions confirm; non-destructive ones don't. If the threshold drifts (some destructive actions confirm; others don't) the user has to read every dialog rather than trust the pattern.
- **Status colors.** Green = success / safe / proceed; red = error / danger / stop; amber = warning / caution. Inverting this even once costs the user every subsequent interaction.
- **Icon vocabulary.** A small named set of icons with stable meanings. A new icon should be a deliberate design decision, not a casual pick from the library.
- **Spatial conventions.** Primary actions on the right (LTR), destructive actions away from the primary, close/cancel in the predictable corner. Breaking these conventions can be done; it should be a deliberate cost, not an accidental one.

### #9 — Honest bounds over universal claims
The system image is a claim about the system. Claims that overreach create mental models that fail in the field:

- A progress bar that fills to 100% and then sits there is claiming the operation is almost done when the system can't actually predict that. An honest indeterminate spinner — or an honest "this can take several minutes" — protects the user's model.
- An autocomplete that returns results in 50ms claims real-time search; if it sometimes returns in 4 seconds, the model is broken in a way the user perceives as a glitch. Either keep the claim (and engineer to it) or change the affordance (a debounced search button).
- A "draft saved" indicator that claims persistence when the draft only exists in client memory until reconnect is a load-bearing lie. Frame it accurately ("Draft saved locally — will sync when online") or don't display it.

The reduction: **don't have the interface promise what the system can't honor**. The mental model the user assembles from a UI is treated as a contract; treat the interface design with the same gravity as the API design, because that's what it is.

### #13 — Done means demonstrable
"It's intuitive" is a claim only the user can verify, and only by trying to predict the system's behavior. Done means:

- **Cold-start usability testing.** Five users who have never seen the product, given a task description in domain language (not interface language), observed completing the task. If they form predictions that fail, the system image is misleading. Nielsen's NN/g research (2000) shows five users surface roughly 85% of issues for a given task on a given design.
- **Predictive testing.** Show a user a screen they haven't acted on yet; ask "what do you think will happen if you do X?" Their answer is their mental model in real time. Mismatches between their prediction and the system's actual behavior are the bugs of this layer.
- **First-action observation.** When a user is dropped into the product fresh, what's their first action? If it's not the action the design intended to elicit, the system image isn't producing the model you thought it would.

A "yes it tested well with our team" report is not done. Your team has the designer's conceptual model already; they cannot evaluate the system image as a stranger.

## Addenda

### Affordances and signifiers (Norman, after Gibson)

The pair is load-bearing for this pairing:

- An **affordance** is a relationship between the object and the user's capabilities — what the object permits a user to do. (Gibson's original usage: a chair affords sitting to an adult, may not afford it to a small child.) Affordances exist whether anyone perceives them or not.
- A **signifier** is a perceptible cue that communicates an affordance to the user. A button that looks raised signifies its press-ability; a link that's underlined signifies its click-ability; an arrow signifies direction. Signifiers are about perception; affordances are about possibility.

The design failure modes are mirror images:

- **Hidden affordances.** The object does something but offers no signifier — a clickable element with no visual cue. The user doesn't know the affordance exists. (Pattern: hover-only reveals on touch devices.)
- **False signifiers.** The object emits cues that suggest a non-existent affordance — text styled like a link that isn't one, an icon that looks like a button but is decorative. The user predicts an interaction that won't happen. (Pattern: skeuomorphic decorations from an earlier design era left behind.)

Norman's revised edition (2013) added the signifier concept specifically to disambiguate the design conversation that had been muddled by years of casual usage of "affordance" to mean both the possibility and the cue. Use both terms; they mean different things.

### Recognition over recall (Krug, Nielsen)

Working memory holds roughly 4-7 items at once, depending on the person, the context, and the task. Recognition (seeing the right option in a list) costs almost nothing; recall (remembering it without prompt) costs a working-memory slot. The interface that asks the user to recall a piece of information they saw five steps ago is taxing working memory; the interface that surfaces it again — or surfaces a recognition cue — is not.

Concrete moves:

- **Auto-complete and suggestions** over free recall. The user picks from a recognizable set rather than producing the answer from memory.
- **Persistent context.** Show the user where they are (breadcrumbs, page titles, current selection), so they don't have to remember.
- **Visible options.** A menu of three buttons is recognition; a command-line that takes any of several text commands is recall.
- **Surface previously-seen state.** "You were last looking at X" is recognition; "remember what you were doing?" is recall.

The exception: power users genuinely prefer recall (keyboard shortcuts, command palettes, command-line). The discipline is to offer recognition as the default and recall as a power-tool escape — not to force recall as the only option.

### Cognitive load (Sweller)

Cognitive Load Theory carves three kinds of load on working memory:

- **Intrinsic load** — the inherent difficulty of the task. A spreadsheet formula has intrinsic load because spreadsheet formulas are intrinsically complex. Intrinsic load is set by the problem, not the interface; the design lever is to decompose tasks into smaller sub-tasks rather than to magically reduce intrinsic load.
- **Extraneous load** — load imposed by the design that has nothing to do with the task. Visual clutter, inconsistent labels, hidden states, unnecessary steps — all extraneous load. **This is the load designers can reduce** and the load most designers are unaware of.
- **Germane load** — load that contributes to learning and schema-building. A well-designed onboarding flow adds germane load deliberately; over time the user's mental model strengthens and the same task feels easier. Germane load is good load.

The design move is to *reduce extraneous, respect intrinsic, and invest germane*. A UI that minimises clutter (low extraneous) on a fundamentally complex domain (high intrinsic) with progressively-disclosed scaffolding (germane) is the canonical "intuitive" experience for non-trivial software. A UI that adds gloss and animation (extraneous), hides genuine complexity (denies intrinsic), and has no learning curve (no germane) is a demo, not a tool.

Sweller's recent work (2021-2023, *Educational Psychology Review*) has extended the theory to address evolutionary cognition and the replication-crisis-grade rigor of the underlying experiments; the three-category core remains the practitioner's working tool.

### Onboarding as initial model formation

The user's mental model on first use is the model they will operate on for the next dozen sessions, even if the product is more capable than what they saw. Onboarding is therefore not "teach the user how to use the product"; it is **the first version of the system image the user perceives, and the foundation of the model they will build**.

Discipline:

- **Show the conceptual model, not the feature list.** "This is a thing where you do X and the result is Y" is the model; "here are the buttons" is the feature list.
- **Defer detail until needed.** Progressive disclosure: the first session shows the smallest model that supports the first action; the third session can introduce the next concept; the tenth session can show the power-user features. The model grows; it doesn't arrive fully formed.
- **Anchor in something the user already knows.** Metaphor is the cheapest scaffolding for a new mental model (the "desktop" metaphor for personal computers; the "feed" metaphor for social media; the "card" metaphor for kanban tools). Metaphors don't survive forever — the desktop metaphor leaks at scale — but they buy the first model cheaply.
- **Never use a modal walkthrough as a substitute for a discoverable interface.** A walkthrough that points at five buttons in sequence is a sign the buttons aren't self-evident. Fix the buttons; don't paper over them with a tour. Walkthroughs that are *contextual* (appearing as the user encounters a feature for the first time) are better than walkthroughs that are *frontloaded* (a tour before the user has done anything).

The empty state is part of onboarding. A first-run dashboard with no data is the first thing a new user sees; designing it as "nothing here yet" is a missed onboarding moment. Use the empty state to demonstrate the model: show what will go here, hint at the first action, anchor the user's mental model before they have data to anchor it.

### "Intuitive" reduced to an operational definition

"Intuitive" as a vague design property is unfalsifiable and therefore unhelpful. The operational definition that's useful:

> An interface is intuitive when the user's prediction about what will happen next matches what actually happens, often enough to feel natural — built from a mental model whose accuracy comes from prior experience, the visible system image, and the consistency of the system's responses.

This reframes the design job. Instead of "make it intuitive" (impossible to plan against), the design job becomes:

1. **What prior experience can we draw on?** (Choose metaphor / convention deliberately.)
2. **What does the system image emit?** (Make state visible; make affordances signified.)
3. **Is the system's behavior consistent with the model the image implies?** (No hidden gotchas; no fictional behaviors.)

Three answerable questions instead of one unfalsifiable one. Most interfaces that feel "intuitive" satisfy all three for the population they serve; most that feel "unintuitive" fail one of them in a specific, fixable way.




---

# Scope Template

The populated scope file must follow this structure exactly.
Section headings and ordering are part of the contract. Fill
placeholders with the user's answers, not the template's
bracketed instructions.

# Project Scope: [Project Name]

## Active milestone
[If the project uses `.agent/ROADMAP.md` (D-0050), the active milestone, its
per-task done-when, backlog, and shipped history live there — keep this a
one-line pointer and don't duplicate the DoD here. Otherwise fill in below.]

**Milestone:** [name/number — or "see ROADMAP `## Active`"]
**Definition of done:** [observable, verifiable criteria — or per-task in ROADMAP]
**Active blockers:** [if any]

## Hard constraints
[Things that must always be true in this project. Violations are bugs.]

- [Constraint]
- [Constraint]

## Out of scope
[Capabilities explicitly excluded from this version of the project. Adding 
anything from this list requires a check-in.]

- [Excluded capability] — [why excluded, and what would be needed to add it later]
- [Excluded capability] — [reason]

## Criticality rubric

What counts as Critical, Material, or Minor for THIS project. The operating 
manual uses this to decide whether to hard-stop or continue on parallel work 
when a check-in is filed.

**Critical** (hard-stop, do not touch related work):
- [Type of change]
- [Type of change]

**Material** (continue on parallel work, avoid downstream):
- [Type of change]
- [Type of change]

**Minor** (continue freely):
- [Type of change]
- [Type of change]

## Default check-in mode
[Usually: hybrid per the operating manual. Override only if this project needs 
something different, like always-hard-stop or always-continue.]

## Verification

<!-- How this project is checked, as COMMANDS an agent can run (D-0129).
     Read at session start, so keep it to these lines.

     The third line is the load-bearing one: a list of what to run is advice;
     a list of what NOT to run is what saves an afternoon, and it cannot be
     inferred from a script list. Name the expensive tiers and say why.

     Each entry is a literal runnable command (D-0119) — "run the unit tests"
     makes the agent go and choose, which is the failure this prevents.

     A project with nothing to run writes `none — <why>` rather than omitting
     the section: omission and "there is nothing here" look identical and only
     one of them is fine. -->

- **After a change:** `<the cheapest command that would catch a mistake here>`
- **Before landing:** `<the command the gate or CI will run>`
- **Not run by hand:** `<tiers that belong to CI — name them, and why: cost, or environment>`

## Reference — durable scope, NOT read at session start

[Everything below is durable scope *reference* — read on demand, **not at
session start**. A resuming agent needs the core above (active milestone, hard
constraints, out-of-scope, rubric, check-in mode), not the full overview /
principles / capability inventory each session. Mirrors the D-0072 history-split
precedent and the token-economy lineage (D-0070/71/72): lean session-read core,
durable reference demoted to an on-demand tail.]

## Overview
[2-3 sentences. What this project is, who it's for, what success looks like.]

## Pairings (optional)
[Domain specializations from `pairings/` that color the canonical principles 
in for a specific domain (language, framework, methodology, skill). Additive 
only — cannot contradict principles. List each by name as it appears in 
`pairings/`. Leave the section empty (or remove it) if none apply.]

- [pairing-name] — [one-line note on why this pairing is selected]
- [pairing-name] — [reason]

## Principles, in priority order
[These extend or override PERSONAL-PRINCIPLES.md for this specific project. 
If a personal principle doesn't fit this project, say so explicitly. If a 
project-specific principle is needed, list it.]

1. [Principle name]. [Brief statement.]
2. [Principle name]. [Brief statement.]
3. [...]

[When principles conflict, prioritize by number. Flag severe conflicts.]

## Capabilities currently in scope (optional but recommended)
[Authoritative inventory of what this project IS supposed to do. Anything 
not on this list is a *review trigger* — re-check it against the decision 
register and surface it — NOT a delete warrant (Principle 18). This list 
can lag `main/` (#15), so its silence is a prompt to look, never an 
authorization to remove. Skip this section for small or early-stage 
projects; add it once the project has enough surface area that scope 
drift becomes a risk.]

### [Category]
- [Capability]
- [Capability]

### Planned but not yet specified (preserve, do not extend)
- **[Capability].** [Why preserved without active development.]

## Removal review (optional, pairs with "Capabilities currently in scope")
[If the in-scope inventory exists, this section governs how the agent 
treats things that don't map to it. Skip if no in-scope inventory.]

Anything in the codebase that does not map to a capability in 
"Capabilities currently in scope" above is a **review trigger, not a 
delete warrant** (Principle 18). The default for unmapped surface is 
**stop and surface** — re-check it against the decision register (it may 
be load-bearing structure the inventory simply hasn't caught up to, #15), 
and raise it. Removal of anything a decision cites requires citing the 
superseding/amending decision — absence from this list is never the 
authorization. Removal is never the default action.

## Project-specific glossary (optional)
[If the project has domain terms that need precise meaning, define them here. 
This is the canonical reference — when in doubt, terms mean what this glossary 
says they mean.]

- **[Term]**: [definition]
- **[Term]**: [definition]
---

# Interview

Conduct this interview one section at a time. For each section:

1. Ask the questions listed.
2. Wait for the user's answer. Ask one follow-up if the answer is
   ambiguous — do not fan out into branching what-ifs (one good
   question, not five hedging ones).
3. Summarize back what you heard in 1–2 sentences. Confirm before
   moving on.
4. Move to the next section.

Sections marked **(optional)** should be asked only if the user
signals they want them, or if the project's surface area justifies
them. Sections marked **(skip if covered by `--include`)** should be
skipped when included context already answers them.

Push back when answers are vague. Defaults are valid answers if the
user explicitly says "default" — record that and move on.

---

## 0. Prior context — read this first

Before asking anything, check for `.agent/REPORTS/project-brief.md`. If it
exists, it carries the vision, stack, surface, methodology, and constraints
captured during the vision phase (Phase 0) — read it in full. Use it to
*pre-fill and confirm* the sections below, not to re-elicit from a blank
slate: state back what the brief already establishes, ask the user to
confirm or correct, and spend new questions only on what the brief doesn't
cover (milestone, definition of done, out of scope, criticality rubric).
Re-asking from scratch what the brief already answers is the
information-loss this step exists to prevent (Principle 14). If no brief
exists, conduct the full interview below.

## 1. Overview

- In 2–3 sentences, what is this project? Who is it for, and what does
  success look like? *(If a project brief exists, confirm its Vision
  rather than re-asking.)*
- Is this a greenfield start, or an existing codebase being adopted
  into this system?

## 2. Pairings (skip if covered by `--include`)

If no pairings bundle was included, ask:

- Which `pairings/` (if any) apply to this project? Name them.
- For each: one line on why it's selected.

If a bundle was included, the user has already chosen — list the
pairing names you see in the additional context and confirm them as
the selection.

## 3. Principles, in priority order

The canonical principles in `personal/PERSONAL-PRINCIPLES.md` apply by
default. Ask:

- Are there any canonical principles that do **not** fit this project,
  and why? (Overrides become numbered project principles that
  explicitly de-prioritize a canonical one — surface the conflict per
  Principle 12, don't bury it.)
- Are there any project-specific principles to add? (E.g., "ship daily
  over polish" for an MVP, "no third-party deps" for embedded, "every
  change ships with a test" for TDD.)

If the user says "defaults are fine," record that as the priority
list — no overrides needed.

## 4. Hard constraints

Hard constraints are things that must always be true. Violations are
bugs, not preferences. Ask:

- What are the immovable constraints? (Performance ceilings, security
  requirements, regulatory limits, hardware budgets, dependency locks,
  language/runtime constraints, deployment targets.)
- For each: what happens if it's violated? If the answer is "nothing
  serious" — it's a preference, not a hard constraint. Recategorize.

## 5. Active milestone & definition of done

Per Principle 13 — done means demonstrable, not reported. Ask:

- What is the current milestone? Give it a short name or number.
- What is the **observable, verifiable** definition of done? (Which
  files exist with what content? What behavior is demonstrated? What
  can the user do after?)
- Any active blockers right now?

If the definition of done is vague ("ship the feature"), push back:
what specifically demonstrates it shipped?

## 6. Out of scope

Per Principles 9 and 10 — honest bounds, explicit exclusions. Ask:

- What capabilities are explicitly **not** part of this version's
  scope? Name 2–5.
- For each: why excluded, and what would be needed to add it later?

This is one of the most load-bearing sections. If the user struggles,
prompt with examples adjacent to their stated scope: "Would X be in
scope? Y? Z?"

## 7. Criticality rubric

This is how the agent decides when to hard-stop vs. continue. Ask:

- What kinds of changes are **Critical** (hard-stop, do not touch
  related work) for this project?
- What kinds are **Material** (continue parallel work, avoid
  downstream)?
- What kinds are **Minor** (continue freely)?

Defaults to suggest if the user is unsure: scope/architecture/data-shape
changes are usually Critical; refactors in well-bounded modules are
usually Material; cosmetic edits, comment fixes, and additive tests are
usually Minor.

## 8. Default check-in mode

Almost always "hybrid" per the operating manual. Ask once:

- Default to hybrid check-ins (mix per criticality), or override to
  always-hard-stop / always-continue?

If "default," set hybrid and move on.

## 9. In-scope capabilities (optional)

Skip for small or early-stage projects. Only ask if the project has
enough surface area that scope drift is a real risk. Ask:

- What capabilities does the project currently have? Group by category
  if useful.
- Are any "planned but not yet specified" — preserve, do not extend?

## 10. Removal authority (optional, pairs with §9)

Only if §9 was populated. Ask:

- Should anything not in the in-scope list be treated as a candidate
  for removal? (Default: yes, per the template's standing language.)

## 11. Project-specific glossary (optional)

Ask:

- Are there domain terms that need precise meaning in this project?
  List them.

If none, skip the section.

---

# Output format

After the interview, produce a single markdown code block containing
the populated scope file. Use the exact section headings from the
**Scope Template**. Fill placeholders with the user's answers, not the
template's bracketed instructions. Sections marked **(optional)** that
were skipped should be **omitted entirely** — do not leave empty
sections with placeholder text.

Hand the populated scope file to the user with these instructions:

1. Review it. Edit anything that drifted from what you said.
2. Save to `.agent/PROJECT-SCOPE.md` in the target project.
3. Run the publish step to produce the project's `CLAUDE.md`:
   ```bash
   cd <target-project>
   ~/Projects/dotagent/publish/publish.sh claude-md \
     --include <(~/Projects/dotagent/pairings/bundle.sh)
   ```

Do not write the file yourself. The human commits scope decisions
(Principle 11).
