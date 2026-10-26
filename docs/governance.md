# Governance: the operator, the auditors and the round chain

Who signs the data definition, the round head and the rounds; who can pause
publication and who can resume it; who can stop a feed and who can fork
it. The interfaces fix none of this: pausing has no standard choice, and
which parties sign the head and the rounds is the implementation's. This
document describes what the reference implementation does, the trade-off
every alternative has to make, the alternatives considered, and the
decision to keep the reference as it is. It summarises the team's
discussion of 15 and 16 October 2026.

Out of scope: accounting ([accounting.md](accounting.md)), verifiers,
retention ([lifecycle.md](lifecycle.md)).

## The trade-off

On Canton, every guarantee of the form "the operator cannot do X alone" is
somebody's signature on a contract, and every signatory's participant is a
confirming party of every transaction that creates, consumes, fetches or
exercises that contract. Confirmation is validation, not consent: a
participant cannot refuse a valid transaction, it can only be unavailable.
So each co-signatory removes a power from the operator and adds a party
whose outage or unwillingness stops publication.

Two facts bound what any design can achieve:

- **Consuming the head prevents two extensions of one head.** Two
  concurrent `RoundHead_CreateRound` on the same head are a double spend;
  one passes. This is what makes round numbers unique along one chain.
- **Only a co-signature prevents a fresh head.** A party that signs the
  head alone can create a new head, pointing at any round, outside any
  choice. The ledger excludes a fork only if the head needs a signature the
  forking party does not hold.

There is no configuration in which nobody can block alone and the ledger
excludes a fork, short of moving both properties to a k-of-n threshold in
Canton's topology (variant E).

## The reference implementation

### Contracts and parties

| Contract | Signatories | Observers | Note |
|---|---|---|---|
| `DataDefinition` | operator, auditors | readers | Created once through `DefinitionProposal`: the operator proposes, each auditor accepts, the operator finalizes. Never touched by a publication. |
| `RoundHead` | operator, auditors | readers | One live contract per definition. Beyond the view's `definition`, `round` and `isPaused`: the parties, the canonical `verifier`, and `publishers` (`None` admits anyone, `Some []` the operator only). |
| `Round` | operator, auditors | readers | Created in `RoundHead_CreateRound` with the fixing time and the verifier's commitment; the auditors' authority comes from the head, so a round cannot be minted or archived outside a choice. |
| `Capsule` (root) | operator | root license's licensees, auditors | Created in the same transaction as the round. |

### A publication

An admitted publisher exercises `RoundHead_CreateRound`. The transaction
fetches the root license (through its interface), exercises
`Verifier_Verify` and `Verifier_VerifyFreshness` on the canonical verifier,
and creates the round, the successor head and the root capsule; the
previous round's number and fixing time come from the head itself, so no
round is fetched. The publisher must see three contracts: the head, the
verifier and the root license, by observation or by explicit disclosure.
The participants of the operator and of every auditor confirm, because they
sign the head and the round.

### Pause

`RoundHead_Pause` and `RoundHead_Resume`: the controller is any single
auditor; the operator's authority flows from the head. The head does not
remember who paused, so any auditor can resume another's pause. The
operator can neither pause nor resume.

### Properties

| Property | State | Why |
|---|---|---|
| Uniqueness of the chain (canonicality) | prevented | A new head, and a new round, need the authority of every signatory, available only inside a choice on the existing head; consuming the head excludes two extensions of it, and the auditors' signature on every round excludes a round minted outside the chain. |
| Censorship by the operator's inaction | excluded | A publisher needs no action from the operator; the operator's participant only validates. |
| Selective censorship by taking a node down | possible | The operator can switch its participant off for an inconvenient round. It is visible (a gap, timeouts), and another publisher can add the missed round after the node returns, within `maxBehind`. |
| Blocking by a single auditor | possible | The outage or boycott of one auditor's participant stops publication, and so does one pause. |
| Blocking by the operator | possible | Through its own participant. Does not affect distribution or consumption of existing capsules, where the operator is no party. |
| Dependence on data production | outside the model | The oracle's nodes sign independently of the operator; CAPS liveness concerns the step on the ledger. |

### Actors

| Actor or event | Fork the chain | Stop publication | Other |
|---|---|---|---|
| Operator alone, malicious | no | yes, by taking its node down (visible) | cannot pause or resume; does not see consumption |
| One auditor, malicious | no | yes, by its node or by a pause | can resume another auditor's pause |
| Operator and every auditor, colluding | yes | yes | full control; the model's boundary |
| Outage of any signatory's node | | yes, until the node returns; transactions time out, nothing is lost | mitigation: multi-hosting |
| Another publisher | no | no | publishes without the operator if it sees the three contracts |
| A consumer | no | no | verifies locally on its own verifier instance |

## Variants

Ordered from the smallest change to the largest. None changes
`caps-api-core-v1`.

### A. Every auditor co-signs (the reference)

What changes: nothing. The head and the rounds are signed by the operator
and every auditor; a single auditor pauses and resumes. Signing the rounds
costs no liveness beyond the head, since the same participants confirm the
same transaction, and it is what makes a round minted outside the chain
impossible rather than merely visible.

- Gains: the fork is excluded by the ledger; canonicality is a property of
  the ledger, not of a consumer's policy. The operator cannot censor
  selectively by inaction. The simplest code and tests; everything
  verifiable in Daml Script.
- Costs: every signatory is a single point of blocking (outage or will). A
  single auditor pauses and resumes, and one auditor can cancel another's
  pause. Each additional auditor worsens liveness.
- Use when: uniqueness of the chain matters more than resistance to a
  single auditor, and the auditors are few and well run.

### B. Multi-hosting (no code change)

What changes: each signatory hosts its party on at least two participants
with a confirmation threshold of one. Pure Canton topology.

- Gains: removes a single node's outage as a cause of stopped publication.
  No Daml change; compatible with every other variant; applies to the
  operator too.
- Costs: does not protect against will, since the party's owner controls
  all of its nodes. Requires auditors to run more than one participant.
  Not testable in the repository.
- Use when: always, as the baseline for A and D.

### C. Auditors as observers, a consumer-side check, pause by threshold

What changes: the operator alone signs the head and the rounds; the
auditors observe them. Pause and resume need k of n auditors through a
proposal contract. The consumer checks in its application, not in
`Verifier_VerifyRound`, that the round comes from a trusted template and
has among its observers the auditors and a public party recorded in the
(still co-signed) definition.

- Gains: no single auditor can stop publication, by inaction or by pause.
  Blocking becomes an explicit, attributable act on the ledger. A fork is
  immediately public: to pass the consumer's check, a forked round must
  carry the auditors and the public party as observers, so everyone sees
  it.
- Costs: the ledger does not prevent a fork; canonicality drops from
  "impossible" to "detectable and useless against consumers that apply the
  check". Until the auditors react, consumers may see two rounds of one
  number and must treat the state as invalid. The operator can archive the
  head alone and create new heads. Checking signatories no longer tells
  branches apart; what remains is the template and the observers. Incident
  response is slower (a threshold) than a single pause.
- Requires: changed signatories of `RoundHead` and `Round` in `caps-core`,
  `PauseProposal` and `ResumeProposal`, the auditors and the public party in
  the definition, a new item in the consumer's checks.
- Use when: the operator is trusted for the history and the auditors are a
  safety brake no single one may abuse.

### D. A subset of co-signers, with pause thresholds

What changes: one `RoundHead` template with `cosigners` (a subset of the
auditors, possibly empty), `pauseThreshold`, `resumeThreshold`, `pausedBy`,
and a choice to replace an auditor (operator plus a majority of auditors).
`signatory operator, cosigners`, `observer auditors`. A is `cosigners =
auditors`; C is `cosigners = []`. The typical compromise is one co-signer
with multi-hosting.

- Gains: one implementation, three policies configured at bootstrap; no
  interface change. With one co-signer, a malicious operator alone cannot
  fork, and the other auditors can block nothing but through a pause.
  Separate thresholds keep the brake fast and its release a consensus;
  `pausedBy` stops one auditor from cancelling another's pause. Replacing
  an auditor needs no consent from the one removed: its authority is in
  the consumed head.
- Costs: the co-signer remains a single point of blocking by will
  (multi-hosting covers outage only), so the most trusted auditor has to be
  chosen. Operator and co-signer colluding can fork; the other auditors see
  it and cannot stop it. Replacing an auditor still needs its participant's
  confirmation (availability, not will). More parameters and test paths.
- Requires: head fields, `PauseProposal` and `ResumeProposal`,
  `RoundHead_ReplaceAuditors`, tests per configuration. Suggested with
  three auditors: pause 1, resume 2, replace operator plus 2.
- Use when: a deployment wants the current behaviour as one configuration
  and operators to trade it off without forking the code. This is how the
  reference implementation would be parametrised if it ever were; it is
  not scheduled.

### D+. The co-signer in a decentralized namespace

What changes: as D, with the co-signer's party created in a namespace
owned by the operator and the auditors with a k-of-n threshold, hosted on
the auditor's node and on a backup node outside its control, with a
confirmation threshold of one.

- Gains: removes the co-signer's will as a point of blocking: switching
  its own node off achieves nothing, and it cannot withdraw the hosting
  alone. The operator stays on the head, so the root capsule's distributor
  and the root license's owner do not change.
- Costs: a topology ceremony with every party and a backup node run by
  someone else. Collusion of k of n namespace owners remains.
- Use when: trusting a single auditor is unacceptable but the full
  governance model is too heavy.

### E. A governance party signs the head

What changes: the head, the rounds and the root capsules are signed by a
party G created in a decentralized namespace of the operator and the
auditors, hosted on their participants with a confirmation threshold of
k. After bootstrap no participant has submission rights as G; publishers
take its authority from the head. Pause, resume and license revocation are
choices with an auditor threshold; replacing an auditor is a k-of-n
topology transaction. The pattern of the DSO party in Splice.

- Gains: uniqueness and liveness together: nobody can create a head as G
  outside a choice, and the outage or boycott of a single node does not
  stop publication. The operator is no longer a single point of blocking
  and cannot censor by taking a node down. Latency does not grow: k of n
  confirm instead of all.
- Costs: the trust assumption drops from "all" to "at least k": k
  namespace owners can grant submission rights and fork. Nobody can act as
  G, so every decision must be a choice with a threshold designed in
  advance; anything unforeseen needs a ceremony restoring submission
  rights, and so does every migration that creates contracts from scratch.
  Bootstrap needs temporary submission rights, withdrawn afterwards. G
  becomes the distributor of root capsules and the owner of the root
  license, so the Data Standard view names the governance party, not the
  oracle, and legal responsibility blurs. Auditors must run highly
  available participants. Liveness cannot be covered by tests in the
  repository.
- Requires: `caps-core` choices with thresholds for revocation, pause,
  publishers and readers; topology procedures; a DevNet demonstration.
- Use when: the feed has genuinely multi-party governance in which no
  organisation may stop or fork the chain alone. A candidate for a later
  milestone, to be tried on DevNet first.

## Pause governance, independent of the variant

Pausing has no choice in the interface, so all of this is `caps-core`'s
and applies to A, C, D and E alike. The reference keeps the first column;
the second describes what a deployment that wants a threshold would build.

| Element | Reference | Alternative | Why |
|---|---|---|---|
| Pause | any one auditor | `pauseThreshold`, suggested 1 | The brake must act in minutes. A single pause is a blocking vector, but replacing the auditor cures it. |
| Resume | any one auditor | `resumeThreshold`, suggested a majority, excluding the pauser and the operator | One auditor does not cancel another's pause; the operator does not bypass one. |
| Memory | none | a `pausedBy` field | Needed for the resume rule and for the audit trail. |
| Replacing an auditor | none (a new bootstrap) | `RoundHead_ReplaceAuditors`: operator plus a majority of auditors | An auditor that pauses repeatedly or is unavailable can be removed; its authority is in the consumed head. |

## Comparison

| Criterion | A reference | B multi-host | C observers | D co-signers | E governance |
|---|---|---|---|---|---|
| Fork of the chain | excluded | as A | detectable, public | excluded short of operator and co-signer colluding | excluded short of k of n owners colluding |
| Blocking: auditor node outage | yes, any | no | no | the co-signer only (not with multi-hosting) | no (threshold k) |
| Blocking: auditor's will | yes, any | yes, any | no (beyond a threshold pause) | the co-signer only (not in D+) | no |
| Blocking: operator through its node | yes | outage no, will yes | yes | yes | no |
| Selective censorship by the operator | by taking its node down | as A | as A | as A | no |
| Incident response | one auditor, at once | as A | threshold k | configurable | threshold k |
| Interface change | | | no | no | no |
| `caps-core` change | | no | medium | medium | large |
| Canton topology | | multi-hosting | | optional (D+) | decentralized namespace, threshold, bootstrap |
| Testable in the repository | fully | not at all | fully (except the public party) | fully | partly |
| Who answers for the data in the view | operator | operator | operator | operator | the governance party |

## Ideas examined and rejected

- **`firstRound` in the definition.** Anchors the start of the chain, not
  its uniqueness: a fork at round 57 gives two branches from the same
  genesis, and two "round 57"s pointing at the same round 56.
- **Contract keys (LF 2.3).** Not unique and not checked by the ledger, so
  they do not strengthen the mutex on the head; `lookupByKey` informs the
  maintainers, the operator, on the consumption path. The standard stays on
  LF 2.1 like the Data Standard and Splice.
- **Checking signatories in `Verifier_VerifyRound`.** The choice receives
  the round's view as data and does not see signatories; an `auditors`
  field in the view could be filled in at will. The check belongs to the
  consumer's application, which sees signatories and observers in the
  Ledger API events.
- **A k-of-n auditor threshold for publication itself, in Daml.** Would
  need a propose-and-accept workflow per round, which kills publication
  latency. An availability threshold is topology's to give (B, D+, E).
- **Auditors as observers as prevention, because "they will notice".** The
  creator of a head writes its observer list; an operator forking the chain
  simply leaves them out. Only the consumer's observer check forces them in
  and makes a fork public (variant C).

## Decision

A is the reference implementation and stays so: every auditor co-signs
the head and the rounds, any single auditor pauses and resumes. The other
variants are
described here so that a deployment with different needs knows what it
trades and what it has to build; none is scheduled for `caps-core`. Two
things follow for every deployment of A:

1. **Multi-hosting (B)** of every signatory's party, as operational
   hygiene: it removes a node outage as a cause of stopped publication at
   no cost to the model.
2. **A consumer-side check** that the signatories of a round, as the
   Ledger API shows them, are the signatories of the definition the
   consumer pinned ([specification.md](specification.md), section 5). It
   costs nothing under A, where it proves the round came from the chain,
   and it is what distinguishes a round of the chain from a round created
   by a lone signatory under a weaker variant.

The topological variants (D+, E) are a direction to try on DevNet with
the open questions below, not a plan.

## Open questions

- How many auditors are expected for RedStone feeds, and are they separate
  organisations with their own participants or parties hosted by RedStone?
  The topological variants make sense only in the first case.
- Is "detectable fork" (C) acceptable for financial feeds in place of
  "excluded" (A, D)? Proposed answer: no, but it is the feed operator's
  decision and should be a configuration.
- Should a single pause stay the default (a fast brake) or a threshold from
  the start (resistance to one auditor)? Proposed: 1 for pause, a majority
  for resume, replacing the auditor as the valve.
- In E, who is the distributor of root capsules and the owner of the root
  license, and will regulated consumers accept a governance party as the
  "distributor" in the Data Standard view?
- How to document that CAPS liveness concerns the step on the ledger, not
  data production, without promising more than the model gives.
