module nft_standard::utils {

    use std::type_name;
    use std::ascii;
    use sui::hex;
    use sui::address;
    use version::version::{Self, Version};

    const VERSION: u64 = 0;
    const EINVALID_VERSION: u64 = 0;

    struct UTILS has drop {}

    public fun from_same_package<T, W>(): bool {
        let type_t = type_name::get<T>();
        let type_w = type_name::get<W>();

        (type_name::get_address(&type_t) == type_name::get_address(&type_w))
    }

    public fun check_version(version: &Version) {
        let type_ = type_name::get<UTILS>();
        let package_id =
            address::from_bytes(hex::decode(*ascii::as_bytes(&type_name::get_address(&type_))));
        let version_current = version::get(version, package_id);
        assert!(version_current == VERSION, EINVALID_VERSION);
    }




}
