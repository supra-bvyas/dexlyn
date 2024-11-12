module airdrop_deployer::Token4{
    use std::signer;
    use std::string;
    use std::account;
    friend airdrop_deployer::airdrop;
    use supra_framework::coin::{Self,zero,Coin,DepositEvent,WithdrawEvent};

    const ENOT_OWNER: u64 = 0;
    const E_ALREADY_HAS_CAPABILITY: u64 = 1;
    const E_DONT_HAVE_CAPABILITY: u64 = 2;

    struct Token4Struct  {}

    struct Token4Capability has key{
        burn_cap: coin::BurnCapability<Token4Struct>,
        freeze_cap: coin::FreezeCapability<Token4Struct>,
        mint_cap: coin::MintCapability<Token4Struct>,
    }

    fun only_owner(addr:address){
        assert!(addr == @airdrop_deployer, ENOT_OWNER);
    }


    fun init_module(account: &signer) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<Token4Struct>(
            account,
            string::utf8(b"TOKEN4"),
            string::utf8(b"TK4"),
            18,
            true,
        );

        move_to(account,Token4Capability {
            burn_cap,
            freeze_cap,
            mint_cap,
        });

    }

    /// Mints new coin `CoinType` on account `acc_addr`.
    public(friend) entry fun mint_coin(acc_addr: address, amount: u64) acquires Token4Capability {
        let caps = borrow_global<Token4Capability>(@airdrop_deployer);
        let coins = coin::mint(amount, &caps.mint_cap);
        coin::deposit(acc_addr, coins);

    }

}