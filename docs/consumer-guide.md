# Consumer guide

How an application that receives CAPS capsules verifies them and uses
them, step by step, with the Daml Script fragments the test suite uses
for the same purpose. [specification.md](specification.md) section 5 is
the normative list of checks; this document is the walk-through.

A consumer is a party that is a client of some distributor (it appears in
the `clients` of a `License_Distribute`, or in the root license's
`licensees` for root capsules) and that reads the data set's rounds: as
the deployment's readers party from one of its read nodes, or from its own
participant where the deployment names it a reader
([lifecycle.md](lifecycle.md)). Without the first it receives nothing;
without the second it verifies only through a round's attestation.

## Onboarding, once per data set

1. **Pin the definition.** Obtain the `DataDefinition` contract id from the
   operator and read its view where you read the rounds: from a read node,
   as the readers party, or from your own participant where you are named
   a reader. Keep the contract id:
   every capsule and round you accept must carry it. The `dataId` is a
   label for humans.

2. **Read the canonical verifier.** The definition's `verifier` is a
   contract the operator makes visible to readers through the template's
   `observers`, next to the publishers it names there (they need it to
   publish, you need it to copy). Read its template id and its fields; the
   template tells you which verifier package to trust, the fields are the
   parameters (node keys, quorum, feeds, schema version, freshness
   window).

3. **Create your own verifier instance** from the same template with the
   same fields and yourself as the signatory. From now on every
   verification exercises this instance, never the canonical one, so that
   nobody is informed of your verifications.

   ```haskell
   ownVerifierCid <- submit client $ createCmd RedStoneVerifier with
     owner = client, observers = []
     signers = canonical.signers
     signerCountThreshold = canonical.signerCountThreshold
     feedIds = canonical.feedIds
     schemaVersion = canonical.schemaVersion
     attestationKeys = canonical.attestationKeys
     maxBehind = canonical.maxBehind, maxAhead = canonical.maxAhead
   let ownVerifier = toInterfaceContractId @Api.Verifier ownVerifierCid
   ```

   If the operator publishes a new definition (a changed verifier is one),
   repeat from step 1; the old instance stays valid for the old
   definition's capsules.

## Receiving a capsule

A capsule reaches you as a `CreatedEvent` of a contract implementing
`Caps.Api.CoreV1.Capsule` with you among its observers. Read its interface
view; you need nothing from the template beyond that.

```haskell
Some capsuleView <- queryInterfaceContractId client capsule
```

A capsule also implements the Data Standard's `PublishedDataPoint`, so a
consumer written against that standard reads `capsuleView.content.dataPoint`
the way it reads any data point. What follows is what CAPS adds.

## The five checks

Run the first three inside one transaction if you use the data in a transaction
with other parties: every informee's participant re-executes them. Authenticity
and freshness carry over as they are; canonicality, inside the transaction, as
the key holder's word, through the round's attestation, since the round view is
an argument you supply, unless the transaction takes the round from the ledger
through `Round_Fetch`. Outside it, a counterparty that reads the round compares
your view with it before it consents; one that consented in advance relies on
the attestation (see check 2).

### 1. Authenticity

```haskell
verified <- submit client $ exerciseCmd ownVerifier Api.Verifier_Verify with
  actor = client, capsule = capsuleView
-- verified : Api.VerificationResult
```

Accept on `Verified dataHash`. On `Rejected reasons` the capsule's content
is not what the oracle's nodes signed, or does not aggregate to what the
data point claims; log the reasons, do not use the data. The transaction
itself succeeds either way; assert on the result if you need it to fail.

### 2. Canonicality

Read the round of the capsule's number for the capsule's definition: from
one of the deployment's read nodes, as its readers party, and from a
second one if you do not take the first's word that no round is missing;
or from your own participant where the deployment names you a reader.
Either way this is a query, not a transaction, and you pass the view. If
a transaction of yours must rest on the ledger's own round, exercise
`Round_Fetch` on it instead, naming the parties that sign the feed's
rounds, in the reference implementation those of the definition you
pinned, and with the round attached as a disclosed contract where you are
not named a reader; what that reveals is under "What your activity
reveals" below.

```haskell
-- `reader` is the party the rounds are read as: the readers party, on a
-- read node, or yourself where you are named a reader.
rounds <- queryInterface @Api.Round reader
let [(_, Some roundView)] =
      [ entry | entry@(_, Some r) <- rounds
              , r.definition == capsuleView.definition
              , r.roundNumber == capsuleView.roundNumber ]
canonical <- submit client $ exerciseCmd ownVerifier Api.Verifier_VerifyRound with
  actor = client, capsule = capsuleView, round = roundView
-- canonical : Api.CheckResult
```

Accept on `Passed`. `Failed` means the capsule's content is not what was
fixed in that round: a capsule claiming a round it does not belong to, or
content that differs from the round's commitment. If you find no round of
that number, the capsule is unverifiable: either you are not a reader, or
the round has been retired under the operator's retention
([lifecycle.md](lifecycle.md)), or the capsule was never published.

If you find two rounds of one number for one definition, stop: under the
reference governance that takes the operator and every auditor acting
together, since the head mutex prevents two extensions of the chain and
every round is co-signed by the auditors ([governance.md](governance.md)).
Report it to the operator and the auditors and accept neither until they
resolve it.

If you cannot read the round, because you are not a reader or because the check
runs inside a choice another party exercises, take the round view the presenter
hands over next to the capsule and run the same check on it. `Passed` then
means that a key the verifier names signed that content for that round number;
`Failed ["round carries no attestation"]` or
`["round attestation matches no key"]` means nobody did, and the view is the
presenter's own. The feed's verifier names the keys, or none; a feed without
attestation keys is verifiable only against the round itself, read or taken
through `Round_Fetch`. A consumer that receives
capsules outside the ledger, or verifies without a participant, runs the
same checks on the same pair of views; [off-ledger.md](off-ledger.md)
describes them and the encodings.

The round binds what your verifier's commitment covers, and the
authenticity check binds the rest of the data point to the signed data,
except `metadata`, which is the distributor's annotation and nobody's
proof. Canonicality without authenticity proves nothing about the fields
the commitment leaves out; [data-model.md](data-model.md) lists them for
each shipped verifier.

### 3. Freshness

```haskell
now <- getTime
fresh <- submit client $ exerciseCmd ownVerifier Api.Verifier_VerifyFreshness with
  actor = client, capsule = capsuleView, asOf = now
```

`asOf` is the time you care about: ledger time for a settlement happening
now, the valuation time for a report. The verifier applies the oracle's
window, the one that admitted the round at publication. If your need is
stricter, compare `capsuleView.content.dataPoint.publishedAt` with your own
bound instead of, or in addition to, this check.

### 4. License

First, `capsuleView.definition` must be the definition you pinned; a
capsule of another definition is not yours to verify, whatever its
content. Then the license: `capsuleView.content.license` is the license
the capsule was distributed under, as of its distribution. You are not a
stakeholder of it, so you cannot fetch it; a fetch would also inform its
owner. What you can do:

- compare `capsuleView.content.dataPoint.distributor` with the party you
  contracted with as your distributor;
- ask the distributor to disclose the license contract to you. Disclosure
  creates no ledger event. From the disclosed contract check that its
  template is one you trust, that its `owner` is the capsule's distributor,
  that its `definition` is the one you pinned, and whatever else the
  template lets you check ([licensing.md](licensing.md)). An older capsule
  may name a license since retired; that is the license that was in force.

The standard does not prove a license's provenance to you; it is policed
by the operator and the licensor. If your distributor is the operator, the
check reduces to the first bullet.

### 5. Chain

The round you verified against SHOULD be signed by the parties that sign
the definition. The participant you read the round from shows the
signatories of every contract in its `CreatedEvent`; compare the round's
with the definition's. Under the reference governance both are the operator and
the auditors, and the auditors' authority over a round exists only inside
`RoundHead_CreateRound`, so a round with those signatories came from the
chain: the operator cannot mint one alone. No view carries signatories,
so this check lives in your application, not in a verifier.

## Which round a transaction settles on

The five checks tell you that a capsule is the content of its round and
that the round is fresh. They do not tell a counterparty that it is the
round you agreed on: every round of the freshness window passes, and a
party that settles alone on a round of its choosing picks the one that
suits it. A contract that lets one party settle SHOULD therefore name the
fixing and hold the round's view to it
([specification.md](specification.md), section 5).

| Rule | The contract checks | Needs |
|---|---|---|
| A round number | `round.roundNumber` is the agreed number | the number known when the parties agree, which holds for a round already published or the next one |
| A fixing time | `round.timestamp` is exactly the agreed time | an operator that publishes at known times; a fixing it misses settles nothing, so agree what happens then |
| The first round at or after a time | the round is fixed at or after the time, the round before it is fixed before, and their numbers are consecutive | the round before as well, verified like the round itself |

The round before is shown in one of two ways: by its own capsule and
view, checked as the round's are, or by `Round_Fetch` on both rounds,
which informs their signatories. Its attested view alone is not enough,
since an attestation does not cover a round's time. The genesis round has
no capsule and no attestation, so where the round before is round 0 only
`Round_Fetch` shows it.

"The latest round" cannot be a rule a contract holds a round to. A reader
sees for itself that no later round exists, but a transaction cannot show
a counterparty that a contract does not exist; the head, which names the
latest round, is not a consumer's to read. A narrow freshness window is
the nearest thing, below.

The freshness window is the verifier's, and how it is set is each
verifier's own: `maxBehind` and `maxAhead` in the shipped ones, in the
instance the parties pin. Whatever the verifier, a contract may hold
`publishedAt` to a narrower bound of its own. A narrower window leaves
fewer rounds to choose from, and for a settlement at the price current
when it is triggered it may be the whole rule. It narrows the choice and
does not make it: the settling party still picks the moment, a window
shorter than the publication interval leaves moments with no fresh round,
and ledger time is the submitter's to set within the synchronizer's
tolerance.

An example is the `Settlement` contract of the test fixtures
([`Settlement.daml`](../tests-fixtures/daml/Caps/Test/Fixtures/Settlement.daml)),
which carries a `FixingRule` of each kind; the tests show it refusing a
fresh round that is not the agreed one.

## Using the data

After the checks, `capsuleView.content.dataPoint.values` is the data,
keyed by field name as the `schemaVersion` describes. For a RedStone price
feed the values are the feed ids with their medians; for a Data Standard
envelope, the signed content.

Keep the view if you need the data beyond the distributor's retention.
Capsules are archived by their distributor by rounds and age; the data you
have read remains valid, and its round remains verifiable within the
round retention window.

## What your activity reveals

Nothing on the path above touches a contract the operator or your
distributor signs, so neither learns which capsules you verified or when.
Four things do reveal something, and are your choice:

- exercising the canonical verifier instead of your own informs the
  operator;
- fetching the capsule or the license inside a transaction, or exercising
  `Round_Fetch`, informs the contract's signatories, and they confirm it;
- reading from a read node shows that node what you read and when, unless
  its operator serves the rounds without authentication;
- being a client of a capsule shows you its co-recipients, and them you.

## Several verifiers, several definitions

A data set is one definition with one verifier. A consumer of several data
sets, or of one data set from two oracles, holds one instance per
definition and routes each capsule by its `definition` field. Nothing
prevents two definitions from sharing a `dataId`; only the contract id is
the identity.
