/// This module is demo registrar for TLD `.apt` that you can register
/// a *.apt name with 1000 aptos coin amount for 1 day.
module dot_apt_registrar::one_coin_registrar {
    use std::error;
    use std::string::{Self, String};

    use aptos_framework::coin;
    use aptos_framework::aptos_coin;

    use apt_id::apt_id;

    struct OneCoinRegistrar has drop {}

    const EZERO_COIN_NOW_ALLOWED: u64 = 3000;

    public fun price(): u64 {
        1000
    }

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
        // round down to N * price, the base unit.
        amount = amount / price() * price();
        assert!(
            amount > 0,
            error::invalid_argument(EZERO_COIN_NOW_ALLOWED),
        );
        let duration = 24 * 3600 * (amount / price());
        // TODO: a native utf-8 rune count function would be good,
        // if not, we will implement a simple one in move.
        coin::transfer<aptos_coin::AptosCoin>(owner, revenue_account(), amount);
        register(owner, name, duration)
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
            true,
            &OneCoinRegistrar{});
    }

    public entry fun renew_script(
        owner: &signer,
        amount: u64,
        name: String) {
        amount = amount / price() * price();
        assert!(
            amount > 0,
            error::invalid_argument(EZERO_COIN_NOW_ALLOWED),
        );
        let duration = 24 * 3600 * (amount / price());
        coin::transfer<aptos_coin::AptosCoin>(owner, revenue_account(), amount);
        apt_id::renew_name(owner, name, duration, &OneCoinRegistrar{});
    }
}
