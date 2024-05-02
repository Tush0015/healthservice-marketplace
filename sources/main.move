module health_marketplace::health_marketplace {
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use std::option::{Option, none, some, is_some, contains, borrow};
    use sui::event::{Self, Event};

    // Error structs
    struct EInvalidBid has drop {}
    struct EInvalidService has drop {}
    struct EDispute has drop {}
    struct EAlreadyResolved has drop {}
    struct ENotServiceProvider has drop {}
    struct EInvalidWithdrawal has drop {}

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
        disputePeriodEndTime: u64, // Timestamp for dispute period end
        patientRating: Option<u8>, // New field to store patient rating
        providerRating: Option<u8>, // New field to store provider rating
    }

    struct HealthcareProvider has key, store {
        id: UID,
        provider_address: address,
        name: vector<u8>,
        specialties: vector<u8>,
        location: vector<u8>,
        contact_info: vector<u8>,
    }

    struct MedicalRecord has key, store {
        id: UID,
        patient: address,
        diagnosis: vector<u8>,
        treatment: vector<u8>,
        prescriptions: vector<u8>,
    }

    struct HealthMarketplaceConfig has key {
        id: UID,
        authorizedAddresses: vector<address>,
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(HealthMarketplaceConfig {
            id: object::new(ctx),
            authorizedAddresses: vector[tx_context::sender(ctx)],
        })
    }

    // Accessors
    public entry fun get_service_description(service: &HealthService): vector<u8> {
        service.description
    }

    public entry fun get_service_price(service: &HealthService): u64 {
        service.price
    }

    public entry fun get_patient_rating(service: &HealthService): Option<u8> {
        service.patientRating
    }

    public entry fun get_provider_rating(service: &HealthService): Option<u8> {
        service.providerRating
    }

    // Helper functions
    fun is_authorized(addr: address, config: &HealthMarketplaceConfig): bool {
        contains(&config.authorizedAddresses, &addr)
    }

    // Public - Entry functions
    public entry fun create_service(
        description: vector<u8>,
        price: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(is_authorized(sender, borrow_global<HealthMarketplaceConfig>()), ENotServiceProvider);

        let service_id = object::new(ctx);
        transfer::share_object(HealthService {
            id: service_id,
            patient: sender,
            provider: none(),
            description,
            price,
            escrow: balance::zero(),
            servicePerformed: false,
            dispute: false,
            disputePeriodEndTime: 0, // Set to 0 initially
            patientRating: none(),
            providerRating: none(),
        });

        // Emit event for service creation
        event::emit(ServiceCreatedEvent {
            service_id: service_id,
            patient: sender,
            description,
            price,
        });
    }

    public entry fun request_service(service: &mut HealthService, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(is_authorized(sender, borrow_global<HealthMarketplaceConfig>()), ENotServiceProvider);
        assert!(!is_some(&service.provider), EInvalidBid);
        service.provider = some(sender);

        // Emit event for service request
        event::emit(ServiceRequestedEvent {
            service_id: service.id,
            patient: service.patient,
            provider: sender,
        });
    }

    public entry fun perform_service(service: &mut HealthService, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(is_authorized(sender, borrow_global<HealthMarketplaceConfig>()), ENotServiceProvider);
        assert!(contains(&service.provider, &sender), EInvalidService);
        service.servicePerformed = true;

        // Emit event for service performed
        event::emit(ServicePerformedEvent {
            service_id: service.id,
            patient: service.patient,
            provider: sender,
        });
    }

    public entry fun dispute_service(service: &mut HealthService, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(is_authorized(sender, borrow_global<HealthMarketplaceConfig>()), ENotServiceProvider);
        assert!(service.patient == sender, EDispute);
        service.dispute = true;
        service.disputePeriodEndTime = tx_context::epoch(ctx) + 14 * 86400; // Set dispute period to 14 days

        // Emit event for service dispute
        event::emit(ServiceDisputedEvent {
            service_id: service.id,
            patient: sender,
            provider: service.provider,
        });
    }

    public entry fun resolve_service_dispute(
        service: &mut HealthService,
        resolved: bool,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(is_authorized(sender, borrow_global<HealthMarketplaceConfig>()), ENotServiceProvider);
        assert!(service.patient == sender, EDispute);
        assert!(service.dispute, EAlreadyResolved);
        assert!(tx_context::epoch(ctx) >= service.disputePeriodEndTime, EAlreadyResolved); // Check if dispute period has ended
        assert!(is_some(&service.provider), EInvalidBid);
        let escrow_amount = balance::value(&service.escrow);
        let escrow_coin = coin::take(&mut service.escrow, escrow_amount, ctx);
        if (resolved) {
            let provider = *borrow(&service.provider);
            transfer::public_transfer(escrow_coin, provider); // Transfer funds to the service provider
        } else {
            transfer::public_transfer(escrow_coin, service.patient); // Refund funds to the patient
        };

        // Reset service state
        service.provider = none();
        service.servicePerformed = false;
        service.dispute = false;
        service.disputePeriodEndTime = 0;

        // Emit event for service dispute resolution
        event::emit(ServiceDisputeResolvedEvent {
            service_id: service.id,
            patient: service.patient,
            provider: service.provider,
            resolved,
        });
    }

    public entry fun pay_for_service(service: &mut HealthService, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(is_authorized(sender, borrow_global<HealthMarketplaceConfig>()), ENotServiceProvider);
        assert!(service.patient == sender, ENotServiceProvider);
        assert!(service.servicePerformed && !service.dispute, EInvalidService);
        assert!(is_some(&service.provider), EInvalidBid);
        let provider = *borrow(&service.provider);
        let escrow_amount = balance::value(&service.escrow);
        let escrow_coin = coin::take(&mut service.escrow, escrow_amount, ctx);
        transfer::public
        _transfer(escrow_coin, provider); // Transfer funds to the service provider

    // Update ratings
    service.patientRating = some(5); // Example: Patient gets a rating of 5 (out of 5)
    service.providerRating = some(4); // Example: Provider gets a rating of 4 (out of 5)

    // Reset service state
    service.provider = none();
    service.servicePerformed = false;
    service.dispute = false;
    service.disputePeriodEndTime = 0;

    // Emit event for service payment
    event::emit(ServicePaidEvent {
    service_id: service.id,
    patient: sender,
    provider,
    });
    }

    // Additional functions
    public entry fun cancel_service(service: &mut HealthService, ctx: &mut TxContext) {
    let sender = tx_context::sender(ctx);
    assert!(is_authorized(sender, borrow_global<HealthMarketplaceConfig>()), ENotServiceProvider);
    assert!(service.patient == sender || contains(&service.provider, &sender), ENotServiceProvider);

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
    service.disputePeriodEndTime = 0;

    // Emit event for service cancellation
    event::emit(ServiceCancelledEvent {
        service_id: service.id,
        patient: service.patient,
        provider: service.provider,
    });
    }

    public entry fun update_service_description(
    service: &mut HealthService,
    new_description: vector<u8>,
    ctx: &mut TxContext
    ) {
    let sender = tx_context::sender(ctx);
    assert!(is_authorized(sender, borrow_global<HealthMarketplaceConfig>()), ENotServiceProvider);
    assert!(service.patient == sender, ENotServiceProvider);
    service.description = new_description;
    }

    public entry fun update_service_price(
    service: &mut HealthService,
    new_price: u64,
    ctx: &mut TxContext
    ) {
    let sender = tx_context::sender(ctx);
    assert!(is_authorized(sender, borrow_global<HealthMarketplaceConfig>()), ENotServiceProvider);
    assert!(service.patient == sender, ENotServiceProvider);
    service.price = new_price;
    }

    // New functions
    public entry fun add_funds_to_service(
    service: &mut HealthService,
    amount: Coin<SUI>,
    ctx: &mut TxContext
    ) {
    let sender = tx_context::sender(ctx);
    assert!(is_authorized(sender, borrow_global<HealthMarketplaceConfig>()), ENotServiceProvider);
    assert!(tx_context::sender(ctx) == service.patient, ENotServiceProvider);
    let added_balance = coin::into_balance(amount);
    balance::join(&mut service.escrow, added_balance);
    }

    public entry fun request_refund_for_service(service: &mut HealthService, ctx: &mut TxContext) {
    let sender = tx_context::sender(ctx);
    assert!(is_authorized(sender, borrow_global<HealthMarketplaceConfig>()), ENotServiceProvider);
    assert!(tx_context::sender(ctx) == service.patient, ENotServiceProvider);
    assert!(service.servicePerformed == false, EInvalidWithdrawal);
    let escrow_amount = balance::value(&service.escrow);
    let escrow_coin = coin::take(&mut service.escrow, escrow_amount, ctx);
    transfer::public_transfer(escrow_coin, service.patient); // Refund funds to the patient

    // Reset service state
    service.provider = none();
    service.servicePerformed = false;
    service.dispute = false;
    service.disputePeriodEndTime = 0;
    }

    public entry fun update_service_provider(
    service: &mut HealthService,
    new_provider: address,
    ctx: &mut TxContext
    ) {
    let sender = tx_context::sender(ctx);
    assert!(is_authorized(sender, borrow_global<HealthMarketplaceConfig>()), ENotServiceProvider);
    assert!(service.patient == sender, ENotServiceProvider);
    assert!(!service.servicePerformed && !service.dispute, EInvalidService);
    service.provider = some(new_provider);
    }

    public entry fun book_appointment(
    service: &mut HealthService,
    provider: address,
    ctx: &mut TxContext
    ) {
    let sender = tx_context::sender(ctx);
    assert!(is_authorized(sender, borrow_global<HealthMarketplaceConfig>()), ENotServiceProvider);
    assert!(tx_context::sender(ctx) == service.patient, ENotServiceProvider);
    assert!(!service.servicePerformed && !service.dispute, EInvalidService);
    assert!(is_some(&service.provider), EInvalidService);
    assert!(contains(&service.provider, &provider), EInvalidService);
    service.provider = some(provider);

    // Emit event for appointment booking
    event::emit(AppointmentBookedEvent {
        service_id: service.id,
        patient: sender,
        provider,
    });
    }

    public entry fun cancel_appointment(service: &mut HealthService, ctx: &mut TxContext) {
    let sender = tx_context::sender(ctx);
    assert!(is_authorized(sender, borrow_global<HealthMarketplaceConfig>()), ENotServiceProvider);
    assert!(tx_context::sender(ctx) == service.patient, ENotServiceProvider);
    assert!(contains(&service.provider, &tx_context::sender(ctx)), EInvalidService);
    service.provider = none(); // Reset the provider to none to cancel the appointment

    // Emit event for appointment cancellation
    event::emit(AppointmentCancelledEvent {
        service_id: service.id,
        patient: sender,
        provider: service.provider,
    });
    }

    // Function to create a medical record
    public entry fun create_medical_record(
    patient: address,
    diagnosis: vector<u8>,
    treatment: vector<u8>,
    prescriptions: vector<u8>,
    ctx: &mut TxContext
    ) {
    let sender = tx_context::sender(ctx);
    assert!(is_authorized(sender, borrow_global<HealthMarketplaceConfig>()), ENotServiceProvider);

    let record_id = object::new(ctx);
    transfer::share_object(MedicalRecord {
        id: record_id,
        patient,
        diagnosis,
        treatment,
        prescriptions,
    });

    // Emit event for medical record creation
    event::emit(MedicalRecordCreatedEvent {
        record_id,
        patient,
        diagnosis,
        treatment,
        prescriptions,
    });
    }

    // Function to update a medical record
    public entry fun update_medical_record(
    record: &mut MedicalRecord,
    new_diagnosis: vector<u8>,
    new_treatment: vector<u8>,
    new_prescriptions: vector<u8>,
    ctx: &mut TxContext
    ) {
    let sender = tx_context::sender(ctx);
    assert!(is_authorized(sender, borrow_global<HealthMarketplaceConfig>()), ENotServiceProvider);
    assert!(record.patient == sender, ENotServiceProvider);

    record.diagnosis = new_diagnosis;
    record.treatment = new_treatment;
    record.prescriptions = new_prescriptions;

    // Emit event for medical record update
    event::emit(MedicalRecordUpdatedEvent {
        record_id: record.id,
        patient: sender,
        new_diagnosis,
        new_treatment,
        new_prescriptions,
    });
    }

    // Function to create a healthcare provider profile
    public entry fun create_provider_profile(
   name: vector<u8>,
   specialties: vector<u8>,
   location: vector<u8>,
   contact_info: vector<u8>,
   ctx: &mut TxContext
) {
   let sender = tx_context::sender(ctx);
   assert!(is_authorized(sender, borrow_global<HealthMarketplaceConfig>()), ENotServiceProvider);

   let provider_id = object::new(ctx);
   transfer::share_object(HealthcareProvider {
       id: provider_id,
       provider_address: sender,
       name,
       specialties,
       location,
       contact_info,
   });

   // Emit event for provider profile creation
   event::emit(ProviderProfileCreatedEvent {
       provider_id,
       provider_address: sender,
       name,
       specialties,
       location,
       contact_info,
   });
}

// Function to update a healthcare provider profile
    public entry fun update_provider_profile(
    provider: &mut HealthcareProvider,
    new_name: vector<u8>,
    new_specialties: vector<u8>,
    new_location: vector<u8>,
    new_contact_info: vector<u8>,
    ctx: &mut TxContext
    ) {
    let sender = tx_context::sender(ctx);
    assert!(is_authorized(sender, borrow_global<HealthMarketplaceConfig>()), ENotServiceProvider);
    assert!(provider.provider_address == sender, ENotServiceProvider);

    provider.name = new_name;
    provider.specialties = new_specialties;
    provider.location = new_location;
    provider.contact_info = new_contact_info;

    // Emit event for provider profile update
    event::emit(ProviderProfileUpdatedEvent {
        provider_id: provider.id,
        provider_address: sender,
        new_name,
        new_specialties,
        new_location,
        new_contact_info,
    });
    }

    // Event structs
    struct ServiceCreatedEvent has copy, drop {
    service_id: UID,
    patient: address,
    description: vector<u8>,
    price: u64,
    }

    struct ServiceRequestedEvent has copy, drop {
    service_id: UID,
    patient: address,
    provider: address,
    }

    struct ServicePerformedEvent has copy, drop {
    service_id: UID,
    patient: address,
    provider: address,
    }

    struct ServiceDisputedEvent has copy, drop {
    service_id: UID,
    patient: address,
    provider: Option<address>,
    }

    struct ServiceDisputeResolvedEvent has copy, drop {
    service_id: UID,
    patient: address,
    provider: Option<address>,
    resolved: bool,
    }

    struct ServicePaidEvent has copy, drop {
    service_id: UID,
    patient: address,
    provider: address,
    }

    struct ServiceCancelledEvent has copy, drop {
    service_id: UID,
    patient: address,
    provider: Option<address>,
    }

    struct AppointmentBookedEvent has copy, drop {
    service_id: UID,
    patient: address,
    provider: address,
    }

    struct AppointmentCancelledEvent has copy, drop {
    service_id: UID,
    patient: address,
    provider: Option<address>,
    }

    struct MedicalRecordCreatedEvent has copy, drop {
    record_id: UID,
    patient: address,
    diagnosis: vector<u8>,
    treatment: vector<u8>,
    prescriptions: vector<u8>,
    }

    struct MedicalRecordUpdatedEvent has copy, drop {
    record_id: UID,
    patient: address,
    new_diagnosis: vector<u8>,
    new_treatment: vector<u8>,
    new_prescriptions: vector<u8>,
    }

    struct ProviderProfileCreatedEvent has copy, drop {
    provider_id: UID,
    provider_address: address,
    name: vector<u8>,
    specialties: vector<u8>,
    location: vector<u8>,
    contact_info: vector<u8>,
    }

    struct ProviderProfileUpdatedEvent has copy, drop {
    provider_id: UID,
    provider_address: address,
    new_name: vector<u8>,
    new_specialties: vector<u8>,
    new_location: vector<u8>,
    new_contact_info: vector<u8>,
    }
}