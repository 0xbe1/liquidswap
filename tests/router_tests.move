#[test_only]
module liquidswap::router_tests {
    use std::signer;

    use aptos_framework::coin;
    use aptos_framework::genesis;
    use aptos_framework::timestamp;

    use liquidswap::liquidity_pool;
    use liquidswap::router;
    use test_coin_admin::test_coins::{Self, USDT, BTC, USDC};
    use test_pool_owner::test_lp::LP;

    const MAX_U64: u64 = 18446744073709551615;

    fun register_pool_with_liquidity(coin_admin: &signer,
                                     pool_owner: &signer,
                                     x_val: u64, y_val: u64) {
        router::register_pool<BTC, USDT, LP>(pool_owner, 2);

        let pool_owner_addr = signer::address_of(pool_owner);
        if (x_val != 0 && y_val != 0) {
            let btc_coins = test_coins::mint<BTC>(coin_admin, x_val);
            let usdt_coins = test_coins::mint<USDT>(coin_admin, y_val);
            let lp_coins =
                liquidity_pool::mint<BTC, USDT, LP>(pool_owner_addr, btc_coins, usdt_coins);
            coin::register_internal<LP>(pool_owner);
            coin::deposit<LP>(pool_owner_addr, lp_coins);
        };
    }

    fun register_stable_pool_with_liquidity(coin_admin: &signer, pool_owner: &signer, x_val: u64, y_val: u64) {
        router::register_pool<USDC, USDT, LP>(pool_owner, 1);

        let pool_owner_addr = signer::address_of(pool_owner);
        if (x_val != 0 && y_val != 0) {
            let usdc_coins = test_coins::mint<USDC>(coin_admin, x_val);
            let usdt_coins = test_coins::mint<USDT>(coin_admin, y_val);
            let lp_coins =
                liquidity_pool::mint<USDC, USDT, LP>(pool_owner_addr, usdc_coins, usdt_coins);
            coin::register_internal<LP>(pool_owner);
            coin::deposit<LP>(pool_owner_addr, lp_coins);
        };
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_add_initial_liquidity(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 0, 0);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = test_coins::mint(&coin_admin, 10100);
        let pool_addr = signer::address_of(&pool_owner);

        let (coin_x, coin_y, lp_coins) =
            router::add_liquidity<BTC, USDT, LP>(
                pool_addr,
                btc_coins,
                101,
                usdt_coins,
                10100,
            );

        assert!(coin::value(&coin_x) == 0, 0);
        assert!(coin::value(&coin_y) == 0, 1);
        // 1010 - 1000 = 10
        assert!(coin::value(&lp_coins) == 10, 2);

        coin::register_internal<BTC>(&pool_owner);
        coin::register_internal<USDT>(&pool_owner);
        coin::register_internal<LP>(&pool_owner);

        coin::deposit(pool_addr, coin_x);
        coin::deposit(pool_addr, coin_y);
        coin::deposit(pool_addr, lp_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_add_liquidity_to_pool(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 9000);
        let pool_addr = signer::address_of(&pool_owner);

        let (coin_x, coin_y, lp_coins) =
            router::add_liquidity<BTC, USDT, LP>(
                pool_addr,
                btc_coins,
                10,
                usdt_coins,
                9000,
            );
        // 101 - 90 = 11
        assert!(coin::value(&coin_x) == 11, 0);
        assert!(coin::value(&coin_y) == 0, 1);
        // 8.91 ~ 8
        assert!(coin::value(&lp_coins) == 8, 2);

        coin::register_internal<BTC>(&pool_owner);
        coin::register_internal<USDT>(&pool_owner);

        coin::deposit(pool_addr, coin_x);
        coin::deposit(pool_addr, coin_y);
        coin::deposit(pool_addr, lp_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_add_liquidity_to_pool_reverse(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let btc_coins = test_coins::mint<BTC>(&coin_admin, 101);
        let usdt_coins = test_coins::mint<USDT>(&coin_admin, 9000);
        let pool_addr = signer::address_of(&pool_owner);

        let (coin_y, coin_x, lp_coins) =
            router::add_liquidity<USDT, BTC, LP>(
                pool_addr,
                usdt_coins,
                9000,
                btc_coins,
                10,
            );
        // 101 - 90 = 11
        assert!(coin::value(&coin_x) == 11, 0);
        assert!(coin::value(&coin_y) == 0, 1);
        // 8.91 ~ 8
        assert!(coin::value(&lp_coins) == 8, 2);

        coin::register_internal<BTC>(&pool_owner);
        coin::register_internal<USDT>(&pool_owner);

        coin::deposit(pool_addr, coin_x);
        coin::deposit(pool_addr, coin_y);
        coin::deposit(pool_addr, lp_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_remove_liquidity(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let lp_coins_val = 2u64;
        let pool_addr = signer::address_of(&pool_owner);
        let lp_coins_to_burn = coin::withdraw<LP>(&pool_owner, lp_coins_val);

        let (x_out, y_out) = router::get_reserves_for_lp_coins<BTC, USDT, LP>(
            pool_addr,
            lp_coins_val
        );
        let (coin_x, coin_y) =
            router::remove_liquidity<BTC, USDT, LP>(pool_addr, lp_coins_to_burn, x_out, y_out);

        let (usdt_reserve, btc_reserve) = router::get_reserves_size<USDT, BTC, LP>(pool_addr);
        assert!(usdt_reserve == 8080, 0);
        assert!(btc_reserve == 81, 1);

        assert!(coin::value(&coin_x) == x_out, 2);
        assert!(coin::value(&coin_y) == y_out, 3);

        coin::register_internal<BTC>(&pool_owner);
        coin::register_internal<USDT>(&pool_owner);

        coin::deposit(pool_addr, coin_x);
        coin::deposit(pool_addr, coin_y);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_exact_coin_for_coin(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, 1);

        let usdt_coins = router::swap_exact_coin_for_coin<BTC, USDT, LP>(
            pool_owner_addr,
            btc_coins_to_swap,
            90,
        );
        assert!(coin::value(&usdt_coins) == 98, 0);

        test_coins::burn(&coin_admin, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_exact_coin_for_coin_reverse(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let usdt_coins_to_swap = test_coins::mint<USDT>(&coin_admin, 110);

        let btc_coins = router::swap_exact_coin_for_coin<USDT, BTC, LP>(
            pool_owner_addr,
            usdt_coins_to_swap,
            1,
        );
        assert!(coin::value(&btc_coins) == 1, 0);

        test_coins::burn(&coin_admin, btc_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coin_for_exact_coin(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, 1);

        let (remainder, usdt_coins) =
            router::swap_coin_for_exact_coin<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_swap,
                98,
            );

        assert!(coin::value(&usdt_coins) == 98, 0);
        assert!(coin::value(&remainder) == 0, 1);

        test_coins::burn(&coin_admin, usdt_coins);
        coin::destroy_zero(remainder);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_swap_coin_for_exact_coin_reverse(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let usdt_coins_to_swap = test_coins::mint<USDT>(&coin_admin, 1114);

        let (remainder, btc_coins) =
            router::swap_coin_for_exact_coin<USDT, BTC, LP>(
                pool_owner_addr,
                usdt_coins_to_swap,
                10,
            );

        assert!(coin::value(&btc_coins) == 10, 0);
        assert!(coin::value(&remainder) == 0, 1);

        test_coins::burn(&coin_admin, btc_coins);
        coin::destroy_zero(remainder);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code = 105)]
    fun test_fail_if_price_fell_behind_threshold(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let btc_coin_to_swap = test_coins::mint<BTC>(&coin_admin, 1);

        let usdt_coins =
            router::swap_exact_coin_for_coin<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coin_to_swap,
                102,
            );

        coin::register_internal<USDT>(&pool_owner);
        coin::deposit(pool_owner_addr, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    #[expected_failure(abort_code = 104)]
    fun test_fail_if_swap_zero_coin(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, 0);

        let usdt_coins =
            router::swap_exact_coin_for_coin<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_swap,
                0,
            );

        coin::register_internal<USDT>(&pool_owner);
        coin::deposit(pool_owner_addr, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_returned_usdt_proportially_decrease_for_big_swaps(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);

        let pool_owner_addr = signer::address_of(&pool_owner);
        let btc_coins_to_swap = test_coins::mint<BTC>(&coin_admin, 200);

        let usdt_coins =
            router::swap_exact_coin_for_coin<BTC, USDT, LP>(
                pool_owner_addr,
                btc_coins_to_swap,
                1,
            );
        assert!(coin::value(&usdt_coins) == 6704, 0);

        let (btc_reserve, usdt_reserve) = router::get_reserves_size<BTC, USDT, LP>(pool_owner_addr);
        assert!(btc_reserve == 301, 1);
        assert!(usdt_reserve == 3396, 2);
        assert!(router::current_price<USDT, BTC, LP>(pool_owner_addr) == 11, 3);

        coin::register_internal<USDT>(&pool_owner);
        coin::deposit(pool_owner_addr, usdt_coins);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_pool_exists(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);

        test_coins::register_coins(&coin_admin);

        router::register_pool<BTC, USDT, LP>(&pool_owner, 2);

        assert!(router::pool_exists_at<BTC, USDT, LP>(signer::address_of(&pool_owner)), 0);
        assert!(router::pool_exists_at<USDT, BTC, LP>(signer::address_of(&pool_owner)), 1);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_cumulative_prices_after_swaps(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_pool_with_liquidity(&coin_admin, &pool_owner, 101, 10100);
        coin::register_internal<USDT>(&pool_owner);

        let pool_addr = signer::address_of(&pool_owner);
        let (btc_price, usdt_price, ts) =
            router::get_cumulative_prices<BTC, USDT, LP>(pool_addr);
        assert!(btc_price == 0, 0);
        assert!(usdt_price == 0, 1);
        assert!(ts == 0, 2);

        // 2 seconds
        timestamp::update_global_time_for_test(2000000);

        let btc_to_swap = test_coins::mint<BTC>(&coin_admin, 1);
        let usdts =
            router::swap_exact_coin_for_coin<BTC, USDT, LP>(
                pool_addr,
                btc_to_swap,
                95,
            );
        coin::deposit(pool_addr, usdts);

        let (btc_cum_price, usdt_cum_price, last_timestamp) =
            router::get_cumulative_prices<BTC, USDT, LP>(pool_addr);
        assert!(btc_cum_price == 3689348814741910323000, 3);
        assert!(usdt_cum_price == 368934881474191032, 4);
        assert!(last_timestamp == 2, 5);

        // 4 seconds
        timestamp::update_global_time_for_test(4000000);

        let btc_to_swap = test_coins::mint<BTC>(&coin_admin, 2);
        let usdts =
            router::swap_exact_coin_for_coin<BTC, USDT, LP>(
                pool_addr,
                btc_to_swap,
                190,
            );
        coin::deposit(pool_addr, usdts);

        let (btc_cum_price, usdt_cum_price, last_timestamp) =
            router::get_cumulative_prices<BTC, USDT, LP>(pool_addr);
        assert!(btc_cum_price == 7307080858374124739730, 6);
        assert!(usdt_cum_price == 745173212911578406, 7);
        assert!(last_timestamp == 4, 8);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_curve_swap_exact(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);

        assert!(router::get_curve_type<USDC, USDT, LP>(pool_owner_addr) == 1, 0);

        // Let's exact amount of USDC to USDT.
        let usdc_to_swap_val = 1258044;

        let usdc_to_swap = test_coins::mint<USDC>(&coin_admin, usdc_to_swap_val);

        let usdt_swapped = router::swap_exact_coin_for_coin<USDC, USDT, LP>(
            pool_owner_addr,
            usdc_to_swap,
            125426900,
        );
        // Value 125426900 checked with coin_out func, yet can't run it, as getting timeout on test.
        assert!(coin::value(&usdt_swapped) == 125426900, 1);

        coin::register_internal<USDT>(&pool_owner);
        coin::deposit(pool_owner_addr, usdt_swapped);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_curve_swap_exact_vise_vera(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);

        assert!(router::get_curve_type<USDC, USDT, LP>(pool_owner_addr) == 1, 0);

        // Let's swap USDT -> USDC.
        let usdt_to_swap_val = 125804412;
        let usdt_to_swap = test_coins::mint<USDT>(&coin_admin, usdt_to_swap_val);

        let usdc_swapped = router::swap_exact_coin_for_coin<USDT, USDC, LP>(
            pool_owner_addr,
            usdt_to_swap,
            1254269,
        );
        assert!(coin::value(&usdc_swapped) == 1254269, 1);
        coin::register_internal<USDC>(&pool_owner);
        coin::deposit(pool_owner_addr, usdc_swapped);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_curve_exact_swap(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);

        assert!(router::get_curve_type<USDC, USDT, LP>(pool_owner_addr) == 1, 0);

        // I want to swap USDT to get at least 1258044 USDC.
        let usdc_to_get_val = 1258044;

        // I will need 125804400 USDT coins, verified with Router::get_amount_in.
        let usdt_to_swap = test_coins::mint<USDT>(&coin_admin, 125804400);
        let (usdt_reminder, usdc_swapped) = router::swap_coin_for_exact_coin<USDT, USDC, LP>(
            pool_owner_addr,
            usdt_to_swap,
            usdc_to_get_val,
        );

        assert!(coin::value(&usdt_reminder) == 0, 1);
        assert!(coin::value(&usdc_swapped) == usdc_to_get_val, 2);

        coin::register_internal<USDC>(&pool_owner);
        coin::register_internal<USDT>(&pool_owner);

        coin::deposit(pool_owner_addr, usdt_reminder);
        coin::deposit(pool_owner_addr, usdc_swapped);
    }

    #[test(core = @core_resources, coin_admin = @test_coin_admin, pool_owner = @test_pool_owner)]
    fun test_stable_curve_exact_swap_vise_vera(core: signer, coin_admin: signer, pool_owner: signer) {
        genesis::setup(&core);
        test_coins::register_coins(&coin_admin);
        register_stable_pool_with_liquidity(&coin_admin, &pool_owner, 15000000000, 1500000000000);

        let pool_owner_addr = signer::address_of(&pool_owner);

        assert!(router::get_curve_type<USDC, USDT, LP>(pool_owner_addr) == 1, 0);

        // I want to swap USDC to get 125804401 USDT.
        let usdt_to_get_val = 125804401;

        // I need at least 1258044 USDC coins, verified with Router::get_amount_in.
        let usdc_to_swap = test_coins::mint<USDC>(&coin_admin, 1258044);
        let (usdc_reminder, usdt_swapped) = router::swap_coin_for_exact_coin<USDC, USDT, LP>(
            pool_owner_addr,
            usdc_to_swap,
            usdt_to_get_val,
        );

        assert!(coin::value(&usdc_reminder) == 0, 1);
        assert!(coin::value(&usdt_swapped) == usdt_to_get_val, 2);

        coin::register_internal<USDC>(&pool_owner);
        coin::register_internal<USDT>(&pool_owner);

        coin::deposit(pool_owner_addr, usdc_reminder);
        coin::deposit(pool_owner_addr, usdt_swapped);
    }

    #[test]
    fun test_convert_with_current_price() {
        let a = router::convert_with_current_price(MAX_U64, MAX_U64, MAX_U64);
        assert!(a == MAX_U64, 0);

        a = router::convert_with_current_price(100, 100, 20);
        assert!(a == 20, 1);

        a = router::convert_with_current_price(256, 8, 2);
        assert!(a == 64, 1);
    }

    #[test]
    #[expected_failure(abort_code = 100)]
    fun test_fail_convert_with_current_price_coin_in_val() {
        router::convert_with_current_price(0, 1, 1);
    }

    #[test]
    #[expected_failure(abort_code = 101)]
    fun test_fail_convert_with_current_price_reserve_in_size() {
        router::convert_with_current_price(1, 0, 1);
    }

    #[test]
    #[expected_failure(abort_code = 101)]
    fun test_fail_convert_with_current_price_reserve_out_size() {
        router::convert_with_current_price(1, 1, 0);
    }
}