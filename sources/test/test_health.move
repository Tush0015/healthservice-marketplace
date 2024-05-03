#[test_only]
module Health::test_health {
    use sui::test_scenario::{Self as ts, Scenario, next_tx, ctx};
    use sui::transfer;
    use sui::test_utils::{assert_eq};
    use sui::coin::{mint_for_testing, Self};
    use sui::object;
    use sui::tx_context::{TxContext};
    use std::string::{Self, String};
    use sui::clock::{Self, Clock};
    use sui::sui::SUI;

    use std::vector::{Self};
    use std::debug;

    use Health::health_marketplace::{Self as hm, Hospital, HospitalCap, Patient, Bill};
    use Health::helpers::{init_test_helper};

    const ADMIN: address = @0xA;
    const TEST_ADDRESS1: address = @0xB;
    const TEST_ADDRESS2: address = @0xC;

    // Initialize the test scenario with admin capability
    #[test]
    public fun test() {

        let scenario_test = init_test_helper();
        let scenario = &mut scenario_test;

        next_tx(scenario, ADMIN);
        {
            let name = string::utf8(b"asd");
            let location = string::utf8(b"asd");
            let contact = string::utf8(b"asd");
            let type = string::utf8(b"asd");

            let (hospital, cap) =  hm::create_hospital(name, location, contact, type, ctx(scenario));

            transfer::public_share_object(hospital);
            transfer::public_transfer(cap, ADMIN);
        };
        let hospital_data = next_tx(scenario, TEST_ADDRESS1);
        let hospital = ts::created(&hospital_data);
        let hospital_id = vector::borrow(&hospital, 0);

        next_tx(scenario, TEST_ADDRESS1);
        {
            let hospital_id = hospital_id;
            let name = string::utf8(b"asd");
            let age: u64 = 1;
            let gender = string::utf8(b"MALE");
            let contact = string::utf8(b"asd");
            let emergency = string::utf8(b"asd");
            let reason = string::utf8(b"asd");
            let date: u64 = 1;
            let time = clock::create_for_testing(ts::ctx(scenario));

            let patient = hm::admit_patient(
                *hospital_id,
                name,
                age,
                gender,
                contact,
                emergency,
                reason,
                date,
                &time,
                ts::ctx(scenario)
            );

            transfer::public_transfer(patient, TEST_ADDRESS1);
            clock::share_for_testing(time); 
        };

        next_tx(scenario, ADMIN);
        {
            let cap = ts::take_from_sender<HospitalCap>(scenario);
            let hospital = ts::take_shared<Hospital>(scenario);
            let patient = ts::take_from_address<Patient>(scenario, TEST_ADDRESS1);
            let patient_id = hm::get_patient_id(&patient);
            let time = ts::take_shared<Clock>(scenario);
            let date: u64 = 1000;
            let charges: u64 = 1000;

            hm::generate_bill(&cap, &mut hospital, patient_id, charges, date, &time, TEST_ADDRESS1, ts::ctx(scenario));

            ts::return_to_sender(scenario, cap);
            ts::return_shared(hospital);
            ts::return_to_address(TEST_ADDRESS1, patient);
            ts::return_shared(time);
        };

        next_tx(scenario, TEST_ADDRESS1);
        {
            let hospital = ts::take_shared<Hospital>(scenario);
            let patient = ts::take_from_sender<Patient>(scenario);
            let time = ts::take_shared<Clock>(scenario);
            let coin = mint_for_testing<SUI>(1000, ts::ctx(scenario));
            clock::increment_for_testing(&mut time, (120 * 60));

            let bill_id = hm::get_bill_id(&hospital);

            hm::pay_bill(&mut hospital, &mut patient, bill_id, coin, &time, ts::ctx(scenario));

            ts::return_to_sender(scenario, patient);
            ts::return_shared(hospital);
            ts::return_shared(time);
        };










        ts::end(scenario_test);      
    }


}