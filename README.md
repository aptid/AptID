# Apt.ID

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
   [Aptos explore for the test account](https://explorer.devnet.aptos.dev/account/0xf71cb5dc58c4290a2cc009ba5c87f389ca624e1d6b9b9135c2b4c43c1bb69cb6)

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

   