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
    const EInvalidTransferAmount: u64 = 8;

    // Struct definitions
    
    struct DeliveryWork has key, store {
        id: UID,
        company: address,
        companyName: vector<u8>,
        origin: vector<u8>,
        destination: vector<u8>,
        deliveryMethod: vector<u8>,
        driver: Option<address>,
        description: vector<u8>,
        deliveryCost: u64,
        escrow: Balance<SUI>,
        deliveryPriority: vector<u8>,
        finishedDelivery: bool,
        delivery_issues: bool,
        proof_of_delivery: Option<vector<u8>>,
        created_at: u64,
        due_date: u64,
    }

    // Driver Profile
    struct DriverProfile has key, store {
        id: UID,
        driver: address,
        driverName: vector<u8>,
        vehicleType: vector<u8>,
        driverRating: u64,
    }

    // Delivery Record
    struct DeliveryRecord has key, store {
        id: UID,
        company: address,
        proof_of_delivery: vector<u8>,
    }

    struct DeliveryRecords has key, store {
        id: UID,
        company: address,
        completedDeliveries: Table<ID, DeliveryRecord>,
    }




    // Create a new Delivery
    public entry fun create_delivery(company: address, companyName: vector<u8>, origin: vector<u8>, 
        destination: vector<u8>, deliveryMethod: vector<u8>, description: vector<u8>, deliveryCost: u64, 
        deliveryPriority: vector<u8>, due_date: u64,
         clock: &Clock, ctx: &mut TxContext) {
        let delivery_id = object::new(ctx);
        transfer::share_object(DeliveryWork {
            id: delivery_id,
            company: company,
            companyName: companyName,
            origin: origin,
            destination: destination,
            deliveryMethod: deliveryMethod,
            driver: none(), 
            description: description,
            deliveryCost: deliveryCost,
            escrow: balance::zero(),
            deliveryPriority: deliveryPriority,
            finishedDelivery: false,
            delivery_issues: false,
            proof_of_delivery: none(),
            created_at: clock::timestamp_ms(clock),
            due_date: due_date,
        });
    }

    // Initialize Delivery Records
    public entry fun initialize_delivery_records(company: address, ctx: &mut TxContext) {
        let delivery_records_id = object::new(ctx);
        let delivery_records = DeliveryRecords {
            id: delivery_records_id,
            company: company,
            completedDeliveries: table::new<ID, DeliveryRecord>(ctx),
        };
        transfer::share_object(delivery_records);
     
    }

    public entry fun create_driver_profile(driver: address, driverName: vector<u8>, vehicleType: vector<u8>, driverRating: u64, ctx: &mut TxContext) {
        let driver_id = object::new(ctx);
        transfer::share_object(DriverProfile {
            id: driver_id,
            driver: driver,
            driverName: driverName,
            vehicleType: vehicleType,
            driverRating: driverRating,
        });
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
        let assigned_driver = borrow(&delivery.driver);
        assert!(tx_context::sender(ctx) == *assigned_driver, ENotDriver); // Ensure the sender is the assigned driver
        delivery.driver = some(tx_context::sender(ctx));
    }

    // The Driver can mark a Delivery as completed
    public entry fun mark_delivery_complete(delivery: &mut DeliveryWork,   ctx: &mut TxContext) {
        assert!(contains(&delivery.driver, &tx_context::sender(ctx)), ENotDriver); // Ensure the sender is the assigned driver
        assert!(!delivery.delivery_issues, EInvalidDeliveryStatus); // Ensure there are no outstanding issues
        delivery.finishedDelivery = true;
    
    }

 
    // Upload proof of delivery and add to delivery records
   public entry fun upload_proof_of_delivery(delivery: &mut DeliveryWork, records: &mut DeliveryRecords, proof: vector<u8>, ctx: &mut TxContext) {
       assert!(tx_context::sender(ctx) == *borrow(&delivery.driver), ENotDriver); // Uncommented line to ensure only the assigned driver can upload proof
       delivery.proof_of_delivery = some(proof);

       let deliveryWorkRecord = DeliveryRecord {
           id: object::new(ctx),
           company: delivery.company,
           proof_of_delivery: proof,
       };
       table::add<ID, DeliveryRecord>(&mut records.completedDeliveries, object::uid_to_inner(&delivery.id), deliveryWorkRecord);

       // Mark the delivery as completed
       mark_delivery_complete(delivery, ctx);
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


    // Helper function to transfer funds
    fun transfer_funds(coin: Coin<SUI>, recipient: address) {
       transfer::public_transfer(coin, recipient);
    }

    // The Company can make payment for a Delivery
    public entry fun make_payment(delivery: &mut DeliveryWork, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == delivery.company, ENotDriver);
        assert!(delivery.finishedDelivery, EInvalidDeliveryStatus);
        // Check if the driver is assigned
        assert!(is_some(&delivery.driver), EInvalidDelivery);

        let state: bool = delivery.finishedDelivery;
        let driver = *borrow(&delivery.driver);
        let escrow_amount = balance::value(&delivery.escrow);
        let escrow_coin = coin::take(&mut delivery.escrow, escrow_amount, ctx);
        if (state) {
           // Transfer funds to the driver
           transfer_funds(escrow_coin, driver);
       } else {
           // Refund funds to the company
           transfer_funds(escrow_coin, delivery.company);
       };

    }


     // The Company can request a refund for a Delivery
    public entry fun request_refund(delivery: &mut DeliveryWork, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == delivery.company, ENotDriver);
        assert!(delivery.finishedDelivery, EInvalidDeliveryStatus);
        let escrow_amount = balance::value(&delivery.escrow);
        let escrow_coin = coin::take(&mut delivery.escrow, escrow_amount, ctx);
        // Refund funds to the company
        transfer_funds(escrow_coin, delivery.company);
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
       transfer_funds(coin, delivery.company);
   }
  



    // Transfer funds to the escrow
   public entry fun transfer_to_escrow(delivery: &mut DeliveryWork, amount: Coin<SUI>, ctx: &mut TxContext) {
       assert!(tx_context::sender(ctx) == delivery.company, ENotDriver);
       assert!(coin::value(&amount) > 0, EInvalidTransferAmount); // Ensure the amount being transferred is not zero
       let add_coin = coin::into_balance(amount);
       balance::join(&mut delivery.escrow, add_coin);
   }

    // The Company can rate a Driver
    public entry fun rate_driver(driver: &mut DriverProfile, rating: u64, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == driver.driver, ENotDriver);
        driver.driverRating = rating;
    }

    // update the driver rating by adding the new rating to the existing rating
    public entry fun update_driver_rating(driver: &mut DriverProfile, rating: u64, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == driver.driver, ENotDriver);
        driver.driverRating = driver.driverRating + rating;
    }

    // Company can pay Tips to the driver for a Delivery
    public entry fun pay_tips(delivery: &mut DeliveryWork, amount: u64, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == delivery.company, ENotCompany);
        let coin = coin::take(&mut delivery.escrow, amount, ctx);
        let driver_address = *borrow(&delivery.driver);
         transfer_funds(coin, driver_address);
    }


    // Get the Delivery status and deliveryCost
   public entry fun get_delivery_info(delivery: &DeliveryWork): (bool, u64) {
       (delivery.finishedDelivery, delivery.deliveryCost)
   }

    
}
