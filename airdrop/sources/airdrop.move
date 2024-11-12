module airdrop_deployer::airdrop{
    use std::error;
    use std::signer;
    use std::string::{Self, String};
    use std::vector;
    use aptos_std::table::{Self, Table};
    use supra_framework::coin::{Self};

    use supra_framework::event;

    use supra_addr::supra_vrf;
    use supra_framework::coin::transfer;

    use airdrop_deployer::Token1::{Self,Token1Struct};
    use airdrop_deployer::Token2::{Self,Token2Struct};
    use airdrop_deployer::Token3::{Self,Token3Struct};
    use airdrop_deployer::Token4::{Self,Token4Struct};

    use supra_oracle::supra_oracle_storage;
    ///The request doesnot exist.
    const ERROR_REQUEST_DOESNOT_EXIST: u64 = 1;
    const ERROR_LENGTH_MISMATCH: u64 = 2;
    const ERROR_NOT_DEPLOYER:u64=3;
    const ERROR_ALREADY_REQUESTED:u64=4;
    const ERROR_TIER_NOT_SET:u64=5;
    const ERROR_TIER_NOT_VALID:u64=5;

    struct TierMapper has key, store {
        tier_to_multiplier:Table<u8, u8>,
    }

    struct RequestMapper has key, store {
        req_to_address: Table<u64, address>,
    }

    struct UserDetails has key,store,copy{
        requested: bool,
        tier:u8,
        token_id:u8,
    }

    struct UserMapper has key, store{
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

    fun init_module(deployer: &signer)  {
        move_to(deployer,RequestMapper{
            req_to_address:table::new()
        });
        move_to(deployer,UserMapper{
            add_to_details:table::new()
        })
    }

    public entry fun add_tier_details(deployer: &signer,tier_details:vector<u8>) acquires TierMapper{
        assert!(signer::address_of(deployer)==@airdrop_deployer,error::permission_denied(ERROR_NOT_DEPLOYER));
        //updating tiers
        move_to(deployer,TierMapper{
            tier_to_multiplier:table::new()
        });
        let tier_mapper=borrow_global_mut<TierMapper>(signer::address_of(deployer));
        let i=1;
        vector::for_each(tier_details,|tier|{
            table::add(&mut tier_mapper.tier_to_multiplier, i, tier);
            i=i+1;
        });
    }

     fun getPrice(token_id: u8):u64{
        // let (current_price, decimal, b, current_round) = supra_oracle_storage::get_price(supra_pair_id);
        // let  r: u128 = 1;
        // let  i: u64 = 0;
        //
        // while (i < (decimal as u64)) {
        // r = r * 10;
        // i = i + 1;
        // };
        // let amount = ((r*WORTH_CONSTANT)/current_price);
        // event::emit(RESPONSE{current_price, a:decimal, b, current_round,amount});

         return (160000 as u64)
    }

    // public entry fun check_price(a:u32){
    //     getPrice(a);
    // }

    fun transfer_tokens(to:address,result:u8,tier:u8) acquires TierMapper{
        assert!(exists<TierMapper>(@airdrop_deployer),error::not_found(ERROR_TIER_NOT_SET));
        assert!(tier>=0 && tier<=4,error::out_of_range(ERROR_TIER_NOT_VALID));

        let tier_mapper=borrow_global<TierMapper>(@airdrop_deployer);
        let multiplier=if(tier==0) 1 else *(table::borrow(&tier_mapper.tier_to_multiplier,tier));

        if(result==1){
            let amount=(getPrice((result)))*(multiplier as u64);
            Token1::mint_coin(to,amount);
        }else if(result==2) {
            let amount=getPrice((result))*(multiplier as u64);
            Token2::mint_coin(to,amount);
        }else if(result==3){
            let amount=getPrice((result))*(multiplier as u64);
            Token3::mint_coin(to,amount);
        }else if(result==4){
            let amount=getPrice((result))*(multiplier as u64);
            Token4::mint_coin(to,amount);
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
    acquires RequestMapper,UserMapper,TierMapper
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


        let res = (*verified_num % 4)+1;

        // Update the user data with the resolved number.

        let req_mapper = borrow_global_mut<RequestMapper>(@airdrop_deployer);
        assert!(table::contains(&req_mapper.req_to_address,request),error::invalid_argument(ERROR_REQUEST_DOESNOT_EXIST));
        let user_address=table::borrow(& req_mapper.req_to_address,request);
        // Update user details
        let user_mapper=borrow_global_mut<UserMapper>(@airdrop_deployer);
        let user_detail=table::borrow_mut(&mut user_mapper.add_to_details,*user_address);
        user_detail.token_id=(res as u8);

        transfer_tokens(*user_address,user_detail.token_id,user_detail.tier);
        event::emit(
            RequestResponseEvent { user_address: *user_address, request_id: request, random_number: res}
        );
    }

    fun make_rng_request(sender: &signer) acquires RequestMapper
    {
        // Set some default values for the VRF request.
        let rng_count = 1;
        let client_seed = 0; // This can be customized or passed as "0" for default.

        // Define callback parameters for VRF once the random number is generated.
        let callback_address = @airdrop_deployer;
        let callback_module = string::utf8(b"airdrop");
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
        table::add(&mut req_mapper.req_to_address, request_id, signer::address_of(sender));

        // Emit an event signaling that a new request_id has been created.
        event::emit(RequestEvent {  user_address: signer::address_of(sender), request_id, });
    }

    public entry fun add_wallet_details(sender: &signer,all_address:vector<address>,tier_details:vector<u8>) acquires UserMapper {
        assert!(signer::address_of(sender)==@airdrop_deployer,error::permission_denied(ERROR_NOT_DEPLOYER));
        assert!(vector::length(&all_address)==vector::length(&tier_details),error::invalid_argument(ERROR_LENGTH_MISMATCH));
        let user_mapper=(borrow_global_mut<UserMapper>(@airdrop_deployer));
        vector::zip(all_address,tier_details,|add,tier|{
            table::add(&mut user_mapper.add_to_details, add, UserDetails {
                requested: false,
                tier,
                token_id:0,
            });
        })

    }

    fun register_user(user:&signer){
        if(!coin::is_account_registered<Token1Struct>(signer::address_of(user))){
            coin::register<Token1Struct>(user);
        };
        if(!coin::is_account_registered<Token2Struct>(signer::address_of(user))){
            coin::register<Token2Struct>(user);
        };
        if(!coin::is_account_registered<Token3Struct>(signer::address_of(user))){
            coin::register<Token3Struct>(user);
        };
        if(!coin::is_account_registered<Token4Struct>(signer::address_of(user))){
            coin::register<Token4Struct>(user);
        };


    }

    public entry fun claim(sender: &signer)acquires UserMapper,RequestMapper{
        assert!(exists<TierMapper>(@airdrop_deployer),error::not_found(ERROR_TIER_NOT_SET));

        let sender_address=signer::address_of(sender);
        let user_mapper=borrow_global_mut<UserMapper>(@airdrop_deployer);
        if(!table::contains(&user_mapper.add_to_details,sender_address)){
            //Create user
            table::add(&mut user_mapper.add_to_details,sender_address,UserDetails{
                requested: true,
                tier:0,
                token_id:0,
            });
        } else {
            //Update user
            let user_details=table::borrow_mut(&mut user_mapper.add_to_details,sender_address);
            assert!(!user_details.requested,error::permission_denied(ERROR_ALREADY_REQUESTED));
            user_details.requested=true;
        };
        register_user(sender);
        //Get random nos from Supra VRF
        make_rng_request(sender)

    }

    #[view]
    public fun get_user_details(add:address):(UserDetails) acquires UserMapper{
        let user_mapper=borrow_global<UserMapper>(@airdrop_deployer);
        let user_details=table::borrow( &user_mapper.add_to_details,add);
        return *user_details
    }



}