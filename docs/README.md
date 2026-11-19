# CAPS documentation

Where to start depends on what you are doing.

| You want to | Read |
|---|---|
| Understand what the standard guarantees and to whom | [specification.md](specification.md), then [threat-model.md](threat-model.md) |
| Consume capsules in an application | [consumer-guide.md](consumer-guide.md) |
| Receive or verify capsules outside the ledger | [off-ledger.md](off-ledger.md) |
| Bring an oracle onto the standard or replace a part of the reference | [implementer-guide.md](implementer-guide.md) |
| Look up a field, a type or who sees what | [data-model.md](data-model.md) |
| Decide how a feed is governed and who can stop or fork it | [governance.md](governance.md) |
| Decide what to keep and for how long | [lifecycle.md](lifecycle.md) |
| Size a deployment and choose what to pay for | [costs.md](costs.md) |
| Keep who reads a feed off the ledger | [lifecycle.md](lifecycle.md), the readers; [threat-model.md](threat-model.md) |
| Extend the standard with a package of your own | [extensions.md](extensions.md) |
| License data and police who distributes it | [licensing.md](licensing.md) |
| Bill for distribution | [accounting.md](accounting.md) |
| Find a term | [glossary.md](glossary.md) |

## The documents

**Normative**

- [specification.md](specification.md): the requirements on a conforming
  deployment, verifier and consumer, interface by interface, with the
  privacy rules and the consumer's checks. The interface source is the
  authority where the two differ.
- [data-model.md](data-model.md): every type, view and choice argument,
  identity, the payload encodings of the shipped verifiers, lifecycle and
  visibility tables, invariants.

**Reference implementation and its choices**

- [extensions.md](extensions.md): the points where a deployment adds its
  own behaviour, the extensions shipped under `extensions/`, and how to
  write one.
- [licensing.md](licensing.md): the license interface and its delegate,
  how provenance is policed rather than proven, the reference license and
  the extended ones.
- [accounting.md](accounting.md): the optional accounting delegate and its
  distribution marker, their guarantees and edges, merging and settlement,
  the variants a deployment may choose instead, the audit.
- [governance.md](governance.md): who signs the head and the rounds, the
  trade-off between excluding a fork and surviving a signatory, the
  variants considered and the decision to keep the reference as it is.
- [lifecycle.md](lifecycle.md): how each contract is created, replaced and
  retired, and retention.
- [costs.md](costs.md): the contracts each role gains per publication and
  per distribution, what that comes to per year and under retention, and
  what a deployment may give up to pay less.
- [round-compaction.md](round-compaction.md): a possible extension, not
  shipped, that folds retired rounds into a tree instead of dropping them.

**Guides**

- [consumer-guide.md](consumer-guide.md): onboarding, the five checks and
  which round a transaction settles on, with Daml Script fragments.
- [implementer-guide.md](implementer-guide.md): writing a verifier,
  publishing with an existing oracle, what may be replaced and what may
  not.
- [off-ledger.md](off-ledger.md): every handoff outside the ledger, what
  a presentation carries, what can be checked without a participant, the
  encodings and vectors of the shipped verifiers.

**Analysis**

- [threat-model.md](threat-model.md): what is proven, policed and out of
  reach; what the standard does not promise; what the verifiers assume;
  accounting; operational assumptions; liveness.
- [glossary.md](glossary.md): the terms.

## Conventions

The documents describe `caps-api-core-v1` and the packages of this
repository at the same commit. "The standard" means the interface
packages; "the reference implementation" means `caps-core` and the other
packages here, which conform but may be replaced. MUST, SHOULD and MAY
are used as in RFC 2119; where they appear outside the specification they
restate one of its requirements.
