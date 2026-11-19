# Off-ledger handoffs and verification

What CAPS hands from one party to another outside the ledger, what each
handoff must carry, and what a party can check from it without a
participant. The normative requirements are in
[specification.md](specification.md) sections 5 and 6; this document
lists the handoffs those procedures rely on and describes the checks for
an implementation outside Daml. The standard fixes what is handed over
and what it proves, never how it travels: a file, an API, a message, a
disclosed contract are all conforming transports.

## The handoffs

| Handoff | From, to | What is handed over | What the recipient checks |
|---|---|---|---|
| Onboarding | operator to consumer | the `DataDefinition` contract id; the canonical verifier's template id and fields, read from the verifier contract the consumer observes or published out of band | the template id names a verifier package the consumer trusts; the fields are the ones the consumer will copy into its own instance |
| Publication | operator to publisher | the head, the canonical verifier and the root license, by observation or by explicit disclosure | nothing: the ledger refuses a publication that cannot see all three |
| Attestation | publisher to key holder, and back | the next round number, the head's plus one, and the commitment of the content; back, the signature | the publication itself: `RoundHead_CreateRound` runs `Verifier_VerifyRound` on the round it is about to create, attestation included |
| Presentation | distributor or presenter to consumer | the capsule's view and the view of its round, attestation included, where the consumer does not read them from the ledger | the consumer's five checks: authenticity, canonicality, freshness, license and chain, with canonicality through the attestation |
| License | distributor to consumer | the license contract the capsule names, by explicit disclosure; for a consumable or a credit license, which the distribution itself archives, also the `LicenseGrant` it names, which stays | its `owner` is the capsule's distributor and its `definition` the capsule's |
| Round | ledger to reader | the round of the capsule's number and definition, through the Ledger API of a participant hosting the reader | the round's signatories are the definition's |

What the table hands over is a view, a contract id, a disclosed contract
or a signature. Nothing a consumer needs is a secret, and nothing a
presenter hands over is taken on trust beyond what the attestation and the
ledger cover: a view that does not match the signed data fails
authenticity, a round view that does not match the round fails
canonicality once the consumer reads the round, and a presenter's own
round view passes only where a key holder signed it.

That holds where the verifier names attestation keys. Where it names none,
`Verifier_VerifyRound` passes a round view that carries no attestation and
fails one that carries any, so a view of the presenter's own making
passes: such a feed is verifiable only against the round itself, read or
taken through `Round_Fetch`, and a consumer that is handed both views
SHOULD NOT accept the capsule.

## A presentation

A presentation is a `CapsuleView` and a `RoundView` of the same
definition and round number, the round carrying its attestation where the
feed attests. It is self-contained: together with the verifier's
parameters from onboarding, it is everything the authenticity,
canonicality and freshness checks take as input. A consumer that reads
the capsule from the ledger and the round from a participant hosting the
reader builds the same pair itself; a consumer that gets both from a
presenter runs the same checks on them, with canonicality resting on the
attestation instead of on the ledger.

## What can be checked without a participant

The verifier is, by requirement, a pure function of its arguments and its
own fields: no ledger time, no other contract, no caller. Every check it
runs can therefore be run outside Daml with the same inputs. Per check:

1. **Authenticity.** For a RedStone payload: parse it, verify the node
   signatures against the verifier's `signers`, require
   `signerCountThreshold` distinct signers per feed, aggregate, and compare
   with the data point: the feeds are exactly `feedIds`, each value the
   aggregate, `publishedAt` the packages' timestamp, `schemaVersion` the
   verifier's. The packages carry whole milliseconds and the Daml verifier
   rejects a `publishedAt` that is not one, so a port does the same. The
   RedStone SDK, in TypeScript or Rust, does the rest. For a Data Standard
   payload: rebuild the signed
   envelope from the data point's `publishedAt`, `schemaVersion` and
   `values` and the payload's `expiresAt`, reject a `publishedAt` that is
   not a whole millisecond or is after `expiresAt`, verify each of the
   payload's signatures over the
   envelope's hash against `signers`, reject one that matches none, and
   require `signerCountThreshold` distinct signers; there are no feeds to
   compare and nothing to aggregate. The Data Standard's codecs do it.
2. **Canonicality.** Recompute the commitment from the capsule's content
   and compare it with the round's `dataHash`; compare definition, round
   number and fixing time; where the verifier names attestation keys,
   verify the attestation over the message below, and where it names none,
   require that the round carries none. Without the ledger this
   proves that the key holder designated this content for this round
   number, not that the ledger holds the round.
3. **Freshness.** `publishedAt` against the consumer's reference time and
   the verifier's window, or the consumer's own bound; for a Data Standard
   payload also the reference time against the signed `expiresAt`, which
   it must not have passed.
4. **License.** Policed, not proven, on the ledger as well; off the ledger
   the consumer sees the license only if the distributor shows it, and
   then checks owner and definition as a participant would. A consumer
   that cannot see it trusts the distributor for it.
5. **Chain.** Needs the Ledger API: the signatories of the round come from
   its `CreatedEvent`, not from any view. A consumer without a participant
   has no chain check and relies on the attestation for canonicality.

What a participant adds, and nothing off the ledger replaces: in a
multi-party transaction every informee's participant re-executes the
first three checks, so counterparties need not trust the consumer's
verdict. Off the ledger each party verifies for itself.

## Encodings of the shipped verifiers

Both verifiers hash and sign hex-encoded byte strings. Hashes are
lowercase; keys are taken as the table says.

| | RedStone verifier | Data Standard verifier |
|---|---|---|
| Commitment `dataHash` | keccak256 of the payload bytes, the hex text decoded | the structural root hash of `SignedDataPoint` (`publishedAt`, `expiresAt`, `schemaVersion`, `values`), the Data Standard's `canonicalHash`, with `expiresAt` from the payload |
| Attestation message | the ASCII bytes of `caps-round-attestation-v1\|<round number in decimal>\|<dataHash>` | the same bytes as for the RedStone verifier; what is signed differs, next row |
| What is signed | the keccak256 digest of the message, as the nodes sign packages: ECDSA secp256k1 over the digest itself, no second hash | the SHA-256 of the message: ECDSA secp256k1 over it, the Data Standard's own scheme |
| Attestation encoding | strict DER, hex | strict DER, hex |
| Signatures inside the payload | the 65 bytes of r, s and v, as the nodes produce them | DER, hex |
| Key format, `signers` and `attestationKeys` alike | hex, one of: the uncompressed secp256k1 point of 65 bytes with the `04` prefix, the 64 bytes of X and Y, or DER SubjectPublicKeyInfo; an attestation key in either case | DER SubjectPublicKeyInfo, hex, as a `DistributorKey` view carries it |

Strict DER is exactly two integers, each minimal, not negative and below
the order of secp256k1. The verifiers fail any other attestation as
`round attestation is not a DER signature`, r, s and v included, and the
Data Standard verifier holds the signatures inside a payload to the same
form: one that is not strict DER matches no signer.

The round's fixing time is not in the attestation message, since the
payload the commitment covers carries it; nor is the definition, which
has no textual identity on the ledger, so a key attests the rounds of one
definition only.

## Vectors

From the test suite ([`tests/daml/Test/RedStoneVerifierTest.daml`](../tests/daml/Test/RedStoneVerifierTest.daml)),
which asserts each of them and which an implementation outside Daml checks
itself against. The payloads
are hex texts as the capsule carries them in `payload`.

| Vector | Value |
|---|---|
| `payloadFull`, three test node packages, BTC and ETH at 1789000000000 ms | `dataHash` `6938dd6d48625c3a6f2e0c31c8e39ab25c2caa30b92cbddf9f62f5bfe999a9fd` |
| `productionPayload`, a `redstone-primary-prod` gateway response | `dataHash` `fc83b7a5a0032c28f9192f0d683e22afcae57929b7a491c784b26f1cc991d53a` |
| attestation message for round 1 of `payloadFull` | ASCII `caps-round-attestation-v1\|1\|6938dd6d…a9fd`; keccak256 digest `0a6826c837abbe82a59f51d532c8e572e054215707346c00029c7fe8d1c72e34` |
| attestation of that round by private key 1 | DER `3045022100bdbe3c37aa32885baedc4f3b6a6fdf3064ccb841e1ed7e269b8735b289743a4c022010a280931c69706e0378e12a60b5c98bf6ef4de93a873c49c9e7e01ae74ae802`, verifiable against the first of `testSigners` |

The test node keys are the secp256k1 private keys 1, 2 and 3, listed in
the same file as `testSigners`; the RedStone verifier's vectors, signed by
them, are what a port of the authenticity check verifies first. The
attestation vector is one valid signature by key 1 over the digest. A port
verifies it and does not expect to reproduce it: an ECDSA signature
depends on the signer's nonce, so another signer's bytes over the same
digest differ. The Data
Standard's own golden vectors, in its repository, pin the envelope hash.

## What an off-ledger consumer trusts

- The node keys and the attestation key it took at onboarding, which is
  what a reader on the ledger trusts too.
- For canonicality, the key holder, through the attestation; a reader on
  the ledger trusts the round's signatories instead, and a consumer that
  has both compares them.
- The distributor, for the license and for `metadata`, exactly as on the
  ledger.
- Its own clock, for freshness.

It gets no re-execution by counterparties, and it is bound by the same
retention as a reader: a round retired under the operator's retention can
no longer be read, so a presentation kept for later keeps the round view
with it.
