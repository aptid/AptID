/// This module is a draft implementation of apt.id.
/// Key features have been implemented and ready for demo.
/// (1) register controller.
/// (2) domain NFT.
/// (3) a simple resolver that resolves names to an address.
/// There are still many undecided design choices:
/// (1) breaking: update hash schemma to drop bcs encoding.
/// (2) sub-domain support. We can support sub-domain using the same logics
///     as how we support different TLDs. BUT Current implementation does not
///     take this feature into account.
/// (3) anyway to specilize a drop-able table?
/// (4) TODO: Use reference instead of copy when possible.
/// (5) directly transfer is enabled by default.
/// (6) TODO: integration with 0x3::token: only creater can mint NFT is not acceptable
///           for apt_id. The module should only be able to set up rules of name registration.
module apt_id::apt_id {
    use std::error;
    use std::signer;
    use std::string::String;
    use std::vector;
    use std::bcs;
    use std::option;

    // ported to local package.
    use apt_id::iterable_table::{Self, IterableTable};

    use aptos_std::aptos_hash::keccak256 as hash_algo;
    use aptos_std::table::{Self, Table};
    use aptos_std::type_info;

    use aptos_framework::timestamp;
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};

    // **** internal errrors ****
    // subspace for internal errors: [0, 999]
    const EINTERNAL_BUG_CHECK: u64 = 0;
    const EINTERNAL_UNINITAILIZED_MISSING_OWNER_LIST: u64 = 1;
    const EINTERNAL_MISSING_TLD_REGISTRAR_TYPE_NAME: u64 = 2;

    /// Initialization of global owner mapping
    public entry fun init(mod_publisher: &signer) {
        require_mod_publisher(signer::address_of(mod_publisher));
        if (!exists<OwnerListStore>(@apt_id)) {
            move_to(mod_publisher, OwnerListStore {
                owners: table::new<NameID, address>(),
                deposit_events: account::new_event_handle<NameDepositEvent>(mod_publisher),
                withdraw_events: account::new_event_handle<NameWithdrawEvent>(mod_publisher),
            });
        };
        if (!exists<RegistrarStore>(@apt_id)) {
            move_to(mod_publisher, RegistrarStore { registrars: table::new() } );
        };
    }

    /// aborts if mod has not been correctly initialized.
    fun require_initialized() {
        assert!(
            exists<OwnerListStore>(@apt_id),
            error::internal(EINTERNAL_UNINITAILIZED_MISSING_OWNER_LIST)
        )
    }

    // ************ AptID Protocol Manager **********
    // NOTE: management with rootCap is NOT USED at this moment.
    // subspace for Protocol level management error: [1000, 1999]
    const ENOT_APT_ID_MOD_PUBLISHER: u64 = 1000;
    const EALREADY_APT_ID_ROOT_OWNER: u64 = 1001;
    const ENOT_APT_ID_ROOT_OWNER: u64 = 1002;

    struct RootCap has store, drop {}
    struct RootCapStore has key {
        root_cap: RootCap
    }

    /// returns true if @p addr has the root capability.
    public fun has_root_cap(addr: address): bool {
        exists<RootCapStore>(addr)
    }

    /// aborts if @p addr is not the publisher of this module.
    fun require_mod_publisher(addr: address) {
        assert!(
            addr == @apt_id,
            error::permission_denied(ENOT_APT_ID_MOD_PUBLISHER),
        );
    }

    /// aborts if @p addr does not have root cap.
    fun require_root(addr: address) {
        assert!(
            has_root_cap(addr),
            error::permission_denied(ENOT_APT_ID_ROOT_OWNER),
        );
    }

    /// give @p root_signer a RootCap, multisig required.
    public entry fun add_root_owner(mod_signer: &signer, root_signer: &signer) {
        require_mod_publisher(signer::address_of(mod_signer));
        assert!(
            !exists<RootCapStore>(signer::address_of(root_signer)),
            error::already_exists(ENOT_APT_ID_ROOT_OWNER),
        );
        move_to(root_signer, RootCapStore {
            root_cap: RootCap{},
        })
    }

    /// remove root cap from @p root_owner.
    public entry fun remove_apt_root_owner(
        mod_signer: &signer, root_owner: address) acquires RootCapStore {
        require_mod_publisher(signer::address_of(mod_signer));
        assert!(
            has_root_cap(root_owner),
            error::already_exists(ENOT_APT_ID_ROOT_OWNER),
        );
        // destroy root cap.
        let RootCapStore { root_cap: _ } = move_from<RootCapStore>(root_owner);
    }

    // ************ TLD Registrar **********
    // subspace for TLD registrar error: [2000, 2999]
    const ENOT_TLD_REGISTRAR: u64 = 2000;
    const EALREADY_TLD_REGISTRAR: u64 = 2001;

    /// Mapping from registrar module's `key` type name
    /// to the TLD under its management. Modules that can 'show' a valid type T
    /// to register<T> function are allowed to register name under their TLD.
    struct RegistrarStore has key {
        registrars: Table<String, NameID>,
    }

    /// aborts if T is not a qualified type for the permission of being a registrar.
    fun require_qualified_tld_registrar<T>(
        _: &T) acquires RegistrarStore {
        let t_name = type_info::type_name<T>();
        assert!(
            table::contains(
                &borrow_global<RegistrarStore>(@apt_id).registrars, t_name),
            error::permission_denied(ENOT_TLD_REGISTRAR),
        );
    }

    /// returns the NameID of the tld that @p keyType was qualified for.
    fun get_tld_of_registrar_type<T>(keyType: &T): NameID acquires RegistrarStore {
        require_qualified_tld_registrar(keyType);
        let t_name = type_info::type_name<T>();
        return *table::borrow(&borrow_global<RegistrarStore>(@apt_id).registrars, t_name)
    }

    /// Registrar module should call this function to become a qualified
    /// TLD registrar. Note that one TLD can have multiple regsitrars as
    /// the same time. They can encode different pricing, validation, and
    /// ACL strategies in their code. But One regsitrar cannot apply and
    /// become a qualified registrar of multiple TLDs.
    /// NOTE: This is not meant for allowing 3rd parties to become
    /// TLD registrar (all TLDs are **owned** by Apt.ID protocol).
    /// Instead, it empowers Apt.ID protocol to delegate
    /// pricing, validation to other trusted modules without introduce
    /// breaking changes to the core module.
    public fun onboard_tld_registrar<T>(
        mod_publisher: &signer,
        tld: String,
        _: &T) acquires RegistrarStore {
        require_mod_publisher(signer::address_of(mod_publisher));
        let tld_name_id = get_tld_lable_name_id(&tld);
        // add table entry
        table::upsert(
            &mut borrow_global_mut<RegistrarStore>(@apt_id).registrars,
            type_info::type_name<T>(),
            tld_name_id);
    }

    /// Registrar use this function to resign.
    public fun fire_tld_registrar_by_type<T>(
        mod_publisher: &signer,
        _: &T) acquires RegistrarStore {
        fire_tld_registrar(mod_publisher, type_info::type_name<T>())
    }

    /// fires a tld registrar without its cooperation. NOTE: emergency function,
    /// use when the account of registrar is compromised.
    public entry fun fire_tld_registrar(
        mod_publisher: &signer,
        type_name: String) acquires RegistrarStore {
        require_mod_publisher(signer::address_of(mod_publisher));
        assert!(
            table::contains(&borrow_global<RegistrarStore>(@apt_id).registrars, type_name),
            error::permission_denied(EINTERNAL_MISSING_TLD_REGISTRAR_TYPE_NAME),
        );
        table::remove(
            &mut borrow_global_mut<RegistrarStore>(@apt_id).registrars,
            type_name);
    }

    // ************ Name Registration **********
    // subspace for name registration error: [3000, 3999]
    const ENAME_NOT_AVAILABLE: u64 = 3000;
    const ENAME_EXPIRED: u64 = 3001;
    const ENAME_NOT_EXPIRED: u64 = 3002;
    const ENAME_NOT_OWNED_BY_ACCOUNT: u64 = 3003;
    const ENAME_REGISTER_EXPIRED_NAME: u64 = 3004;
    const ENAME_NON_TRANSFERABLE: u64 = 3005;
    const ENAME_DIRECT_TRANSFER_DISABLED: u64 = 3006;
    const ENAME_OWNER_STORE_UNINITIALIZED: u64 = 3007;

    /// Register a name under the TLD of @p T.
    /// For example, if the module of T is allowed to register names under 'apt' TLD,
    /// it can call this function with:
    ///   owner = user_address,
    ///   name  = "my",
    ///   expiredAt = 1668888888,
    /// to register a the 'my.apt' name under @p owner's account.
    /// NOTE: This function does not handle:
    /// (1) pricing.
    /// (2) name validatation.
    /// ACL through the ability to 'show' type T.
    /// Modules can obtain a resource of type T is the proof of being a qualified TLD owner.
    public fun register<T>(
        owner: &signer,
        name: String,
        expired_at: u64,
        transferable: bool,
        keyType: &T) acquires RegistrarStore, OwnerListStore, NameOwnerStore {
        let tld: NameID = get_tld_of_registrar_type(keyType);
        let new_name_id = get_name_id_of(&tld, &name);
        // the new name must not be owned by anyone.
        assert!(
            expired_at > now(),
            error::invalid_argument(ENAME_REGISTER_EXPIRED_NAME),
        );
        assert!(
            is_name_available(&new_name_id),
            error::invalid_argument(ENAME_NOT_AVAILABLE),
        );
        let name = Name {
            parent: tld,
            name: name,
            expired_at: expired_at,
            transferable: transferable,
            records: iterable_table::new<RecordKey, RecordValue>(),
        };
        collect_name(owner, name);
    }

    /// collect @p name to @p owner. If @p owner does not have NameOwnerStore initialized
    /// this function will also initialize it with signer's authority.
    /// NOTE: direct_transfer is enabled by default.
    public fun collect_name(
        owner: &signer,
        name: Name) acquires NameOwnerStore, OwnerListStore {
        let owner_addr = signer::address_of(owner);
        initialize_name_owner_store(owner);
        deposit_name_internal(owner_addr, name)
    }

    /// deposit @p name to @p owner_addr. Possible only when @p owner_addr enabled
    /// direct_transfer.
    public fun deposit_name(
        owner_addr: address,
        name: Name) acquires NameOwnerStore, OwnerListStore {
        assert!(
            exists<NameOwnerStore>(owner_addr),
            error::not_found(ENAME_OWNER_STORE_UNINITIALIZED),
        );
        let owner_store = borrow_global<NameOwnerStore>(owner_addr);
        assert!(
            owner_store.enable_direct_transfer,
            error::permission_denied(ENAME_DIRECT_TRANSFER_DISABLED));
        deposit_name_internal(owner_addr, name)
    }

    /// deposit name to @p owner_addr, private function.
    /// premise:
    /// (1) caller should check if OwnerStore is initialized.
    /// (2) caller should check if direct_transfer is enabled.
    /// Expired name can never be deposited.
    fun deposit_name_internal(
        owner_addr: address,
        name: Name) acquires NameOwnerStore, OwnerListStore {
        assert!(
            !is_name_expired(&name),
            error::permission_denied(ENAME_EXPIRED)
        );
        let name_id = get_name_id(&name);
        // move name to owner
        let owner_store = borrow_global_mut<NameOwnerStore>(owner_addr);
        iterable_table::add(&mut owner_store.names, name_id, name);
        // update name_id => address mapping.
        let owner_list_store = borrow_global_mut<OwnerListStore>(@apt_id);
        table::upsert(&mut owner_list_store.owners, name_id, owner_addr);
        // emit events
        event::emit_event<NameDepositEvent>(
            &mut owner_list_store.deposit_events,
            NameDepositEvent { id: name_id, to: owner_addr },
        );
    }

    /// withdraw the NAME of @p name_id from @p owner.
    public fun withdraw_name(
        owner: &signer,
        name_id: NameID) : Name acquires NameOwnerStore, OwnerListStore {
        let owner_addr = signer::address_of(owner);
        require_is_owner_of(owner_addr, name_id);
        // update name_id => address mapping.
        let owner_list_store = borrow_global_mut<OwnerListStore>(@apt_id);
        let _ = table::remove(&mut owner_list_store.owners, name_id);
        // emit events
        event::emit_event<NameWithdrawEvent>(
            &mut owner_list_store.withdraw_events,
            NameWithdrawEvent { id: name_id, from: owner_addr },
        );
        // update owner store
        let owner_store = borrow_global_mut<NameOwnerStore>(owner_addr);
        // extract name from owner store.
        let name = iterable_table::remove(
            &mut owner_store.names,
            name_id,
        );
        assert!(
            name.transferable,
            error::invalid_argument(ENAME_NON_TRANSFERABLE),
        );
        assert!(
            !is_name_expired(&name),
            error::not_found(ENAME_EXPIRED),
        );
        name
    }

    /// transfer @p name_id Name owned by @p from to @p to.
    /// TODO: Typescript tx builder does not support user-defined struct arg,
    /// so we destruct it into name and tld, instead of a NameID.
    public entry fun direct_transfer(from: &signer, to: address, name: String, tld: String)
        acquires NameOwnerStore, OwnerListStore {
        let name_id = get_name_id_of(&get_tld_lable_name_id(&tld), &name);
        let name = withdraw_name(from, name_id);
        deposit_name(to, name);
    }

    /// renew an unexpired name.
    /// TODO: allow user to renew name for names owned by others?
    public fun renew_name<T>(
        owner: &signer,
        name: String,
        additional_duration_seconds: u64,
        keyType: &T) acquires RegistrarStore, NameOwnerStore {
        let tld: NameID = get_tld_of_registrar_type(keyType);
        let name_id = get_name_id_of(&tld, &name);
        let owner_addr = signer::address_of(owner);
        assert!(
            exists<NameOwnerStore>(owner_addr),
            error::not_found(ENAME_OWNER_STORE_UNINITIALIZED),
        );
        let owner_store = borrow_global_mut<NameOwnerStore>(owner_addr);
        assert!(
            iterable_table::contains(&owner_store.names, name_id),
            error::not_found(ENAME_NOT_OWNED_BY_ACCOUNT),
        );
        let name = iterable_table::borrow_mut(&mut owner_store.names, name_id);
        // only unexpired name can be renewed.
        assert!(
            !is_name_expired(name),
            error::not_found(ENAME_EXPIRED),
        );
        name.expired_at = name.expired_at + additional_duration_seconds;
    }

    /// burn an expired name of @p expired_name_id in @p owner's store.
    public entry fun burn_expired_name(
        owner: &signer,
        expired_name_id: NameID) acquires NameOwnerStore {
        let owner_addr = signer::address_of(owner);
        assert!(
            exists<NameOwnerStore>(owner_addr),
            error::not_found(ENAME_OWNER_STORE_UNINITIALIZED),
        );
        let owner_store = borrow_global_mut<NameOwnerStore>(owner_addr);
        assert!(
            iterable_table::contains(&owner_store.names, expired_name_id),
            error::not_found(ENAME_NOT_OWNED_BY_ACCOUNT),
        );
        let name = iterable_table::borrow(&owner_store.names, expired_name_id);
        // only expired name can be burned.
        assert!(
            is_name_expired(name),
            error::not_found(ENAME_NOT_EXPIRED),
        );
        let Name {
            parent: _,
            name: _,
            expired_at: _,
            transferable: _,
            records,
        } = iterable_table::remove(
            &mut owner_store.names,
            expired_name_id,
        );
        destory_iterable_table(records)
    }

    /// initialize a name owner store for @p account.
    public entry fun initialize_name_owner_store(account: &signer) {
        if (!exists<NameOwnerStore>(signer::address_of(account))) {
            move_to(
                account,
                NameOwnerStore {
                    names: iterable_table::new(),
                    enable_direct_transfer: true,

                },
            );
        }
    }

    /// set direct transfer flag of @p account to @p is_enabled.
    public entry fun set_direct_transfer_flag(
        account: &signer,
        is_enabled: bool) acquires NameOwnerStore {
        let owner_addr = signer::address_of(account);
        assert!(
            exists<NameOwnerStore>(owner_addr),
            error::not_found(ENAME_OWNER_STORE_UNINITIALIZED),
        );
        let owner_store = borrow_global_mut<NameOwnerStore>(owner_addr);
        owner_store.enable_direct_transfer = is_enabled;
    }

    // ****** Name ******
    /// resouce record key.
    struct RecordKey has copy, store, drop {
        name: String,
        type: String,
    }
    // resource record value.
    struct RecordValue has copy, store, drop {
        value: String,
        ttl: u64,
    }

    public fun new_record_key(name: String, type: String): RecordKey {
        return RecordKey { name: name, type: type }
    }

    public fun new_record_value(value: String, ttl: u64): RecordValue {
        return RecordValue { ttl: ttl, value: value }
    }
    // TODO: add getters for record key and value.

    /// resource type of name
    /// Owner of the domain will hold this resources under NameStore.
    /// (1) upon deposit, the mapping from nameID to owner managed by register
    ///     needs to be changed.
    /// (2) expired names can only be burned.
    /// (3) unexpired names cannot be burned.
    /// (4) TLD names will have empty parent hash.
    struct Name has store {
        parent: NameID,
        name: String,
        expired_at: u64,    // timestamp of expiration
        transferable: bool,
        records: IterableTable<RecordKey, RecordValue>,
        // TODO:
        // records update events?
    }

    struct NameOwnerStore has key {
        /// Mapping name hash to actual name.
        /// Name Owners store their domain use this Store under their account.
        names: IterableTable<NameID, Name>,
        enable_direct_transfer: bool,
    }

    struct NameDepositEvent has drop, store {
        id: NameID,
        to: address,
    }

    struct NameWithdrawEvent has drop, store {
        id: NameID,
        from: address,
    }

    struct OwnerListStore has key {
        /// Mapping a name hash to the address of its owner.
        owners: Table<NameID, address>,
        deposit_events: EventHandle<NameDepositEvent>,
        withdraw_events: EventHandle<NameWithdrawEvent>,
    }

    /// The ID of any name, including TLDs.
    struct NameID has store, copy, drop {
        hash: vector<u8>,
    }

    /// returns the NameID of 'name.tld'
    public fun get_name_id_of(tld: &NameID, name: &String): NameID {
        let lable = hash_algo(bcs::to_bytes(name));
        let hash = *&tld.hash;
        vector::append(&mut hash, lable);
        NameID { hash: hash_algo(hash) }
    }

    /// returns NameID of @p name
    public fun get_name_id(name: &Name): NameID {
        get_name_id_of(&name.parent, &name.name)
    }

    /// returns the NameID of the tld lable @p lable.
    public fun get_tld_lable_name_id(lable: &String): NameID {
        NameID { hash: hash_algo(bcs::to_bytes(lable)) }
    }

    /// returns true if the name has been expired.
    public fun is_name_expired(name: &Name): bool {
        name.expired_at < now()
    }

    /// returns true when the name can be registered:
    /// (1) the name has not been registered, or
    /// (2) previous registration has been expired.
    public fun is_name_available(
        name_id: &NameID): bool acquires OwnerListStore, NameOwnerStore {
        require_initialized();
        let owner_store = borrow_global<OwnerListStore>(@apt_id);
        if (table::contains(&owner_store.owners, *name_id)) {
            let owner = table::borrow(&owner_store.owners, *name_id);
            let name_store = borrow_global<NameOwnerStore>(*owner);
            is_name_expired(iterable_table::borrow(&name_store.names, *name_id))
        } else {
            true
        }
    }

    /// returns true if @p addr is the owner of name_id.
    public fun is_owner_of(
        addr: address,
        name_id: NameID): bool acquires NameOwnerStore {
        if (!exists<NameOwnerStore>(addr)) {
            return false
        };
        let owner_store = borrow_global<NameOwnerStore>(addr);
        if (!iterable_table::contains(&owner_store.names, name_id)) {
            return false
        };
        let name = iterable_table::borrow(&owner_store.names, name_id);
        // expired names are considered to be not-owned by the account.
        if (is_name_expired(name)) {
            return false
        };
        true
    }

    /// abort if @p addr is not the owner of @p name_id.
    fun require_is_owner_of(
        addr: address,
        name_id: NameID) acquires NameOwnerStore {
        assert!(
            is_owner_of(addr, name_id),
            error::not_found(ENAME_NOT_OWNED_BY_ACCOUNT),
        )
    }

    /// upsert record to owner's name.
    public entry fun upsert_record(
        owner: &signer,
        tld: String,
        name: String,
        record_name: String,
        record_type: String,
        ttl: u64,
        value: String,
    ) acquires NameOwnerStore {
        let owner_addr = signer::address_of(owner);
        let name_id = get_name_id_of(&get_tld_lable_name_id(&tld), &name);
        require_is_owner_of(owner_addr, name_id);
        let owner_store = borrow_global_mut<NameOwnerStore>(owner_addr);
        let name = iterable_table::borrow_mut(&mut owner_store.names, name_id);
        let key = RecordKey { name: record_name, type: record_type };
        let new_val = RecordValue { value : value, ttl: ttl };
        if (iterable_table::contains(&name.records, key)) {
            let val_ref = iterable_table::borrow_mut(&mut name.records, key);
            *val_ref = new_val;
        } else {
            iterable_table::add(&mut name.records, key, new_val);
        }
    }

    /// returns a string of the corresponding record.
    public entry fun get_record(
        owner_addr: address,
        name_id: NameID,
        record_name: String,
        record_type: String,
    ) : (String, u64) acquires NameOwnerStore {
        require_is_owner_of(owner_addr, name_id);
        let owner_store = borrow_global<NameOwnerStore>(owner_addr);
        let name = iterable_table::borrow(&owner_store.names, name_id);
        let key = RecordKey { name: record_name, type: record_type };
        let record = iterable_table::borrow(&name.records, key);
        (record.value, record.ttl)
    }

    // ******* utils *******
    public fun now(): u64 {
        timestamp::now_seconds()
    }

    fun destory_iterable_table<K: copy + store + drop, V: store + drop>(
        table: IterableTable<K, V>
    ) {
        let key = iterable_table::head_key(&table);
        while (option::is_some(&key)) {
            let (_, _, next) = iterable_table::remove_iter(
                &mut table, *option::borrow(&key));
            key = next;
        };
        iterable_table::destroy_empty(table);
    }

    // #[test(account = @apt_id)]
    // public entry fun can_add_tld_registrar(account: signer) {
    //     let addr = signer::address_of(&account);
    //     aptos_framework::account::create_account_for_test(addr);
    // }
}
