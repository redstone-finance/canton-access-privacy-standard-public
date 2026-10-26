# CAPS v1 data model

The types of `caps-api-core-v1`: what each field means, which contract
refers to which, what identifies a thing, and who sees what in the
reference implementation. [specification.md](specification.md) states the
requirements; this document is the field-level reference.

## Contracts and references

```
DataDefinition ◄──────────────────────────────────────────────┐
  dataId, verifier ──► Verifier (canonical instance)          │
        ▲                                                     │
        │ definition                                          │ definition
  RoundHead ──round──► Round (latest)                         │
  (consumed on every   roundNumber, timestamp, dataHash       │
   CreateRound)              ▲                                │
                             │ by roundNumber, not by id      │
  License ◄──content.license── Capsule ─────────────────────┘
  owner, licensees             roundNumber
     ▲                         content: dataPoint, payload, license
     │ licensor (party)        observers: the audience
  License (sublicense)
```

Every arrow is a `ContractId` field, except the two marked otherwise: a
capsule names its round by number, and a sublicense names its licensor by
party. Both are deliberate. A round is replaced by nothing and referenced by
every capsule of its number, so a number is the stable name; a licensor's
license may be retired and re-issued without touching the sublicenses
below it.

## Identity

| Thing | Identified by | Why |
|---|---|---|
| A data set | the `DataDefinition` contract id | `dataId` is a label and may repeat; the contract id is what a consumer pins and what every other contract carries. |
| The verification rules | the canonical `Verifier` contract id in the definition's view | It names a template and its parameters. A consumer reads the contract, creates an instance of its own from the same template with the same fields, and verifies against that. |
| A fixing | `(definition, roundNumber)` | Unique because the head is consumed on every round. The `Round` contract id is not referenced by anything. |
| A license | its contract id | `content.license` of a capsule is the license as issued, at the time of distribution. |
| A capsule | its contract id | Referenced by nothing in the core interfaces except, optionally, `LicenseDelegate_OnDistribute`. An extension may record it, as the accounting extension's marker does. |
| A distributor | a `Party` | `dataPoint.distributor`, which is also the capsule's signatory, and `LicenseView.owner`. |

## Types

### `CapsuleContent`

What a capsule carries beyond its round. Used by `RoundHead_CreateRound`,
where it describes the root capsule, and by `CapsuleView`.

| Field | Type | Meaning |
|---|---|---|
| `dataPoint` | `PublishedDataPointView` | The aggregated data point in the Canton Data Standard's shape. `publishedAt` is the fixing time; `distributor` is the capsule's signatory. |
| `payload` | `AnyValue` | The signed oracle data the aggregate was computed from, in the oracle's own encoding, opaque to the standard. Carried so that a capsule can be verified on its own and redistributed through `License_Distribute`. |
| `license` | `ContractId License` | The license the capsule is distributed under: the root license for a root capsule, the distributor's license otherwise. |

Along a chain of distributions, `dataPoint.publishedAt`, `dataPoint.values`,
`dataPoint.schemaVersion`, `dataPoint.metadata` and `payload` are copied
unchanged; `license` and `dataPoint.distributor` change at every level.
A conforming verifier gives the same verdict and the same commitment for a
root capsule and for every capsule distributed from it, because
[specification.md](specification.md) section 3.2 forbids it to depend on
the two fields that change, and `Verifier_VerifyRound` passes all of them
against the one round.

### `CapsuleSource`

How `License_Distribute` receives the capsule it redistributes.

| Constructor | Informees of the exercise | Use |
|---|---|---|
| `ByView CapsuleView` | the license's owner and the new capsule's clients, plus the informees of the license's delegate if it names one | The private option: the source is passed as data. |
| `ById (ContractId Capsule)` | the above, plus the source capsule's signatory | The implementation fetches the source, which informs its distributor (the operator for a root capsule) of the time of this distribution. |

### `CreateRoundResult`

What `RoundHead_CreateRound` returns.

| Field | Type | Meaning |
|---|---|---|
| `head` | `ContractId RoundHead` | The successor of the consumed head, pointing at `round`. The next publication exercises this one. |
| `round` | `ContractId Round` | The new round. |
| `capsule` | `ContractId Capsule` | The root capsule for the new round. |

### `VerificationResult` and `CheckResult`

| Type | Constructors | Returned by |
|---|---|---|
| `VerificationResult` | `Verified with dataHash : Text`, `Rejected [RejectionReason]` | `Verifier_Verify` |
| `CheckResult` | `Passed`, `Failed [RejectionReason]` | `Verifier_VerifyRound`, `Verifier_VerifyFreshness` |

`RejectionReason` is `Text`, in the implementation's words. A rejection
carries one or more reasons, unstructured and specific to the verifier;
the verifiers in this repository list the checks that failed up to the
first one that makes the rest meaningless, such as a malformed payload or
a wrong set of feeds, and a consumer SHOULD treat the list as something
to log, not to branch on. A
verifier reports rather than aborts, by the requirement of
[specification.md](specification.md) section 3.2, and the caller decides.

### Views

**`DataDefinitionView`**

| Field | Type | Meaning |
|---|---|---|
| `dataId` | `Text` | Human-readable name of the data set: "BTC/USD", a basket id, a NAV series. Not unique. |
| `verifier` | `ContractId Verifier` | The canonical verifier instance. |

**`VerifierView`**: empty. A verifier's parameters are fields of its
template, known to whoever creates an instance.

**`RoundHeadView`**

| Field | Type | Meaning |
|---|---|---|
| `definition` | `ContractId DataDefinition` | The data set. |
| `round` | `ContractId Round` | The latest round; the genesis round right after bootstrap. A pointer, not a dependency: it may have been retired. |
| `roundNumber` | `Int` | The latest round's number, for whoever counts rounds without fetching one. |
| `isPaused` | `Bool` | True while publication is suspended. |

**`RoundView`**

| Field | Type | Meaning |
|---|---|---|
| `definition` | `ContractId DataDefinition` | The data set. |
| `roundNumber` | `Int` | 0 for the genesis round, then one more per round. |
| `timestamp` | `Time` | The fixing time, strictly greater than the previous round's. The genesis round carries the bootstrap time. |
| `dataHash` | `Text` | The verifier's commitment to the root capsule's content, as `Verified` returned it at publication. Empty on the genesis round. |

**`LicenseView`**

| Field | Type | Meaning |
|---|---|---|
| `definition` | `ContractId DataDefinition` | The data set the license covers. |
| `owner` | `Party` | The signatory, and the only party that may distribute under it. |
| `licensees` | `[Party]` | Parties entitled to sublicense from it. On the root license, also the audience of every root capsule. Fixed for the life of the contract. |
| `delegate` | `Optional (ContractId LicenseDelegate)` | The delegate the license calls on every distribution and sublicense; `None` for none. |

**`LicenseDelegateView`**: empty, like `VerifierView`.

**`CapsuleView`**

| Field | Type | Meaning |
|---|---|---|
| `definition` | `ContractId DataDefinition` | The data set. |
| `roundNumber` | `Int` | The round the data was fixed in. |
| `content` | `CapsuleContent` | Data point, payload and license. `content.dataPoint` equals the `PublishedDataPoint` view of the same contract. |

### Choice arguments

| Choice | Field | Type | Meaning |
|---|---|---|---|
| `Verifier_Verify` | `actor` | `Party` | The verifying party; sole controller. |
| | `capsule` | `CapsuleView` | The capsule being checked, as data. |
| `Verifier_VerifyRound` | `actor`, `capsule` | | As above. |
| | `round` | `RoundView` | The round as read from the consumer's own participant. |
| `Verifier_VerifyFreshness` | `actor`, `capsule` | | As above. |
| | `asOf` | `Time` | The reference time the fixing time is judged against: ledger time at publication, the time the consumer cares about otherwise. |
| `RoundHead_CreateRound` | `actor` | `Party` | The publisher; sole controller. |
| | `content` | `CapsuleContent` | The root capsule's content, with the root license in force for this round. |
| `Round_Archive` | `actor` | `Party` | The party retiring the round; sole controller. The authority to archive flows from the round. |
| `License_Distribute` | `source` | `CapsuleSource` | The capsule being redistributed. |
| | `clients` | `[Party]` | Observers of the new capsule. They see each other. |
| `License_CreateSublicense` | `actor` | `Party` | Owner of the new license; sole controller; must be one of the license's `licensees`. |
| | `licenseType` | `AnyValue` | The kind of right granted, in the implementation's encoding. |
| | `licensees` | `[Party]` | Parties the new license entitles to sublicense from it. |
| `LicenseDelegate_OnDistribute` | `distributor` | `Party` | The license's owner; sole controller. |
| | `license` | `ContractId License` | The license as issued, also when its contract was replaced. |
| | `roundNumber` | `Int` | The round the distributed data was fixed in. |
| | `capsule` | `Optional (ContractId Capsule)` | The capsule the distribution created, if the license names it. |
| | `clients` | `Optional [Party]` | The parties the capsule was distributed to, if the license names them; the reference licenses pass `None`. |
| | `context` | `Optional AnyValue` | Anything else the license tells its delegate, in its own encoding; the extended licenses pass an `AVMap` with the distribution's weight under `weight`, the reference license `None`. |
| `LicenseDelegate_Subdelegate` | `licensor` | `Party` | Owner of the license being sublicensed; controls the choice together with `actor`. |
| | `actor` | `Party` | Owner of the new license, as in `License_CreateSublicense`; controls the choice together with `licensor`. |
| | `licenseType` | `AnyValue` | The kind of right the new license grants, in the implementation's encoding. |
| | `licensees` | `[Party]` | Licensees of the new license, who sublicense through its delegate. |

## Types taken from the Canton Data Standard

CAPS depends on two packages of the
[Canton Data Standard](https://github.com/kaikodata/canton-data-standard),
version 0.2.0, vendored in `deps/`: `canton-data-standard-utils-v1` for
`AnyValue` and `canton-data-standard-datapoint-v1` for `PublishedDataPoint`.
The Data Standard verifier also uses `canton-data-standard-codecs` and
`canton-data-standard-distributor-key-v1`, and the RedStone verifier the
RedStone Daml SDK (`redstone-sdk-v20`, `redstone-common-v20`); the
interfaces depend on the first two packages only.

**`AnyValue`** (`DataStandard.Utils`), a tagged value:

```
AVInt Int | AVDecimal Decimal | AVText Text | AVTime Time | AVBool Bool
| AVList [AnyValue] | AVMap (TextMap AnyValue)
```

CAPS uses it for `payload`, for `licenseType` and for the delegate's
`context`, in all three cases as an opaque container whose shape the
implementation defines.

**`PublishedDataPointView`** (`DataStandard.DataPointV1`):

| Field | Type | Meaning in CAPS |
|---|---|---|
| `distributor` | `Party` | The capsule's signatory. |
| `publishedAt` | `Time` | The fixing time. Equal to the round's `timestamp`. |
| `schemaVersion` | `Text` | The version of the `values` schema; the distributor's, independent of the interface version. |
| `values` | `TextMap AnyValue` | The data: field names to tagged values. For a price feed, typically the feed id and the price. |
| `metadata` | `Metadata`, a record wrapping a `TextMap Text` in its `values` field | Annotations that are not part of the data. |

**`PublishedDataPoint`** is the interface every capsule implements. Its one
choice, `PublishedDataPoint_Fetch`, returns the view to any `actor` that
can see the contract, including a party that holds it by explicit
disclosure and so cannot `fetch` it. A consumer written against the Data
Standard reads a capsule through this choice or by querying the view, and
sees the data point without the CAPS provenance; the CAPS view is what it
adds.

## Payload encodings

The standard fixes `payload : AnyValue` and nothing about its shape; each
verifier defines the encoding it accepts and the commitment it computes.
The repository ships three.

| Verifier | `payload` | `dataPoint` must be | Commitment (`dataHash`) |
|---|---|---|---|
| `caps-verifier-redstone` | `AVText` of a RedStone payload as the nodes sign it and the gateways serve it, hex-encoded: signed data packages, unsigned metadata, the RedStone marker | exactly the verifier's `feedIds`, each equal to the median of the quorum of packages for that feed | keccak256 of the payload bytes |
| `caps-verifier-datastandard` | `AVMap` with `expiresAt : AVTime` and `signatures : AVList [AVText]`, each signature hex DER ECDSA over the SHA-256 of the envelope's structural root hash | the signed content: its `publishedAt`, `schemaVersion` and `values` are the envelope's | the envelope's structural root hash, the Data Standard's `canonicalHash` |
| `caps-tests-fixtures` (`TestVerifier`) | `AVText` equal to the configured tag; no cryptography | anything | SHA-256 over the fixing time and the values |

Rejection reasons are the verifier's. The RedStone verifier prefixes those
of the RedStone SDK with the error's kind (`verifier configuration
rejected`, `malformed RedStone payload`, `payload packages rejected`,
`payload aggregation rejected`); the round and freshness checks of the
three verifiers use similar but not identical wording (`round number
mismatch`, `round commitment mismatch` in the two shipped verifiers and
`commitment mismatch` in the test one, `fixing time too far in the past`).
A consumer SHOULD treat the reasons as text, not as an enumeration.

The freshness window is two durations, `maxBehind` and `maxAhead`, on the
verifier template, inclusive at both edges: a fixing time `t` passes at
`asOf` when `asOf - maxBehind <= t <= asOf + maxAhead`. The Data Standard
verifier additionally fails a payload whose `expiresAt` is before `asOf`.

## Lifecycle

Where each contract comes from and where it goes, in the reference
implementation. The standard fixes the first column only.

| Contract | Created by | Consumed or archived by | Note |
|---|---|---|---|
| `DefinitionProposal` | the operator, directly | `DefinitionProposal_Accept` replaces it per auditor; `DefinitionProposal_Finalize` consumes it | Not an interface; the bootstrap workflow. No cancel choice yet. |
| `DataDefinition` | `DefinitionProposal_Finalize` | nobody; operator and auditors would have to co-sign an archive | Lives as long as the data set. |
| `Verifier` (canonical) | the operator, directly, before the proposal | the operator | Replacing it means a new definition. |
| `Verifier` (consumer's) | the consumer, directly | the consumer | Private; no other party is ever informed of it. |
| `RoundHead` | `DefinitionProposal_Finalize` (first), `RoundHead_CreateRound` (every later one), `RoundHead_Pause` and `RoundHead_Resume` | the same choices consume the predecessor | Exactly one live head per definition. |
| `Round` | `DefinitionProposal_Finalize` (genesis), `RoundHead_CreateRound` | `Round_Archive` by the operator | Must outlive every capsule of its number. |
| `License` (root) | the operator, directly | `License_Revoke` by the licensor or the operator | A new root license may be attached at any round. |
| `License` (sublicense) | `License_CreateSublicense` on the parent | `License_Revoke` | Refers to its licensor by party, so it survives the parent's retirement. |
| `LicenseDelegate` | its signatory, directly; `LicenseDelegate_Subdelegate` for a sublicense | nobody | Only where an extension is in use, such as `caps-accounting`. |
| `Capsule` (root) | `RoundHead_CreateRound` | `CapsuleArchiver_Archive` | Observers: the root license's licensees and the auditors. |
| `Capsule` (distributed) | `License_Distribute` | `CapsuleArchiver_Archive` of its distributor | Observers: the clients. |

`CapsuleArchiver` (package `caps-capsule-archiver`) is one distributor's
archiver for one definition: it carries the distributor's authority and
archives, for any actor that sees it, the distributor's capsules at least
`keptRounds` rounds behind the head's latest round once `keepPeriod` has
passed since their fixing time. `RoundArchiver` (package
`caps-round-archiver`) is the operator's archiver for one definition and
does the same for the operator's rounds, the genesis round aside; with the
same `keptRounds` and `keepPeriod`, a round goes no sooner than the
capsules of its number.

## Visibility

Who is a signatory and who an observer of each contract in the reference
implementation, which is what decides who is informed of what. The
standard fixes the signatory of `Capsule` (the distributor) and the owner
as signatory of `License`; the rest is `caps-core`'s choice. The table
covers `caps-core`; the templates of the extensions are described with
them, in [accounting.md](accounting.md) and [licensing.md](licensing.md).

| Contract | Signatories | Observers |
|---|---|---|
| `DefinitionProposal` | operator, auditors that accepted | auditors |
| `DataDefinition` | operator, auditors | readers |
| `Verifier` (canonical) | operator | readers, as the template's `observers` |
| `RoundHead` | operator, auditors | readers |
| `Round` | operator, auditors | readers |
| `License` | owner | operator, licensor, licensees |
| `Capsule` (root) | operator | root license's licensees, auditors |
| `Capsule` (distributed) | distributor | clients |

What follows for the roles:

- **The operator** signs or observes everything on the publication path and
  every license. It is a stakeholder of no distributed capsule and of no
  consumer's verifier, which is the standard's privacy claim.
- **An auditor** co-signs the definition, the head and every round, so
  the operator cannot archive the definition or the head, fork the chain or
  mint a round alone, and retires a round only through `Round_Archive`;
  observes every root capsule, so it can audit what was published;
  sees no distributed capsule and no license.
- **A reader** sees the definition, the canonical verifier, the head and
  the rounds: everything needed to verify a capsule, nothing of
  distribution.
- **A licensee** of the root license observes the root license and every
  root capsule; it sees the rounds only if it is also a reader, which it
  must be to verify.
- **A client** sees the capsules distributed to it and its co-recipients on
  each, and needs to be a reader to verify.

## Invariants

What the `caps-core` templates enforce with `ensure` or at creation; the
extensions' checks are listed in [accounting.md](accounting.md) and
[licensing.md](licensing.md).

- `Capsule`: `content.dataPoint.distributor == distributor`.
- `RoundHead_CreateRound`: not paused; the actor is admitted; the latest
  round belongs to this definition; the fixing time is strictly after the
  latest round's; the data point's distributor is the operator; the license
  belongs to this definition and is owned by the operator; the canonical
  verifier returns `Verified` and passes freshness at ledger time.
- `License_Distribute`: the license has not expired; the source belongs to
  this definition.
- `License_CreateSublicense`: the license has not expired; the actor is a
  licensee.
- `License_Revoke`: the revoker is the licensor or the operator.
- `DefinitionProposal_Accept`: the acceptor is an auditor that has not yet
  accepted. `DefinitionProposal_Finalize`: every auditor has accepted.
  `DefinitionProposal_Cancel`: the operator, with the acceptors' authority
  from the contract.
- `RoundHead_Pause`, `RoundHead_Resume`: the actor is an auditor.
- `Round_Archive`: the actor is the operator. Nothing on the ledger depends
  on a round's existence, the latest and the genesis round included; what
  stays is the archiver's rule.
- The two shipped verifier templates: a positive signer threshold not
  above the number of signers; the RedStone verifier also a non-empty feed
  list. The test fixture's verifier enforces nothing.
