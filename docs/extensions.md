# Extensions

CAPS is open to extension. The standard fixes what a consumer checks and
what a distribution must not reveal; everything else is a place where a
deployment adds its own behaviour without touching the interfaces. The
interfaces name three such places, and this repository ships an extension
for each, under `extensions/`.

## Extension points

| Point | Interface | What an extension adds | Shipped |
|---|---|---|---|
| The oracle | `Verifier` | The signing scheme, the aggregation, the payload encoding and the freshness window of one oracle. An oracle joins the standard by implementing it. | `caps-verifier-redstone`, `caps-verifier-datastandard` |
| The license | `License` | Kinds of license with terms of their own: expiry, prepaid quotas, a price per distribution. `licenseType` is an `AnyValue`, so the terms travel through `License_CreateSublicense` in the implementation's own encoding. | `caps-extended-licensing` |
| The distribution | `LicenseDelegate` | What a distribution and a sublicense do beyond creating the capsule or the child license: record it for accounting, meter it, count it against a quota, notify a party. A license names its delegate and calls it, so any delegate serves any license implementation. | `caps-accounting` |

A tool that only reads or retires contracts needs no extension point:
`caps-capsule-archiver` and `caps-round-archiver` archive capsules and
rounds through the `RoundHead`, `Capsule` and `Round` interfaces alone.

## The shipped extensions

| Path | Package | Built on | What it is |
|---|---|---|---|
| `extensions/caps-verifier-redstone` | `caps-verifier-redstone` | `Verifier` | A verifier for RedStone oracle data, delegating to the RedStone Daml SDK. |
| `extensions/caps-verifier-datastandard` | `caps-verifier-datastandard` | `Verifier` | The standard's default verifier, for data signed in the Canton Data Standard's own envelope. |
| `extensions/caps-extended-licensing` | `caps-extended-licensing` | `License`, and the distribution step of `caps-core` | The open license, paid for by use, and the prepaid consumable, subscription and credit licenses a sublicense can be created as. See [licensing.md](licensing.md). |
| `extensions/caps-accounting` | `caps-accounting` | `LicenseDelegate` | `AccountingDelegate`, which leaves a `DistributionMarker` for the accountants on every distribution it is told of, and the merging and settlement of markers. See [accounting.md](accounting.md). |

Extensions combine freely. A license of `caps-extended-licensing` may name
an accounting delegate, or none; the delegate does not know which license
calls it, only the weight the license passes in the context. The reference
license of `caps-core` passes no context, which an accounting delegate
accounts at weight 1.0, paid for by use. The test suite exercises both
licenses with the accounting delegate and without one.

The interfaces of the three points, `LicenseDelegate` among them, are
specified in [specification.md](specification.md) section 3.

## Writing an extension

- Depend on `caps-api-core-v1`, and on `caps-core` when reusing a step of
  the reference implementation, as `caps-extended-licensing` reuses its
  distribution step.
- An extension is an implementation package, so it may be upgraded in place
  under Daml's smart-contract upgrade rules. The interface package may not;
  see [specification.md](specification.md) section 8.
- In this repository an extension lives under `extensions/` as a package of
  its own, listed in `multi-package.yaml` and, when tested, in the tests'
  `data-dependencies`.
