module airdrop_deployer::Token1{
    use std::signer;
    use std::string;
    use std::account;
    friend airdrop_deployer::airdrop;
    use supra_framework::coin::{Self};

    const ENOT_OWNER: u64 = 0;
    const E_ALREADY_HAS_CAPABILITY: u64 = 1;
    const E_DONT_HAVE_CAPABILITY: u64 = 2;

    struct Token1Struct  {}

    struct Token1Capability has key{
        burn_cap: coin::BurnCapability<Token1Struct>,
        freeze_cap: coin::FreezeCapability<Token1Struct>,
        mint_cap: coin::MintCapability<Token1Struct>,
    }

    fun only_owner(addr:address){
        assert!(addr == @airdrop_deployer, ENOT_OWNER);
    }


    fun init_module(account: &signer) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<Token1Struct>(
            account,
            string::utf8(b"TOKEN1"),
            string::utf8(b"TK1"),
            18,
            true,
        );
        coin::register<Token1Struct>(account);
        let coins = coin::mint(1_000_000_000_000_000_000, &mint_cap);
        coin::deposit(signer::address_of(account), coins);

        move_to(account,Token1Capability {
            burn_cap,
            freeze_cap,
            mint_cap,
        });

    }

    /// Mints new coin `CoinType` on account `acc_addr`.
    public(friend) entry fun mint_coin(acc_addr: address, amount: u64) acquires Token1Capability {
        let caps = borrow_global<Token1Capability>(@airdrop_deployer);
        let coins = coin::mint(amount, &caps.mint_cap);
        coin::deposit(acc_addr, coins);

    }

}