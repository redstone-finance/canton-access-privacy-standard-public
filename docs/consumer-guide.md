# Consumer guide

How an application that receives CAPS capsules verifies them and uses
them, step by step, with the Daml Script fragments the test suite uses
for the same purpose. [specification.md](specification.md) section 5 is
the normative list of checks; this document is the walk-through.

A consumer is a party that is a client of some distributor (it appears in
the `clients` of a `License_Distribute`, or in the root license's
`licensees` for root capsules) and a reader of the data set (it observes
the rounds). Without the first it receives nothing; without the second it
cannot verify what it receives.

## Onboarding, once per data set

1. **Pin the definition.** Obtain the `DataDefinition` contract id from the
   operator and read its view from your participant. Keep the contract id:
   every capsule and round you accept must carry it. The `dataId` is a
   label for humans.

2. **Read the canonical verifier.** The definition's `verifier` is a
   contract the operator makes visible to readers through the template's
   `observers` (the head requires it, or nobody could publish). Read its
   template id and its fields; the
   template tells you which verifier package to trust, the fields are the
   parameters (node keys, quorum, feeds, freshness window).

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

Run the first three inside one transaction if you use the data in a
transaction with other parties: every informee's participant re-executes
them, so your counterparties need not trust your reading.

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

Read the round of the capsule's number for the capsule's definition from
your own participant. You observe it as a reader; this is a query, not a
transaction.

```haskell
rounds <- queryInterface @Api.Round client
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
the definition. Your participant shows you the signatories of every
contract you observe in its `CreatedEvent`; compare the round's with the
definition's. Under the reference governance both are the operator and
the auditors, and the auditors' authority over a round exists only inside
`RoundHead_CreateRound`, so a round with those signatories came from the
chain: the operator cannot mint one alone. No view carries signatories,
so this check lives in your application, not in a verifier.

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
Three things do reveal something, and are your choice:

- exercising the canonical verifier instead of your own informs the
  operator;
- fetching the capsule or the license inside a transaction informs its
  signatory;
- being a client of a capsule shows you its co-recipients, and them you.

## Several verifiers, several definitions

A data set is one definition with one verifier. A consumer of several data
sets, or of one data set from two oracles, holds one instance per
definition and routes each capsule by its `definition` field. Nothing
prevents two definitions from sharing a `dataId`; only the contract id is
the identity.
