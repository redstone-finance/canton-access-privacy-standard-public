# Implementer guide

How to bring an oracle onto CAPS, how to write the one contract that is
yours, the `Verifier`, how to replace other parts of the reference
implementation when you need to, and what you may not change without
leaving the standard. [specification.md](specification.md) is the list of
requirements; this document is the order of work.

## Three ways in

| You are | You write | You reuse |
|---|---|---|
| An oracle that signs its own payloads | a `Verifier` template for your signing scheme | everything else in `caps-core` |
| An oracle whose nodes sign the Data Standard envelope | nothing | `caps-verifier-datastandard` and `caps-core` |
| A deployment with its own governance, licensing or accounting | the templates you need, implementing the interfaces | the interface package, and whatever of `caps-core` still fits |

In every case the interface package `caps-api-core-v1` is taken as is: it
is what consumers and other implementers code against.

## Writing a verifier

A verifier is a template implementing `Caps.Api.CoreV1.Verifier` through
three method bodies. Its fields are the parameters of your scheme; its
signatory is whoever creates an instance.

```haskell
template MyVerifier
  with
    owner : Party
    observers : [Party]
      -- the readers, on the canonical instance; empty on a consumer's
    signers : [Text]
    signerCountThreshold : Int
    maxBehind : RelTime
    maxAhead : RelTime
  where
    signatory owner
    observer observers

    interface instance Api.Verifier for MyVerifier where
      view = Api.VerifierView {}
      verifier_verifyImpl _self arg = pure $ verifyContent signers signerCountThreshold arg.capsule.content
      verifier_verifyRoundImpl _self arg = pure $ verifyRound arg.capsule arg.round
      verifier_verifyFreshnessImpl _self arg = pure $ verifyFreshness maxBehind maxAhead arg.capsule arg.asOf
```

The three functions are pure Daml over the arguments and the fields. Write
them in an `Internal` module and keep the template thin, as the two
shipped verifiers do; the test fixture's `TestVerifier` inlines its checks.

**`verifyContent`** decides authenticity and computes the commitment.
Decode `content.payload` from the `AnyValue` encoding you chose; check the
signatures against `signers` and the quorum; check that
`content.dataPoint` is the aggregate your rules derive from the payload.
Return `Verified dataHash` or `Rejected reasons`, with every reason you
can name rather than the first. Two shapes to collect checks, as the test
fixture writes them:

```haskell
failures : [(Api.RejectionReason, Bool)] -> [Api.RejectionReason]
failures checks = [ reason | (reason, ok) <- checks, not ok ]

verdict : Text -> [(Api.RejectionReason, Bool)] -> Api.VerificationResult
verdict dataHash checks = case failures checks of
  [] -> Api.Verified dataHash
  failed -> Api.Rejected failed

outcome : [(Api.RejectionReason, Bool)] -> Api.CheckResult
```

**The commitment** must be a function of the fields `License_Distribute`
copies unchanged: `dataPoint.publishedAt`, `schemaVersion`, `values`,
`metadata` and `payload`. Never include `dataPoint.distributor` or
`content.license`, or every distributed capsule fails canonicality. The
RedStone verifier hashes the payload bytes; the Data Standard verifier
hashes the signed envelope, which carries no distributor. Choose what a
third party can recompute from a capsule alone.

**`verifyRound`** compares the round view with the capsule: same
definition, same round number, round timestamp equal to the fixing time,
round `dataHash` equal to your commitment of the content. Nothing else: do
not look at ledger time, do not fetch.

**`verifyFreshness`** judges `dataPoint.publishedAt` against `asOf` and
your window, inclusive at both edges. Add what your scheme knows, such as
a signed expiry.

Rules that are easy to break:

- No `getTime`, no `fetch`, no `exercise` in any of the three bodies. The
  verdict must be reproducible by any party from the same inputs, and a
  fetch would inform a signatory that the caller consumed something.
- Never `abort` on a bad capsule. A caller that needs failure asserts on
  the result.
- The canonical instance needs the readers as observers: a publication
  exercises it, and a contract used in a transaction must be visible to
  the submitter. A consumer's instance has no observers.
- Hashing builtins live in `DA.Crypto.Text`, which Daml marks alpha; add
  `-Wno-crypto-text-is-alpha` to `build-options` as the RedStone verifier
  does.

**Package wiring.** A verifier package depends on the interface DAR and
the two Data Standard DARs as `data-dependencies`, targets LF 2.1 and sets
`--explicit-serializable=yes`:

```yaml
data-dependencies:
  - ../../deps/canton-data-standard-utils-v1-0.2.0.dar
  - ../../deps/canton-data-standard-datapoint-v1-0.2.0.dar
  - ../../interfaces/caps-api-core-v1/.daml/dist/caps-api-core-v1-0.1.0.dar
build-options:
  - --explicit-serializable=yes
  - --target=2.1
```

Put the package under `extensions/`, as the shipped verifiers are, add it
to `multi-package.yaml` after `caps-core` and before the tests, and list
its DAR in the `data-dependencies` of `tests/daml.yaml`. Add a
test module under `tests/` that publishes a round through the reference
head with your verifier as the canonical one, distributes a capsule, and
verifies it as a client; the RedStone and Data Standard test modules are
the pattern, including rejection cases for every reason your verifier can
produce and both edges of the freshness window.

## Publishing with an existing oracle

The publisher, the relayer in RedStone's terms, needs the three contracts
a publication touches (head, canonical verifier, root license) visible on
its participant, and a party admitted by the head's `publishers`. Then
every round is one command:

```haskell
exerciseCmd head Api.RoundHead_CreateRound with
  actor = publisher
  content = Api.CapsuleContent with
    dataPoint = aggregate          -- publishedAt = the fixing time
    payload = encodedSignedData    -- as your verifier decodes it
    license = rootLicense
```

The result carries the successor head; the next publication uses it. A
failed submission on a consumed head means another publisher won; re-read
the head and retry. The ledger time at submission must lie within the
verifier's window around the fixing time, so a relayer that batches or
delays cannot publish a fixing older than `maxBehind`.

Where to keep the current head, the live capsules and the rounds is the
publisher's business: the Ledger API answers all three for the operator,
and a deployment may add a publisher contract that tracks them and
archives in the same transaction it publishes
([lifecycle.md](lifecycle.md)). Such a contract is yours, not the
standard's, and may key, time or reward as your integration needs.

## Replacing parts of the reference

`caps-core` is one way to satisfy the interfaces. What you may change, and
what each change touches:

| You want | Change | Keeps conformance if |
|---|---|---|
| A different signatory policy on the head and rounds | your `RoundHead` and `Round` templates | `RoundHead_CreateRound` meets every MUST of specification §3.3; see [governance.md](governance.md) for the trade-offs |
| A pause by threshold | a proposal contract around `RoundHead_Pause`, or your own head | pausing stays outside the interface |
| License kinds with terms or expiry | your `License` templates; `caps-extended-licensing` is one set | `License_Distribute` copies the content unchanged except license and distributor, sets observers to `clients` only, and `License_CreateSublicense` requires a licensee |
| Accounting, metering or another effect of a distribution | your `LicenseDelegate` template; `caps-accounting` is one | the license calls it in every distribution and sublicense, and the licensees of every license that names it observe it |
| A capsule with extra fields (e.g. metadata of your own) | your `Capsule` template | the signatory is `content.dataPoint.distributor`, the observers are the audience, `content.dataPoint` equals the `PublishedDataPoint` view |
| A different bootstrap | your proposal workflow | the genesis round is number 0 with an empty commitment |
| Retention | your archiver, or `caps-capsule-archiver` with other parameters | rounds outlive the capsules of their number |

Keep the shared pieces shared: `Caps.Core.Distribution.distribute` creates
the capsule and reports it to the delegate, and `sublicenseDelegate` gives
a sublicense its delegate, for any license implementation (they are what
`caps-extended-licensing` reuses), and the reference head reads the root
license through the interface only, so any `License` implementation can be
a root license without touching the head.

## What you may not change

- The interface package. A changed view, type or choice is
  `caps-api-core-v2`, which existing consumers do not understand.
- Verification by contract id. Every verifier choice takes views; adding
  a choice that fetches would inform signatories of consumption.
- The observers of a distributed capsule: `clients`, and nobody else. A
  delegate the license names may add informees of the distribution, but
  only its own signatories, as the table in specification.md section 3.7
  lays out; it never adds observers to the capsule.
- The meaning of `roundNumber` and `timestamp`: one more per round,
  strictly increasing fixing times, genesis at 0.
- The consumer's own verifier instance as the verification path. A design
  that routes verification through an operator's contract reveals
  consumption, whatever else it offers.

## Checklist before a release

- `make ci` green: headers, build, DAR validation, tests, committed DARs
  match a rebuild.
- Every verifier rejection reason covered by a test, and both edges of the
  freshness window.
- A privacy test per claim: the operator and the auditors see no
  distributed capsule and no marker; a distribution by view informs no
  party above the distributor.
- The canonical verifier's observers include the readers, or publishers
  cannot publish.
- The documentation's visibility matrix ([data-model.md](data-model.md))
  still matches your templates.
