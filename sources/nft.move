module nft_standard::souffl3 {

    use std::vector;
    use sui::address;
    use sui::package;
    use sui::transfer;
    use sui::object::{Self, UID};
    use std::string::{utf8, String};
    use sui::vec_map::{Self, VecMap};
    use sui::display::{Self, Display};
    use sui::tx_context::{TxContext};
    use nft_standard::utils::{check_version, from_same_package};
    use version::version::Version;
    use sui::package::Publisher;
    use sui::tx_context;
    use version::version;
    use nft_protocol::mint_cap::MintCap;
    use sui::transfer_policy;
    use sui::transfer::{public_share_object, public_transfer};
    use kiosk::royalty_rule;

    const ENOT_ADMIN: u64 = 0;
    const ENOT_ALLOWED_TO_BURN: u64 = 1;
    const ENOT_ALLOWED_TO_MUTATE: u64 = 2;


    struct NFT<phantom T> has key, store {
        id: UID,
        index: u64,
        name: String,
        image_url: String,
        properties: VecMap<String, String>
    }

    struct SharedPublisher has key, store {
        id: UID,
        publisher: Publisher
    }

    /// One time witness is only instantiated in the init method
    struct SOUFFL3 has drop {}

    fun init(witness: SOUFFL3, ctx: &mut TxContext) {
        let publisher = package::claim(witness, ctx);

        let shared_publisher = SharedPublisher {
            id: object::new(ctx),
            publisher
        };
        transfer::public_share_object(shared_publisher);
    }

    public fun create_display<T>(
        version: &Version,
        _cap: &MintCap<T>,
        publisher: &SharedPublisher,
        ctx: &mut TxContext
    ): Display<NFT<T>> {

        check_version(version);

        let display_t = display::new<NFT<T>>(&publisher.publisher, ctx);
        display::add<NFT<T>>(&mut display_t, utf8(b"name"), utf8(b"{name}"));
        display::add<NFT<T>>(&mut display_t, utf8(b"image_url"), utf8(b"{image_url}"));
        display::add<NFT<T>>(&mut display_t, utf8(b"thumbnail_url"), utf8(b"{image_url}"));
        display::update_version(&mut display_t);

        display_t

    }

    public entry fun create_then_set_display_and_transfer_policy_then_royalty_rule_v1<T>(
        version: &Version,
        cap: &MintCap<T>,
        publisher: &SharedPublisher,
        collection_name: String,
        cover_image_url: String,
        symbol: String,
        description: String,
        creator: address,
        display_name: String,
        display_value: String,
        royalty_bps: u16,
        royalty_min_amount: u64,
        ctx: &mut TxContext
    ) {

        check_version(version);
        let sender = tx_context::sender(ctx);
        let display = create_display(version, cap, publisher, ctx);
        set_collection_info(
            version,
            &mut display,
            collection_name,
            cover_image_url,
            symbol,
            description,
            creator,
            ctx
        );
        display::add<NFT<T>>(&mut display, display_name, display_value);
        let (policy, policy_cap) = transfer_policy::new<NFT<T>>(&publisher.publisher, ctx);
        royalty_rule::add(&mut policy, &mut policy_cap, royalty_bps, royalty_min_amount);

        public_share_object(policy);
        public_transfer(display, sender);
        public_transfer(policy_cap, sender);

    }


    public entry fun create_then_set_display_and_transfer_policy_then_royalty_rule<T>(
        version: &Version,
        cap: &MintCap<T>,
        publisher: &SharedPublisher,
        display_name: String,
        display_value: String,
        royalty_bps: u16,
        royalty_min_amount: u64,
        ctx: &mut TxContext
    ) {

        check_version(version);
        let sender = tx_context::sender(ctx);
        let display = create_display(version, cap, publisher, ctx);
        display::add<NFT<T>>(&mut display, display_name, display_value);
        display::update_version(&mut display);
        let (policy, policy_cap) = transfer_policy::new<NFT<T>>(&publisher.publisher, ctx);
        royalty_rule::add(&mut policy, &mut policy_cap, royalty_bps, royalty_min_amount);

        public_share_object(policy);
        public_transfer(display, sender);
        public_transfer(policy_cap, sender);

    }

    public fun mint_nft_with_cap<T>(
        version: &Version,
        index: u64,
        name: String,
        image_url: String,
        _mint_cap: &MintCap<T>,
        property_keys: vector<String>,
        property_values: vector<String>,
        ctx: &mut TxContext,
    ): NFT<T> {
        check_version(version);
        let len = vector::length(&property_keys);
        assert!(len == vector::length(&property_values), 1);

        let properties = vec_map::empty<String, String>();
        let i = 0;
        while (i < len) {
            let key = vector::pop_back(&mut property_keys);
            let val = vector::pop_back(&mut property_values);
            vec_map::insert(&mut properties, key, val);
            i = i + 1;
        };

        NFT<T> {
            id: object::new(ctx),
            index,
            name,
            image_url,
            properties
        }
    }

    public fun set_collection_info<T>(
        version: &Version,
        display: &mut Display<NFT<T>>,
        collection_name: String,
        cover_image_url: String,
        symbol: String,
        description: String,
        creator: address,
        _ctx: &mut TxContext
    ) {

        check_version(version);

        display::add<NFT<T>>(display, utf8(b"collection_name"), collection_name);
        display::add<NFT<T>>(display, utf8(b"collection_image"), cover_image_url);
        display::add<NFT<T>>(display, utf8(b"symbol"), symbol);
        display::add<NFT<T>>(display, utf8(b"creator"), address::to_string(creator));
        display::add<NFT<T>>(display, utf8(b"description"), description);
        display::update_version(display);

    }

    fun publisher_borrow(publisher: &SharedPublisher): &Publisher {
        &publisher.publisher
    }

    public fun new_version(shared_publisher: &SharedPublisher, version: &mut Version, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(sender == @admin, ENOT_ADMIN);
        let publisher = publisher_borrow(shared_publisher);
        version::add(publisher, version);
    }

    public fun set_version(shared_publisher: &SharedPublisher, version: &mut Version, version_num: u64, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(sender == @admin, ENOT_ADMIN);
        let publisher = publisher_borrow(shared_publisher);
        version::set(publisher, version, version_num);
    }

    public fun burn<C, W: drop>(_witness: W, nft: NFT<C>) {
        assert!(from_same_package<C, W>(), ENOT_ALLOWED_TO_BURN);
        let NFT<C> {
            id,
            index: _,
            name: _,
            image_url: _,
            properties: _
        } = nft;
        object::delete(id);
    }

    public fun mutate_name_and_image_url<C, W: drop>(
        _witness: W,
        nft: &mut NFT<C>,
        name: String,
        image_url: String
    ) {
        assert!(from_same_package<C, W>(), ENOT_ALLOWED_TO_MUTATE);
        nft.name = name;
        nft.image_url = image_url;
    }
}
