# Costs and sizing

What a CAPS deployment puts on the ledger per publication and per
distribution, what that comes to at the cadences the standard is meant
for, and which properties a deployment may give up to pay less. The
counts per publication are those of the reference implementation and are
held by a test
([`tests/daml/Test/CostsTest.daml`](../tests/daml/Test/CostsTest.daml)),
which also holds that retention stops the growth; the tables per year and
under retention are arithmetic on those counts.
[lifecycle.md](lifecycle.md) has the mechanics of retention.

## What CAPS is sized for

CAPS carries any published data point, a price or whatever else a
`PublishedDataPoint` holds, at any cadence a deployment pays for. Among
its uses it is proposed mainly for data that parties must agree on, whose
lineage must be provable and whose audience is entitled: reference data,
benchmark rates, a fund's net asset value at its dealing cut-off, the
valuation a margin call or a settlement is computed from. Such data is
published from once a day to once a minute, and those are the cadences
the counts below are worked for.

Nothing stops a faster feed. Every round is a transaction and a contract
several parties hold, so every count below grows in proportion to the
cadence. A deployment that publishes more often than it needs a fixing
may also keep the values in between off the ledger, as the oracle's signed
payloads, and publish a round for the moments that settle.

## Contracts per publication

One publication creates a round and a root capsule. Each distribution of
it creates a capsule and, where the license names the accounting delegate,
a marker.

| Party | Gains per publication | Which contracts |
|---|---|---|
| Operator | 2 | the round, the root capsule |
| Each auditor | 2 | the round, the root capsule |
| Each read node of the readers party | 1 | the round |
| Each root licensee | 1 | the root capsule |
| A distributor, per capsule it distributes | 2, or 1 without accounting | the capsule, and with accounting its marker |
| A client, per capsule it receives | 1 | the capsule |
| An accountant, per capsule distributed with accounting | 1 | the marker |
| A consumer reading through read nodes | 0 for the round | |

A distributor that is a root licensee and sends every round to each of its
C clients separately therefore gains 1 + 2C contracts per publication; one
that sends a single capsule to all of them gains 3 whatever their number,
which is 2C - 2 fewer. Licenses, delegates,
verifiers and the definition are created once and do not grow; the head is
replaced, not added to.

## Per year, per feed

Without any retention, at three cadences:

| Party | Daily | Hourly | Every minute |
|---|---|---|---|
| Publications | 365 | 8,760 | 525,600 |
| Operator, each auditor | 730 | 17,520 | 1,051,200 |
| Each read node | 365 | 8,760 | 525,600 |
| Distributor, 10 clients, a capsule each, accounting | 7,665 | 183,960 | 11,037,600 |
| Distributor, 10 clients, a capsule each, no accounting | 4,015 | 96,360 | 5,781,600 |
| Distributor, 10 clients, one capsule for all, accounting | 1,095 | 26,280 | 1,576,800 |
| Client | 365 | 8,760 | 525,600 |
| Accountant, per distributor with 10 clients, a capsule each | 3,650 | 87,600 | 5,256,000 |

The publication path is small at every cadence. The distributor's line is
the large one, and it is the price of one thing: a capsule per client, so
that no client sees another.

## Retention

Nothing in the standard archives a round, a capsule or a marker, and the
archivers of the reference implementation are separate packages a
deployment must run. A deployment that runs none keeps everything above,
so one meant to run for long needs them.

With the round archiver, the operator's capsule archiver for the root
capsules and each distributor's for its own, what a party holds stops
depending on how long the feed has run. Without the operator's capsule
archiver the operator, each auditor and each root licensee keep a root
capsule per publication: a licensee observes the root capsule and cannot
retire it, so a distributor's line below depends on the operator's
archiver as well as on its own. An archiver keeps the newest `keptRounds`
rounds whatever their age and an older one for `keepPeriod`, and retires
nothing between its runs. A party therefore holds its gain per publication
times the larger of `keptRounds` and the rounds of one `keepPeriod`, plus
the rounds since the archiver last ran: a daily feed that keeps ten rounds
holds ten days of them. With a `keepPeriod` of one day, `keptRounds` within
it and the archivers run after every publication:

| Party | Daily | Hourly | Every minute |
|---|---|---|---|
| Operator, each auditor | 2 | 48 | 2,880 |
| Each read node | 1 | 24 | 1,440 |
| Distributor, 10 clients, a capsule each | 11 | 264 | 15,840 |
| Client | 1 | 24 | 1,440 |

Whoever holds the rounds holds the genesis round besides, which the round
archiver never takes.

Markers, which exist only with accounting, are outside the archivers: an
open marker stays until it is merged or closed. `DistributionMarker_Merge`
folds any number of a distributor's open markers under one license into
one, so an accountant or a distributor that merges once a day holds one
open marker per license, plus the day's markers not merged yet; a closed
marker, one per settlement, stays ([accounting.md](accounting.md)).

Retention has two costs. An archive is a transaction, sent to the parties
the contract was sent to, though one archiver exercise retires any number
of contracts. And a retired round can no longer be read from the ledger,
so a capsule of its number can no longer be checked against the round's
signatories. What remains verifiable is what its holder kept: a capsule's
view and its round's view with the attestation verify outside the ledger
for as long as the keys are known ([off-ledger.md](off-ledger.md)), which
proves that the key holder designated that content for that round, not
that the ledger held the round. An audit that must reach back further than
the retention window therefore rests on kept presentations and the
attestation key, or on a longer window for the rounds alone, which are the
cheapest line of every table. There are also ways of folding retired
rounds that keep them checkable on the ledger; compaction into a tree
([round-compaction.md](round-compaction.md)) is one, described as a
possible extension.

## Traffic

A publication is one transaction for the operator, the auditors, the read
nodes and the root licensees; a distribution is one transaction per
capsule, for the distributor, the capsule's clients and the accountants.
A capsule to each of N clients is therefore N transactions carrying the
payload where one capsule to all of them is one, deliberately, for the
same reason as in the contract counts. What a transaction costs in
traffic depends on the synchronizer's parameters and on how well it
compresses, so it is measured on the network a deployment runs on, not
derived here. As one measurement: RedStone's publication on DevNet every
ten seconds, with rounds and root capsules retired after a minute and no
distribution, takes about 3 MB of traffic an hour, a median of 7 kB a
write.

## What a deployment may give up

Each line of the table below saves what its second column says and gives
up what its third says. None of them is a setting of the standard; each is
a choice of the operator or of a distributor, and they combine.

| Choice | Saves | Gives up |
|---|---|---|
| One capsule for a group of clients | the distributor's 2C becomes 2 per group, and N transactions one | the clients of a group see each other |
| Capsules distributed on request, not with every round | every contract and transaction of the rounds no client asked for | the distributor learns which rounds a client uses, and when |
| No accounting delegate on the license | the marker of every distribution, and everything the accountant holds | distribution measured on the ledger |
| Markers merged often | open markers, down to one per license | nothing the accountants did not already see |
| A shorter retention window | every count, in proportion | the check against the ledger for older rounds |
| A slower cadence | every count and all traffic, in proportion | freshness |
| Several feeds in one definition | every count, divided by the number of feeds | licensing a feed by itself; a round waits for every feed |
| Named readers instead of a readers party | the read nodes | the reader list in confidence ([lifecycle.md](lifecycle.md)) |
| Capsules delivered outside the ledger, with the round's attestation ([off-ledger.md](off-ledger.md)) | every contract and transaction of distribution | license provenance and accounting on the ledger for those capsules; the consumer keeps what it received |

What no choice removes is the round and the root capsule of each
publication, for the operator and each auditor. That is the cost of a
fixing the operator cannot rewrite alone.
