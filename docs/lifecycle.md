# Lifecycle and retention

How each contract of a CAPS deployment is created, replaced and retired,
and what has to be kept for how long. The interfaces fix where a round and
a capsule may come from and nothing about retirement; this document
describes the reference implementation and the retention a deployment has
to decide on. [data-model.md](data-model.md) has the
summary table; [governance.md](governance.md) covers who may pause and
replace the parties on the publication path.

## The data set

**Bootstrap.** The operator creates the canonical verifier, then a
`DefinitionProposal` naming the data id, the auditors, the readers, the
head's observers, the verifier and the admitted publishers. Each auditor
exercises `DefinitionProposal_Accept`; the operator exercises
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

## The readers

**One party, hosted on read nodes.** The readers of a definition are named
at bootstrap and observe the definition, the canonical verifier and every
round, and every stakeholder of a contract sees its full observer list, so
a definition that named each consumer as a reader would show every
consumer to every other. The reference deployment therefore names one
readers party: a public party, as Daml applications call a party that
holds what every user may read, that is
[multi-hosted](https://docs.canton.network/appdev/deep-dives/multi-hosting)
on
[observing participant nodes](https://docs.canton.network/overview/reference/external-party).
It is a party in the operator's namespace with no role but observing,
hosted with observation permission on one or more read nodes,
participants run by the operator or by parties it designates, none of
them a consumer's. The hosting of a party is a topology transaction, and
those are
[broadcast to every member of the synchronizer](https://docs.canton.network/overview/reference/topology),
which is why a consumer's own participant must not host it. A node with
observation permission receives the party's transactions and can neither
submit nor confirm for it, and a party hosted with that permission alone
is purely observing, so a read node that is down delays no publication
and no settlement.

**Fixed for the definition, open to consumers.** A definition's view is
constant for its life, so its readers cannot change. With a readers party
that fixes one party and nothing else: admitting a consumer is giving it
read access to a read node, removing one is taking that away, and neither
touches the ledger.

**Reading.** A consumer reads the rounds as the readers party, through a
user of a read node with read rights on it or, since a round carries no
price, through a service the read node's operator puts in front of it
without authentication; the Ledger API itself is per user. A round a read
node makes up fails the attestation where the feed attests its rounds, and
where it does not only a second read node tells; a read node can also
withhold a round or lag. A consumer that does not trust a single one reads
from several and compares, as Canton recommends for any party reading
through nodes it does not run, and treats a disagreement as a withheld
round. The consumer passes the round's view to its verifier, which is all
verification takes.
A transaction that must rest on the ledger's own round exercises
`Round_Fetch` on the round, attached as a
[disclosed contract](https://docs.canton.network/appdev/deep-dives/explicit-contract-disclosure)
built from the created event and its blob as the read node returns them;
a plain fetch would fail, since it needs a stakeholder among its
authorizers and disclosure gives sight of a contract, not that authority.

**How many read nodes.** Each read node holds every round under retention
and receives every publication, one small contract per round, so the
traffic a node adds is small next to the reads, which grow with the
consumers and not with the nodes. The number is a choice between the
independence a consumer can check against and the nodes somebody has to
run. Changing the read nodes is a topology change signed by the party's
namespace owner and by the node that joins, not a new definition; changing
the readers party is. A node that joins receives the rounds published from
then on; the earlier ones reach it only through Canton's party
replication, an export and import of the party's active contracts.

**Where the list is not confidential**, as for a public market feed, a
deployment may name the consumers as readers directly; each then reads
from its own participant, with no read node and no disclosure.

## The round chain

**Publication.** Every `RoundHead_CreateRound` consumes the head and
creates the round, the successor head and the root capsule. The live head
is the only one; a publisher that loses the race gets a failed submission
and nothing is created, re-reads the head and resubmits. `RoundHead_Pause`
and `RoundHead_Resume` consume and re-create the head as well, so a
publisher racing a pause fails and retries against the new head. A reader
does not observe the head, since an observer of the consumed head would
witness every publication in full, so it cannot read `isPaused`; a
deployment that wants its readers to tell a pause from an outage announces
the pause with a contract of its own, observed by the readers, created
with the pause and archived with the resume, with nothing beneath either.

**Rounds are never replaced.** A round is referenced by number, not by
contract id, by every capsule of that number; a consumer verifies a capsule
against the round of its number read from a participant hosting the
reader. A round therefore has to exist for as long as any capsule of its
number may be verified.

**Round archival.** Each round is a small contract on the participants of
the operator, the auditors and the readers; at one round a minute that is
half a million rounds per definition per year on each of them, the
smallest of the counts in [costs.md](costs.md). Nothing retires a round
unless the operator runs an archiver, which a deployment meant to run for
long needs. A round is co-signed by the auditors, so nobody archives one
directly: `Round_Archive` carries their authority from the round and
admits the operator alone.
When no capsule may point at a round any more is an archiver's rule, as for
capsules; `caps-round-archiver` applies the capsule archiver's, counting
from the head's latest round, which it never takes, and always keeps the
genesis round. Neither is a
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
no expiry. A `ConsumableLicense` is archived by its one distribution; a
`CreditLicense` is replaced on every distribution by a contract with one
credit fewer, keeping the id it was issued with in `origin`, and archived
by its last; a `SubscriptionLicense` lives until revoked. The consumable
and the credit license are observed by nobody, since an observer of a
consumed contract is informed of the exercise; the `LicenseGrant` created
with either is what its licensor and the operator see and revoke
(`LicenseGrant_Revoke`), and it stays until revoked or archived by its
owner, saying nothing of whether the license was spent.

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
has read one may still be using it. A distributor that runs no archiver
keeps every capsule it ever distributed ([costs.md](costs.md)). The reference retention is the one a
RedStone price pill follows: keep the capsules of the newest `keptRounds`
rounds regardless of age, and past them each capsule until `keepPeriod`
after its fixing time. `CapsuleArchiver` (package `caps-capsule-archiver`)
implements it for one distributor and one definition: it carries the
distributor's authority, and `CapsuleArchiver_Archive` archives, for any
actor that sees the archiver and the capsules, those of the given capsules
that are stale by the rule. The current round is that of the distributor's
newest capsule, which the actor names: a distributor needs no sight of the
head, and naming an older capsule only keeps more. The archive fails on a
capsule of another definition and on a newest capsule the distributor did
not sign. A capsule of another distributor fails the archive
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
| `Capsule` | as the round, counted from each distributor's newest capsule | each distributor, through its archiver |
| `License` | revoked by the licensor or the operator; an expired one lingers until then; a consumable or credit license, by its last distribution | licensor, operator; the owner's distribution |
| `LicenseGrant` (extended licensing) | revoked by the licensor or the operator, or retired by its owner once the license is spent | licensor, operator, owner |
| `LicenseDelegate` | no live license names it | its signatories |
| consumer's `Verifier` | the consumer stops verifying this definition | the consumer |
| `DefinitionProposal` | finalized, or cancelled by the operator | operator |

Where accounting is in use, its contracts add:

| Contract | Kept until | Decided by |
|---|---|---|
| open `DistributionMarker` | merged or closed | distributor, accountant |
| settled `DistributionMarker` | to be designed with token settlement | accountant |
| `SettlementHead` | replaced on every close | the ledger |
