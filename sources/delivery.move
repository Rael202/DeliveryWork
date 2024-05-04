module delivery::delivery {
    // Imports
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID, ID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{TxContext, sender};
    use sui::table::{Self, Table};

    use std::option::{Option, none};
    use std::string::{String};

    // Errors
    //Error for invalid Delivery Status
    const EInvalidDeliveryStatus: u64 = 0;
    // Error for share object access
    const EInvalidAccess : u64 = 1;

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

    struct DeliveryCap has key, store {
        id: UID,
        to: ID
    }

    // Driver Profile
    struct DriverProfile has store, copy, drop {
        driver: address,
        driverName: String,
        vehicleType: String,
        driverRating: u64,
        apply: bool
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
    public fun new_delivery(company: address, deliveryMethod: String, deliveryCost: u64, due_date: u64, ctx: &mut TxContext) : DeliveryCap {
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
        // init the cap 
        let cap = DeliveryCap {
            id: object::new(ctx),
            to: inner_
        };
        cap
    }
    // creates new driver inside the share object
    public entry fun new_driver(self: &mut DeliveryWork, driver: address, driverName: String, vehicleType: String, driverRating: u64) {
        let driver_ = DriverProfile {
            driver: driver,
            driverName: driverName,
            vehicleType: vehicleType,
            driverRating: driverRating,
            apply: false
        };
        table::add(&mut self.drivers, driver, driver_);
    }
    // The Driver can apply for a Delivery
    public entry fun apply_for_delivery(self: &mut DeliveryWork, ctx: &mut TxContext) {
        let driver = table::borrow_mut(&mut self.drivers, sender(ctx));
        driver.apply = true;
    }

    // The Driver can mark a Delivery as completed
    public entry fun mark_delivery_complete(records: &mut DeliveryRecords, self: &mut DeliveryWork, proof_of_delivery: String, ctx: &mut TxContext) {
        let driver = table::borrow_mut(&mut self.drivers, sender(ctx));
        driver.apply = true;

        let deliveryWorkRecord = DeliveryRecord {
            id: object::new(ctx),
            company: self.company,
            proof_of_delivery: proof_of_delivery,
        };
        table::add<ID, DeliveryRecord>(&mut records.completedDeliveries, object::uid_to_inner(&self.id), deliveryWorkRecord);
    }

    // The Company can make payment for a Delivery
    public fun make_payment(cap: &DeliveryCap, self: &mut DeliveryWork, driver: address, ctx: &mut TxContext) {
        assert!(cap.to == object::id(self), EInvalidAccess);
        assert!(self.finishedDelivery, EInvalidDeliveryStatus);

        let driver = table::borrow(&self.drivers, driver);
        let coin = coin::take(&mut self.escrow, self.deliveryCost, ctx);
        transfer::public_transfer(coin, driver.driver);
    }
    // The Company can withdraw funds from the escrow
    public entry fun withdraw_funds(cap: &DeliveryCap, self: &mut DeliveryWork, amount: u64, ctx: &mut TxContext) {
        assert!(cap.to == object::id(self), EInvalidAccess);
        let coin = coin::take(&mut self.escrow, amount, ctx);
        transfer::public_transfer(coin, self.company);
    }
    // Transfer funds to the escrow
    public entry fun deposit(delivery: &mut DeliveryWork, amount: Coin<SUI>) {
        let coin_ = coin::into_balance(amount);
        balance::join(&mut delivery.escrow, coin_);
    }
    // The Company can rate a Driver
    public entry fun rate_driver(cap: &DeliveryCap, self: &mut DeliveryWork, rating: u64, driver: address) {
        assert!(cap.to == object::id(self), EInvalidAccess);
        let driver = table::borrow_mut(&mut self.drivers, driver);
        driver.driverRating = driver.driverRating + rating;
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
