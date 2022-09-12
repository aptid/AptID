/// This module is demo registrar for TLD `.apt` that you can register
/// a *.apt name with 1 aptos coin for 1 day.
module dot_apt_registrar::one_coin_registrar {
    use std::error;
    use std::string::{Self, String};

    use aptos_framework::coin;
    use aptos_framework::aptos_coin;

    use apt_id::apt_id;

    struct OneCoinRegistrar has drop {}

    const EZERO_COIN_NOW_ALLOWED: u64 = 3000;

    public fun tld(): String {
        string::utf8(b"apt")
    }

    public fun revenue_account(): address {
        @dot_apt_registrar
    }

    public entry fun onboard(apt_id_owner: &signer) {
        apt_id::onboard_tld_registrar(
            apt_id_owner, tld(), &OneCoinRegistrar{});
    }

    public entry fun resign(apt_id_owner: &signer) {
        apt_id::fire_tld_registrar_by_type(
            apt_id_owner, &OneCoinRegistrar{});
    }

    public entry fun register_script(
        owner: &signer,
        amount: u64,
        name: String) {
        assert!(
            amount > 0,
            error::invalid_argument(EZERO_COIN_NOW_ALLOWED),
        );
        // TODO: a native utf-8 rune count function would be good,
        // if not, we will implement a simple one in move.
        coin::transfer<aptos_coin::AptosCoin>(owner, revenue_account(), amount);
        register(owner, name, amount * 3600 * 24)
    }

    fun register(
        owner: &signer,
        name: String,
        duration: u64,
        ) {
        apt_id::register(
            owner,
            name,
            apt_id::now() + duration,
            &OneCoinRegistrar{});
    }
}
