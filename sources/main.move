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
    /// Represents a health service offered by a healthcare provider
    struct HealthService has key, store {
        id: UID,
        patient: address,
        provider: Option<address>,
        description: vector<u8>,
        price: u64,
        escrow: Balance<SUI>,
        service_performed: bool,
        dispute: bool,
    }

    /// Represents a healthcare provider
    struct HealthcareProvider has key, store {
        id: UID,
        provider_address: address,
        name: vector<u8>,
        specialties: vector<u8>,
        location: vector<u8>, // Address or geographic coordinates
        contact_info: vector<u8>, // Contact information such as phone number, email, etc.
        // Other provider information can be added here
    }

    /// Represents a medical record
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
    /// Creates a new health service with the provided description and price
    public entry fun create_service(description: vector<u8>, price: u64, ctx: &mut TxContext) {
        let service_id = object::new(ctx);
        transfer::share_object(HealthService {
            id: service_id,
            patient: tx_context::sender(ctx),
            provider: none(), // Set to an initial value, can be updated later
            description: description,
            price: price,
            escrow: balance::zero(),
            service_performed: false,
            dispute: false,
        });
    }

    /// Requests a healthcare provider to perform the specified service
    public entry fun request_service(service: &mut HealthService, ctx: &mut TxContext) {
        assert!(!is_some(&service.provider), EInvalidBid);
        service.provider = some(tx_context::sender(ctx));
    }

    /// Marks the service as performed by the assigned healthcare provider
    public entry fun perform_service(service: &mut HealthService, ctx: &mut TxContext) {
        assert!(contains(&service.provider, &tx_context::sender(ctx)), EInvalidService);
        service.service_performed = true;
    }

    /// Raises a dispute for the specified service by the patient
    public entry fun raise_service_dispute(service: &mut HealthService, ctx: &mut TxContext) {
        assert!(service.patient == tx_context::sender(ctx), EDispute);
        service.dispute = true;
    }

    /// Resolves a service dispute and settles the payment based on the resolution
    public entry fun resolve_service_dispute_and_settle_payment(
        service: &mut HealthService,
        resolved: bool,
        ctx: &mut TxContext,
    ) {
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
        reset_service_state(service);
    }

    /// Pays the healthcare provider for the performed service
    public entry fun pay_for_service(service: &mut HealthService, ctx: &mut TxContext) {
        assert!(service.patient == tx_context::sender(ctx), ENotServiceProvider);
        assert!(service.service_performed && !service.dispute, EInvalidService);
        assert!(is_some(&service.provider), EInvalidBid);

        let provider = *borrow(&service.provider);
        let escrow_amount = balance::value(&service.escrow);
        let escrow_coin = coin::take(&mut service.escrow, escrow_amount, ctx);

        // Transfer funds to the service provider
        transfer::public_transfer(escrow_coin, provider);

        // Reset service state
        reset_service_state(service);
    }

    // Additional functions
    /// Cancels a service request and refunds the patient if the service has not been performed or disputed
    public entry fun cancel_service(service: &mut HealthService, ctx: &mut TxContext) {
        assert!(
            service.patient == tx_context::sender(ctx)
                || contains(&service.provider, &tx_context::sender(ctx)),
            ENotServiceProvider,
        );

        refund_patient_for_service(service, ctx);
        reset_service_state(service);
    }

    /// Updates the description of a health service
    public entry fun update_service_description(
        service: &mut HealthService,
        new_description: vector<u8>,
        ctx: &mut TxContext,
    ) {
        assert!(service.patient == tx_context::sender(ctx), ENotServiceProvider);
        service.description = new_description;
    }

    /// Updates the price of a health service
    public entry fun update_service_price(
        service: &mut HealthService,
        new_price: u64,
        ctx: &mut TxContext,
    ) {
        assert!(service.patient == tx_context::sender(ctx), ENotServiceProvider);
        service.price = new_price;
    }

    // New functions
    /// Adds funds to the service's escrow account
   public entry fun add_funds_to_service(
       service: &mut HealthService,
       amount: Coin<SUI>,
       ctx: &mut TxContext,
   ) {
       assert!(tx_context::sender(ctx) == service.patient, ENotServiceProvider);
       let added_balance = coin::into_balance(amount);
       balance::join(&mut service.escrow, added_balance);
   }

   /// Requests a refund for the service if it has not been performed
   public entry fun request_refund_for_service(service: &mut HealthService, ctx: &mut TxContext) {
       assert!(tx_context::sender(ctx) == service.patient, ENotServiceProvider);
       assert!(service.service_performed == false, EInvalidWithdrawal);
       refund_patient_for_service(service, ctx);
       reset_service_state(service);
   }

   /// Updates the healthcare provider assigned to a service
   public entry fun update_service_provider(
       service: &mut HealthService,
       new_provider: address,
       ctx: &mut TxContext,
   ) {
       assert!(service.patient == tx_context::sender(ctx), ENotServiceProvider);
       check_service_eligibility(service);
       service.provider = some(new_provider);
   }

   /// Books an appointment with a healthcare provider for a service
   public entry fun book_appointment(
       service: &mut HealthService,
       provider: address,
       ctx: &mut TxContext,
   ) {
       assert!(tx_context::sender(ctx) == service.patient, ENotServiceProvider);
       check_service_eligibility(service);
       assert!(is_some(&service.provider), EInvalidService);
       assert!(contains(&service.provider, &provider), EInvalidService);
       service.provider = some(provider);
   }

   /// Cancels an appointment with a healthcare provider for a service
   public entry fun cancel_appointment(service: &mut HealthService, ctx: &mut TxContext) {
       assert!(tx_context::sender(ctx) == service.patient, ENotServiceProvider);
       assert!(contains(&service.provider, &tx_context::sender(ctx)), EInvalidService);
       // Reset the provider to none to cancel the appointment
       service.provider = none();
   }

   // Helper functions
   /// Refunds the patient for the service by transferring the escrow funds back
   fun refund_patient_for_service(service: &mut HealthService, ctx: &mut TxContext) {
       if (is_some(&service.provider) && !service.service_performed && !service.dispute) {
           let escrow_amount = balance::value(&service.escrow);
           let escrow_coin = coin::take(&mut service.escrow, escrow_amount, ctx);
           transfer::public_transfer(escrow_coin, service.patient);
       };
   }

   /// Resets the state of a health service
   fun reset_service_state(service: &mut HealthService) {
       service.provider = none();
       service.service_performed = false;
       service.dispute = false;
   }

   /// Checks if a service is eligible for certain operations based on its current state
   fun check_service_eligibility(service: &HealthService) {
       assert!(!service.service_performed && !service.dispute, EInvalidService);
   }
}
