#[test_only]
module liquidswap::liquidity_pool_tests {
    use std::option;
    use std::signer;
    use std::string::utf8;

    use aptos_framework::coin;
    use aptos_framework::timestamp;

    use liquidswap::coin_helper::supply;
    use liquidswap::curves::{Uncorrelated, Stable};
    use liquidswap::emergency;
    use liquidswap::liquidity_pool;
    use test_coin_admin::test_coins::{Self, USDT, BTC, USDC};
    use test_helpers::test_pool;
    use liquidswap_lp::lp_coin::LP;

    fun setup_btc_usdt_pool(): (signer, signer) {
        let (coin_admin, lp_owner) = test_pool::setup_coins_and_lp_owner();
        liquidity_pool::register<BTC, USDT, Uncorrelated>(&lp_owner);
        (coin_admin, lp_owner)
    }

    fun setup_usdc_usdt_pool(): (signer, signer) {
        let (coin_admin, lp_owner) = test_pool::setup_coins_and_lp_owner();
        liquidity_pool::register<USDC, USDT, Stable>(&lp_owner);
        (coin_admin, lp_owner)
    }

    // Register pool tests.

    #[test]
    fun test_liquidswap_lp_and_liquidswap_pool_account_are_the_same() {
        assert!(@liquidswap_lp == @liquidswap_pool_account, 1);
    }

    #[test]
    fun test_create_empty_pool_uncorrelated() {
        let (_, lp_owner) = test_pool::setup_coins_and_lp_owner();

        let pool_lp_name = utf8(b"Liquidswap LP");
        let pool_lp_symbol = utf8(b"LP-BTC-USDT-Uncorrelated");

        liquidity_pool::register<BTC, USDT, Uncorrelated>(
            &lp_owner);

        assert!(liquidity_pool::is_pool_exists<BTC, USDT, Uncorrelated>(), 10);
        assert!(coin::is_coin_initialized<LP<BTC, USDT, Uncorrelated>>(), 11);
        assert!(!coin::is_coin_initialized<LP<USDT, BTC, Uncorrelated>>(), 12);

        let (x_res_val, y_res_val) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res_val == 0, 13);
        assert!(y_res_val == 0, 14);

        let (x_price, y_price, _) =
            liquidity_pool::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(x_price == 0, 15);
        assert!(y_price == 0, 16);

        // Check created LP.
        assert!(coin::is_coin_initialized<LP<BTC, USDT, Uncorrelated>>(), 17);
        let lp_name = coin::name<LP<BTC, USDT, Uncorrelated>>();
        assert!(lp_name == pool_lp_name, 18);
        let lp_symbol = coin::symbol<LP<BTC, USDT, Uncorrelated>>();
        assert!(lp_symbol == pool_lp_symbol, 19);
        let lp_supply = coin::supply<LP<BTC, USDT, Uncorrelated>>();
        assert!(option::is_some(&lp_supply), 20);
        assert!(*option::borrow(&lp_supply) == 0, 21);

        // Get cumulative prices.

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(x_cum_price == 0, 22);
        assert!(y_cum_price == 0, 23);
        assert!(ts == 0, 24);

        // Check if it's locked.
        assert!(!liquidity_pool::is_pool_locked<BTC, USDT, Uncorrelated>(), 25);
    }

    #[test(emergency_acc = @emergency_admin)]
    #[expected_failure(abort_code = 4001)]
    fun test_create_pool_emergency_fails(emergency_acc: signer) {
        let (_, lp_owner) = test_pool::setup_coins_and_lp_owner();

        emergency::pause(&emergency_acc);
        liquidity_pool::register<BTC, USDT, Uncorrelated>(
            &lp_owner);
    }

    #[test]
    fun test_create_empty_pool_stable() {
        let (_, lp_owner) = test_pool::setup_coins_and_lp_owner();

        let pool_lp_name = utf8(b"Liquidswap LP");
        let pool_lp_symbol = utf8(b"LP-USDC-USDT-Stable");

        liquidity_pool::register<USDC, USDT, Stable>(
            &lp_owner);

        let (x_res_val, y_res_val) =
            liquidity_pool::get_reserves_size<USDC, USDT, Stable>();
        assert!(x_res_val == 0, 0);
        assert!(y_res_val == 0, 1);

        // Check scales.
        let (x_scale, y_scale) = liquidity_pool::get_decimals_scales<USDC, USDT, Stable>();
        assert!(x_scale == 10000, 2);
        assert!(y_scale == 1000000, 3);

        // Check created LP.

        assert!(coin::is_coin_initialized<LP<USDC, USDT, Stable>>(), 4);
        let lp_name = coin::name<LP<USDC, USDT, Stable>>();
        assert!(lp_name == pool_lp_name, 6);
        let lp_symbol = coin::symbol<LP<USDC, USDT, Stable>>();
        assert!(lp_symbol == pool_lp_symbol, 7);
        let lp_supply = coin::supply<LP<USDC, USDT, Stable>>();
        assert!(option::is_some(&lp_supply), 8);

        // Get cummulative prices.

        let (x_cumm_price, y_cumm_price, ts) = liquidity_pool::get_cumulative_prices<USDC, USDT, Stable>();
        assert!(x_cumm_price == 0, 9);
        assert!(y_cumm_price == 0, 10);
        assert!(ts == 0, 11);

        // Check if it's locked.
        assert!(!liquidity_pool::is_pool_locked<USDC, USDT, Stable>(), 12);
    }

    #[test]
    #[expected_failure(abort_code = 100)]
    fun test_fail_if_coin_generics_provided_in_the_wrong_order() {
        let (_, lp_owner) = test_pool::setup_coins_and_lp_owner();

        
        liquidity_pool::register<BTC, USDT, Uncorrelated>(
            &lp_owner);

        // here generics are provided as USDT-BTC, but pool is BTC-USDT. `reverse` parameter is irrelevant
        let (_x_price, _y_price, _) =
            liquidity_pool::get_cumulative_prices<USDT, BTC, Uncorrelated>();
    }

    #[test]
    #[expected_failure(abort_code = 3001)]
    fun test_fail_if_x_is_not_coin() {
        let (coin_admin, lp_owner) = test_pool::create_coin_admin_and_lp_owner();

        test_coins::register_coin<USDT>(&coin_admin, b"USDT", b"USDT", 6);

        liquidity_pool::register<BTC, USDT, Uncorrelated>(
            &lp_owner);
    }

    #[test]
    #[expected_failure(abort_code = 3001)]
    fun test_fail_if_y_is_not_coin() {
        let (coin_admin, lp_owner) = test_pool::create_coin_admin_and_lp_owner();

        test_coins::register_coin<BTC>(&coin_admin, b"BTC", b"BTC", 8);

        liquidity_pool::register<BTC, USDT, Uncorrelated>(
            &lp_owner);
    }

    #[test]
    #[expected_failure(abort_code = 101)]
    fun test_fail_if_pool_already_exists() {
        let (_, lp_owner) = test_pool::setup_coins_and_lp_owner();

        liquidity_pool::register<BTC, USDT, Uncorrelated>(
            &lp_owner);

        liquidity_pool::register<BTC, USDT, Uncorrelated>(
            &lp_owner);
    }

    // Add liquidity tests.
    #[test]
    fun test_add_liquidity_to_empty_pool() {
        let (coin_admin, lp_owner) = setup_btc_usdt_pool();

        let btc_liq_val = 100000000;
        let usdt_liq_val = 28000000000;
        let btc_liq = test_coins::mint<BTC>(&coin_admin, btc_liq_val);
        let usdt_liq = test_coins::mint<USDT>(&coin_admin, usdt_liq_val);

        timestamp::fast_forward_seconds(1660338836);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_liq, usdt_liq);

        let expected_liquidity = 1673320053 - 1000;
        assert!(coin::value(&lp_coins) == expected_liquidity, 0);
        assert!(supply<LP<BTC, USDT, Uncorrelated>>() == (expected_liquidity as u128), 1);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == btc_liq_val, 2);
        assert!(y_res == usdt_liq_val, 3);

        let (x_price, y_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(x_price == 0, 4);
        assert!(y_price == 0, 5);
        assert!(ts == 1660338836, 6);

        coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins)
    }

    #[test]
    #[expected_failure(abort_code = 102)]
    fun test_add_liquidity_less_than_minimal() {
        let (coin_admin, lp_owner) = setup_btc_usdt_pool();

        let btc_liq_val = 1000;
        let usdt_liq_val = 1000;
        let btc_liq = test_coins::mint<BTC>(&coin_admin, btc_liq_val);
        let usdt_liq = test_coins::mint<USDT>(&coin_admin, usdt_liq_val);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_liq, usdt_liq);

        coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins)
    }

    #[test]
    #[expected_failure(abort_code = 102)]
    fun test_add_liquidity_zero_initially() {
        let (coin_admin, lp_owner) = setup_btc_usdt_pool();

        let btc_liq_val = 0;
        let usdt_liq_val = 0;
        let btc_liq = test_coins::mint<BTC>(&coin_admin, btc_liq_val);
        let usdt_liq = test_coins::mint<USDT>(&coin_admin, usdt_liq_val);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_liq, usdt_liq);

        coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins)
    }

    #[test]
    fun test_add_liquidity_minimal() {
        let (coin_admin, lp_owner) = setup_btc_usdt_pool();

        let btc_liq_val = 1001;
        let usdt_liq_val = 1001;
        let btc_liq = test_coins::mint<BTC>(&coin_admin, btc_liq_val);
        let usdt_liq = test_coins::mint<USDT>(&coin_admin, usdt_liq_val);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_liq, usdt_liq);

        let expected_liquidity = 1001 - 1000;
        assert!(coin::value(&lp_coins) == expected_liquidity, 0);
        assert!(supply<LP<BTC, USDT, Uncorrelated>>() == (expected_liquidity as u128), 1);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == btc_liq_val, 2);
        assert!(y_res == usdt_liq_val, 3);

        coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins)
    }

    #[test(emergency_acc = @emergency_admin)]
    #[expected_failure(abort_code = 4001)]
    fun test_add_liquidity_emergency_stop_fails(emergency_acc: signer) {
        let (coin_admin, lp_owner) = setup_btc_usdt_pool();

        let btc_liq_val = 1001;
        let usdt_liq_val = 1001;
        let btc_liq = test_coins::mint<BTC>(&coin_admin, btc_liq_val);
        let usdt_liq = test_coins::mint<USDT>(&coin_admin, usdt_liq_val);

        emergency::pause(&emergency_acc);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_liq, usdt_liq);

        coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins)
    }

    #[test]
    fun test_add_liquidity_after_initial_liquidity_added() {
        let (coin_admin, lp_owner) = setup_btc_usdt_pool();

        let btc_liq_val = 100000000;
        let usdt_liq_val = 28000000000;
        let btc_liq = test_coins::mint<BTC>(&coin_admin, btc_liq_val);
        let usdt_liq = test_coins::mint<USDT>(&coin_admin, usdt_liq_val);

        let initial_ts = 1660338836;
        timestamp::fast_forward_seconds(initial_ts);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_liq, usdt_liq);

        let expected_liquidity = 1673320053 - 1000;
        assert!(coin::value(&lp_coins) == expected_liquidity, 0);
        assert!(supply<LP<BTC, USDT, Uncorrelated>>() == (expected_liquidity as u128), 1);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == btc_liq_val, 2);
        assert!(y_res == usdt_liq_val, 3);

        let (x_price, y_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(x_price == 0, 4);
        assert!(y_price == 0, 5);
        assert!(ts == initial_ts, 6);

        coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        timestamp::fast_forward_seconds(360);

        let expected_liquidity_2 = 3346638106;
        let btc_liq = test_coins::mint<BTC>(&coin_admin, btc_liq_val * 2);
        let usdt_liq = test_coins::mint<USDT>(&coin_admin, usdt_liq_val * 2);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_liq, usdt_liq);

        assert!(coin::value(&lp_coins) == expected_liquidity_2, 7);
        assert!(supply<LP<BTC, USDT, Uncorrelated>>() == ((expected_liquidity_2 + expected_liquidity) as u128), 8);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == btc_liq_val * 3, 9);
        assert!(y_res == usdt_liq_val * 3, 10);

        let (x_price, y_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(x_price == 1859431802629922802792000, 11);
        assert!(y_price == 23717242380483709200, 12);
        assert!(ts == initial_ts + 360, 13);

        coin::deposit(signer::address_of(&lp_owner), lp_coins);
    }

    #[test]
    #[expected_failure(abort_code = 103)]
    fun test_add_liquidity_zero() {
        let (coin_admin, _) = setup_btc_usdt_pool();

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100100);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100100);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);
        assert!(coin::value(&lp_coins) == 99100, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 100100, 1);
        assert!(y_res == 100100, 2);

        let lp_coins_zero = liquidity_pool::mint<BTC, USDT, Uncorrelated>(coin::zero(), coin::zero());

        coin::register<LP<BTC, USDT, Uncorrelated>>(&coin_admin);
        coin::deposit(signer::address_of(&coin_admin), lp_coins);
        coin::deposit(signer::address_of(&coin_admin), lp_coins_zero);
    }

    // Test burn liquidity.
    #[test]
    fun test_burn_liquidity() {
        let (coin_admin, _) = setup_btc_usdt_pool();

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 2000000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 560000000000000);
        
        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);
        assert!(coin::value(&lp_coins) == 33466401060363, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 2000000000000, 1);
        assert!(y_res == 560000000000000, 2);

        let (btc_return, usdt_return) =
            liquidity_pool::burn<BTC, USDT, Uncorrelated>(lp_coins);

        assert!(coin::value(&btc_return) == 2000000000000, 3);
        assert!(coin::value(&usdt_return) == 560000000000000, 4);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 0, 5);
        assert!(y_res == 0, 6);

        test_coins::burn(&coin_admin, btc_return);
        test_coins::burn(&coin_admin, usdt_return);
    }

    #[test]
    fun test_burn_liquidity_after_initial() {
        let (coin_admin, _) = setup_btc_usdt_pool();

        // Initial liquidity

        timestamp::fast_forward_seconds(1660517742);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 2000000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 560000000000000);

        let lp_coins_initial =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);

        // Additional liquidity

        timestamp::fast_forward_seconds(7200);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 50000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 14000000000);

        let lp_coins_user =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);

        let (btc_return, usdt_return) =
            liquidity_pool::burn<BTC, USDT, Uncorrelated>(lp_coins_initial);

        assert!(coin::value(&btc_return) == 2000000000000, 0);
        assert!(coin::value(&usdt_return) == 560000000000008, 1);

        test_coins::burn(&coin_admin, btc_return);
        test_coins::burn(&coin_admin, usdt_return);

        let (btc_return, usdt_return) =
            liquidity_pool::burn<BTC, USDT, Uncorrelated>(lp_coins_user);

        assert!(coin::value(&btc_return) == 50000000, 2);
        assert!(coin::value(&usdt_return) == 13999999992, 3);

        test_coins::burn(&coin_admin, btc_return);
        test_coins::burn(&coin_admin, usdt_return);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 0, 4);
        assert!(y_res == 0, 5);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(x_cum_price == 37188636052598456055840000, 6);
        assert!(y_cum_price == 474344847609674184000, 7);
        assert!(ts == 1660517742 + 7200, 8);
    }

    #[test]
    fun test_overflow_and_emergency_exit() {
        let (coin_admin, _) = setup_btc_usdt_pool();

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 18446744073709551615);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 18446744073709551615);

        // Now we can't swap or add liquidity, if cumulative price is still has space, it wouldn never overflow,
        // we are able to exit.

        
        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);

        let (btc_return, usdt_return) =
            liquidity_pool::burn<BTC, USDT, Uncorrelated>(lp_coins);

        assert!(coin::value(&btc_return) == 18446744073709551615, 0);
        assert!(coin::value(&usdt_return) == 18446744073709551615, 1);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 0, 2);
        assert!(y_res == 0, 3);

        test_coins::burn(&coin_admin, btc_return);
        test_coins::burn(&coin_admin, usdt_return);
    }

    #[test(emergency_acc = @emergency_admin)]
    fun test_emergency_exit(emergency_acc: signer) {
        let (coin_admin, _) = setup_btc_usdt_pool();

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 18446744073709551615);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 18446744073709551615);

        // Now we can't swap or add liquidity, if cumulative price is still has space, it wouldn never overflow,
        // we are able to exit.

        
        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);

        emergency::pause(&emergency_acc);
        assert!(emergency::is_emergency() == true, 0);

        let (btc_return, usdt_return) =
            liquidity_pool::burn<BTC, USDT, Uncorrelated>(lp_coins);

        assert!(coin::value(&btc_return) == 18446744073709551615, 1);
        assert!(coin::value(&usdt_return) == 18446744073709551615, 2);

        test_coins::burn(&coin_admin, btc_return);
        test_coins::burn(&coin_admin, usdt_return);
    }

    // Test swap.
    #[test]
    fun test_swap_coins() {
        let (coin_admin, lp_owner) = setup_btc_usdt_pool();

        

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100100);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100100);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);
        coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 2);
        let (zero, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, Uncorrelated>(
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 1
            );
        assert!(coin::value(&usdt_coins) == 1, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 100102, 1);
        assert!(y_res == 100099, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(emergency_acc = @emergency_admin)]
    #[expected_failure(abort_code = 4001)]
    fun test_swap_coins_emergency_fails(emergency_acc: signer) {
        let (coin_admin, lp_owner) = setup_btc_usdt_pool();

        

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100100);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100100);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);
        coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        emergency::pause(&emergency_acc);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 2);
        let (zero, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, Uncorrelated>(
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 1
            );

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    fun test_swap_coins_max_amounts() {
        let (coin_admin, lp_owner) = setup_btc_usdt_pool();

        

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 18446744073709550615);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 18446744073709551615);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);
        coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 1000);
        let (zero, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, Uncorrelated>(
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 0
            );

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    fun test_swap_coins_1() {
        let (coin_admin, lp_owner) = setup_btc_usdt_pool();

        

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 10000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 2800000000000);

        timestamp::fast_forward_seconds(1660545565);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);
        coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        timestamp::fast_forward_seconds(20);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 100000000);
        let (btc_zero, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, Uncorrelated>(
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 27640424963
            );
        assert!(coin::value(&usdt_coins) == 27640424963, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 10099900000, 1);
        assert!(y_res == 2772359575037, 2);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(x_cum_price == 103301766812773489044000, 3);
        assert!(y_cum_price == 1317624576693539400, 4);
        assert!(ts == 1660545565 + 20, 5);

        timestamp::fast_forward_seconds(3600);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 1000000);
        let (btc_coins, usdt_zero) =
            liquidity_pool::swap<BTC, USDT, Uncorrelated>(
                coin::zero<BTC>(), 3632,
                usdt_coins_to_exchange, 0
            );

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 10099896368, 6);
        assert!(y_res == 2772360574037, 7);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(x_cum_price == 18331960191116039718441600, 8);
        assert!(y_cum_price == 243247632405227595000, 9);
        assert!(ts == 1660545565 + 20 + 3600, 10);

        coin::destroy_zero(btc_zero);
        coin::destroy_zero(usdt_zero);
        test_coins::burn(&coin_admin, btc_coins);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_swap_coins_1_fail() {
        let (coin_admin, lp_owner) = setup_btc_usdt_pool();

        

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 10000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 2800000000000);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);
        coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 100000000);
        let (zero, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, Uncorrelated>(
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 27640424964
            );
        assert!(coin::value(&usdt_coins) == 27640424964, 0);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    #[expected_failure(abort_code = 104)]
    fun test_swap_coins_zero_fail() {
        let (coin_admin, lp_owner) = setup_btc_usdt_pool();

        

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 10000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 2800000000000);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);
        coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        let (btc_coins, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, Uncorrelated>(
                coin::zero<BTC>(), 1,
                coin::zero<USDT>(), 1
            );

        test_coins::burn(&coin_admin, usdt_coins);
        test_coins::burn(&coin_admin, btc_coins);
    }

    #[test]
    fun test_swap_coins_vice_versa() {
        let (coin_admin, lp_owner) = setup_btc_usdt_pool();

        

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 10000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 2800000000000);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);
        coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 28000000000);
        let (btc_coins, zero) =
            liquidity_pool::swap<BTC, USDT, Uncorrelated>(
                coin::zero<BTC>(), 98715803,
                usdt_coins_to_exchange, 0
            );
        assert!(coin::value(&btc_coins) == 98715803, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 9901284197, 1);
        assert!(y_res == 2827972000000, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, btc_coins);
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_swap_coins_vice_versa_fail() {
        let (coin_admin, lp_owner) = setup_btc_usdt_pool();

        

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 10000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 2800000000000);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);
        coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 28000000000);
        let (btc_coins, zero) =
            liquidity_pool::swap<BTC, USDT, Uncorrelated>(
                coin::zero<BTC>(), 98715804,
                usdt_coins_to_exchange, 0
            );
        assert!(coin::value(&btc_coins) == 98715804, 0);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, btc_coins);
    }

    #[test]
    fun test_swap_two_coins_success() {
        let (coin_admin, lp_owner) = setup_btc_usdt_pool();

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 10000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 2800000000000);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);
        coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 28000000000);
        let btc_to_exchange = test_coins::mint<BTC>(&coin_admin, 100000000);
        let (btc_coins, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, Uncorrelated>(
                btc_to_exchange, 99900003,
                usdt_coins_to_exchange, 27859998039
            );

        assert!(coin::value(&btc_coins) == 99900003, 0);
        assert!(coin::value(&usdt_coins) == 27859998039, 1);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 9999999997, 2);
        assert!(y_res == 2800112001961, 3);

        test_coins::burn(&coin_admin, btc_coins);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_swap_two_coins_failure() {
        let (coin_admin, lp_owner) = setup_btc_usdt_pool();

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 10000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 2800000000000);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);
        coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 28000000000);
        let btc_to_exchange = test_coins::mint<BTC>(&coin_admin, 100000000);
        let (btc_coins, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, Uncorrelated>(
                btc_to_exchange, 99900003,
                usdt_coins_to_exchange, 27859998040
            );

        assert!(coin::value(&btc_coins) == 99900003, 0);
        assert!(coin::value(&usdt_coins) == 27859998040, 1);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 9999999997, 2);
        assert!(y_res == 2800112001960, 3);

        test_coins::burn(&coin_admin, btc_coins);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_cannot_swap_coins_and_reduce_value_of_pool() {
        let (coin_admin, lp_owner) = setup_btc_usdt_pool();

        

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 100100);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100100);

        let lp_coins =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins, usdt_coins);
        coin::register<LP<BTC, USDT, Uncorrelated>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        // 1 minus fee for 1
        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 1);
        let (zero, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, Uncorrelated>(
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 1
            );
        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    fun test_swap_coins_with_stable_curve_type() {
        let (coin_admin, lp_owner) = setup_usdc_usdt_pool();

        
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 1000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, Stable>(usdc_coins, usdt_coins);
        coin::register<LP<USDC, USDT, Stable>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        let usdc_coins_to_exchange = test_coins::mint<USDC>(&coin_admin, 1);
        let (zero, usdt_coins) =
            liquidity_pool::swap<USDC, USDT, Stable>(
                usdc_coins_to_exchange, 0,
                coin::zero<USDT>(), 99
            );
        assert!(coin::value(&usdt_coins) == 99, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, Stable>();
        assert!(x_res == 1000001, 1);
        assert!(y_res == 99999901, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    fun test_swap_coins_with_stable_curve_type_1() {
        let (coin_admin, lp_owner) = setup_usdc_usdt_pool();

        
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 15000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 1500000000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, Stable>(usdc_coins, usdt_coins);
        coin::register<LP<USDC, USDT, Stable>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        let usdc_coins_to_exchange = test_coins::mint<USDC>(&coin_admin, 7078017525);
        let (zero, usdt_coins) =
            liquidity_pool::swap<USDC, USDT, Stable>(
                usdc_coins_to_exchange, 0,
                coin::zero<USDT>(), 672790928423
            );
        assert!(coin::value(&usdt_coins) == 672790928423, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, Stable>();
        assert!(x_res == 22070939508, 1);
        assert!(y_res == 827209071577, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    fun test_swap_coins_with_stable_curve_type_2() {
        let (coin_admin, lp_owner) = setup_usdc_usdt_pool();

        
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 15000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 1500000000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, Stable>(usdc_coins, usdt_coins);
        coin::register<LP<USDC, USDT, Stable>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        let usdc_coins_to_exchange = test_coins::mint<USDC>(&coin_admin, 152);
        let (zero, usdt_coins) =
            liquidity_pool::swap<USDC, USDT, Stable>(
                usdc_coins_to_exchange, 0,
                coin::zero<USDT>(), 15199
            );
        assert!(coin::value(&usdt_coins) == 15199, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, Stable>();
        assert!(x_res == 15000000152, 1);
        assert!(y_res == 1499999984801, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    fun test_swap_coins_with_stable_curve_type_3() {
        let (coin_admin, lp_owner) = setup_usdc_usdt_pool();

        
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 15000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 1500000000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, Stable>(usdc_coins, usdt_coins);
        coin::register<LP<USDC, USDT, Stable>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        let usdc_coins_to_exchange = test_coins::mint<USDC>(&coin_admin, 6748155);
        let (zero, usdt_coins) =
            liquidity_pool::swap<USDC, USDT, Stable>(
                usdc_coins_to_exchange, 0,
                coin::zero<USDT>(), 672791099
            );
        assert!(coin::value(&usdt_coins) == 672791099, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, Stable>();
        assert!(x_res == 15006741407, 1);
        assert!(y_res == 1499327208901, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    fun test_swap_coins_with_stable_curve_type_1_unit() {
        let (coin_admin, lp_owner) = setup_usdc_usdt_pool();

        
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 1000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, Stable>(usdc_coins, usdt_coins);
        coin::register<LP<USDC, USDT, Stable>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        let usdc_coins_to_exchange = test_coins::mint<USDC>(&coin_admin, 10000);
        let (zero, usdt_coins) =
            liquidity_pool::swap<USDC, USDT, Stable>(
                usdc_coins_to_exchange, 0,
                coin::zero<USDT>(), 996999
            );
        assert!(coin::value(&usdt_coins) == 996999, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, Stable>();
        assert!(x_res == 1009990, 1);
        assert!(y_res == 99003001, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_swap_coins_with_stable_curve_type_1_unit_fail() {
        let (coin_admin, lp_owner) = setup_usdc_usdt_pool();

        
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 1000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, Stable>(usdc_coins, usdt_coins);
        coin::register<LP<USDC, USDT, Stable>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        let usdc_coins_to_exchange = test_coins::mint<USDC>(&coin_admin, 10000);
        let (zero, usdt_coins) =
            liquidity_pool::swap<USDC, USDT, Stable>(
                usdc_coins_to_exchange, 0,
                coin::zero<USDT>(), 997000
            );
        assert!(coin::value(&usdt_coins) == 997000, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, Stable>();
        assert!(x_res == 1009990, 1);
        assert!(y_res == 99003000, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_swap_coins_with_stable_curve_type_fails() {
        let (coin_admin, lp_owner) = setup_usdc_usdt_pool();

        
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 1000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, Stable>(usdc_coins, usdt_coins);
        coin::register<LP<USDC, USDT, Stable>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        let usdc_coins_to_exchange = test_coins::mint<USDC>(&coin_admin, 1);
        let (zero, usdt_coins) =
            liquidity_pool::swap<USDC, USDT, Stable>(
                usdc_coins_to_exchange, 0,
                coin::zero<USDT>(), 100
            );
        assert!(coin::value(&usdt_coins) == 100, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, Stable>();
        assert!(x_res == 1000001, 1);
        assert!(y_res == 99999901, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    fun test_swap_coins_with_stable_curve_type_vice_versa() {
        let (coin_admin, lp_owner) = setup_usdc_usdt_pool();

        
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 1000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, Stable>(usdc_coins, usdt_coins);
        coin::register<LP<USDC, USDT, Stable>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 999901);
        let (usdc_coins, zero) =
            liquidity_pool::swap<USDC, USDT, Stable>(
                coin::zero<USDC>(), 9969,
                usdt_coins_to_exchange, 0
            );
        assert!(coin::value(&usdc_coins) == 9969, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, Stable>();
        assert!(y_res == 100998902, 1);
        assert!(x_res == 990031, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdc_coins);
    }

    #[test]
    fun test_swap_coins_two_coins_with_stable_curve() {
        let (coin_admin, lp_owner) = setup_usdc_usdt_pool();
        
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 1000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, Stable>(usdc_coins, usdt_coins);
        coin::register<LP<USDC, USDT, Stable>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 1000000);
        let usdc_coins_to_exchange = test_coins::mint<USDC>(&coin_admin, 10000);

        let (usdc_coins, usdt_coins) =
            liquidity_pool::swap<USDC, USDT, Stable>(
                usdc_coins_to_exchange, 9969,
                usdt_coins_to_exchange, 997099
            );

        assert!(coin::value(&usdc_coins) == 9969, 0);
        assert!(coin::value(&usdt_coins) == 997099, 1);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, Stable>();
        assert!(x_res == 1000021, 2);
        assert!(y_res == 100001901, 3);

        test_coins::burn(&coin_admin, usdc_coins);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_swap_coins_two_coins_with_stable_curve_fail() {
        let (coin_admin, lp_owner) = setup_usdc_usdt_pool();

        
        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 1000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, Stable>(usdc_coins, usdt_coins);
        coin::register<LP<USDC, USDT, Stable>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 1000000);
        let usdc_coins_to_exchange = test_coins::mint<USDC>(&coin_admin, 10000);

        let (usdc_coins, usdt_coins) =
            liquidity_pool::swap<USDC, USDT, Stable>(
                usdc_coins_to_exchange, 9970,
                usdt_coins_to_exchange, 997099
            );

        assert!(coin::value(&usdc_coins) == 9970, 0);
        assert!(coin::value(&usdt_coins) == 997099, 1);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, Stable>();
        assert!(x_res == 1000020, 2);
        assert!(y_res == 100001901, 3);

        test_coins::burn(&coin_admin, usdc_coins);
        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test]
    fun test_swap_coins_with_stable_curve_type_vice_versa_1() {
        let (coin_admin, lp_owner) = setup_usdc_usdt_pool();

        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 15000000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 1500000000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, Stable>(usdc_coins, usdt_coins);
        coin::register<LP<USDC, USDT, Stable>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 125804314);
        let (usdc_coins, zero) =
            liquidity_pool::swap<USDC, USDT, Stable>(
                coin::zero<USDC>(), 1254269,
                usdt_coins_to_exchange, 0
            );
        assert!(coin::value(&usdc_coins) == 1254269, 0);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdc_coins);
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_swap_coins_with_stable_curve_type_vice_versa_fail() {
        let (coin_admin, lp_owner) = setup_usdc_usdt_pool();

        let usdc_coins = test_coins::mint<USDC>(&coin_admin, 1000000);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 100000000);

        let lp_coins =
            liquidity_pool::mint<USDC, USDT, Stable>(usdc_coins, usdt_coins);
        coin::register<LP<USDC, USDT, Stable>>(&lp_owner);
        coin::deposit(signer::address_of(&lp_owner), lp_coins);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 1000000);
        let (usdc_coins, zero) =
            liquidity_pool::swap<USDC, USDT, Stable>(
                coin::zero<USDC>(), 9970,
                usdt_coins_to_exchange, 0
            );
        assert!(coin::value(&usdc_coins) == 9970, 0);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<USDC, USDT, Stable>();
        assert!(y_res == 100999000, 1);
        assert!(x_res == 990030, 2);

        coin::destroy_zero(zero);
        test_coins::burn(&coin_admin, usdc_coins);
    }

    // Getters.

    #[test(emergency_acc = @emergency_admin)]
    #[expected_failure(abort_code = 4001)]
    fun test_get_reserves_emergency_fails(emergency_acc: signer) {
        let (_, _) = setup_btc_usdt_pool();

        emergency::pause(&emergency_acc);

        let (_, _) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
    }

    #[test(emergency_acc = @emergency_admin)]
    #[expected_failure(abort_code = 4001)]
    fun test_get_cumulative_price_emergency_fails(emergency_acc: signer) {
        let (_, _) = setup_btc_usdt_pool();

        emergency::pause(&emergency_acc);

        let (_, _, _) = liquidity_pool::get_cumulative_prices<BTC, USDT, Uncorrelated>();
    }

    #[test]
    fun test_pool_exists() {
        let (_, _) = setup_btc_usdt_pool();

        assert!(liquidity_pool::is_pool_exists<BTC, USDT, Uncorrelated>(), 0);
        assert!(!liquidity_pool::is_pool_exists<USDC, USDT, Uncorrelated>(), 1);
    }

    #[test]
    fun test_fees_config() {
        setup_btc_usdt_pool();

        let (fee_pct, fee_scale) = liquidity_pool::get_fees_config();

        assert!(fee_pct == 30, 0);
        assert!(fee_scale == 10000, 1);
    }

    // End to end.

    #[test]
    fun test_end_to_end() {
        let (coin_admin, _) = setup_btc_usdt_pool();

        let btc_coins_initial = test_coins::mint<BTC>(&coin_admin, 10000000000);
        let usdt_coins_initial = test_coins::mint<USDT>(&coin_admin, 2800000000000);

        timestamp::fast_forward_seconds(1660545565);

        let lp_coins_initial =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins_initial, usdt_coins_initial);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 10000000000, 0);
        assert!(y_res == 2800000000000, 1);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(x_cum_price == 0, 2);
        assert!(y_cum_price == 0, 3);
        assert!(ts == 1660545565, 4);

        let btc_coins_user = test_coins::mint<BTC>(&coin_admin, 1500000000);
        let usdt_coins_user = test_coins::mint<USDT>(&coin_admin, 420000000000);

        let lp_coins_user =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins_user, usdt_coins_user);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 11500000000, 5);
        assert!(y_res == 3220000000000, 6);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(x_cum_price == 0, 7);
        assert!(y_cum_price == 0, 8);
        assert!(ts == 1660545565, 9);

        timestamp::fast_forward_seconds(3600);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 2500000000);
        let (btc_zero, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, Uncorrelated>(
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 573582276219
            );
        assert!(coin::value(&usdt_coins) == 573582276219, 10);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 13997500000, 11);
        assert!(y_res == 2646417723781, 12);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(x_cum_price == 18594318026299228027920000, 12);
        assert!(y_cum_price == 237172423804837092000, 13);
        assert!(ts == 1660549165, 14);

        let lp_coins_user_val = coin::value(&lp_coins_user);
        let lp_coins_to_burn_part = coin::extract(&mut lp_coins_user, lp_coins_user_val / 2);
        let (btc_earned_user, usdt_earned_user) = liquidity_pool::burn<BTC, USDT, Uncorrelated>(
            lp_coins_to_burn_part,
        );

        assert!(coin::value(&btc_earned_user) == 912880434, 15);
        assert!(coin::value(&usdt_earned_user) == 172592460234, 16);

        test_coins::burn(&coin_admin, btc_earned_user);
        test_coins::burn(&coin_admin, usdt_earned_user);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 13084619566, 17);
        assert!(y_res == 2473825263547, 18);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(x_cum_price == 18594318026299228027920000, 19);
        assert!(y_cum_price == 237172423804837092000, 20);
        assert!(ts == 1660549165, 21);

        timestamp::fast_forward_seconds(3600);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 10000000000);
        let (btc_coins, usdt_zero) =
            liquidity_pool::swap<BTC, USDT, Uncorrelated>(
                coin::zero<BTC>(), 52521904,
                usdt_coins_to_exchange, 0
            );

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 13032097662, 22);
        assert!(y_res == 2483815263547, 23);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(x_cum_price == 31149706178195224153700400, 24);
        assert!(y_cum_price == 588420782034956560800, 25);
        assert!(ts == 1660552765, 26);

        timestamp::fast_forward_seconds(3600);

        let (btc_earned_user, usdt_earned_user) = liquidity_pool::burn<BTC, USDT, Uncorrelated>(
            lp_coins_user,
        );
        assert!(coin::value(&btc_earned_user) == 909216115, 27);
        assert!(coin::value(&usdt_earned_user) == 173289436992, 28);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 12122881547, 29);
        assert!(y_res == 2310525826555, 30);

        let (btc_earned_initial, usdt_earned_initial) = liquidity_pool::burn<BTC, USDT, Uncorrelated>(
            lp_coins_initial,
        );
        assert!(coin::value(&btc_earned_initial) == 12122881547, 31);
        assert!(coin::value(&usdt_earned_initial) == 2310525826555, 32);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 0, 33);
        assert!(y_res == 0, 34);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(x_cum_price == 43806601518678425423523600, 35);
        assert!(y_cum_price == 936852159292991150400, 36);
        assert!(ts == 1660556365, 37);

        coin::destroy_zero(btc_zero);
        coin::destroy_zero(usdt_zero);
        test_coins::burn(&coin_admin, btc_coins);
        test_coins::burn(&coin_admin, usdt_coins);
        test_coins::burn(&coin_admin, btc_earned_user);
        test_coins::burn(&coin_admin, usdt_earned_user);
        test_coins::burn(&coin_admin, btc_earned_initial);
        test_coins::burn(&coin_admin, usdt_earned_initial);
    }

    #[test(emergency_acc = @emergency_admin)]
    fun test_end_to_end_emergency(emergency_acc: signer) {
        let (coin_admin, _) = setup_btc_usdt_pool();

        let btc_coins_initial = test_coins::mint<BTC>(&coin_admin, 10000000000);
        let usdt_coins_initial = test_coins::mint<USDT>(&coin_admin, 2800000000000);

        timestamp::fast_forward_seconds(1660545565);

        let lp_coins_initial =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins_initial, usdt_coins_initial);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 10000000000, 0);
        assert!(y_res == 2800000000000, 1);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(x_cum_price == 0, 2);
        assert!(y_cum_price == 0, 3);
        assert!(ts == 1660545565, 4);

        let btc_coins_user = test_coins::mint<BTC>(&coin_admin, 1500000000);
        let usdt_coins_user = test_coins::mint<USDT>(&coin_admin, 420000000000);

        let lp_coins_user =
            liquidity_pool::mint<BTC, USDT, Uncorrelated>(btc_coins_user, usdt_coins_user);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 11500000000, 5);
        assert!(y_res == 3220000000000, 6);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(x_cum_price == 0, 7);
        assert!(y_cum_price == 0, 8);
        assert!(ts == 1660545565, 9);

        timestamp::fast_forward_seconds(3600);

        let btc_coins_to_exchange = test_coins::mint<BTC>(&coin_admin, 2500000000);
        let (btc_zero, usdt_coins) =
            liquidity_pool::swap<BTC, USDT, Uncorrelated>(
                btc_coins_to_exchange, 0,
                coin::zero<USDT>(), 573582276219
            );
        assert!(coin::value(&usdt_coins) == 573582276219, 10);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 13997500000, 11);
        assert!(y_res == 2646417723781, 12);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(x_cum_price == 18594318026299228027920000, 13);
        assert!(y_cum_price == 237172423804837092000, 14);
        assert!(ts == 1660549165, 15);

        emergency::pause(&emergency_acc);
        let lp_coins_user_val = coin::value(&lp_coins_user);
        let lp_coins_to_burn_part = coin::extract(&mut lp_coins_user, lp_coins_user_val / 2);
        let (btc_earned_user, usdt_earned_user) = liquidity_pool::burn<BTC, USDT, Uncorrelated>(
            lp_coins_to_burn_part,
        );

        assert!(coin::value(&btc_earned_user) == 912880434, 16);
        assert!(coin::value(&usdt_earned_user) == 172592460234, 17);

        test_coins::burn(&coin_admin, btc_earned_user);
        test_coins::burn(&coin_admin, usdt_earned_user);

        emergency::resume(&emergency_acc);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 13084619566, 18);
        assert!(y_res == 2473825263547, 19);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(x_cum_price == 18594318026299228027920000, 20);
        assert!(y_cum_price == 237172423804837092000, 21);
        assert!(ts == 1660549165, 22);

        timestamp::fast_forward_seconds(3600);

        let usdt_coins_to_exchange = test_coins::mint<USDT>(&coin_admin, 10000000000);
        let (btc_coins, usdt_zero) =
            liquidity_pool::swap<BTC, USDT, Uncorrelated>(
                coin::zero<BTC>(), 52521904,
                usdt_coins_to_exchange, 0
            );

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 13032097662, 23);
        assert!(y_res == 2483815263547, 24);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(x_cum_price == 31149706178195224153700400, 25);
        assert!(y_cum_price == 588420782034956560800, 26);
        assert!(ts == 1660552765, 27);

        timestamp::fast_forward_seconds(3600);

        emergency::pause(&emergency_acc);

        let (btc_earned_user, usdt_earned_user) = liquidity_pool::burn<BTC, USDT, Uncorrelated>(
            lp_coins_user,
        );
        assert!(coin::value(&btc_earned_user) == 909216115, 28);
        assert!(coin::value(&usdt_earned_user) == 173289436992, 29);

        let (btc_earned_initial, usdt_earned_initial) = liquidity_pool::burn<BTC, USDT, Uncorrelated>(
            lp_coins_initial,
        );
        assert!(coin::value(&btc_earned_initial) == 12122881547, 30);
        assert!(coin::value(&usdt_earned_initial) == 2310525826555, 31);

        emergency::resume(&emergency_acc);

        let (x_res, y_res) = liquidity_pool::get_reserves_size<BTC, USDT, Uncorrelated>();
        assert!(x_res == 0, 32);
        assert!(y_res == 0, 33);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::get_cumulative_prices<BTC, USDT, Uncorrelated>();
        assert!(x_cum_price == 43806601518678425423523600, 34);
        assert!(y_cum_price == 936852159292991150400, 35);
        assert!(ts == 1660556365, 36);

        coin::destroy_zero(btc_zero);
        coin::destroy_zero(usdt_zero);
        test_coins::burn(&coin_admin, btc_coins);
        test_coins::burn(&coin_admin, usdt_coins);
        test_coins::burn(&coin_admin, btc_earned_user);
        test_coins::burn(&coin_admin, usdt_earned_user);
        test_coins::burn(&coin_admin, btc_earned_initial);
        test_coins::burn(&coin_admin, usdt_earned_initial);
    }

    // Compute LP
    #[test]
    fun test_compute_lp_uncorrelated() {
        let x_res = 100;
        let y_res = 100;
        let x_res_new = 101 * 10000;
        let y_res_new = 101 * 10000;

        liquidity_pool::compute_and_verify_lp_value_for_test<Uncorrelated>(
            0,
            0,
            x_res,
            y_res,
            x_res_new,
            y_res_new,
        );

        let x_res = 18446744073709551615;
        let y_res = 18446744073709551515;
        let x_res_new = 18446744073709551615 * 10000;
        let y_res_new = 18446744073709551615 * 10000;

        liquidity_pool::compute_and_verify_lp_value_for_test<Uncorrelated>(
            0,
            0,
            x_res,
            y_res,
            x_res_new,
            y_res_new,
        );

        let x_res = 18446744073709551115;
        let y_res = 18446744073709551115;
        let x_res_new = 18446744073709551615 * 10000;
        let y_res_new = 18446744073709551615 * 10000;

        liquidity_pool::compute_and_verify_lp_value_for_test<Uncorrelated>(
            10000,
            10000,
            x_res,
            y_res,
            x_res_new,
            y_res_new,
        );
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_compute_lp_uncorrelated_fails_equal() {
        let x_res = 0;
        let y_res = 0;
        let x_res_new = 0;
        let y_res_new = 0;

        liquidity_pool::compute_and_verify_lp_value_for_test<Uncorrelated>(
            0,
            0,
            x_res,
            y_res,
            x_res_new,
            y_res_new,
        );
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_compute_lp_uncorrelated_fails_equal_1() {
        let x_res = 18446744073709551615;
        let y_res = 18446744073709551615;
        let x_res_new = 18446744073709551615 * 10000;
        let y_res_new = 18446744073709551615 * 10000;

        liquidity_pool::compute_and_verify_lp_value_for_test<Uncorrelated>(
            0,
            0,
            x_res,
            y_res,
            x_res_new,
            y_res_new,
        );
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_compute_lp_uncorrelated_fails_equal_2() {
        let x_res = 18446744073709551615;
        let y_res = 1;
        let x_res_new = 1 * 10000;
        let y_res_new = 18446744073709551615 * 10000;

        liquidity_pool::compute_and_verify_lp_value_for_test<Uncorrelated>(
            0,
            0,
            x_res,
            y_res,
            x_res_new,
            y_res_new,
        );
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_compute_lp_uncorrelated_fails_less() {
        let x_res = 100;
        let y_res = 99;
        let x_res_new = 100 * 10000;
        let y_res_new = 99 * 10000;

        liquidity_pool::compute_and_verify_lp_value_for_test<Uncorrelated>(
            0,
            0,
            x_res,
            y_res,
            x_res_new,
            y_res_new,
        );
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_compute_lp_uncorrelated_fails_less_1() {
        let x_res = 18446744073709551615;
        let y_res = 10;
        let x_res_new = 18446744073709551613 * 10000;
        let y_res_new = 10 * 10000;

        liquidity_pool::compute_and_verify_lp_value_for_test<Uncorrelated>(
            0,
            0,
            x_res,
            y_res,
            x_res_new,
            y_res_new,
        );
    }

    #[test]
    fun test_compute_lp_stable() {
        let x_res = 10000;
        let y_res = 100;
        let x_res_new = 9999;
        let y_res_new = 101;

        liquidity_pool::compute_and_verify_lp_value_for_test<Stable>(
            100,
            10,
            x_res,
            y_res,
            x_res_new,
            y_res_new,
        );

        let x_res = 10000;
        let y_res = 100;
        let x_res_new = 10001;
        let y_res_new = 100;

        liquidity_pool::compute_and_verify_lp_value_for_test<Stable>(
            100,
            10,
            x_res,
            y_res,
            x_res_new,
            y_res_new,
        );

        let x_res = 1000000001;
        let y_res = 100;
        let x_res_new = 1000000001;
        let y_res_new = 101;

        liquidity_pool::compute_and_verify_lp_value_for_test<Stable>(
            1000000000,
            10,
            x_res,
            y_res,
            x_res_new,
            y_res_new,
        );

        let x_res = 100000000000000000;
        let y_res = 100000000000000000;
        let x_res_new = 100000000000000001;
        let y_res_new = 100000000000000001;

        liquidity_pool::compute_and_verify_lp_value_for_test<Stable>(
            100000000,
            100000000,
            x_res,
            y_res,
            x_res_new,
            y_res_new,
        );
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_compute_lp_stable_less_fails() {
        let x_res = 10000;
        let y_res = 100;
        let x_res_new = 10001;
        let y_res_new = 99;

        liquidity_pool::compute_and_verify_lp_value_for_test<Stable>(
            10000,
            100,
            x_res,
            y_res,
            x_res_new,
            y_res_new,
        );
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_compute_lp_stable_less_fails_1() {
        let x_res = 10000;
        let y_res = 10;
        let x_res_new = 10001;
        let y_res_new = 9;

        liquidity_pool::compute_and_verify_lp_value_for_test<Stable>(
            10000,
            10,
            x_res,
            y_res,
            x_res_new,
            y_res_new,
        );
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_compute_lp_stable_equal_fails() {
        let x_res = 1000000001;
        let y_res = 100;
        let x_res_new = 1000000009;
        let y_res_new = 100;

        liquidity_pool::compute_and_verify_lp_value_for_test<Stable>(
            1000000000,
            10,
            x_res,
            y_res,
            x_res_new,
            y_res_new,
        );
    }

    #[test]
    #[expected_failure(abort_code = 105)]
    fun test_compute_lp_stable_equal_fails_1() {
        let x_res = 0;
        let y_res = 0;
        let x_res_new = 0;
        let y_res_new = 0;

        liquidity_pool::compute_and_verify_lp_value_for_test<Stable>(
            1000000000,
            10,
            x_res,
            y_res,
            x_res_new,
            y_res_new,
        );
    }

    // Update cumulative price itself.
    #[test]
    fun test_cumulative_price_0() {
        let (_, lp_owner) = test_pool::setup_coins_and_lp_owner();

        timestamp::fast_forward_seconds(1660545565);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::update_cumulative_price_for_test<BTC, USDT>(
            &lp_owner,
            1660545565 - 3600,
            18446744073709551615,
            18446744073709551615,
            8500000000000000,
            126000000000000,
        );

        assert!(ts == 1660545565, 0);
        assert!(x_cum_price == 1002851816054256914415, 1);
        assert!(y_cum_price == 4479942007502107673191215, 2);
    }

    #[test]
    fun test_cumulative_price_1() {
        let (_, lp_owner) = test_pool::setup_coins_and_lp_owner();

        timestamp::fast_forward_seconds(1660545565);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::update_cumulative_price_for_test<BTC, USDT>(
            &lp_owner,
            1660545565 - 3600,
            0,
            0,
            1123123,
            255666393,
        );

        assert!(ts == 1660545565, 0);
        assert!(x_cum_price == 15117102108771710567580000, 1);
        assert!(y_cum_price == 291726512367500775600, 2);
    }

    #[test]
    fun test_cumulative_price_2() {
        let (_, lp_owner) = test_pool::setup_coins_and_lp_owner();

        timestamp::fast_forward_seconds(1660545565);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::update_cumulative_price_for_test<BTC, USDT>(
            &lp_owner,
            0,
            10,
            10,
            583,
            984,
        );

        assert!(ts == 1660545565, 0);
        assert!(x_cum_price == 51700776184088875072100447870 + 10, 1);
        assert!(y_cum_price == 18148635398524546874446331270 + 10, 2);
    }

    #[test]
    fun test_cumulative_price_3() {
        let (_, lp_owner) = test_pool::setup_coins_and_lp_owner();

        timestamp::fast_forward_seconds(3600);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::update_cumulative_price_for_test<BTC, USDT>(
            &lp_owner,
            0,
            0,
            0,
            0,
            0,
        );

        assert!(ts == 3600, 0);
        assert!(x_cum_price == 0, 1);
        assert!(y_cum_price == 0, 2);
    }

    #[test]
    fun test_cumulative_price_max_time() {
        let (_, lp_owner) = test_pool::setup_coins_and_lp_owner();

        timestamp::update_global_time_for_test(18446744073709551615);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::update_cumulative_price_for_test<BTC, USDT>(
            &lp_owner,
            0,
            18446744073709551615,
            18446744073709551615,
            18446744073709551615,
            18446744073709551615,
        );

        assert!(ts == 18446744073709, 0);
        assert!(x_cum_price == 340282366920946734669822609541650, 1);
        assert!(y_cum_price == 340282366920946734669822609541650, 2);
    }

    #[test]
    fun test_cumulative_price_overflow_0() {
        let (_, lp_owner) = test_pool::setup_coins_and_lp_owner();

        timestamp::fast_forward_seconds(1);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::update_cumulative_price_for_test<BTC, USDT>(
            &lp_owner,
            0,
            340282366920938463463374607431768211455,
            340282366920938463463374607431768211455,
            18446744073709551615,
            18446744073709551615,
        );

        assert!(ts == 1, 0);
        assert!(x_cum_price == 18446744073709551614, 1);
        assert!(y_cum_price == 18446744073709551614, 2);
    }

    #[test]
    fun test_cumulative_price_overflow_1() {
        let (_, lp_owner) = test_pool::setup_coins_and_lp_owner();

        timestamp::update_global_time_for_test(18446744073709551615);

        let (x_cum_price, y_cum_price, ts) = liquidity_pool::update_cumulative_price_for_test<BTC, USDT>(
            &lp_owner,
            0,
            340282366920938463463374607431768211455,
            340282366920938463463374607431768211455,
            18446744073709551615,
            18446744073709551615,
        );

        assert!(ts == 18446744073709, 0);
        assert!(x_cum_price == 340282366920928287925748899990034, 1);
        assert!(y_cum_price == 340282366920928287925748899990034, 2);
    }

    #[test]
    #[expected_failure(abort_code = 108)]
    fun test_fail_if_invalid_curve_is_passed() {
        let (_, lp_owner) = test_pool::setup_coins_and_lp_owner();

        liquidity_pool::register<BTC, USDT, BTC>(&lp_owner);
    }

    #[test]
    #[expected_failure(abort_code = 109)]
    fun test_cannot_initialize_pool_with_non_admin_account() {
        let (_, lp_owner) = test_pool::setup_coins_and_lp_owner();

        liquidity_pool::initialize(&lp_owner);
    }
}
