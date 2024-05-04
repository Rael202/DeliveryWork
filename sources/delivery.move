module delivery::delivery {
    // Imports
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::object::{Self, UID, ID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};

    use std::option::{Option, none, some, is_some, contains, borrow};
    use std::string::{String};

    // Errors
    //Error for invalid Application
    const EInvalidApplication: u64 = 1;
    //Error for invalid Delivery
    const EInvalidDelivery: u64 = 2;
    //Error for invalid Delivery Status
    const EInvalidDeliveryStatus: u64 = 3;
    const ENotCompany: u64 = 4;
    // Error for already resolved issues
    const EAlreadyResolved: u64 = 5;
    // Error for not being a driver
    const ENotDriver: u64 = 6;
    // Error for invalid withdrawal
    const EInvalidWithdrawal: u64 = 7;

    // Struct definitions
    struct DeliveryWork has key, store {
        id: UID,
        company: address,
        deliveryMethod: String,
        driver: Option<address>,
        deliveryCost: u64,
        escrow: Balance<SUI>,
        drivers: Table<address, DriverProfile>,
        finishedDelivery: bool,
        delivery_issues: bool,
        proof_of_delivery: Option<String>,
        due_date: u64,
    }

    // Driver Profile
    struct DriverProfile has store, copy, drop {
        driver: address,
        driverName: String,
        vehicleType: String,
        driverRating: u64,
    }

    // Delivery Record
    struct DeliveryRecord has key, store {
        id: UID,
        company: address,
        proof_of_delivery: String,
    }

    struct DeliveryRecords has key, store {
        id: UID,
        company: ID,
        completedDeliveries: Table<ID, DeliveryRecord>,
    }

    // Create a new Delivery
    public fun new_delivery(company: address, deliveryMethod: String, deliveryCost: u64, due_date: u64, ctx: &mut TxContext) {
        let id_ = object::new(ctx);
        let inner_ = object::uid_to_inner(&id_);
        transfer::share_object(DeliveryWork {
            id: id_,
            company: company,
            deliveryMethod: deliveryMethod,
            driver: none(), 
            deliveryCost: deliveryCost,
            escrow: balance::zero(),
            drivers: table::new(ctx),
            finishedDelivery: false,
            delivery_issues: false,
            proof_of_delivery: none(),
            due_date: due_date
        });
        // Initialize Delivery Records
        let delivery_records_id = object::new(ctx);
        let delivery_records = DeliveryRecords {
            id: delivery_records_id,
            company: inner_,
            completedDeliveries: table::new<ID, DeliveryRecord>(ctx),
        };
        transfer::share_object(delivery_records);

    }
    // creates new driver inside the share object
    public entry fun new_driver(self: &mut DeliveryWork, driver: address, driverName: String, vehicleType: String, driverRating: u64, ctx: &mut TxContext) {
        let driver_ = DriverProfile {
            driver: driver,
            driverName: driverName,
            vehicleType: vehicleType,
            driverRating: driverRating,
        };
        table::add(&mut self.drivers, driver, driver_);
    }

    // The Company can assign a Driver
    public entry fun assign_driver(delivery: &mut DeliveryWork, driver: address, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == delivery.company, ENotDriver);
        delivery.driver = some(driver);
    }

    // The Company can unassign a Driver
    public entry fun unassign_driver(delivery: &mut DeliveryWork, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == delivery.company, ENotDriver);
        delivery.driver = none();
    }

    // The Driver can apply for a Delivery
    public entry fun apply_for_delivery(delivery: &mut DeliveryWork, ctx: &mut TxContext) {
        assert!(is_some(&delivery.driver), EInvalidApplication);
        delivery.driver = some(tx_context::sender(ctx));
    }

    // The Driver can mark a Delivery as completed
    public entry fun mark_delivery_complete(delivery: &mut DeliveryWork,   ctx: &mut TxContext) {
        assert!(contains(&delivery.driver, &tx_context::sender(ctx)), ENotDriver);
        delivery.finishedDelivery = true;
    
    }

    // Add Delivery Record to the Delivery Records
    public entry fun add_complete_delivery_record(records: &mut DeliveryRecords, delivery: &DeliveryWork, proof_of_delivery: String, ctx: &mut TxContext) {
        let deliveryWorkRecord = DeliveryRecord {
            id: object::new(ctx),
            company: delivery.company,
            proof_of_delivery: proof_of_delivery,
        };
        table::add<ID, DeliveryRecord>(&mut records.completedDeliveries, object::uid_to_inner(&delivery.id), deliveryWorkRecord);
    }

    // Upload proof of delivery
    public entry fun upload_proof_of_delivery(delivery: &mut DeliveryWork, proof: String, ctx: &mut TxContext) {
        // assert!(tx_context::sender(ctx) == delivery.driver, ENotDriver);
        delivery.proof_of_delivery = some(proof);
        // Mark the delivery as completed
        // mark_delivery_complete(delivery,records, ctx);
        // Start the Payment process
        make_payment(delivery, ctx);
    }

    // The Driver can report issues with a Delivery
    public entry fun report_delivery_issues(delivery: &mut DeliveryWork, ctx: &mut TxContext) {
        assert!(contains(&delivery.driver, &tx_context::sender(ctx)), ENotDriver);
        delivery.delivery_issues = true;
    }

    // The Company can resolve issues with a Delivery
    public entry fun resolve_delivery_issues(delivery: &mut DeliveryWork, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == delivery.company, ENotDriver);
        assert!(delivery.delivery_issues, EAlreadyResolved);
        assert!(is_some(&delivery.driver), EInvalidDelivery);


        delivery.finishedDelivery = false;
        delivery.delivery_issues = false;
    }

    // The Company can make payment for a Delivery
    public entry fun make_payment(delivery: &mut DeliveryWork, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == delivery.company, ENotDriver);
        assert!(delivery.finishedDelivery, EInvalidDeliveryStatus);

        let state: bool = delivery.finishedDelivery;
        let driver = *borrow(&delivery.driver);
        let escrow_amount = balance::value(&delivery.escrow);
        let escrow_coin = coin::take(&mut delivery.escrow, escrow_amount, ctx);
        if (state) {
            // Transfer funds to the driver
            transfer::public_transfer(escrow_coin, driver);
        } else {
            // Refund funds to the company
            transfer::public_transfer(escrow_coin, delivery.company);
        };
    }

    // The Company can request a refund for a Delivery
    public entry fun request_refund(delivery: &mut DeliveryWork, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == delivery.company, ENotDriver);
        assert!(delivery.finishedDelivery, EInvalidDeliveryStatus);
        let escrow_amount = balance::value(&delivery.escrow);
        let escrow_coin = coin::take(&mut delivery.escrow, escrow_amount, ctx);
        // Refund funds to the company
        transfer::public_transfer(escrow_coin, delivery.company);

    }

    // The Company can extend the due date for a Delivery
    public entry fun extend_due_date(delivery: &mut DeliveryWork, new_due_date: u64, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == delivery.company, ENotDriver);
        delivery.due_date = new_due_date;
    }

    // The Company can update the deliveryCost for a Delivery
    public entry fun update_delivery_price(delivery: &mut DeliveryWork, new_cost: u64, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == delivery.company, ENotDriver);
        delivery.deliveryCost = new_cost;
    }


    // The Company can withdraw funds from the escrow
    public entry fun withdraw_funds(delivery: &mut DeliveryWork, amount: u64, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == delivery.company, ENotDriver);
        assert!(balance::value(&delivery.escrow) >= amount, EInvalidWithdrawal);
        let coin = coin::take(&mut delivery.escrow, amount, ctx);
        transfer::public_transfer(coin, delivery.company);
    }
    // Transfer funds to the escrow
    public entry fun transfer_to_escrow(delivery: &mut DeliveryWork, amount: Coin<SUI>, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == delivery.company, ENotDriver);
        let add_coin = coin::into_balance(amount);
        balance::join(&mut delivery.escrow, add_coin);
    }

    // // The Company can rate a Driver
    // public entry fun rate_driver(driver: &mut DriverProfile, rating: u64, ctx: &mut TxContext) {
    //     assert!(tx_context::sender(ctx) == driver.driver, ENotDriver);
    //     driver.driverRating = rating;
    // }

    // // update the driver rating by adding the new rating to the existing rating
    // public entry fun update_driver_rating(driver: &mut DriverProfile, rating: u64, ctx: &mut TxContext) {
    //     assert!(tx_context::sender(ctx) == driver.driver, ENotDriver);
    //     driver.driverRating = driver.driverRating + rating;
    // }

    // Company can pay Tips to the driver for a Delivery
    public entry fun pay_tips(delivery: &mut DeliveryWork, amount: u64, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == delivery.company, ENotCompany);
        let coin = coin::take(&mut delivery.escrow, amount, ctx);
        let driver_address = *borrow(&delivery.driver);
        sui::transfer::public_transfer(coin, driver_address);
    }

    // The Company can view the Delivery's status
    public entry fun view_delivery_status(delivery: &DeliveryWork): bool {
        delivery.finishedDelivery
    }

    //  get the deliveryCost
    public entry fun get_deliveryCost(delivery: &DeliveryWork): u64 {
        delivery.deliveryCost
    }

    
}
