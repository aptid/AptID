# Apt.ID
Apt.ID is a name service built on Aptos! It is written in Move with following principles:
1. Least privilege: The Apt.ID protocol only has the following privileges:
   + Publish new Top-Level Domain (TLD). For example, initially we will launch the `*.apt`, and the reserve look-up domain `*.reverse`.
   + Approve or withdraw pricing strategies, naming rules, and registration requirement (e.g., commit-and-reveal, or merkle-proof) through the 'dynamic registrar' design.
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

Aptos Explorer links to deployed contracts:
+ [Devnet apt\_id packge](https://explorer.devnet.aptos.dev/account/0xc7050e4a5fce7292e0e7def652d70e79447fce2d6edb00a1e1fdb3d711978beb?network=Devnet) 
+ [Devnet dot\_apt\_tld packge](https://explorer.devnet.aptos.dev/account/0xfb3e8bc44d50e040c39bb7dc4cef28e93078e7c6bd3db16b05cac2a41ce2b5d8?network=Devnet) 

We are still working on the first draft implementation, so anything can be drastically changed.
Key features has been implemented and weekly deployed to devnet.

Implemented features are
1. Core module of AptID protocol: `apt_id`.
   + Add/Remove TLD registrars.
   + Register a name if approved by the corresponding TLD registrar.
   + Deposit and withdraw names and theirs events.
   + Direct transfer owned Name.
   + Update resource records.
   + Burn expired `Name` resource.
   + Getters for check the availability and the owner of a name.
2. Registrars (under `dot_apt_tld` package)
   + Sample `.apt` domain registrar `one_coin_registrar.move`: you can register a .apt name with
     one coin per day.
   + A `reverse_registrar` that allows any account to set `address.reverse` to a `*.apt` domain name.

Ongoing efforts:
1. More Getters for resource records.
2. More EventHandles.
3. Solution for linking name and aptos\_token (NFT). Currently aptos\_token can only be minted by owner,
   which might not be decentralized enough for a name service. Workarounds might be that to mint many token 
   upfront and link them with a Name upon registration. Different TLDs should be linked to different NFT collections.
4. Misc better-engineering items noted as TODO in code.
5. Reverse name must not be allowed to be *transfer* to others.
6. Direct transfer is enabled by default, we need to add a way to disable direct transfer.

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
6. Optional: If you are working on [aptid-ts](...), you can update `apt_id_abis.ts` file by `make ts-abi`.

## Random notes from hello_blockchain example.
1. Create a new directory as home for your local testnet `mkdir local-node && cd local-node`.
2. Start a local aptos node by `aptos node run-local-testnet --with-faucet`.
3. Enter hello\_blockchain example directory `cd aptos-core/aptos-move/move-examples/hello_blockchain`.
4. Run `aptos init` to generate a .aptos configuration folder under **current** working directory and 
   a config.yaml with a **default** profile. You will need to configure nodes to localhost:* for rest and faucet. 
   Alternatively, you can setup a local profile for CLI by:
   `aptos init --profile local --rest-url http://localhost:8080 --faucet-url http://localhost:8081`.
   Remember to use `--profile local` if you are not configuring aptos default.
5. try to (replacing ACCOUNT with the address you configured in config.yaml):
   1. compile: `aptos move compile --named-addresses hello_blockchain=0xACCOUNT`
   2. test: `aptos move test --named-addresses hello_blockchain=0xACCOUNT`
   3. publish: `aptos move publish --named-addresses hello_blockchain=0xACCOUNT`
   4. set message: `aptos move run --function-id 'XXX::message::set_message' --args 'string:hello, apt.id`
   5. query message: `curl http://localhost:8080/v1/accounts/ACCOUNT/resource/0xACCOUNT::message::MessageHolder` 
      (in their official tutorial they do not have 0x prefix in this part `accounts/ACCOUNT/resource`, 
      although adding the 0x prefix still seems to be okay.
   6. list events: `http://127.0.0.1:8080/v1/accounts/ACCOUNT/events/ACCOUNT::message::MessageHolder/message_change_events`.
   
NOTE: If you got simulation error, you might not have the right configuration. Aptos is very strict
in terms of move compiler version and 

   