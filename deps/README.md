# Vendored dependencies

The DARs in this directory are the only external packages the CAPS packages
build against. They are taken as released by their projects, never rebuilt
here, so that the package ids below are the ones a consumer finds on a
ledger. Each entry gives where the file comes from and its hashes.

| File | What it is | Source | Release | License |
|---|---|---|---|---|
| `canton-data-standard-codecs-0.3.0.dar` | Canton Data Standard: the signed-envelope codecs the Data Standard verifier delegates to | https://github.com/kaikodata/canton-data-standard | tag `v0.3.0`, file `dars/` of the release | Apache-2.0 |
| `canton-data-standard-datapoint-v1-0.3.0.dar` | Canton Data Standard: `PublishedDataPoint`, which every capsule implements | https://github.com/kaikodata/canton-data-standard | tag `v0.3.0`, file `dars/` of the release | Apache-2.0 |
| `canton-data-standard-distributor-key-v1-0.3.0.dar` | Canton Data Standard: distributor keys, used by the Data Standard verifier | https://github.com/kaikodata/canton-data-standard | tag `v0.3.0`, file `dars/` of the release | Apache-2.0 |
| `canton-data-standard-utils-v1-0.3.0.dar` | Canton Data Standard: `AnyValue` and the shared utility types | https://github.com/kaikodata/canton-data-standard | tag `v0.3.0`, file `dars/` of the release | Apache-2.0 |
| `redstone-sdk-v1-0.5.0.dar` | RedStone Daml SDK: RedStone payload parsing and signature verification, which the RedStone verifier delegates to; carries `redstone-common-v1`, the time helpers it depends on | https://github.com/redstone-finance/redstone-oracles-monorepo, `packages/canton-connector/daml/sdk` and `packages/canton-connector/daml/common` | commit `8e598bd47b07d0bcec2c7cf4fa8e119f95d3b24c`, file `packages/canton-connector/daml/dars/` | Apache-2.0 |

| File | SHA-256 | Package id |
|---|---|---|
| `canton-data-standard-codecs-0.3.0.dar` | `20bb84687e7d934e9fcf61da452cbffa8e4e903926cbb6872226b52840a18500` | `cccab2f8a785db7ec2654c262f84ae8204201edf8e5f22f0197b933fd94e5523` |
| `canton-data-standard-datapoint-v1-0.3.0.dar` | `bec6c8a8fe929a341fb78bb24ff8596746961067396b8b5ef54ad6671c544a8d` | `80ee10cc9ab2356334b9f6d55c3b5742eee2c6a3790b9051a60438da729188a2` |
| `canton-data-standard-distributor-key-v1-0.3.0.dar` | `3309c760c2d982a62bf4682d78e555e3208f270c9c358af330caac663c9d1bf2` | `6fffac23d5c73948ee3ace6f0bf740322887e278ea9baa267e1e85875d05bff3` |
| `canton-data-standard-utils-v1-0.3.0.dar` | `e79dabe91c9aca5688dd9e245b952c8f0998a1dcc8f4093def61335d26d39161` | `6a4d4b88b1edf01be248dc23eccb4a027dfcb4de396c4a1cca761b359618243b` |
| `redstone-sdk-v1-0.5.0.dar` | `bb34cc0c62f1ffc8da4e24711ff37ef5c34ee832525488d5d9e8ac9c5850b318` | `b674a8f0959d47015c5d69df2cba31c0fe5d6abd17cdc73d9c3fea0aa0f7b30b` |

The Canton Data Standard files are byte-identical to the `dars/` directory of
its `v0.3.0` tag. Every CAPS package builds against this one version: a
package cannot build against two versions of an interface package.

The RedStone Daml SDK file is byte-identical to the one in the
[`packages/canton-connector/daml/dars/`][redstone-sdk-dars] directory of
[redstone-oracles-monorepo] at the commit above. Its sources are
`packages/canton-connector/daml/sdk` and
`packages/canton-connector/daml/common` at the same commit, licensed under
Apache-2.0 by their `LICENSE` files, so the RedStone verifier verifies against
the code RedStone publishes there.

[redstone-oracles-monorepo]: https://github.com/redstone-finance/redstone-oracles-monorepo
[redstone-sdk-dars]: https://github.com/redstone-finance/redstone-oracles-monorepo/tree/8e598bd47b07d0bcec2c7cf4fa8e119f95d3b24c/packages/canton-connector/daml/dars
