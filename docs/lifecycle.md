# Lifecycle and retention

How each contract of a CAPS deployment is created, replaced and retired,
and what has to be kept for how long. The interfaces fix where a round and
a capsule may come from and nothing about retirement; this document
describes the reference implementation, the retention a deployment has to
decide on, and the gaps still open. [data-model.md](data-model.md) has the
summary table; [governance.md](governance.md) covers who may pause and
replace the parties on the publication path.

## The data set

**Bootstrap.** The operator creates the canonical verifier, then a
`DefinitionProposal` naming the data id, the auditors, the readers, the
verifier and the admitted publishers. Each auditor exercises
`DefinitionProposal_Accept`; the operator exercises
`DefinitionProposal_Finalize` once every auditor has, which creates in one
transaction the `DataDefinition`, the genesis round (number 0, the
bootstrap time, an empty commitment, no capsule) and the first `RoundHead`
pointing at it. No partial bootstrap can exist.

**Replacement.** A definition's view is constant for its life. Changing
the verifier, the data id, the auditors or the readers is a new
definition with a new bootstrap, a new chain starting at round 0, and a
new root license; consumers pin the new contract id. The old definition
stays until the operator and the auditors archive it together, and its
rounds and capsules follow the retention below.

**Cancelling.** The operator cannot archive a proposal alone once an
auditor has accepted, since the acceptors are signatories.
`DefinitionProposal_Cancel`, the operator's, takes their authority from
the contract and retires the proposal. An acceptance itself is not taken
back: an auditor that changes its mind asks the operator to cancel.

## The round chain

**Publication.** Every `RoundHead_CreateRound` consumes the head and
creates the round, the successor head and the root capsule. The live head
is the only one; a publisher that loses the race gets a failed submission
and nothing is created, re-reads the head and resubmits. `RoundHead_Pause`
and `RoundHead_Resume` consume and re-create the head as well, so a
publisher racing a pause fails and retries against the new head.

**Rounds are never replaced.** A round is referenced by number, not by
contract id, by every capsule of that number; a consumer verifies a capsule
against the round of its number read from its own participant. A round
therefore has to exist for as long as any capsule of its number may be
verified.

**Round archival.** Each round is a small contract on the participants of
the operator, the auditors and the readers; at one round a minute that is
half a million per definition per year, held by every reader. A round is
co-signed by the auditors, so nobody archives one directly: `Round_Archive`
carries their authority from the round and admits the operator alone.
When no capsule may point at a round any more is an archiver's rule, as for
capsules; `caps-round-archiver` applies the capsule archiver's, never takes
the head's latest round and always keeps the genesis round. Neither is a
need of the ledger: the head carries the latest round's number and fixing
time, so publication fetches no round and retiring the latest one, or the
genesis round, stops nothing. The operator's
automation finds rounds by number through the Ledger API, since the
operator sees them all; nothing on the ledger has to link a capsule to its
round's contract id. A consumer must be told that canonicality is
verifiable within the retention window only.

**Possible extension: round compaction.** A deployment that wants the
hashes and fixing times of older rounds kept on the ledger without a
contract per round can fold them into a tree instead of dropping them; see
[round-compaction.md](round-compaction.md).

## Verifiers

**The canonical instance** is created by the operator before the proposal
and named by the definition. Its parameters are template fields; changing
any of them is a new instance and, because the definition names the
instance, a new definition. A verifier template that must evolve (new
keys, a new quorum) therefore plans for it: key rotation that does not
change the verdicts for existing capsules can be a new instance under a new
definition with the old one kept for its retention window, or a template
whose parameters are a reference the consumer resolves, which the standard
leaves to the implementation.

**A consumer's instance** is the consumer's own: created from the same
template with the same fields, visible to nobody else, kept as long as
the consumer verifies capsules of that definition, archived by the
consumer. Its contract id appears in no other contract.

## Licenses

**Issuance.** The root license is created directly by the operator and
attached to a round through `content.license`; a different root license
may be attached each round. Every sublicense is created through
`License_CreateSublicense` on its parent, by the party that will own it.

**Licensees are fixed.** A license's `licensees` do not change for its
life. To admit or remove a licensee, the owner creates a new license and
retires the old one. Sublicenses name their licensor by party, not by
contract id, so they survive the parent's retirement; capsules name the
license as of their distribution, so an older capsule may point at a
retired license, which is expected and which a consumer treats as the
license in force at that time.

**Revocation.** `License_Revoke` by the licensor or the operator archives
the license; later distributions under it fail. Capsules already
distributed are unaffected: revocation stops future distribution, it does
not recall data. A sublicense of a revoked license remains valid, since it
refers to its licensor by party; the licensor revokes it separately if the
terms say so.

**Expiry.** The reference license carries an optional `validUntil`,
inherited by sublicenses and checked at every distribution and
sublicensing. An expired license is refused, not archived: it stays active
until revoked. A deployment that minds the contract count revokes expired
licenses as part of its operations; a choice that lets anyone archive an
expired license is a possible addition.

**Prepaid licenses**, where `caps-extended-licensing` is in use: an
`OpenLicense` expires as the reference license does and passes its
`validUntil` to its open sublicenses only; a `SubscriptionLicense` expires
at the `validUntil` of its own terms; consumable and credit licenses carry
no expiry. A `ConsumableLicense` is archived by its one distribution; a `CreditLicense` is replaced on every
distribution by a contract with one credit fewer, keeping the id it was
issued with in `origin`, and archived by its last; a `SubscriptionLicense`
lives until revoked.

**Delegates.** Archiving a license leaves its delegate in place, since a
delegate may serve several licenses. Its signatories archive it once no
live license names it, and not before: a license whose delegate is gone
can neither distribute nor sublicense. To change a license's delegate, the
owner creates a new license naming the new one and retires the old.

## Capsules

**Creation.** A root capsule is created by `RoundHead_CreateRound` with
the root license's licensees and the auditors as observers; every other
capsule by `License_Distribute` with its `clients`. A capsule is never
modified.

**Retention.** The standard does not archive capsules, and a consumer that
has read one may still be using it. The reference retention is the one a
RedStone price pill follows: keep the capsules of the newest `keptRounds`
rounds regardless of age, and past them each capsule until `keepPeriod`
after its fixing time. `CapsuleArchiver` (package `caps-capsule-archiver`)
implements it for one distributor and one definition: it carries the
distributor's authority, and `CapsuleArchiver_Archive` archives, for any
actor that sees the archiver, the head and the capsules, those of the
given capsules that are stale by the rule, failing on a capsule or a head
of another definition. A capsule of another distributor fails the archive
for want of that distributor's authority, so each distributor runs its own
archiver and the operator cannot retire a licensee's capsules.

**Who runs it.** The distributor's automation, on a schedule, with the
capsules it holds; or any party the distributor discloses the archiver to,
since the choice is open to any actor. The test suite shows a licensee
archiving the operator's root capsules with the operator's archiver
disclosed.

**What a consumer may rely on.** A capsule is readable until its
distributor archives it; the content a consumer has already read remains
valid data, and its round remains verifiable within the round retention
window. A consumer that needs a capsule beyond the distributor's retention
keeps the view.

## Accounting contracts

Where accounting is in use ([accounting.md](accounting.md)):

- an **accounting delegate** is created directly by its owner, or by a
  parent's delegate when a sublicense is created, and archived by its owner
  once no live license names it;
- an **open marker** is created with its capsule, in the same transaction,
  and lives until merged or closed; the distributor can archive one, which
  the accountants see;
- a **merged marker** replaces the open markers it consumed and is itself
  open;
- a **settled marker** carries the accountant's signature and is the record
  to bill from. Nothing archives it yet: its retirement is to be designed
  with token settlement, where the payment that retires it becomes the
  proof;
- a **settlement head** is consumed and re-created on every close; one
  live contract per accountant, distributor and license is the
  accountant's discipline, not a ledger invariant.

## A publisher's state

The relayer that publishes rounds has to know the current head, and the
distributor that archives has to know its capsules and, once rounds are
archived, the rounds. Both are available from the Ledger API, since the
operator is a stakeholder of all three, and the reference implementation
keeps no on-ledger state for them. A deployment may add a publisher
contract of the operator's that holds the current head, the live capsules
and the live rounds, consumed and re-created on every publication, and
whose publish choice creates the round and archives what has become stale
in one transaction. Such a contract is an operator's convenience, not part
of the standard: it is not an interface, and a vendor's integration layer
may key it, time it or reward from it as it likes. The RedStone relayer's
integration on the monorepo side is built this way.

## Retention summary

| Contract | Kept until | Decided by |
|---|---|---|
| `DataDefinition` | the data set is retired, and its last capsule's retention has passed | operator and auditors |
| canonical `Verifier` | as the definition that names it | operator, its sole signatory |
| `RoundHead` | replaced on every round, pause and resume; never kept | the ledger |
| `Round` | as long as a capsule of its number may be verified; the genesis round always | operator, through its archiver |
| `Capsule` | as the round, per distributor | each distributor, through its archiver |
| `License` | revoked by the licensor or the operator; an expired one lingers until then | licensor, operator |
| `LicenseDelegate` | no live license names it | its signatories |
| consumer's `Verifier` | the consumer stops verifying this definition | the consumer |
| `DefinitionProposal` | finalized, or cancelled by the operator | operator |

Where accounting is in use, its contracts add:

| Contract | Kept until | Decided by |
|---|---|---|
| open `DistributionMarker` | merged or closed | distributor, accountant |
| settled `DistributionMarker` | to be designed with token settlement | accountant |
| `SettlementHead` | replaced on every close | the ledger |
