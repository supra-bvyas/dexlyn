module token_deployer::TOKEN1{

    native public entry fun mint_coin(token_admin: &signer, acc_addr: address, amount: u64) ;

}
