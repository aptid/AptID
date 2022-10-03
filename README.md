# Apt.ID
Apt.ID is a name service built on Aptos! It is written in Move with following principles:
1. Least privilege: The Apt.ID protocol only has the following privileges:
   + Publish new Top-Level Domain (TLD). For example, initially we will launch the `*.apt`, and the reserve look-up domain `*.reverse`.
   + Approve or withdraw pricing strategies, naming rules, and registration requirements (e.g., commit-and-reveal, or merkle-proof) through the 'dynamic registrar' design.
2. Flexible registrars: registration workflows can be very different for different TLDs, and also for different stages during public launch. Upgrading registrars should
   not touch the main protocol. We leverages Move's type system to enforce ACL rules between modules. See diagram below.
3. You Own The Name: Once you have got the name, you own the name. You can freely transfer it, or update records. The Apt.ID protocol does not have the power to stop you.
   The main protocol will be have `upgrade_policy = "immutable"` upon public launch. `Registrars` can be upgraded separately.
4. Static and simple: Move does not have any form of dynamic dispatch. So unlike name services on other blockchains, which usually allow the owner to configure a resolver
   for the name, Apt.ID protocol simply attaches an `iterable_table<RecordKey, RecordValue>` to a Name for the owner to store resource records.
   Note that Aptos network allows you to run scripts in a transaction. You can encode dynamic behaviors into a script to achieve the same level of expressiveness.

Registration flow on the protocol level:
```
 ┌────┐                  ┌─────────┐                                     ┌──────┐
 │user│                  │registrar│                                     │apt_id│
 └─┬──┘                  └────┬────┘                                     └──┬───┘
   │                          │                                             │
   │                          │                  onboard()                  │
   │                          │────────────────────────────────────────────>│
   │                          │                                             │
   │                          │     approve by save the secret type T.      │
   │                          │<────────────────────────────────────────────│
   │                          │                                             │
   │register(name, fee, proof)│                                             │
   │─────────────────────────>│                                             │
   │                          │                                             │
   │                          │register<T>(tld, validated_name, expiration.)│
   │                          │────────────────────────────────────────────>│
   │                          │                                             │
   │                          │  Name(name.tld)                             │
   │<───────────────────────────────────────────────────────────────────────│
 ┌─┴──┐                  ┌────┴────┐                                     ┌──┴───┐
 │user│                  │registrar│                                     │apt_id│
 └────┘                  └─────────┘                                     └──────┘
```

## Development status

We are on longevity testnet! Visit [Apt.id](https://apt.id/) to register your name!

Aptos Explorer links to deployed contracts:
+ [Testnet apt\_id packge](https://explorer.devnet.aptos.dev/account/0xd6f8440eabd59bfc0ca6dcf7bf864d206e9825e264faf14188af68a72f500bb9?network=Testnet)
+ [Testnet dot\_apt\_tld packge](https://explorer.devnet.aptos.dev/account/0x8add34212cbe560856ac610865f9bc2e4ac49b65739d58e7f2c87125d73bad02?network=Testnet)

We are still working on the first draft implementation, so anything can be drastically changed.

Implemented features are
1. Core module of AptID protocol: `apt_id`.
   + Add/Remove TLD registrars.
   + Register a name if approved by the corresponding TLD registrar.
   + Deposit and withdraw names and their events.
   + Direct transfer owned Name.
   + Update resource records.
   + Burn expired `Name` resource.
   + Getters for check the availability and the owner of a name.
2. Registrars (under `dot_apt_tld` package)
   + Sample `.apt` domain registrar `one_coin_registrar.move`: you can register or renew a .apt name at
     the price of 1000 coin amount per day.
   + A `reverse_registrar` that allows any account to set `address.reverse` to a `*.apt` domain name.

Ongoing efforts:
1. More Getters for resource records.
2. More EventHandles: record update events.
3. Solution for linking name and aptos\_token (NFT). Currently aptos\_token can only be minted by owner,
   which might not be decentralized enough for a name service. Workarounds might be that to mint many token
   upfront and link them with a Name upon registration. Different TLDs should be linked to different NFT collections.
4. Misc better-engineering items noted as TODO in code.

# Developer guide
## Install aptos core utils
```
# we use version-locked git submodule aptos-core to install dependencies.
git submodule update --init --recursive
cd aptos-core
```
Follow this [install-aptos-cli-from-git](https://aptos.dev/cli-tools/aptos-cli-tool/install-aptos-cli/#install-from-git) to install aptos CLI.
We will run our local testnet using the `devnet` branch, which is already locked through git submodule.

NOTE: 32GB RAM is not enough to run 24 threads for compilation. use `-jN` to limit the number of threads to avoid OOM.

optional: Copy binary to a directory under PATH for ease-of-use.
```
cp ./target/release/aptos ~/.cargo/bin/
```

## Let's go!
A test account config is attached in this repository. It will be our module publisher for the local devnet.
Its config is saved at `.aptos/config.yaml`.

We have most of commonly used commands saved in Makefile. The workflow is:
1. Start local Aptos node by `make run-local-node`. If you have made breaking changes to contracts,
   you need to `make purge-local-node` to start from a clean state.
2. Compile contracts by `make compile`. The test account address is configured to be the default address for all packages.
3. You will need to run `make faucet` to fund the test account if you are starting from a clean state.
   You might need to run it **multiple** times as our contracts might requires more coins than one free try:).
4. Publish all packages to the local node by `make local-publish`. It will publish both the main AptID protocol module
   and all registrars.
5. You can visit Aptos explore and swtich to `local` to see trasactions of the test account:
   [Aptos explore for the test account](https://explorer.devnet.aptos.dev/account/0xf71cb5dc58c4290a2cc009ba5c87f389ca624e1d6b9b9135c2b4c43c1bb69cb6?network=local)
6. Optional: If you are working on [aptid-client-ts](https://github.com/aptid/aptid-client-ts), you can update `apt_id_abis.ts` file by `make ts-abi`.
