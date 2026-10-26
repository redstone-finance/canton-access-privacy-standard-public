# Threat model

What CAPS proves, what it merely polices, and the trade-offs a deployment
chooses between: the data path's guarantees, the verifiers, and, for a
deployment that uses it, the accounting extension. The governance of
rounds (operator and auditors) and its variants are in
[governance.md](governance.md).

## Proven, policed, out of reach

CAPS gives a consumer two proofs it computes itself, on its own participant,
with no informee but itself: **authenticity** (`Verifier_Verify`, the
content is what the oracle's nodes signed) and **canonicality**
(`Verifier_VerifyRound`, the round it read is the one the content belongs
to). Everything else is one of two weaker things:

- **Policed**: made visible to a party that can react. License provenance is
  policed: the operator observes every license that names it, the licensor
  named on a license knows whether it issued it, and the licensor or the
  operator may revoke. A license created outside the chain is caught in one
  of two ways: if it names the operator as an observer, the operator sees
  it the moment it exists; if it does not, only a client who is shown the
  license contract and compares its template and fields with the
  configuration the operator published can tell, which the standard's
  `LicenseView` alone does not allow. Where the accounting extension is in
  use, distribution is policed too: distributions through a license that
  names an accounting delegate are recorded, and the accountant audits the
  rest on a sample.
- **Out of reach**: what no design on this ledger can prevent without giving
  up a stated goal. The entries below.

## What the standard does not promise

**Capsules can be created directly.** A capsule template signed by its
distributor alone can always be created without any license choice: a
distributor can fabricate a capsule, redistribute without a license, or,
where accounting is in use, distribute without leaving a marker. The
consumer's `Verifier_Verify` is what
rejects fabricated content; nothing rejects a genuine capsule that skipped the
license. The only structural remedy, a co-signatory of the capsule, would see
the capsule's audience, so the standard forgoes it. Accounting, where in
use, measures cooperating distributors; the price list and the audit deter
the others.

**Nothing on the consumption path touches a contract of the operator**, but
the operator does learn who publishes rounds and, in the reference
implementation, who holds licenses.

**On-ledger metering cannot be made bypass-proof without revealing clients.**
Every variant that would catch the direct creation of a capsule requires a
party other than the distributor to sign the capsule, and a signatory sees
the contract. This is a property of the visibility model, not of a
particular design.

## Verifiers

Both proofs rest on the verifier, so what the verifier assumes is what the
consumer assumes.

- **The verifier's parameters are the trust anchor, and the consumer pins
  them.** A consumer copies the node keys, the quorum and the window from
  the canonical instance at onboarding and verifies against its own copy
  from then on. A later change to the canonical instance is a new
  definition, which the consumer adopts deliberately; nothing changes under
  a consumer's feet. The flip side: an operator that publishes a definition
  whose verifier names the wrong keys, or a quorum of one, has published a
  feed that proves nothing. The consumer checks the parameters once,
  against the oracle's published keys, exactly as it would for any signed
  feed.
- **The verifier's template is trusted code.** A template that returned
  `Verified` for anything would pass every check, so the consumer trusts
  the package the definition's verifier is an instance of, by its package
  id, as it trusts any Daml package it vets. The shipped verifiers
  delegate signature checks to libraries that are themselves published and
  tested (the RedStone Daml SDK, the Data Standard codecs).
- **Authenticity is m-of-n honesty.** A verifier proves that at least the
  quorum of the configured nodes signed the data. It does not prove that
  the data is right: colluding nodes above the quorum, or a compromised
  majority of keys, produce an authentic lie. That is the oracle's risk,
  not the ledger's, and it is why the quorum is a parameter the consumer
  sees.
- **A round binds a payload to one fixing time, so a payload cannot be
  replayed as a later round.** The head refuses a fixing time not strictly
  after the previous round's, and the RedStone verifier requires the
  signed packages to carry exactly the fixing time, so a payload signed
  once can be the content of at most one round. A capsule can be
  redistributed any number of times; every copy verifies against the same
  round, which is the design.
- **Freshness is a window, not a timestamp check.** `maxBehind` and
  `maxAhead` are the oracle's tolerance around a reference time; a fixing
  anywhere inside passes. A consumer that needs a tighter bound applies
  its own to `publishedAt`, and a consumer that needs the fixing time
  itself reads it from the data point, which the signatures cover.
- **The commitment is only as strong as its function.** The round's
  `dataHash` ties content to a round through whatever the verifier
  computes: keccak256 of the signed payload for RedStone, the Data
  Standard's structural hash for its envelope. A verifier whose commitment
  ignored part of the content would let that part vary between capsules
  of one round; the specification requires the commitment to cover
  everything `License_Distribute` copies, and the shipped verifiers hash
  the signed bytes or the signed envelope in full.
- **Verification costs the consumer, nobody else.** Every check runs on
  the consumer's participant; a large payload or an expensive signature
  scheme is the consumer's compute, and in a settlement it is re-executed
  by every informee's participant. The standard puts no bound on payload
  size; an oracle that wants to be cheap to verify keeps its payload to
  what the proof needs.
- **A verifier sees data, never contracts.** It cannot tell who signed the
  capsule or the round, which is what keeps verification free of
  informees; the chain check (specification section 5, check 5) is the
  consumer application's for that reason.

## Accounting

What follows applies to a deployment that uses the accounting extension.

- **An open marker is evidence in history, not an invariant of the active
  contracts.** The distributor, its sole signatory, can archive or mint one;
  the accountants, as observers, receive both events. Tooling must read the
  event stream.
- **A settled marker is safe to bill from.** It carries the accountant's
  signature; the distributor can neither archive, forge nor merge into it.
- **One settlement head per accountant, distributor and license is the
  accountant's discipline.** The ledger makes numbers unique within a head,
  not across heads; the distributor observes every head and can tell
  competing sequences apart.
- **A forged license is caught in one of two ways.** One that names the
  real operator as its observer is visible to it the moment it exists. The
  operator cannot tell from the event whether a parent's choice created it,
  since `License_CreateSublicense` is non-consuming and informs only the
  parent's signatory and the actor; the licensor it names can, as signatory
  of the parent and observer of the child, and the licensor or the operator
  revokes. The accountants observe the delegates but not the licenses,
  so they see a forged license only through the markers it leaves, and
  one that names no accounting delegate leaves none. In the default
  model a forged license the operator does not observe is caught only by
  a client comparing the disclosed contract with the published
  configuration, or by the audit. The co-signed variants detect it on
  the ledger at the cost of making the accountant a confirming party of
  every paid distribution.
- **A license chooses its delegate when it is created.** A sublicense
  names the delegate its parent's delegate returns; a license created
  directly may name any delegate, or none, and so record nothing.
- **The accountant must be a party other than the operator**, or the
  operator learns every licensee's distribution counts and times. Hosting
  both on one participant keeps the ledger-level separation but not the
  organizational one.
- **An audit party is a client like any other**; its existence is the only
  pressure on a distributor that distributes outside its license.

## Operational assumptions

The entries below concern accountants, so they apply where accounting is in
use.

- **Accountants keep and index the full event stream**, not only the active
  contracts: open markers can be archived by the distributor, merges and
  closes consume them, and the absence of a marker is an observation in the
  accountant's own history.
- **`closedAt` does not order settlements strictly**; two closes can share a
  ledger time. The reference implementation orders them by the head's
  `sequence`, which is not part of the interface.
- **Several accountants are peers.** In the reference implementation any
  accountant may close any open marker it sees. A deployment with more than
  one accountant agrees off the ledger which one closes; the others observe
  for redundancy. Independent closes by different accountants produce
  separate settlements over disjoint markers.
- **A compromised accountant key** can merge compatible visible open
  markers, close any visible open marker and co-sign settlements in the
  accountant's name. It cannot mint an open marker for the distributor or
  archive one without replacement. The accountant role alone grants no
  access to capsule contents or audiences.
- **A missing marker is not a portable proof.** The ledger offers no proof
  of absence; what an accountant can show a third party is the capsule,
  signed by the distributor, and its own transaction history. Settling a
  dispute requires the counterparty's history or an arbiter with access to
  one of the participants.

## Liveness

- A distribution needs no participant other than the distributor's. Where
  accounting is in use, a settlement needs the closing accountant's as well,
  and no accountant can stop distribution.
- Publication needs the participants of every signatory of the round head.
  Which parties those are, and what each choice costs in availability, is
  the subject of [governance.md](governance.md).
