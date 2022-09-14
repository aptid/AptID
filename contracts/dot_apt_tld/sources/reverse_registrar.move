/// This module is the registrar for the reversed-look-up service that
/// maps addresses to `*.apt` names. Account owner can set "0xaddress.reverse"'s
/// (.apt, TXT) record to a *.apt name.
module dot_apt_registrar::reverse_registrar {
    // use std::error;
    use std::signer;
    use std::string::{Self, String};
    use std::bcs;
    use std::vector;
    use apt_id::apt_id;

    const DURATION_1000_YEARS: u64 = 1000 * 365 * 24 * 3600;
    const EUNIMPLEMENTED: u64 = 0;

    struct ReverseRegistrar has drop {}

    public fun tld(): String {
        string::utf8(b"reverse")
    }

    public entry fun onboard(apt_id_owner: &signer) {
        apt_id::onboard_tld_registrar(
            apt_id_owner, tld(), &ReverseRegistrar{});
    }

    public entry fun resign(apt_id_owner: &signer) {
        apt_id::fire_tld_registrar_by_type(
            apt_id_owner, &ReverseRegistrar{});
    }

    public entry fun set_reversed_name_script(
        owner: &signer,
        reversed_name: String) {
        let name_id = register_if_not_exists(owner);
        apt_id::upsert_record(owner, name_id,
            string::utf8(b".apt"), string::utf8(b"TXT"), 600, reversed_name);
    }

    fun register_if_not_exists(
        owner: &signer): apt_id::NameID {
        let addr = signer::address_of(owner);
        let name_str = address_to_hex(addr);
        let tld_name_id = apt_id::get_tld_lable_name_id(&tld());
        let name_id = apt_id::get_name_id_of(&tld_name_id, &name_str);
        if (!apt_id::is_owner_of(addr, name_id)) {
            apt_id::register(
                owner,
                name_str,
                apt_id::now() + DURATION_1000_YEARS,
                false,
                &ReverseRegistrar{});
        };
        name_id
    }

    /// returns hex-encoded string of @p addr.
    /// TODO: we should replace this function when there is a
    /// native implementation of address hex encoding.
    fun address_to_hex(addr: address) : String {
        let hex_chars: vector<u8> = b"0123456789ABCDEF";
        let bytes = bcs::to_bytes(&addr);
        let char_vec = vector::empty<u8>();
        while (vector::length(&bytes) > 0) {
            let v: u8 = vector::pop_back(&mut bytes);
            let mod = *vector::borrow(&hex_chars, ((v % 16) as u64));
            let div = *vector::borrow(&hex_chars, ((v / 16) as u64));
            vector::push_back(&mut char_vec, (mod as u8));
            vector::push_back(&mut char_vec, (div as u8));
        };
        vector::reverse(&mut char_vec);
        string::utf8(char_vec)
    }

    #[test(addr = @0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)]
    fun test_address_to_hex(addr: address) {
        let rst = address_to_hex(addr);
        assert!(vector::length(string::bytes(&rst)) == 64, 1);
        assert!(*vector::borrow(string::bytes(&rst), 11) == 70, 1); // 'F' is 70
    }

}
