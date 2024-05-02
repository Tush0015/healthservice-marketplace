module health_marketplace::health_marketplace {

    // Imports
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use std::option::{Option, none, some, is_some, contains, borrow};

    // Errors
    const EInvalidBid: u64 = 1;
    const EInvalidService: u64 = 2;
    const EDispute: u64 = 3;
    const EAlreadyResolved: u64 = 4;
    const ENotServiceProvider: u64 = 5;
    const EInvalidWithdrawal: u64 = 7;

    // Struct definitions
    struct HealthService has key, store {
        id: UID,
        patient: address,
        provider: Option<address>,
        description: vector<u8>,
        price: u64,
        escrow: Balance<SUI>,
        servicePerformed: bool,
        dispute: bool,
    }

    struct HealthcareProvider has key, store {
        id: UID,
        provider_address: address,
        name: vector<u8>,
        specialties: vector<u8>,
        location: vector<u8>, // Address or geographic coordinates
        contact_info: vector<u8>, // Contact information such as phone number, email, etc.
        // Other provider information can be added here
    }

    struct MedicalRecord has key, store {
        id: UID,
        patient: address,
        diagnosis: vector<u8>, // Diagnosis details
        treatment: vector<u8>, // Treatment details
        prescriptions: vector<u8>, // Prescriptions details
        // Other medical record details can be added here
    }

    // Accessors
    public entry fun get_service_description(service: &HealthService): vector<u8> {
        service.description
    }

    public entry fun get_service_price(service: &HealthService): u64 {
        service.price
    }

    // Public - Entry functions
    public entry fun create_service(description: vector<u8>, price: u64, ctx: &mut TxContext) {
        
        let service_id = object::new(ctx);
        transfer::share_object(HealthService {
            id: service_id,
            patient: tx_context::sender(ctx),
            provider: none(), // Set to an initial value, can be updated later
            description: description,
            price: price,
            escrow: balance::zero(),
            servicePerformed: false,
            dispute: false,
        });
    }

    public entry fun request_service(service: &mut HealthService, ctx: &mut TxContext) {
        assert!(!is_some(&service.provider), EInvalidBid);
        service.provider = some(tx_context::sender(ctx));
    }

    public entry fun perform_service(service: &mut HealthService, ctx: &mut TxContext) {
        assert!(contains(&service.provider, &tx_context::sender(ctx)), EInvalidService);
        service.servicePerformed = true;
    }

    public entry fun dispute_service(service: &mut HealthService, ctx: &mut TxContext) {
        assert!(service.patient == tx_context::sender(ctx), EDispute);
        service.dispute = true;
    }

    public entry fun resolve_service_dispute(service: &mut HealthService, resolved: bool, ctx: &mut TxContext) {
        assert!(service.patient == tx_context::sender(ctx), EDispute);
        assert!(service.dispute, EAlreadyResolved);
        assert!(is_some(&service.provider), EInvalidBid);
        let escrow_amount = balance::value(&service.escrow);
        let escrow_coin = coin::take(&mut service.escrow, escrow_amount, ctx);
        if (resolved) {
            let provider = *borrow(&service.provider);
            // Transfer funds to the service provider
            transfer::public_transfer(escrow_coin, provider);
        } else {
            // Refund funds to the patient
            transfer::public_transfer(escrow_coin, service.patient);
        };

        // Reset service state
        service.provider = none();
        service.servicePerformed = false;
        service.dispute = false;
    }

    public entry fun pay_for_service(service: &mut HealthService, ctx: &mut TxContext) {
        assert!(service.patient == tx_context::sender(ctx), ENotServiceProvider);
        assert!(service.servicePerformed && !service.dispute, EInvalidService);
        assert!(is_some(&service.provider), EInvalidBid);
        let provider = *borrow(&service.provider);
        let escrow_amount = balance::value(&service.escrow);
        let escrow_coin = coin::take(&mut service.escrow, escrow_amount, ctx);
        // Transfer funds to the service provider
        transfer::public_transfer(escrow_coin, provider);

        // Reset service state
        service.provider = none();
        service.servicePerformed = false;
        service.dispute = false;
    }

    // Additional functions
    public entry fun cancel_service(service: &mut HealthService, ctx: &mut TxContext) {
        assert!(service.patient == tx_context::sender(ctx) || contains(&service.provider, &tx_context::sender(ctx)), ENotServiceProvider);
        
        // Refund funds to the patient if service not yet performed
        if (is_some(&service.provider) && !service.servicePerformed && !service.dispute) {
            let escrow_amount = balance::value(&service.escrow);
            let escrow_coin = coin::take(&mut service.escrow, escrow_amount, ctx);
            transfer::public_transfer(escrow_coin, service.patient);
        };

        // Reset service state
        service.provider = none();
        service.servicePerformed = false;
        service.dispute = false;
    }

    public entry fun update_service_description(service: &mut HealthService, new_description: vector<u8>, ctx: &mut TxContext) {
        assert!(service.patient == tx_context::sender(ctx), ENotServiceProvider);
        service.description = new_description;
    }

    public entry fun update_service_price(service: &mut HealthService, new_price: u64, ctx: &mut TxContext) {
        assert!(service.patient == tx_context::sender(ctx), ENotServiceProvider);
        service.price = new_price;
    }

    // New functions
    public entry fun add_funds_to_service(service: &mut HealthService, amount: Coin<SUI>, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == service.patient, ENotServiceProvider);
        let added_balance = coin::into_balance(amount);
        balance::join(&mut service.escrow, added_balance);
    }

    public entry fun request_refund_for_service(service: &mut HealthService, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == service.patient, ENotServiceProvider);
        assert!(service.servicePerformed == false, EInvalidWithdrawal);
        let escrow_amount = balance::value(&service.escrow);
        let escrow_coin = coin::take(&mut service.escrow, escrow_amount, ctx);
        // Refund funds to the patient
        transfer::public_transfer(escrow_coin, service.patient);

        // Reset service state
        service.provider = none();
        service.servicePerformed = false;
        service.dispute = false;
    }
     public entry fun update_service_provider(service: &mut HealthService, new_provider: address, ctx: &mut TxContext) {
    assert!(service.patient == tx_context::sender(ctx), ENotServiceProvider);
    assert!(!service.servicePerformed && !service.dispute, EInvalidService);
    service.provider = some(new_provider);
    }
    public entry fun book_appointment(service: &mut HealthService, provider: address, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == service.patient, ENotServiceProvider);
    assert!(!service.servicePerformed && !service.dispute, EInvalidService);
    assert!(is_some(&service.provider), EInvalidService);
    assert!(contains(&service.provider, &provider), EInvalidService);
    service.provider = some(provider);
    }
    public entry fun cancel_appointment(service: &mut HealthService, ctx: &mut TxContext) {
    assert!(tx_context::sender(ctx) == service.patient, ENotServiceProvider);
    assert!(contains(&service.provider, &tx_context::sender(ctx)), EInvalidService);
    // Reset the provider to none to cancel the appointment
    service.provider = none();
    }

}
