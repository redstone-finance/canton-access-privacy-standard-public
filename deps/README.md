# Vendored dependencies

The DARs in this directory are the only external packages the CAPS packages
build against. They are taken as released by their projects, never rebuilt
here, so that the package ids below are the ones a consumer finds on a
ledger. Each entry gives where the file comes from and its hashes.

| File | What it is | Source | Release | License |
|---|---|---|---|---|
| `canton-data-standard-codecs-0.2.0.dar` | Canton Data Standard: the signed-envelope codecs the Data Standard verifier delegates to | https://github.com/kaikodata/canton-data-standard | tag `v0.2.0`, file `dars/` of the release | Apache-2.0 |
| `canton-data-standard-datapoint-v1-0.2.0.dar` | Canton Data Standard: `PublishedDataPoint`, which every capsule implements | https://github.com/kaikodata/canton-data-standard | tag `v0.2.0`, file `dars/` of the release | Apache-2.0 |
| `canton-data-standard-distributor-key-v1-0.2.0.dar` | Canton Data Standard: distributor keys, used by the Data Standard verifier | https://github.com/kaikodata/canton-data-standard | tag `v0.2.0`, file `dars/` of the release | Apache-2.0 |
| `canton-data-standard-utils-v1-0.2.0.dar` | Canton Data Standard: `AnyValue` and the shared utility types | https://github.com/kaikodata/canton-data-standard | tag `v0.2.0`, file `dars/` of the release | Apache-2.0 |
| `redstone-common-v20-0.5.0.dar` | RedStone Daml SDK: time helpers the SDK depends on | RedStone monorepo, `packages/canton-connector/daml/common`; public release pending | version 0.5.0 | Apache-2.0 |
| `redstone-sdk-v20-0.5.0.dar` | RedStone Daml SDK: RedStone payload parsing and signature verification, which the RedStone verifier delegates to | RedStone monorepo, `packages/canton-connector/daml/sdk`; public release pending | version 0.5.0 | Apache-2.0 |

| File | SHA-256 | Package id |
|---|---|---|
| `canton-data-standard-codecs-0.2.0.dar` | `72d280f17dcff94deb89b82c20aa40264f9fc335d0d29c5674230a2aec433df1` | `02e8e63d23c9fdf4aaf014e41cf28580baf56a704578236df6dce1a16b7c9ecc` |
| `canton-data-standard-datapoint-v1-0.2.0.dar` | `9dc459499a2830a3150abe9856662abe4f9ca36bd5aa55f2e26d5f3f58b9f519` | `a968e85b69e8723d4a016512ac098104c42a341ad2251bacdb4ee8e72bcadc25` |
| `canton-data-standard-distributor-key-v1-0.2.0.dar` | `c3bf540fa2ac2938de6652068ec37f3d9a1022ea03ddaa21c214eb4bbdcde2ac` | `e25a6aaa6fb4258ba1a5b5ce9c9d07510c358f4b6d94d4da5e0c824bca1cc053` |
| `canton-data-standard-utils-v1-0.2.0.dar` | `1859fd441e4bb807374f0aa4a7b234756369cf7f324a33603526e59ef26749df` | `ce9c6cd5d815429a4f326be340764f8a92a570fe6ca8c75869d1e7f7f6a0bdef` |
| `redstone-common-v20-0.5.0.dar` | `2121e1e0240ca8fd67275cf0ce178fe1ca1862f5fc68375f0ee7a855860f320a` | `ea7f843e267faba4b78b578a6d70b9f3ff9eb34f1f43543e429054e04a5ffdec` |
| `redstone-sdk-v20-0.5.0.dar` | `595f551f40261415694f942050c9ec1846d455dfed59f2ff133eacd496ded2ef` | `c85b34b4032f1e3925431d4e86c0c6d5ed9d642b2052f49e8c81ba0caf517bae` |

The Canton Data Standard files are byte-identical to the `dars/` directory of
its `v0.2.0` tag. CAPS stays on 0.2.0 deliberately: a package cannot build
against two versions of an interface package, and the 0.3.0 line changes
`AnyValue`, so the move is a coordinated upgrade of every CAPS package.

The RedStone Daml SDK is licensed under Apache-2.0 by its `LICENSE` files;
its public source release will be linked here when it is published. The
package ids are those of the DARs deployed with RedStone's Canton adapter,
so the RedStone verifier verifies against the same code that runs there.
