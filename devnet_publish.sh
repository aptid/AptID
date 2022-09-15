set -x;
if [ -z "$(git status --porcelain)" ]; then 
    cp contracts/apt_id/devnet_Move.toml contracts/apt_id/Move.toml
    cp contracts/dot_apt_tld/devnet_Move.toml contracts/dot_apt_tld/Move.toml
    make compile
    make ts-abi
    mv apt_id_abis.ts apt_id_abis_devnet.ts
    cp devnet/.aptos/config.yaml ./.aptos/config.yaml
    make devnet-faucet
    make devnet-publish
    git checkout -- .
else
    echo "CANNOT PUBLISH: git status not clean"
fi

