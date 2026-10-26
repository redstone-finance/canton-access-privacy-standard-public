# Licensing in CAPS

How the right to distribute a data set is modelled, who may do what with a
license, what a client can check about the license behind a capsule, the
reference license, and the license kinds an extension may add.

## The license

A `License` is a right to distribute capsules of one data definition and to
grant that right onward. One interface serves every level of a chain: the
root license is owned by the publishing party (the operator) and created
directly; every sublicense is created through its parent's
`License_CreateSublicense` by the party that will own it, so it is signed by
that party alone. The interface's view is deliberately small: the
definition, the owner, the licensees entitled to sublicense from it, and
the delegate the license calls, if any.

| Choice | Controller | Effect |
|---|---|---|
| `License_Distribute` | the owner | Creates a capsule for a list of clients from a source capsule, given by view, which does not fetch the source or inform its distributor, or by contract id, which fetches it and informs its signatory. The new capsule carries the same content, with the owner as distributor and this license as its license. When the license names a delegate, the distribution is reported to it in the same transaction; other informees depend on the delegate. |
| `License_CreateSublicense` | `actor` | Creates a child license owned by `actor`, with the terms given by `licenseType` and the licensees given by `licensees`. When the license names a delegate, the child names the delegate it returns. The reference implementations require `actor` to be one of the license's licensees. |

Two rules shape the model:

- **A license names its licensees for life.** Changing the audience of a
  license means a new sublicense from the same parent; sublicenses refer to
  their licensor by party, not by contract id, so they are unaffected when
  the parent is replaced.
- **The root license's licensees are the audience of every root capsule.**
  The round head reads them through the interface when it publishes, so any
  `License` implementation can serve as the root license.

## Provenance: policed, not proven

A license created outside `License_CreateSublicense` cannot be prevented: a
template signed by its owner alone is always directly creatable. The
reference implementations police provenance instead:

- the operator is an observer of every license that names it, at every
  level of the chain, so such a license is visible to it the moment it
  exists, whether a parent's choice or a direct creation made it; the
  event does not say which, because `License_CreateSublicense` is
  non-consuming and an observer of the parent is not informed of it, but
  the licensor named on the license is, as the parent's signatory, and
  observes the child, so it knows whether it issued it; a revoke choice
  (`License_Revoke` in `caps-core`, `<Template>_Revoke` in the extended
  licenses) lets the licensor or the operator retire one;
- a license created outside the chain that does not name the operator is
  caught only when a client is shown it and compares it with what the
  operator published.

What a client can check, given the license contract disclosed by its
distributor: the template (is it one the client trusts), the owner (is it the
capsule's distributor), the definition, the delegate, and that the operator
observes the license. The
standard's `LicenseView` carries the owner, the definition, the licensees
and the delegate's contract id, so the template, the observers and what the
delegate does need the full contracts of known templates, not the
interfaces. Disclosure creates no ledger event and informs no party other
than its recipient.

## The delegate

A license may name a `LicenseDelegate`: the extension point for what a
distribution does beyond creating the capsule, accounting for instance. The
license tells its delegate of every distribution, in the same transaction,
with a context in its own encoding, for the extended licenses the weight
their terms give the distribution, and asks it for the delegate a
sublicense names. The license does not know what the delegate does, and
the delegate does not know which license template calls it.
[specification.md](specification.md) section 3.7 specifies the interface
and the privacy consequence of who signs a delegate.

## The reference license (caps-core)

`Caps.Core.License` is the minimal license: an opaque `licenseType`, an
optional `validUntil` inherited by sublicenses, the operator, the licensor
and the licensees as observers, `License_Revoke` for the first two, and an
optional
delegate it reports every distribution to, with no context. A deployment
that charges nothing, or charges off the ledger, names no delegate and
needs nothing more.

## Extended licenses (caps-extended-licensing)

An extension may add license kinds of its own. `caps-extended-licensing`,
one such extension, ships four, each of which reports its distributions to
its delegate, priced by its terms. They police provenance as `caps-core`
does, and a sublicense of any kind names the delegate its parent's
delegate returns for it.

| Template | Terms | Weight | Sublicensable |
|---|---|---|---|
| `OpenLicense` | open: any number of distributions, paid for by use, optionally until a `validUntil` its open sublicenses inherit | 1.0 | yes; the root license is one |
| `ConsumableLicense` | one distribution, prepaid | 0.0 | no |
| `SubscriptionLicense` | any number of distributions until `validUntil`, prepaid | 0.0 | no |
| `CreditLicense` | `credits` distributions, prepaid; the contract is replaced on each, keeping the id it was issued with, which the delegate is told | 0.0 | no |

The rule is one line: open licenses are metered, typed licenses are prepaid.
Prepaid distributions are still reported, at weight 0.0.

The kind of a sublicense is the parent's `License_CreateSublicense`
argument `licenseType`, decoded as `LicenseTerms`:

| Terms | Encoding | Value |
|---|---|---|
| open | anything without a `unit` | none |
| `Consumable` | `{unit: "consumable"}` | none |
| `Subscription t` | `{unit: "subscription", validUntil: t}` | the time the license ends, the new license's `validUntil` |
| `Credits n` | `{unit: "credits", amount: n}` | positive integer distributions |

A `licenseType` with a `unit` that does not decode (missing, fractional or
non-positive amount, missing end, unknown unit) is refused rather than
rounded.

These four are not a closed set. A license kind is a template implementing
`License`, and `licenseType` is an `AnyValue`, so an implementation adds
kinds of its own: a volume tier, a per-client price, a license that expires
with the data definition. The only rule a delegate adds is that a license
naming one reports every distribution to it in the same transaction as the
capsule.
