// module airdrop_deployer::Warin_coin{
//     use std::signer;
//     use std::string;
//     use std::account;
//     use supra_framework::coin::{Self,zero,Coin,DepositEvent,WithdrawEvent};
//
//     const ENOT_OWNER: u64 = 0;
//     const E_ALREADY_HAS_CAPABILITY: u64 = 1;
//     const E_DONT_HAVE_CAPABILITY: u64 = 2;
//
//     struct Warin  {}
//
//     struct WarinCapability has key{
//         burn_cap: coin::BurnCapability<Warin>,
//         freeze_cap: coin::FreezeCapability<Warin>,
//         mint_cap: coin::MintCapability<Warin>,
//     }
//
//     fun only_owner(addr:address){
//         assert!(addr == @airdrop_deployer, ENOT_OWNER);
//     }
//
//
//     fun init_module(account: &signer) {
//         let (burn_cap, freeze_cap, mint_cap) = coin::initialize<Warin>(
//             account,
//             string::utf8(b"WARIN"),
//             string::utf8(b"WAR"),
//             18,
//             true,
//         );
//
//         move_to(account,WarinCapability {
//             burn_cap,
//             freeze_cap,
//             mint_cap,
//         });
//
//     }
//
//     /// Mints new coin `CoinType` on account `acc_addr`.
//     public entry fun mint_coin(token_admin: &signer, acc_addr: address, amount: u64) acquires WarinCapability {
//         let token_admin_addr = signer::address_of(token_admin);
//         let caps = borrow_global<WarinCapability>(token_admin_addr);
//         let coins = coin::mint(amount, &caps.mint_cap);
//         coin::deposit(acc_addr, coins);
//
//     }
//
// }