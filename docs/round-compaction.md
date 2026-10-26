# Round compaction

A possible extension, not shipped. A deployment that wants the hashes and
fixing times of older rounds kept on the ledger without a contract per
round can fold them into a tree instead of archiving them outright, as
the round archiver of [lifecycle.md](lifecycle.md) does.

A merger of the operator takes every round at least `keptRounds` behind
the latest one, keeps its hash and fixing time as an entry and archives
it. The entries of N consecutive rounds become one meta-round, and N
meta-rounds of a level one a level up, the rounds being level 0. A tree
whose last round is older than a retention X goes with everything below
it, and the genesis entry always stays. The picture shows it for N = 3,
K = 4 (`keptRounds`) and X = 24 with a round every hour.

![A round merger for N = 3, K = 4 and X = 24 after rounds 14, 16 and
116](images/round-compaction.svg)
