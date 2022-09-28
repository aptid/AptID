NAME=AptID
LOCAL_TEST_OWNER=0xf71cb5dc58c4290a2cc009ba5c87f389ca624e1d6b9b9135c2b4c43c1bb69cb6
DEVNET_APT_ID=0xd6f8440eabd59bfc0ca6dcf7bf864d206e9825e264faf14188af68a72f500bb9
DEVNET_DOT_APT_TLD_REGISTRAR=0x8add34212cbe560856ac610865f9bc2e4ac49b65739d58e7f2c87125d73bad02
TESTNET_APT_ID=0xd6f8440eabd59bfc0ca6dcf7bf864d206e9825e264faf14188af68a72f500bb9
TESTNET_DOT_APT_TLD_REGISTRAR=0x8add34212cbe560856ac610865f9bc2e4ac49b65739d58e7f2c87125d73bad02

.PHONY: build-aptos-cli
build-aptos-cli:
	cd aptos-core && cargo build --package aptos --release

.PHONY:
install-aptos-cli:
	cp ./aptos-core/target/release/aptos ~/.cargo/bin/

.PHONY: run-local-node
run-local-node:
	aptos node run-local-testnet --with-faucet # somehow test-dir option does not work: --test-dir local-node/

.PHONY: unsafe-purge-local-node
unsafe-purge-local-node:
	rm -rf .aptos/testnet

.PHONY: faucet
faucet:
	aptos account fund-with-faucet --account $(LOCAL_TEST_OWNER)

.PHONY: compile
compile:
	cd contracts/apt_id && aptos move compile --save-metadata --included-artifacts all
	cd contracts/dot_apt_tld && aptos move compile --save-metadata --included-artifacts all

.PHONY: local-publish
local-publish:
	cd contracts/apt_id && aptos move publish
	cd contracts/dot_apt_tld && aptos move publish

# premise: setup correct address in Move.toml
.PHONY: devnet-publish
devnet-publish:
	cd contracts/apt_id && aptos move publish --profile apt_id
	cd contracts/dot_apt_tld && aptos move publish --profile apt_tld

# premise: setup correct address in Move.toml
.PHONY: testnet-publish
testnet-publish:
	cd contracts/apt_id && aptos move publish --profile apt_id
	cd contracts/dot_apt_tld && aptos move publish --profile apt_tld

.PHONY: devnet-faucet
devnet-faucet:
	aptos account fund-with-faucet --account $(DEVNET_APT_ID)
	aptos account fund-with-faucet --account $(DEVNET_DOT_APT_TLD_REGISTRAR)

.PHONY: testnet-faucet
testnet-faucet:
	aptos account fund-with-faucet --account $(TESTNET_APT_ID)
	aptos account fund-with-faucet --account $(TESTNET_DOT_APT_TLD_REGISTRAR)

.PHONY: test
test:
	cd contracts/apt_id && aptos move test
	cd contracts/dot_apt_tld && aptos move test

# .PHONY: local-prove
# prove:
# 	cd contract && aptos move prove

define append_abi_hex_str
	cat $(1)  | od -v -t x1 -A n | tr -d ' \n' >> $(2)
	echo "" >> $(2)
endef

.PHONY: ts-abi
ts-abi:
	rm -f apt_id.abi
	$(call append_abi_hex_str,contracts/dot_apt_tld/build/DotAptTLD/abis/one_coin_registrar/onboard.abi,apt_id.abi)
	$(call append_abi_hex_str,contracts/dot_apt_tld/build/DotAptTLD/abis/one_coin_registrar/resign.abi,apt_id.abi)
	$(call append_abi_hex_str,contracts/dot_apt_tld/build/DotAptTLD/abis/one_coin_registrar/register_script.abi,apt_id.abi)
	$(call append_abi_hex_str,contracts/dot_apt_tld/build/DotAptTLD/abis/one_coin_registrar/renew_script.abi,apt_id.abi)

	$(call append_abi_hex_str,contracts/dot_apt_tld/build/DotAptTLD/abis/reverse_registrar/onboard.abi,apt_id.abi)
	$(call append_abi_hex_str,contracts/dot_apt_tld/build/DotAptTLD/abis/reverse_registrar/resign.abi,apt_id.abi)
	$(call append_abi_hex_str,contracts/dot_apt_tld/build/DotAptTLD/abis/reverse_registrar/set_reversed_name_script.abi,apt_id.abi)

	$(call append_abi_hex_str,contracts/apt_id/build/AptID/abis/apt_id/init.abi,apt_id.abi)
	$(call append_abi_hex_str,contracts/apt_id/build/AptID/abis/apt_id/direct_transfer.abi,apt_id.abi)
	$(call append_abi_hex_str,contracts/apt_id/build/AptID/abis/apt_id/burn_expired_name.abi,apt_id.abi)
	$(call append_abi_hex_str,contracts/apt_id/build/AptID/abis/apt_id/fire_tld_registrar.abi,apt_id.abi)
	$(call append_abi_hex_str,contracts/apt_id/build/AptID/abis/apt_id/initialize_name_owner_store.abi,apt_id.abi)
	$(call append_abi_hex_str,contracts/apt_id/build/AptID/abis/apt_id/upsert_record.abi,apt_id.abi)
	python3 gen_ts_abi.py apt_id.abi > apt_id_abis.ts
	rm -f apt_id.abi
