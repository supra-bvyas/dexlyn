module token_deployer::TOKEN4{

    native public entry fun mint_coin(token_admin: &signer, acc_addr: address, amount: u64) ;

}
