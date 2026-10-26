# CAPS v1 specification

The Canton Access and Privacy Standard fixes a set of Daml interfaces for a
push oracle on Canton: fixings are canonical and recorded on the ledger,
data reaches consumers through capsules a distributor scopes to its own
clients, and the party that publishes the data is a stakeholder of nothing a
consumer touches. This document is the normative description of version 1
of those interfaces, package `caps-api-core-v1`. The interface source,
[CoreV1.daml](../interfaces/caps-api-core-v1/daml/Caps/Api/CoreV1.daml), is
the authority where the two differ; this document says what the signatures
cannot.

The words MUST, SHOULD and MAY are used as in RFC 2119. Where this document
says "the reference implementation", it describes `caps-core` and the other
packages of this repository, which conform to the standard but are not part
of it: a deployment may replace any of them.

The data types every field refers to are described in
[data-model.md](data-model.md).

## 1. Conformance

The standard names three things that can conform.

- **A deployment** conforms when it runs, for each data set, one contract
  implementing `DataDefinition`, one implementing `Verifier` that the
  definition points to, a chain of contracts implementing `RoundHead` and
  `Round`, and contracts implementing `License` and `Capsule`, all of which
  satisfy the requirements of section 3. A deployment MAY add contracts,
  choices and fields beyond the interfaces; the requirements concern only
  what is reachable through them.
- **A verifier** conforms when its template implements `Verifier` under the
  requirements of section 3.2. A verifier is the only vendor-specific
  contract a deployment needs: an oracle joins the standard by providing
  one.
- **A consumer** conforms when it accepts a capsule only after the checks of
  section 5. A consumer written against the Canton Data Standard's
  `PublishedDataPoint` interface alone reads a capsule but does not conform;
  what it misses is described in section 5.

A deployment MAY give its licenses a `LicenseDelegate` (section 3.7), the
extension point through which it can add behaviour such as accounting;
[extensions.md](extensions.md) describes the extensions this repository
ships as examples. None is required for conformance.

## 2. Parties

The standard refers to parties by role. One party may hold several roles,
with the consequences section 4 describes.

| Role | What it does | Named by the standard as |
|---|---|---|
| Operator | Publishes the data set: owns the root license and is the distributor of every root capsule. In the reference implementation it also signs the definition, the round head and the rounds. | `LicenseView.owner` of the root license, `dataPoint.distributor` of a root capsule |
| Publisher | Submits `RoundHead_CreateRound`. The operator always is one; an implementation MAY admit others. | `RoundHead_CreateRound.actor` |
| Readers | The parties entitled to see that a round exists and to check capsules against it. | observers of `Round` in the implementation |
| Distributor | The owner of a license, who signs the capsules created under it. The operator is the distributor of root capsules; every other distributor is a licensee. | `LicenseView.owner`, `dataPoint.distributor` |
| Licensee | A party a license entitles to create a sublicense from it. On the root license, also the audience of every root capsule. | `LicenseView.licensees` |
| Client | A party a capsule is distributed to. | `License_Distribute.clients`, observers of `Capsule` |
| Consumer | A client that verifies a capsule before acting on it. | `Verifier_*.actor` |
| Auditors | Parties that co-sign the definition, the round head and the rounds in the reference implementation, so that the operator cannot archive the definition or the head, fork the chain or mint a round alone, and retires a round only through `Round_Archive`; they may pause publication. Not named by the interfaces. | |

The standard's privacy goal is stated in terms of these roles: **the
operator learns who holds a license and who publishes rounds; it does not
learn who consumes, or how much any distributor distributes.** Section 4
lists the rules that deliver this and section 6 what the standard does not
promise.

## 3. Contracts

Each interface is described as: what the contract is, the semantics of its
view, the semantics of its choices, requirements on implementations, and
what the standard leaves open.

### 3.1 `DataDefinition`

The identity and trust anchor of one data set. Its contract id is what every
round, capsule and license of the data set points to; a consumer pins it
once at onboarding and compares every capsule against it.

**View.** `dataId` is a human-readable name of the data set and is not
unique by itself; the contract id is. `verifier` is the canonical
`Verifier` instance: its contract id identifies the template and the
parameters consumers verify against.

**Choices.** None in the interface.

**Requirements.** An implementation MUST keep a definition's view constant
for its life: a change of verifier or of data set is a new definition. A
definition SHOULD be visible to the readers, so that a consumer can read the
verifier it points to.

**Left open.** Who signs the definition and how it is created. The
reference implementation co-signs it by the operator and the auditors,
through a proposal that each auditor accepts and the operator finalizes,
creating the definition, the genesis round and the first round head in one
transaction.

### 3.2 `Verifier`

The oracle's verification rules as a contract, and the only vendor-specific
piece of a deployment. A verifier answers three questions about a capsule,
each through a non-consuming choice whose only controller is the party
asking.

**View.** Empty. The parameters of a verifier are fields of its template,
known to whoever creates an instance.

**`Verifier_Verify` (authenticity).** Given a `CapsuleView`, returns
`Verified dataHash` when the capsule's content is authentic by the
verifier's rules, `Rejected reasons` otherwise. What the rules are is the
implementation's; typically that `payload` carries a sufficient set of valid
oracle signatures and that `dataPoint` is the correct aggregate of it.
`dataHash` is the verifier's commitment to the content and becomes the
round's `dataHash` when the capsule is the root of a round.

**`Verifier_VerifyRound` (canonicality).** Given a `CapsuleView` and a
`RoundView`, returns `Passed` when the round belongs to the capsule's
definition, has the capsule's round number, has the capsule's fixing time
as its timestamp, and has as `dataHash` this verifier's commitment to the
capsule's content; `Failed reasons` otherwise. It checks the round against
the content only; authenticity is `Verifier_Verify`.

**`Verifier_VerifyFreshness` (freshness).** Given a `CapsuleView` and a
reference time `asOf`, returns `Passed` when the capsule's fixing time is
acceptable at `asOf` by the verifier's window, `Failed reasons` otherwise.
The window is the oracle's: how far behind `asOf` a fixing may be and still
be the latest round, and how far ahead.

**Requirements.**

- A verifier MUST NOT abort on a bad capsule. It reports, so that a caller
  can branch on the outcome; a caller that needs the transaction to fail
  asserts on the result.
- Each verdict MUST be a function of the choice's arguments and the
  verifier's own fields only. It MUST NOT depend on ledger time, on the
  calling party or on any other contract, so that a verdict can be
  reproduced later by any party holding the same inputs.
- The commitment MUST be stable: for one content, `Verifier_Verify` returns
  the same `dataHash` on every instance with the same parameters, and
  `Verifier_VerifyRound` passes a round whose `dataHash` is that value.
- The verdict of `Verifier_Verify` and its `dataHash` MUST depend only on
  the fields of `CapsuleContent` that `License_Distribute` copies
  unchanged: `dataPoint.publishedAt`, `dataPoint.schemaVersion`,
  `dataPoint.values`, `dataPoint.metadata` and `payload`. They MUST NOT
  depend on `content.license` or on `dataPoint.distributor`, which change
  at every level of distribution. Otherwise a distributed capsule would
  fail `Verifier_VerifyRound` against the round its root capsule created.
- A verifier MUST NOT fetch or exercise another contract. A fetch informs
  the fetched contract's signatories and would reveal that the caller
  consumed something.
- Two instances with the same template and the same parameters MUST give
  the same verdicts. This is what lets a consumer verify against an
  instance of its own (section 4).

**Left open.** The signing scheme, the aggregation, the encoding of
`payload`, the commitment function and the freshness window. The
repository ships a verifier for RedStone payloads and one for the Canton
Data Standard's signed envelope; [data-model.md](data-model.md) describes
both encodings.

### 3.3 `RoundHead`

The head of a data definition's round chain and its publishing endpoint.
One live contract per definition, consumed and re-created on every round.

**View.** `definition` is the data definition the head belongs to. `round`
is the latest round and `roundNumber` its number; the pointer is for
whoever wants the contract, the number for whoever counts rounds, such as
an archiver, and the round may already be retired. `isPaused` is true
while publication is suspended by the feed's governance.

**`RoundHead_CreateRound`.** Given `content`, a `CapsuleContent`
describing the root capsule, it archives this head and creates, in the same
transaction, the new round, the successor head pointing at it, and the root
capsule, returning the three contract ids as `CreateRoundResult`. The
controller is `actor`, the publisher; the authority to sign the round and
the root capsule flows from the head, not from the caller.

**Requirements.** An implementation of `RoundHead_CreateRound` MUST:

- consume the head, so that two concurrent publications on one head are a
  double spend and the losing one creates nothing. This is what makes round
  numbers unique;
- give the new round the previous round's number plus one, and the fixing
  time `content.dataPoint.publishedAt` as its timestamp;
- fail unless the fixing time is strictly greater than the previous round's
  timestamp;
- exercise `Verifier_Verify` on the definition's canonical verifier with the
  new capsule's view, fail on `Rejected`, and record the returned
  `dataHash` in the round;
- exercise `Verifier_VerifyFreshness` with ledger time as `asOf` and fail
  on `Failed`. A future-dated round would block every later one until the
  clock caught up; a stale one would be recorded as the latest fixing;
- fail while `isPaused`;
- create the root capsule with `content` unchanged, the new round's number
  and the definition, signed by the operator, with
  `content.dataPoint.distributor` equal to the operator;
- fail unless `content.license` is a license of this definition owned by the
  operator. A different license MAY be attached each round.

An implementation MAY restrict who may publish. The reference
implementation admits the operator always and, when `publishers` is set,
the parties it lists; `None` admits anyone who can see the contracts a
publication touches.

**Left open.** Who signs the head and the rounds, how publication is
paused and resumed, and who the root capsule's observers are. The
reference implementation co-signs the head and every round by the operator
and the auditors, lets any single auditor pause or
resume, and makes the root license's licensees plus the auditors the
observers of every root capsule. Pausing is governance and has no standard
choice.

### 3.4 `Round`

The immutable, price-free record of one fixing. A consumer reads it from
its own participant and passes the view to `Verifier_VerifyRound`; it is
never fetched inside a consumer's transaction.

**View.** `definition`, `roundNumber`, `timestamp` (the fixing time) and
`dataHash` (the verifier's commitment to the root capsule's content).

**`Round_Archive`.** Retires the round. The controller is `actor`; the
authority to archive the round flows from the round, not from the caller.

**Requirements.**

- A round MUST be created only by `RoundHead_CreateRound`, with the
  exception of round 0, the genesis round, which the bootstrap of a
  definition creates with the bootstrap time as its timestamp, an empty
  `dataHash` and no capsule. Data rounds start at 1.
- A round's view MUST NOT change after creation.
- Rounds MUST be visible to the readers. A round MUST NOT carry the data:
  the view holds a commitment, never a value.
- A round MUST be archived only by `Round_Archive`, which MUST refuse any
  actor the implementation does not admit.
- A round SHOULD outlive every capsule of its number, since a consumer
  checks a capsule against its round; when it may go is an archiver's rule,
  not the standard's.

**Left open.** Whom `Round_Archive` admits. The reference implementation
admits the operator alone.

### 3.5 `License`

A right to distribute capsules and to sublicense. One interface for every
level of the chain: the root license is owned by the operator; every
sublicense is owned by the licensee it was created for.

**View.** `definition` is the data set the license covers. `owner` is the
signatory and the only party that may distribute under it. `licensees` are
the parties entitled to sublicense from it; on the root license they are
also the audience of every root capsule. `delegate` is the
`LicenseDelegate` the license calls, or `None`.

**`License_Distribute`.** Creates a capsule for `clients` carrying an
existing capsule's content. The controller is the owner. `source` gives the
capsule being redistributed, by view or by contract id; `CapsuleSource` in
[data-model.md](data-model.md) says what each reveals.

**`License_CreateSublicense`.** Creates a child license owned by `actor`.
The controller is `actor`, because the child is signed by them alone.
`licenseType` is the kind of right granted, in the implementation's own
encoding; `licensees` are the parties the new license entitles to
sublicense from it.

**Requirements.**

- `License_Distribute` MUST copy the source capsule's `definition`,
  `roundNumber` and `content` unchanged, except for `content.license`, which
  becomes this license, and `content.dataPoint.distributor`, which becomes
  the owner. It MUST fail when the source belongs to another definition. It
  MUST make `clients`, and no other party, the observers of the new
  capsule: the privacy of a distribution (section 4) rests on this.
- `License_Distribute` MUST NOT verify the source's authenticity. That is
  the consumer's check, and a verification inside the distribution would
  cost every distribution a verifier exercise for a property the consumer
  checks anyway.
- `License_CreateSublicense` MUST fail unless `actor` is one of the
  license's `licensees`. The child MUST have the same `definition`.
- A license that names a delegate MUST exercise
  `LicenseDelegate_OnDistribute` in every `License_Distribute`, after
  creating the capsule, and MUST give the child of every
  `License_CreateSublicense` the delegate `LicenseDelegate_Subdelegate`
  returns.
- A license's `licensees` MUST be fixed for its life. To change the list,
  the owner creates a new license and retires the old one. A capsule points
  at the license as of its distribution, so an older capsule may point at a
  retired one; this is expected.
- An implementation SHOULD provide a way for the licensor to retire a
  license. Which party else may is the implementation's.

**Left open.** The encoding of `licenseType`, expiry, revocation, how
provenance is policed, and what a distribution costs. The reference license
makes the operator and the licensor observers of every license, inherits an
optional expiry, and lets the licensor or the operator revoke. An extension
may add kinds of its own, as `caps-extended-licensing` adds three prepaid
ones. [licensing.md](licensing.md) describes both.

### 3.6 `Capsule`

The unit of distribution. A capsule implements the Canton Data Standard's
`PublishedDataPoint`, so any consumer of that standard reads it unchanged;
the CAPS view adds provenance.

**View.** `definition`, `roundNumber` and `content`, the `CapsuleContent`
with the data point, the opaque signed payload and the license.

**Choices.** None in the interface. Authenticity and canonicality are
checked through a verifier.

**Requirements.**

- The signatory MUST be `content.dataPoint.distributor`, so that the Data
  Standard view names the party that signed.
- `content.dataPoint` MUST equal the view the contract exposes through
  `PublishedDataPoint`.
- The observers MUST be the audience the capsule was distributed to: the
  root license's licensees for a root capsule (the reference adds the
  auditors), the `clients` of `License_Distribute` otherwise. Observers of
  one capsule see each other; a distributor that must keep two clients
  apart distributes to each separately.
- A capsule MUST NOT be modified: its view is fixed at creation. Retention
  is the distributor's: the standard does not archive capsules, and the
  repository ships an archiver that does so by rounds and age.

### 3.7 `LicenseDelegate`

What a license does on a distribution beyond creating the capsule, such as
accounting. Optional: a license names one in its view, or `None`.

**View.** Empty.

**`LicenseDelegate_OnDistribute`.** Reports a distribution: the
distributor, who is the controller, the license as issued, the round
number, the new capsule and its clients, each if the license names them,
and an optional context in the license's own encoding.
The license exercises it in the same transaction, after
creating the capsule, so a distribution through the license cannot happen
without it. The reference licenses name the new capsule but not its
clients; a delegate that fetches the capsule learns them.

**`LicenseDelegate_Subdelegate`.** Returns the delegate a sublicense
names: this one, for a delegate shared along the chain, a new one, or none.
The controllers are the owner of the license being sublicensed and the
owner of the sublicense, whose authority `License_CreateSublicense`
carries; the choice also receives the sublicense's license type and
licensees. The sublicense's owner submits it, so the licensees of every
license that names a delegate MUST observe the delegate.

**Left open.** Who signs a delegate, and what it does. A non-consuming
exercise informs the delegate's signatories and the actor, and both confirm
it, so who signs decides who learns of distributions:

| Delegate signed by | Learns of every distribution that calls it | Confirms it |
|---|---|---|
| the distributor | nobody beyond the distribution's own informees | nobody new |
| an accountant | the accountant | the accountant's participant, so its outage stops distribution |
| the operator | the operator, against the privacy goal of section 2 | the operator's participant |

What the delegate creates informs that contract's stakeholders. A capsule
created directly, outside any license, calls no delegate (section 7).

## 4. Privacy rules

Canton informs a party of a transaction node when the party is a
*stakeholder* of a contract the node creates or archives, a *signatory* or
*actor* of a contract the node fetches or exercises, or an *observer* of a
contract a consuming exercise archives. Every rule below follows from this.

1. **Verification takes views, never contract ids.** Every `Verifier`
   choice receives the capsule, and the round, as data. A fetch would inform
   the fetched contract's signatories, the distributor and the operator,
   that the consumer used the capsule and when.
2. **A consumer verifies against its own verifier instance.** Exercising the
   canonical instance would inform its signatory, the operator, of every
   verification. A consumer creates an instance from the same template with
   the same parameters and itself as signatory; by the requirements of
   section 3.2 the verdicts are the same, and the exercise has no informee
   beyond the consumer.
3. **A consumer reads its round from its own participant.** It is an
   observer of the round, so it has the round's view without any
   transaction; passing the view to `Verifier_VerifyRound` informs nobody.
4. **Distribution by view is private; by id is not.** `ByView` passes the
   source capsule as data: the exercise informs the license's owner and the
   new capsule's observers, which are its `clients` and nobody else by the
   requirements of section 3.5, plus the informees of the license's
   delegate, if it names one (section 3.7). `ById` makes the implementation
   fetch the
   source, which informs its signatory, the operator for a root capsule or
   the parent distributor otherwise, of the time of this distribution. A
   distributor that wants to keep its distributions to itself uses `ByView`.
5. **Nothing on the consumption path touches a contract the operator
   signs.** A consumer's transaction exercises its own verifier and reads
   its own view of the round. The operator is informed of a round's
   existence, which it created, and of nothing downstream.
6. **The operator is informed of licenses it observes.** In the reference
   implementation the operator observes every license at every level, so it
   learns who holds a license, which section 2 states as accepted.
7. **A license's delegate is informed of its distributions.** Its
   signatories learn of every distribution that calls it, so a delegate
   that must not widen the audience of a distribution is signed by the
   distributor.
8. **Disclosure informs the recipient only.** Showing a contract to a party
   through explicit disclosure creates no ledger event. A publisher that is
   not a reader can be given the contracts a publication touches this way;
   a client can be shown the license a capsule names.

The consequence for roles: the party acting as operator MUST NOT also act
as a client's verifier owner or, where an extension such as accounting
adds that role, as an accountant, or it learns through those roles what
the rules above keep from the operator.

## 5. The consumer's procedure

A consumer that received a capsule, as a `Capsule` or as a
`PublishedDataPoint`, accepts it only after the checks below. The first
three are exercises on the consumer's own verifier instance; the fourth and
fifth are readings of contracts and events the consumer already sees.

1. **Authenticity.** `Verifier_Verify` with the capsule's view MUST return
   `Verified`. The consumer MAY record the returned `dataHash`.
2. **Canonicality.** `Verifier_VerifyRound` with the capsule's view and the
   view of the round of the capsule's `roundNumber` for the capsule's
   `definition`, as read from the consumer's own participant, MUST return
   `Passed`. A capsule whose round the consumer cannot see is not
   verifiable, and a consumer that is not a reader SHOULD NOT accept one.
3. **Freshness.** `Verifier_VerifyFreshness` with the time the consumer
   cares about MUST return `Passed`, or the consumer applies a policy of its
   own to `content.dataPoint.publishedAt`. The oracle's window is the one
   that admitted the round at publication; a consumer's need may be
   stricter.
4. **License.** The capsule's `definition` MUST be the definition the
   consumer pinned, and `content.license` SHOULD resolve to a license the
   consumer sees, or is shown, whose `owner` is `content.dataPoint.distributor`
   and whose `definition` is the capsule's. What a consumer can tell from a
   license is the standard's `LicenseView` plus whatever the template it
   recognises adds; [licensing.md](licensing.md) describes what the reference
   templates let a client check.

5. **Chain.** The round's signatories, as the Ledger API reports them to
   the consumer, SHOULD be the signatories of the definition the consumer
   pinned. In the reference implementation both are the operator and the
   auditors, and the auditors' authority over a round is available only
   inside `RoundHead_CreateRound`, so a round with those signatories came
   from the chain and nobody can create a second round of one number
   alone; [governance.md](governance.md) describes the variants in which
   the check takes a different form. Signatories are not part of any
   view, so this check is the consumer application's, not a verifier's.

A consumer that uses the capsule in a transaction with other parties
performs checks 1 to 3 inside that transaction: every informee's
participant re-executes them, so the counterparties need not trust the
consumer's reading. Check 4 cannot be performed inside a transaction without
fetching the license, which informs its owner; a consumer that needs it
proven to a counterparty discloses the license contract instead.

## 6. The publisher's procedure

A publication is one exercise of `RoundHead_CreateRound` on the current
head with the root capsule's content. Every contract used in a transaction
MUST be visible to the submitter's participant, whatever authority the
choice carries. In the reference implementation a publication touches
three existing contracts: the head, the canonical verifier and the root
license; the head carries the latest round's number and fixing time, so no
round is fetched and retiring one never stops publication. Publishing is
therefore open to whoever sees all three: the operator and the root
license's licensees by observation, provided the verifier's template makes
the readers observers of the canonical instance, and anyone else by
explicit disclosure of the three contracts.

A publisher that loses the race on the head gets a failed submission and
nothing is created; it re-reads the head and submits again with the same
or a later fixing.

## 7. What the standard does not promise

The standard proves two things to a consumer, authenticity and
canonicality, and polices or leaves open everything else.
[threat-model.md](threat-model.md) is the full account; the three entries
that every implementer and consumer should know are these.

- **A capsule can be created directly.** A capsule template signed by its
  distributor alone can always be created without any license choice.
  `Verifier_Verify` is what rejects fabricated content; nothing rejects a
  genuine capsule that skipped the license. The only structural remedy, a
  co-signatory of the capsule, would see the capsule's audience, so the
  standard forgoes it.
- **License provenance is policed, not proven.** The standard's
  `LicenseView` carries owner, definition and licensees; whether a license
  was issued through the chain is visible to the parties the implementation
  makes observers of it and known to the licensor it names, not provable to
  a consumer from the interface alone.
- **The operator learns who publishes and who holds licenses.** Both follow
  from the operator signing the head and observing the licenses. What the
  operator does not learn is consumption.

## 8. Versioning

An interface package can never be smart-contract-upgraded, so
`caps-api-core-v1` holds views, data types and choices whose bodies are
single method calls, and no logic. A change to any view, type or choice
signature is a new interface package, `caps-api-core-v2`, which a deployment
adopts by implementing both for the transition. Implementation packages,
the verifiers among them, MAY be upgraded in place under Daml's
smart-contract upgrade rules, which is where the executable code lives for
that reason.

The interface package targets Daml-LF 2.1, the version the Canton Data
Standard and the Splice packages target, and declares every type
`Serializable` explicitly.
