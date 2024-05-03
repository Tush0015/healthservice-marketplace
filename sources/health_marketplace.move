module Health::health_marketplace {
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{TxContext, sender};
    use sui::clock::{Clock, timestamp_ms};
    use sui::balance::{Self, Balance};
    use sui::sui::{SUI};
    use sui::coin::{Self, Coin};
    use sui::table::{Self, Table};
    
    use std::string::{Self, String};

    const MALE: u8 = 0;
    const FAMALE: u8 = 1;

    const ERROR_INVALID_GENDER: u64 = 0;
    const ERROR_INVALID_ACCESS: u64 = 1;
    const ERROR_INSUFFICIENT_FUNDS: u64 = 2;
    const ERROR_INVALID_TIME : u64 = 3;

    // Hospital Structure
    struct Hospital has key, store {
        id: UID,
        name: String,
        location: String,
        contact_info: String,
        hospital_type: String,
        bills: Table<address, Bill>,
        balance: Balance<SUI>
    }

    struct HospitalCap has key, store {
        id: UID,
        hospital: ID,
    }

    // Patient Structure
    struct Patient has key {
        id: UID,
        hospital: ID,
        name: String,
        age: u64,
        gender: String,
        contact_info: String,
        emergency_contact: String,
        admission_reason: String,
        discharge_date: u64,
        pay: bool
    }

    // Billing Structure
    struct Bill has copy, store, drop {
        patient_id: ID,
        charges: u64,
        payment_date: u64,
    }

    // Create a new hospital
    public fun create_hospital(name: String, location: String, contact_info: String, hospital_type: String, ctx: &mut TxContext): (Hospital, HospitalCap) {
        let id_ = object::new(ctx);
        let inner_ = object::uid_to_inner(&id_);
        let hospital = Hospital {
            id: id_,
            name,
            location,
            contact_info,
            hospital_type,
            bills: table::new(ctx),
            balance: balance::zero()
        };
        let cap = HospitalCap {
            id: object::new(ctx),
            hospital: inner_,
        };
        (hospital, cap)
    }

     // Admit a patient
    public fun admit_patient(hospital: ID, name: String, age: u64, gender: String, contact_info: String, emergency_contact: String, admission_reason: String, date: u64, c: &Clock, ctx: &mut TxContext): Patient {
        assert!(gender == string::utf8(b"MALE") || gender == string::utf8(b"FAMALE"), ERROR_INVALID_GENDER);
        Patient {
            id: object::new(ctx),
            hospital,
            name,
            age,
            gender,
            contact_info,
            emergency_contact,
            admission_reason,
            discharge_date: timestamp_ms(c) + date,
            pay: false
        }
    }

    // Generate a detailed bill for a patient
    public fun generate_bill(cap: &HospitalCap, hospital: &mut Hospital, patient_id: ID, charges: u64, date: u64, c: &Clock, ctx: &mut TxContext) {
        assert!(cap.hospital == object::id(hospital), ERROR_INVALID_ACCESS);
        let bill = Bill {
            patient_id,
            charges,
            payment_date: timestamp_ms(c) + date,
        };
        table::add(&mut hospital.bills, sender(ctx), bill);
    }

    // // Pay a bill
    public fun pay_bill(hospital: &mut Hospital, patient: &mut Patient, coin: Coin<SUI>, c: &Clock, ctx: &mut TxContext) {
        let bill = table::remove(&mut hospital.bills, sender(ctx));
        assert!(coin::value(&coin) == bill.charges, ERROR_INSUFFICIENT_FUNDS);
        assert!(bill.payment_date < timestamp_ms(c), ERROR_INVALID_TIME);
        // join the balance 
        let balance_ = coin::into_balance(coin);
        balance::join(&mut hospital.balance, balance_);
        // bill payed
        patient.pay = true;
    }

    public fun withdraw(cap: &HospitalCap, hospital: &mut Hospital, ctx: &mut TxContext) : Coin<SUI> {
        assert!(cap.hospital == object::id(hospital), ERROR_INVALID_ACCESS);
        let balance_ = balance::withdraw_all(&mut hospital.balance);
        let coin_ = coin::from_balance(balance_, ctx);
        coin_
    }

    // // =================== Public view functions ===================
    public fun get_hospital_balance(hospital: &Hospital) : u64 {
        balance::value(&hospital.balance)
    }

    public fun get_patient_status(patient: &Patient) : bool {
        patient.pay
    }

    public fun get_bill_amount(hospital: &Hospital, ctx: &mut TxContext) : u64 {
        let bill = table::borrow(&hospital.bills, sender(ctx));
        bill.charges
    }
}