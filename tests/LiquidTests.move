#[test_only]
module MultiSwap::LiquidTests {
    use Std::Option;
    use Std::Signer;

    use AptosFramework::Coin::{Self, MintCapability, BurnCapability};
    use AptosFramework::Genesis;
    use AptosFramework::Timestamp;

    use MultiSwap::Liquid::{Self, LAMM};

    struct MintCap has key { mint_cap: MintCapability<LAMM> }

    struct BurnCap has key { burn_cap: BurnCapability<LAMM> }

    #[test(core_resource = @CoreResources, admin = @MultiSwap, user = @0x43)]
    fun test_mint_burn_with_functions(core_resource: signer, admin: signer, user: signer) {
        Genesis::setup(&core_resource);
        Liquid::initialize(&admin);
        Coin::register_internal<LAMM>(&user);

        let user_addr = Signer::address_of(&user);
        Liquid::mint_internal(&admin, user_addr, 100);
        assert!(Coin::balance<LAMM>(user_addr) == 100, 1);

        let lamm_coins = Coin::withdraw<LAMM>(&user, 50);
        Liquid::burn_internal(&admin, lamm_coins);
        assert!(Coin::supply<LAMM>() == Option::some(50), 2);
    }

    #[test(core_resource = @CoreResources, admin = @MultiSwap)]
    fun test_mint_burn_with_caps(core_resource: signer, admin: signer) {
        Genesis::setup(&core_resource);
        Liquid::initialize(&admin);

        let mint_cap = Liquid::get_mint_cap(&admin);
        let lamm_coins = Coin::mint(100, &mint_cap);

        let burn_cap = Liquid::get_burn_cap();
        Coin::burn(lamm_coins, &burn_cap);

        move_to(&admin, MintCap { mint_cap });
        Coin::destroy_burn_cap(burn_cap);
    }

    #[test(core_resource = @CoreResources, admin = @MultiSwap)]
    #[expected_failure(abort_code = 101)]
    fun test_cannot_get_mint_cap_if_locked(core_resource: signer, admin: signer) {
        Genesis::setup(&core_resource);
        Liquid::initialize(&admin);

        Liquid::lock_minting_internal(&admin);
        // failure here, need to store mint_cap somewhere anyway, otherwise it won't compile
        let mint_cap = Liquid::get_mint_cap(&admin);
        move_to(&admin, MintCap { mint_cap });
    }

    #[test(core_resource = @CoreResources, admin = @MultiSwap)]
    #[expected_failure(abort_code = 101)]
    fun test_cannot_mint_if_locked(core_resource: signer, admin: signer) {
        Genesis::setup(&core_resource);
        Liquid::initialize(&admin);

        Liquid::lock_minting_internal(&admin);
        // failure here
        Liquid::mint_internal(&admin, Signer::address_of(&admin), 100);
    }

    #[test(core_resource = @CoreResources, admin = @MultiSwap, user = @0x42)]
    #[expected_failure(abort_code = 100)]
    fun test_cannot_mint_if_no_cap(core_resource: signer, admin: signer, user: signer) {
        Genesis::setup(&core_resource);
        Liquid::initialize(&admin);

        Liquid::mint_internal(&user, Signer::address_of(&user), 100);
    }

    #[test(core_resource = @CoreResources, admin = @MultiSwap, user = @0x42)]
    #[expected_failure(abort_code = 100)]
    fun test_cannot_get_mint_cap_if_no_cap(core_resource: signer, admin: signer, user: signer) {
        Genesis::setup(&core_resource);
        Liquid::initialize(&admin);

        let mint_cap = Liquid::get_mint_cap(&user);
        move_to(&user, MintCap { mint_cap });
    }

    #[test(core_resource = @CoreResources, admin = @MultiSwap, user = @0x43)]
    fun test_anyone_can_acquire_burn_cap(core_resource: signer, admin: signer, user: signer) {
        Genesis::setup(&core_resource);
        Liquid::initialize(&admin);
        Coin::register_internal<LAMM>(&user);

        Liquid::mint_internal(&admin, Signer::address_of(&user), 100);

        let coins = Coin::withdraw<LAMM>(&user, 100);
        let burn_cap = Liquid::get_burn_cap();
        Coin::burn(coins, &burn_cap);

        move_to(&admin, BurnCap { burn_cap });
    }

    #[test(core_resource = @CoreResources, admin = @MultiSwap)]
    #[expected_failure(abort_code = 101)]
    fun test_lock_minting_after_6_months_later(core_resource: signer, admin: signer) {
        Genesis::setup(&core_resource);
        Liquid::initialize(&admin);

        Timestamp::update_global_time_for_test((Timestamp::now_seconds() + (60 * 60 * 24 * 30 * 6)) * 1000000);

        Liquid::mint_internal(&admin, Signer::address_of(&admin), 100);
    }

    #[test(core_resource = @CoreResources, admin = @MultiSwap)]
    #[expected_failure(abort_code = 101)]
    fun test_cannot_get_mint_cap_after_6_months_late(core_resource: signer, admin: signer) {
        Genesis::setup(&core_resource);
        Liquid::initialize(&admin);

        Timestamp::update_global_time_for_test((Timestamp::now_seconds() + (60 * 60 * 24 * 30 * 6)) * 1000000);
        // failure here, need to store mint_cap somewhere anyway, otherwise it won't compile
        let mint_cap = Liquid::get_mint_cap(&admin);
        move_to(&admin, MintCap { mint_cap });
    }
}