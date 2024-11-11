module airdrop_deployer::airdrop{
    use std::error;
    use std::signer;
    use std::string::{Self, String};
    use std::vector;
    use aptos_std::table::{Self, Table};

    use supra_framework::event;

    use supra_addr::supra_vrf;

    use token_deployer::TOKEN1;
    use token_deployer::TOKEN2;
    use token_deployer::TOKEN3;
    use token_deployer::TOKEN4;

    use supra_oracle::supra_oracle_storage;
    ///The request doesnot exist.
    const ERROR_REQUEST_DOESNOT_EXIST: u64 = 11;
    const ERROR_LENGTH_MISMATCH: u64 = 12;
    const ERROR_NOT_DEPLOYER:u64=13;
    const ERROR_ALREADY_CLAIMED:u64=4;

    const WORTH_CONSTANT: u128 = 1_000;

    struct RequestData has key, store, copy {
        user_address: address,
        resolved_number: u256,
    }

    struct RequestMapper has key {
        req_to_data: Table<u64, RequestData>,
    }

    struct UserDetails has key{
        user_address:address,
        tier:u8,
        is_whitelisted:bool,
        has_claimed:bool

    }

    struct UserMapper has key{
        add_to_details:Table<address,UserDetails>,
    }


    #[event]
    /// Event emitted when a request is created.
    struct RequestEvent has drop, store {
        user_address: address,
        request_id: u64,
    }

    #[event]
    /// Event emitted when decider function is called
    struct RequestResponseEvent has drop, store {
        user_address: address,
        request_id: u64,
        random_number: u256,
    }

    #[event]
    /// Event emitted when decider function is called
    struct RESPONSE  has drop, store {
        current_price:u128,
        a:u16,
        b:u64,
        current_round:u64,
        amount:u128
    }

    // fun init_module(owner: &signer) {
    // }

     fun getPrice(supra_pair_id: u32):u64{
        let (current_price, decimal, b, current_round) = supra_oracle_storage::get_price(supra_pair_id);
        let  r: u128 = 1;
        let  i: u64 = 0;

        while (i < (decimal as u64)) {
        r = r * 10;
        i = i + 1;
        };
        let amount = ((r*WORTH_CONSTANT)/current_price);
        event::emit(RESPONSE{current_price, a:decimal, b, current_round,amount});
         return (amount as u64)
    }

    public entry fun check_price(a:u32){
        getPrice(a);
    }

    public entry fun claim_airdrop(sender:&signer,result:u8,to:address) {
        if(result==1){
            let amount=getPrice((result as u32));
            TOKEN1::mint_coin(sender,to,amount);
        }else if(result==2) {
            let amount=getPrice((result as u32));
            TOKEN2::mint_coin(sender,to,amount);
        }else if(result==3){
            let amount=getPrice((result as u32));
            TOKEN3::mint_coin(sender,to,amount);
        }else if(result==4){
            let amount=getPrice((result as u32));
            TOKEN4::mint_coin(sender,to,amount);
        }

    }

    /// Callback function triggered by Supra VRF once a random number is generated.
    public entry fun call_back(
        request: u64, // Request for the random number request
        message: vector<u8>, // Message returned by VRF
        signature: vector<u8>, // Signature from VRF
        caller_address: address, // Caller address (VRF service)
        rng_count: u8, // Number of RNG values generated
        client_seed: u64         // Seed used for RNG
    )
    acquires RequestMapper,UserMapper
    {
        // Check if the request mapper exists for the contract deployer.
        assert!(exists<RequestMapper>(@airdrop_deployer), error::unavailable(ERROR_REQUEST_DOESNOT_EXIST));

        // Verify the VRF response to ensure it is valid.
        let verified_vec = supra_vrf::verify_callback(
            request,
            message,
            signature,
            caller_address,
            rng_count,
            client_seed
        );

        // Extract the generated number from the verification result.
        let verified_num: &u256 = vector::borrow(&verified_vec, 0);

        // Update the request data with the resolved number.
        let req_mapper = borrow_global_mut<RequestMapper>(@airdrop_deployer);
        let req_data = table::borrow_mut(&mut req_mapper.req_to_data, request);
        let res = (*verified_num % 4)+1;
        req_data.resolved_number = res;
        //Transer tokens for the corresponding value
        // transferring_token()
        // Update user details
        let user_mapper=borrow_global_mut<UserMapper>(@airdrop_deployer);
        if(table::contains(&mut user_mapper.add_to_details,req_data.user_address)){
            let user_detail=table::borrow(&user_mapper.add_to_details,req_data.user_address);
            assert!(user_detail.is_whitelisted,error::permission_denied(ERROR_ALREADY_CLAIMED));
            //Whitelisted user
        } else {
            table::add(&mut user_mapper.add_to_details,req_data.user_address,UserDetails{
                user_address: req_data.user_address,
                tier:0,
                is_whitelisted:false,
                has_claimed:false
            });
        };

        event::emit(
            RequestResponseEvent { user_address: req_data.user_address, request_id: request, random_number: res}
        );
    }

    fun make_rng_request(sender: &signer) acquires RequestMapper
    {
        let sender_address=signer::address_of(sender);
        // Set some default values for the VRF request.
        let rng_count = 1;
        let client_seed = 0; // This can be customized or passed as "0" for default.

        // Define callback parameters for VRF once the random number is generated.
        let callback_address = @airdrop_deployer;
        let callback_module = string::utf8(b"rng_generator");
        let callback_function = string::utf8(b"call_back");
        let num_confirmations = 1;

        // Request random number generation from Supra VRF.
        let request_id = supra_vrf::rng_request(
            sender,
            callback_address,
            callback_module,
            callback_function,
            rng_count,
            client_seed,
            num_confirmations
        );

        // Add the request and user information to the request mapper.
        let req_mapper = borrow_global_mut<RequestMapper>(@airdrop_deployer);
        let user = signer::address_of(sender);
        table::add(&mut req_mapper.req_to_data, request_id, RequestData {
            user_address: user,
            resolved_number: 0,
        });

        // Emit an event signaling that a new request_id has been created.
        event::emit(RequestEvent {  user_address: user, request_id, });
    }

    public entry fun add_wallet_details(sender: &signer,all_address:vector<address>,tier_details:vector<u8>) acquires UserMapper {
        assert!(signer::address_of(sender)==@airdrop_deployer,error::permission_denied(ERROR_NOT_DEPLOYER));
        assert!(vector::length(&all_address)==vector::length(&tier_details),error::invalid_argument(ERROR_LENGTH_MISMATCH));
        let user_mapper=(borrow_global_mut<UserMapper>(@airdrop_deployer));
        vector::zip(all_address,tier_details,|add,tier|{
            table::add(&mut user_mapper.add_to_details, add, UserDetails {
                user_address: add,
                tier,
                is_whitelisted:true,
                has_claimed:false
            });
        })
        // let i=0;
        // vector::for_each(all_address,|add|{
        //     table::add(&mut user_mapper.add_to_details, add, UserDetails {
        //         user_address: add,
        //         tier: *vector::borrow(&tier_details,i),
        //     });
        //     i=i+1;
        // })
    }

    public entry fun decide_token(sender: &signer)acquires UserMapper ,RequestMapper{
        let sender_address=signer::address_of(sender);
        let user_mapper=borrow_global<UserMapper>(@airdrop_deployer);
        if(table::contains(&user_mapper.add_to_details,sender_address)){
            let user_detail=table::borrow(&user_mapper.add_to_details,sender_address);
            assert!(!user_detail.has_claimed,error::permission_denied(ERROR_ALREADY_CLAIMED));
        };
        //Get random nos from Supra VRF
        make_rng_request(sender)

    }


}