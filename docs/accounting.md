# Accounting in CAPS

How a CAPS deployment measures and settles the use of a data set, what the
measurement can and cannot promise, and how it can be shaped differently for
other needs. Accounting is an extension: `caps-accounting` implements it as
a `LicenseDelegate` (see [specification.md](specification.md) section
3.7), so it serves any license that names its delegate: at the weight the
license passes in the context, as the extended licenses do, or at 1.0 for
the reference license of `caps-core`, which passes none. It is optional: a
deployment that charges nothing, or charges off the ledger, names no
delegate. The licenses
themselves are described in [licensing.md](licensing.md).

## The parties

| Party | Role in accounting |
|---|---|
| Operator | Publishes rounds and issues the root license with its accounting delegate. Learns who holds licenses; does not learn who consumes or how much downstream licensees distribute. |
| Accountant | A party the operator names on the root license's accounting delegate, separate from the operator. Observes the delegates that name it and every distribution marker, closes periods, bills. One or more per root license; the delegates of sublicenses inherit them. |
| Distributor | Owner of a license: the operator for the root capsule, a licensee for everything below. Signs the capsules it distributes and the markers that record its distributions. |
| Client | Receives capsules. Sees nothing of accounting unless it chooses to show a capsule to an accountant. |

The accountant is a separate party by design. Were the operator its own
accountant, it would learn the number and timing of every licensee's
distributions, which is most of what "the operator does not see consumption"
is meant to keep from it.

## The accounting delegate

`AccountingDelegate` is signed by its `owner` and observed by its
`accountants` and its `licensees`. The latter must be the licensees of
every license that names it, since they sublicense through it; the
delegate fixes the list at creation and nothing ties it to the licenses
afterwards, so a deployment keeps the two in step. It accepts
distribution reports and
sublicenses from its owner only, so a license that names it works only
when the license's owner is the delegate's. It carries the data
definition its markers name, since the license reports none. On a
distribution it creates the marker below. On a sublicense it creates a
delegate for the new owner, with the same accountants and definition and
the sublicense's licensees, so accountants set on the root reach, and
see, every level of the chain.

## The distribution marker

Every distribution reported to an accounting delegate creates, in the same
transaction as the capsule, a `DistributionMarker`:

| Field | Meaning |
|---|---|
| `distributor` | Who distributed; the marker's signatory. |
| `accountants` | Who the marker is reported to; its observers. |
| `definition`, `license` | What was distributed and under which license, the latter by the contract id the license was issued with. |
| `fromRound`, `toRound` | The rounds of the distributed capsules; equal for one distribution. The accountant is no stakeholder of the capsule, so the round in the marker is all it learns of what was distributed. |
| `count` | How many distributions the marker covers; 1 before merging. |
| `weight` | What they are worth under the license's terms; see below. |
| `capsule` | The capsule of a marker of one distribution; `None` once merged. |
| `closed` | `None` while open; the `Closure` once an accountant has settled the marker. |
| `sequence` | `None` while open; the settlement's number from the accountant's head once closed. |

A marker is in one of three states, all of them the same template:

| State | Signatories | `capsule` | `closed` | `sequence` | Purpose |
|---|---|---|---|---|---|
| One distribution | distributor | set | `None` | `None` | the trace of one distribution; the audit's join key |
| Merged, open | distributor | `None` | `None` | `None` | compaction of the active contracts by either side |
| Settled | distributor and the closing accountant | `None` | set | set | a closed period, safe to bill from the active contracts |

What the templates enforce: a marker has a positive `count`, a
non-negative `weight`, `fromRound <= toRound`, `closed` and `sequence`
both set or both `None`, and a closing accountant among its
`accountants`; a merge is exercised by the distributor or an accountant,
on a non-empty list of open markers of the same distributor, definition,
license and accountants; a close by an accountant of the marker, on a head
of that accountant for the same distributor and license, and never on a
closed marker; a head's `nextSequence` is positive; the delegate accepts
reports and subdelegations from its owner only.

### Weight

The weight is the price list applied at the moment of distribution, by the
license's own code, so that the accountant sums weights and never needs the
terms. The license passes it under `weight` in the `AVMap` it gives as the
context of `LicenseDelegate_OnDistribute`. A report with no context at all
is accounted at 1.0, the weight of a license that prices nothing itself; a
context without a decimal `weight` is refused, since a license that tried
to price a distribution and failed must not be billed by default. The
extended licenses use two values, 1.0
for a distribution paid for by use and 0.0 for one covered by a prepaid
license, which is why usage under a prepaid license is recorded without
being charged. The field is a number rather than a flag because a license
can price a distribution however its terms say, for instance:

- by data set: 0.5 for a low-value feed, 2.0 for a premium one, set on the
  license when it is issued;
- by audience: the distributor knows the capsule's observers and the
  accountant does not, so a license can weigh a distribution by the number
  of clients it reaches without naming them;
- by volume: a license that lowers the weight after a number of
  distributions in a period;
- by level: a sublicense that passes on a share of its own price.

Each of these is a license kind of the implementation's; the delegate only
carries the result.

### Sharing a price with the licensors above

A possible extension. The reference marker names its distributor and its
license, not the licenses above, and the accountants see the delegates
but not the licenses, while a delegate names neither its license nor the
one above, so a price shared along the chain cannot be settled from the
markers as they are. A delegate that also carries `upstream`, the
owners of the licenses above its own, nearest first, closes the gap
without a change to the interface: `LicenseDelegate_Subdelegate` receives
the `licensor`, so the delegate it creates takes the parent's `upstream`
with that licensor in front, and every marker it leaves copies the list.
The accountant then splits each weight itself, for instance 80% to the
nearest licensor and 20% kept by the distributor; markers merged under one
license share one list. In exchange the accountants learn who holds the
licenses above every distributor.

Reporting the share to the parent's delegate instead, from the child's
`LicenseDelegate_OnDistribute`, would make the split the ledger's, at the
cost the reference avoids: the parent's owner, as the signatory of its
delegate, would be informed of and confirm every distribution below it, at
every level up the chain, and its delegate would have to accept reports
from its licensees, who could then leave markers in its name at will.

### What the marker guarantees, and what it does not

The marker is created by the delegate `License_Distribute` calls, in the
same transaction as the capsule, so **a distribution made through a license
that names an accounting delegate cannot go unrecorded**. That is the whole
guarantee, and it is worth stating its edges plainly.

- **A license that names no accounting delegate leaves no marker.** Which
  delegate a license names is fixed when it is created, by the parent's
  delegate for a sublicense; a license created directly may name any.
- **A capsule can be created outside any license.** The reference capsule is
  signed by its distributor alone, so the distributor can create one directly
  and no marker will exist. Nothing on the ledger prevents this: the only
  party that could co-sign the capsule and thereby refuse it would see the
  capsule's audience, which is exactly what CAPS keeps private. Markers
  therefore measure cooperating distributors; what deters the others is the
  price list and the audit at the end of this document.
- **An open marker can be archived or minted by the distributor**, who is its
  sole signatory. Both acts are as visible to the accountants as the
  distribution was, because observers receive the archive and create events
  too. An open marker is evidence in the accountants' transaction history
  before it is a contract; accounting tooling reads the event stream, not
  only the active contract set.
- **A settled marker is beyond the distributor.** It carries the accountant's
  signature, so the distributor can neither archive, forge nor merge into it.
  What the active contracts hold under an accountant's signature is safe to
  bill from.
- **Over-reporting is possible and pointless** under a price list that
  charges for use: a distributor minting markers pays more. It becomes
  profitable only under a price list that pays per marker (variant M5),
  which is why that variant is not the default.

### Why the distributor signs alone

An accountant could co-sign every marker through a delegate it signs. It
would make a forged license with another accountant detectable on the
ledger, but it would also make the accountant's participant a confirming
party of every paid distribution, so an accountant's outage or bad will would
stop distribution; and it would not stop the capsule created outside any
license, an attack of the same cost. The protection bought does not justify
the dependency. The co-signed design remains a valid variant for a
deployment that wants it (M1 and M2 below).

## Merging and settlement

A marker per distribution grows with use, and both the distributor and the
accountants pay for every active contract they hold. An open marker is also
only evidence: the distributor can retire it, and nothing marks a period as
done. Two operations address this, kept apart on purpose: merging compacts,
closing settles.

**`DistributionMarker_Merge` compacts.** Either the distributor or any
accountant consumes an open marker and other open markers of the same
distributor, definition, license and accountants, and creates one open marker
with summed weights and counts and the joined round range. The merged
marker names no capsule; which capsules it covers is recorded by the merge
transaction itself, which consumed the markers naming them, so every party
that saw those markers can tell from its history. Merging changes nothing
about what the accountants know, since they observed every marker merged;
it reduces what both sides hold, and later, at settlement, what a payment
reveals to third parties.

**`DistributionMarker_Close` settles.** A period needs a state the
distributor cannot change and a boundary. An accountant consumes an open
marker and other open markers of the period and creates one closed marker,
co-signed by the accountant, with `Closure {accountant, period, closedAt}`.
Nothing merges into a closed marker and a closed marker is not reopened.

**`SettlementHead` numbers settlements.** The accountant keeps, per
distributor and license, a head consumed and re-created on every close, so
two closes on the same head are a double spend and each settlement gets a
number of its own (`sequence`, a field of the reference template). Numbers
are unique only within one head: keeping one active head per accountant,
distributor and license is the accountant's discipline, not a ledger
invariant, and the distributor observes every head and can tell competing
sequences apart. `period` is a label; two settlements may carry the same
one, and the number and the closing time tell them apart.

## Settling with a token transfer

The closed marker is where payment can attach. A deployment can settle a
period by transferring the network token from the distributor to the
accountant in the same transaction that retires the closed marker: payment
becomes the proof, self-reporting of the settlement disappears, and the
token's confirmers are involved once per period rather than once per
distribution. They see one payment, its amount and time, instead of one
transfer per distribution; what the amount reveals depends on the price
list, since under an open license the weight equals the number of paid
distributions. This is a direction, not an implementation: the transfer
instruments of the token standard, the blinding of the amount and the
retirement of settled markers are to be designed when it is built.

## Shaping the model differently

The delegate interface fixes what a license tells its delegate and nothing
else. Who signs a marker, who confirms a distribution, what the operator
learns and what the model protects against are the implementation's, and a
deployment may want them different from the reference. The variants below
are each a complete way of building accounting as a delegate, with licenses
of the deployment's own where a variant needs them; the table at the end
compares them. None requires a change to `caps-api-core-v1`.

### M1: markers co-signed through a factory, provenance by fetch

The accountant signs one delegate, shared along the chain, a factory; a
license creates its marker by exercising it, so the marker carries the
accountant's signature as well as the distributor's. At distribution the
license fetches the license of the source capsule and requires it to name
the same delegate, so a license forged with another one cannot distribute
what the chain's capsules carry.

- Signs: distributor and accountant. Confirms every paid distribution: the
  accountant's participant.
- The operator learns of every first-level distribution, because the source
  capsule's license is the root license and a fetch informs its signatory;
  every licensor learns the same of the level below it.
- Protects against a forged license with another factory. Does not protect
  against a capsule created outside any license.
- Choose it when a structural proof of license provenance matters more
  than the operator's ignorance of distribution timing and than independence
  from the accountant's availability. Requires a delegate signed by the
  accountant, a two-signatory marker and the fetch in `License_Distribute`.

### M2: the accountant co-signs licenses

As M1, but the license itself carries the accountant's signature, obtained
through the factory when the root license is issued and when a sublicense is
created. A forged license has no such signature, so the fetch of the source
capsule's license is not needed and the operator is no informee of
distribution.

- Signs: distributor and accountant on licenses and markers. Confirms every
  paid distribution and every license issued: the accountant's participant.
- The operator learns nothing of distribution.
- Protects against a forged license. Does not protect against a capsule
  created outside any license.
- Choose it when provenance must be provable and an accountant that is a
  confirming party of every distribution is acceptable. Requires a factory
  that issues licenses, and prepaid licenses that replace their contract
  must do so with the accountant's authority from the choice.

### M3: the distributor signs, the accountants observe (reference)

Markers are signed by the distributor alone and observed by the
accountants, set on the root delegate and inherited. A distribution by
view touches no contract of the operator or of a licensor above; by id,
it fetches the source capsule, which informs its distributor.

The accountants observe the delegates that name them, not the licenses:
they learn who distributes from the markers and who holds a delegate from
the delegates, but what a marker's license id stands for, a credit
license's credits and a subscription's expiry come from the operator or
from a disclosed license. Nor do they police provenance, which the operator's
observation of the licenses does not prove either:
`License_CreateSublicense` is non-consuming, and an observer of the parent
is not an informee of a non-consuming choice on it, so the operator
receives the creation of the child license and not the choice that created
it. The party that can tell is the licensor named on it: it signs the
parent, so it is an informee of its own choice, and it observes the child,
so it sees the forged one too.

- Signs: distributor. Confirms: nobody beyond the distributor and the
  clients.
- The operator learns nothing of distribution; the accountants learn that
  and when a distribution occurred, under which license and for which round.
- Protects against omission on the licensed path. Does not prove chain
  provenance: a forged license that names the real operator is visible to
  it, and the licensor it names knows it did not issue it; one that omits
  them is policed by the client's check and the audit (see
  [licensing.md](licensing.md)). Does not prevent a capsule created outside
  any license.
- The default, because the co-signed variants protect only against an attack
  of the same cost as the one nothing prevents, and because no accountant can
  stop distribution.

### M4: prepaid licenses

Consumable, subscription and credit licenses are paid for when issued;
their distributions leave markers of weight 0.0 or, in an implementation
that prefers it, none at all.

- Signs and confirms: as the data model it is combined with; in the
  reference, as M3.
- Protects against nothing it needs to: there is no per-use charge to evade.
  A capsule created outside the license, before or after expiry, still
  evades the license's limits, and its marker can still be omitted, which
  skews usage and the audit.
- Choose it for clients that want no metering or no dependency on an
  accountant, and for data sets with a flat price. Ships with the reference
  alongside M3.

### M5: prepay with a refund per marker

The distributor prepays a period and is refunded per marker, so leaving a
distribution unrecorded costs the distributor, not the operator.

- Signs and confirms: as the data model it is combined with.
- Protects against omission, by making it unprofitable. Invites
  over-reporting instead: a distributor is paid for markers, and a marker
  without a capsule, or with a capsule for a party of the distributor's own,
  cannot be told from a real one without seeing capsules. The refund is safe
  only if it stays below the cost of the distribution's transaction, at which
  point the model is a prepaid plan with a small rebate.
- Choose it only as a pricing policy on top of M3 or M1, with the refund
  bounded as above, and knowing that the measurement is the distributor's
  own statement.

### Comparison

| | Signs a marker | Confirms a distribution | Operator learns of distribution | Prevents | Does not prevent |
|---|---|---|---|---|---|
| M1 factory and fetch | distributor, accountant | accountant's participant | yes, first level; each licensor, the level below | forged license with another factory | capsule outside a license |
| M2 co-signed licenses | distributor, accountant | accountant's participant, also at license issue | no | forged license | capsule outside a license |
| M3 reference | distributor | nobody new | no | omission on the licensed path | forged license (policed); capsule outside a license |
| M4 prepaid | as combined | as combined | no | nothing it needs to | capsule outside a license; omitted usage records |
| M5 refund per marker | as combined | as combined | as combined | omission | over-reporting |

## The audit: a capsule obtained as a client

Accountants cannot see clients, so they cannot ask them. What they can do is
become one. An accountant controls a party that buys data from a distributor
like any client; the distributor cannot tell it from the others. For every
capsule X that party receives:

1. The accountant looks for an open marker with `capsule = Some X` in its
   active contracts, or, after a merge, for the marker that named X in the
   history of the merge transaction, which it has as an observer.
2. A marker exists: the distribution was recorded. None exists: the
   distribution bypassed the license. The capsule is signed by the
   distributor, so it cannot be denied, and the absence of a marker is in
   the accountant's own history.
3. Off the ledger, the breach is a matter for the contract. On the ledger,
   the operator revokes the license, after which the distributor can no
   longer distribute through it.

A client may also volunteer: explicit disclosure of its capsule to an
accountant creates no ledger event and informs no third party. It does hand
the accountant the whole contract, observers included, so the accountant
learns who else received that capsule; the same holds for a capsule the
audit party receives, since observers of one capsule see each other. A
distributor that wants its clients unknown to one another issues one capsule
per client. The audit checks a sample, so it turns the undetectable bypass
into a probability rather than a certainty; that is the best any measurement
can do without revealing clients.

Two conventions make the audit and the client's own checks work:

- The operator publishes the accountants of each data set through a channel
  of its own, off the ledger, so that a client knows whom a capsule may be
  shown to and can tell an official accountant from one a forged license
  names.
- A distributor discloses its license and delegate contracts to its
  clients, so that a client can check the license's template, owner,
  definition and delegate, the delegate's accountants, and that the
  operator observes the license; see [licensing.md](licensing.md) for what
  the interface alone does and does not show.
