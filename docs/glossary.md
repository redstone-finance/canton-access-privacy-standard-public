# Glossary

Terms as the CAPS documents use them. Canton terms are given with the
meaning that matters here, not their full definition.

**Accountant.** A party the operator names on the root license's
accounting delegate, separate from the operator, that observes the
delegates and distribution markers, closes periods and bills. Optional; see
[accounting.md](accounting.md).

**Attestation.** The data producer's signatures over a round by the
attestation keys of the definition's verifier, in the verifier's encoding,
carried in the round where the verifier names such keys, so that a party
that cannot read the round can check its view. It is the key holder's word
that it designated that content for that round number, not proof that the
ledger holds the round.

**Attestation key.** A key the verifier names for attestations: the data
producer's, not a publisher's. A key attests the rounds of one definition
only.

**Auditor.** In the reference implementation, a party that co-signs the
data definition, the round head and every round, so that the operator
cannot archive the definition or the head, fork the chain or mint a round
alone, and retires a round only through `Round_Archive`; and that may
pause publication. Not named by the interfaces.

**Authenticity.** The property that a capsule's content is what the
oracle's nodes signed and aggregates to what the data point claims.
Checked by `Verifier_Verify`.

**Candidate.** The content of the next round with the key holder's
attestation, signed before publication. The key holder signs one per round
number, retries a failed publication with the same one, and signs another
for the same number only when no reference time exists at which both would
pass the freshness check.

**Canonicality.** The property that a capsule's content is what was fixed
in the round of its number: the round's commitment matches the content.
Checked by `Verifier_VerifyRound` against the round read from a
participant hosting the reader or, for a consumer that cannot read it, against
the view the presenter hands over next to the capsule, which the round's
attestation makes checkable where the verifier names attestation keys.

**Capsule.** The unit of distribution: a contract implementing `Capsule`
and the Data Standard's `PublishedDataPoint`, signed by its distributor,
observed by its audience, carrying the definition, the round number and
the content.

**Capsule content.** The data point, the opaque signed payload and the
license a capsule carries. Copied unchanged along a chain of
distributions except for the license and the distributor.

**Client.** A party a capsule is distributed to; an observer of it.

**Commitment** (`dataHash`). The verifier's hash of the capsule content,
recorded in the round at publication and recomputed at verification. Its
function is the verifier's; it depends on nothing that changes at
distribution.

**Confirming party.** A party whose participant must confirm a
transaction for it to commit: the signatories of every contract the
transaction creates, consumes, fetches or exercises, and the parties that
act on them. Confirmation is
validation, not consent. The reason every co-signature costs liveness.

**Consumer.** A client that verifies a capsule before acting on it.

**Data definition.** The identity and trust anchor of a data set: its
contract id is what everything else points at; its view names the
canonical verifier.

**Data point.** The Data Standard's `PublishedDataPointView`: distributor,
fixing time (`publishedAt`), schema version, values, metadata.

**Data Standard.** The Canton Data Standard, whose `PublishedDataPoint`
interface every capsule implements and whose `AnyValue` type carries
payloads and license types.

**Disclosure** (explicit disclosure). Handing a contract to a party that
is not its stakeholder so that it can use it in a transaction. Creates no
ledger event and informs nobody but the recipient.

**Distribution.** Creating a capsule for a list of clients from an
existing capsule's content, under a license, through
`License_Distribute`. By view, it informs nobody above the distributor;
by id, it informs the source capsule's signatory.

**Distribution marker.** The optional record a licensed distribution
leaves for the accountants, in the same transaction as the capsule.

**Distributor.** The owner of a license and the signatory of the capsules
created under it. The operator for root capsules.

**Extension.** A package that adds behaviour at a point the interfaces
leave open: an oracle's `Verifier`, a kind of `License`, or a
`LicenseDelegate`. Optional; see [extensions.md](extensions.md).

**Fixing, fixing time.** One publication of the data set and its
timestamp, `dataPoint.publishedAt`, which becomes the round's timestamp.
Strictly increasing along the chain.

**Fixing rule.** What a contract that settles on a capsule names to say
which round it means ([specification.md](specification.md), section 5).

**Fork.** Two rounds of the same number for one definition. Excluded by
the reference governance, where a new head and every round need every
auditor's signature, available only inside a choice on the head, as long
as an auditor is independent of the operator; detectable only under weaker
variants.

**Freshness.** Whether a fixing time is acceptable at a reference time by
the oracle's window (`maxBehind`, `maxAhead`). Checked by
`Verifier_VerifyFreshness`: at ledger time by the head on publication, at
a time of the consumer's choosing afterwards.

**Genesis round.** Round 0, created at bootstrap with the bootstrap time,
an empty commitment and no capsule.

**Head.** See round head.

**Informee.** A party that learns of a transaction node: stakeholders of
a created or archived contract, signatories and actors of a fetched or
exercised one, observers of a contract a consuming exercise archives. The
basis of every privacy rule in the standard.

**Key holder.** The holder of an attestation key: the data producer. A
publisher that holds none carries the key holder's signed candidate to the
ledger. Two attestations of one number fresh together are the key holder's
equivocation, provable by anyone holding both.

**License.** A right to distribute capsules and to sublicense, owned by
one party. The root license is the operator's; every sublicense is its
licensee's.

**License delegate.** The contract a license names to be told of every
distribution and to give a sublicense its delegate, through
`LicenseDelegate`. Optional; the accounting extension implements one. See
[specification.md](specification.md) section 3.7.

**License type.** An `AnyValue` describing the kind of right a sublicense
grants, in the implementation's encoding. Opaque to `caps-core`; decoded
by `caps-extended-licensing` into open, consumable, subscription or credit
terms.

**Licensee.** A party a license entitles to create a sublicense from it.
On the root license, also the audience of every root capsule.

**Licensor.** The owner of the parent license, or the operator for the
root; may revoke the license. Named by party, so a sublicense survives
its parent's retirement.

**Operator.** The publishing party: owner of the root license, distributor
of every root capsule, and in the reference implementation a signatory of
the definition, the head and the rounds.

**Payload.** The signed oracle data a data point was computed from, in the
oracle's own encoding as an `AnyValue`, opaque to the standard, decoded by
the verifier.

**Policed.** Made visible to a party that can react, as opposed to proven
(enforced by the ledger) or out of reach. License provenance and
accounting are policed.

**Presentation.** A capsule's view and the view of its round, attestation
included, handed to a consumer that does not read them from the ledger.
Everything the authenticity, canonicality and freshness checks take as
input; see [off-ledger.md](off-ledger.md).

**Public party.** A party that holds what every user of a deployment may
read and acts for nobody, as Daml applications call it. The readers party
is one.

**Publisher.** The party submitting `RoundHead_CreateRound`; the operator
or any party the head admits. The authority to sign the round comes from
the head, not from the publisher.

**Read node.** An observing participant node: one that hosts the readers party
with observation permission and from which consumers read the rounds; run
by the operator or a party it designates, never by a consumer.

**Reader.** A party entitled to see that a round exists and to check
capsules against it: an observer of the rounds and the definition. By
default the readers party.

**Readers party.** The one party a deployment names by default as the
reader of a definition: a public party in the operator's namespace,
multi-hosted with observation permission on read nodes, which consumers
read the rounds as, so that no consumer appears on the ledger as a reader
([lifecycle.md](lifecycle.md)).

**Root capsule.** The capsule created with a round, distributed by the
operator under the root license to the root license's licensees.

**Round.** The immutable, price-free record of one fixing: definition,
number, fixing time, commitment and, where the feed attests, an
attestation. Visible to the readers. Capsules reference it by number,
never by contract id.

**Round head.** The head of the round chain and the publishing endpoint:
one live contract per definition, consumed on every publication, which is
what makes round numbers unique.

**Self-report.** What an open distribution marker is: signed by the
distributor alone, with no field checked by another party at creation.

**Settlement.** In accounting, closing a period of distribution markers
under the accountant's signature, numbered by a settlement head. In the
guides, also a transaction in which parties settle on a capsule's data.

**Smart-contract upgrade (SCU).** Daml's in-place upgrade of a package.
Available to implementation packages, never to a package that defines an
interface, which is why the interface package holds no logic beyond the
check of signatories in `Round_Fetch`.

**Stakeholder.** A signatory or observer of a contract. Stakeholders see
the contract and are informed of its creation and archival.

**Verifier.** The oracle's verification rules as a contract: the only
vendor-specific piece of a deployment. The canonical instance is named by
the definition; a consumer verifies against an instance of its own.

**View** (interface view). The data a contract exposes through an
interface. Every verifier choice takes views rather than contract ids, so
that verification fetches nothing.
