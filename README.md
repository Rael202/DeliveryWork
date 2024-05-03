# Delivery Contract

This Move code (Delivery Contract) defines a module for managing deliveries on the Sui blockchain. It structures data using objects like DeliveryWork, DriverProfile, and DeliveryRecords. Functions are provided for the entire delivery lifecycle, including creation, driver assignment, completion, proof upload, issue resolution, and payment. Access control mechanisms ensure that only authorized parties (company, driver) can perform specific actions, maintaining security throughout the delivery process.

## Functions 
## Delivery Lifecycle

The code defines functions for various stages of a delivery, including creation, assigning/unassigning drivers, marking completion, uploading proof, resolving issues, and making payments.

### create_delivery
- Creates a new DeliveryWork object and initializes its properties.
- Transfers ownership of the object to the company.

<!--  -->
### initialize_delivery_records

- Creates a new DeliveryRecords object for a company.
- Initializes an empty table to store completed delivery records.

### create_driver_profile:

- Creates a new DriverProfile object for a driver.
- Initializes driver information and rating.

### assign_driver:

- Assigns a specific driver to a delivery (only the company can do this).
- Updates the driver field in the DeliveryWork object.

### unassign_driver:

- Removes the assigned driver from a delivery (only the company can do this).
- Sets the driver field in the DeliveryWork object to None.

### apply_for_delivery:

- Allows a driver to apply for a specific delivery (only if no driver is assigned).
- Updates the driver field in the DeliveryWork object with the applying driver's address.

### mark_delivery_complete:

- Marks a delivery as completed (only the assigned driver can do this).
- Sets the finishedDelivery flag to true.

### add_complete_delivery_record:

- Adds a record of the completed delivery to the company's DeliveryRecords.
- Stores information like company, proof of delivery, and delivery ID

### upload_proof_of_delivery:

- Allows the driver to upload proof of delivery for a completed job.
- Updates the proof_of_delivery field in the DeliveryWork object.
- Triggers the payment process (if applicable).

### report_delivery_issues:

- Allows the driver to report any issues encountered during the delivery.
- Sets the delivery_issues flag to true.

### resolve_delivery_issues:

- Allows the company to resolve reported delivery issues.
- Resets finishedDelivery and delivery_issues flags.
- Requires the delivery to have a driver assigned and issues reported.

### make_payment:

- Transfers funds from the delivery escrow to the driver upon successful completion.
- Verifies that the delivery is marked as finished and has a driver assigned.

### request_refund:

- Allows the company to request a refund of escrow funds if the delivery is not completed.
- Requires the delivery to be marked as finished.

### extend_due_date:

- Allows the company to extend the due date for a delivery.
- Updates the due_date field in the DeliveryWork object.

### update_delivery_price:

- Allows the company to update the delivery cost.
- Updates the deliveryCost field in the DeliveryWork object.

### withdraw_funds:

- Allows the company to withdraw funds from the delivery escrow.
- Requires the company to be the sender and verifies sufficient escrow balance.

### transfer_to_escrow:

- Allows the company to add funds to the delivery escrow.
- Verifies that the sender is the company.

### rate_driver:

- Allows the driver to update their own driver rating.
- Updates the `driverRating` field in the `DriverProfile` object.

### update_driver_rating:

- Allows the driver to update their own driver rating by adding a new value.
- Updates the driverRating field in the DriverProfile object.

### pay_tips:

- Allows the company to pay additional tips to the driver for a completed delivery.
- Transfers funds from the delivery escrow to the driver's address.

### view_delivery_status:

- Returns a boolean indicating whether the delivery is marked as completed.

### get_deliveryCost:

- Returns the delivery cost associated with a specific delivery.

### After Succesful build Result:
``` bash
    INCLUDING DEPENDENCY Sui
    INCLUDING DEPENDENCY MoveStdlib
    BUILDING delivery
```

### Installation and Deployment
Before we proceed, we should install a couple of things. Also, if you are using a Windows machine, it's recommended to use WSL2.

On Ubuntu/Debian/WSL2(Ubuntu):
```
sudo apt update
sudo apt install curl git-all cmake gcc libssl-dev pkg-config libclang-dev libpq-dev build-essential -y
```
On MacOs:
```
brew install curl cmake git libpq
```
If you don't have `brew` installed, run this:
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Next, we need rust and cargo:
```
curl https://sh.rustup.rs -sSf | sh
```

### Install Sui
If you are using Github codespaces, it's recommended to use pre-built binaries rather than building them from source.

To download pre-built binaries, you should run `download-sui-binaries.sh` in the terminal. 
This scripts takes three parameters (in this particular order) - `version`, `environment` and `os`:
- sui version, for example `1.15.0`. You can lookup a more up-to-date version available here [SUI Github releases](https://github.com/MystenLabs/sui/releases).
- `environment` - that's the environment that you are targeting, in our case it's `devnet`. Other available options are: `testnet` and `mainnet`.
- `os` - name of the os. If you are using Github codespaces, put `ubuntu-x86_64`. Other available options are: `macos-arm64`, `macos-x86_64`, `ubuntu-x86_64`, `windows-x86_64` (not for WSL).

To donwload SUI binaries for codespace, run this command:
```
./download-sui-binaries.sh "v1.18.0" "devnet" "ubuntu-x86_64"
```
and restart your terminal window.

If you prefer to build the binaries from source, run this command in your terminal:
```
cargo install --locked --git https://github.com/MystenLabs/sui.git --branch devnet sui
```

### Install dev tools (not required, might take a while when installin in codespaces)
```
cargo install --git https://github.com/move-language/move move-analyzer --branch sui-move --features "address32"

```

### Run a local network
To run a local network with a pre-built binary (recommended way), run this command:
```
RUST_LOG="off,sui_node=info" sui-test-validator
```

Optionally, you can run it from sources.
```
git clone --branch devnet https://github.com/MystenLabs/sui.git

cd sui

RUST_LOG="off,sui_node=info" cargo run --bin sui-test-validator
```

### Install SUI Wallet (optionally)
```
https://chrome.google.com/webstore/detail/sui-wallet/opcgpfmipidbgpenhmajoajpbobppdil?hl=en-GB
```

### Configure connectivity to a local node
Once the local node is running (using `sui-test-validator`), you should the url of a local node - `http://127.0.0.1:9000` (or similar).
Also, another url in the output is the url of a local faucet - `http://127.0.0.1:9123`.

Next, we need to configure a local node. To initiate the configuration process, run this command in the terminal:
```
sui client active-address
```
The prompt should tell you that there is no configuration found:
```
Config file ["/home/codespace/.sui/sui_config/client.yaml"] doesn't exist, do you want to connect to a Sui Full node server [y/N]?
```
Type `y` and in the following prompts provide a full node url `http://127.0.0.1:9000` and a name for the config, for example, `localnet`.

On the last prompt you will be asked which key scheme to use, just pick the first one (`0` for `ed25519`).

After this, you should see the ouput with the wallet address and a mnemonic phrase to recover this wallet. You can save so later you can import this wallet into SUI Wallet.

Additionally, you can create more addresses and to do so, follow the next section - `Create addresses`.


### Create addresses
For this tutorial we need two separate addresses. To create an address run this command in the terminal:
```
sui client new-address ed25519
```
where:
- `ed25519` is the key scheme (other available options are: `ed25519`, `secp256k1`, `secp256r1`)

And the output should be similar to this:
```
╭─────────────────────────────────────────────────────────────────────────────────────────────────╮
│ Created new keypair and saved it to keystore.                                                   │
├────────────────┬────────────────────────────────────────────────────────────────────────────────┤
│ address        │ 0x05db1e318f1e4bc19eb3f2fa407b3ebe1e7c3cd8147665aacf2595201f731519             │
│ keyScheme      │ ed25519                                                                        │
│ recoveryPhrase │ lava perfect chef million beef mean drama guide achieve garden umbrella second │
╰────────────────┴────────────────────────────────────────────────────────────────────────────────╯
```
Use `recoveryPhrase` words to import the address to the wallet app.


### Get localnet SUI tokens
```
curl --location --request POST 'http://127.0.0.1:9123/gas' --header 'Content-Type: application/json' \
--data-raw '{
    "FixedAmountRequest": {
        "recipient": "<ADDRESS>"
    }
}'
```
`<ADDRESS>` - replace this by the output of this command that returns the active address:
```
sui client active-address
```

You can switch to another address by running this command:
```
sui client switch --address <ADDRESS>
```
abd run the HTTP request to mint some SUI tokens to this account as well.

Also, you can top up the balance via the wallet app. To do that, you need to import an account to the wallet.

## Build and publish a smart contract

### Build package
To build tha package, you should run this command:
```
sui move build
```

If the package is built successfully, the next step is to publish the package:
### Publish package
```
sui client publish --gas-budget 100000000 --json
```
Here we do not specify the path to the package dir so it will use the current dir - `.`

After the contract is published we need to extract some object ids from the output. Here is the list of env variable that we source in the current shell and their values:
- `PACKAGE_ID` - the id of the published package. The json path to it is `.objectChanges[].packageId`
- `ORIGINAL_UPGRADE_CAP_ID` - the upgrade cap id that we might need if we find ourselves in the situation when we need to upgrade the contract. Path: `.objectChanges[].objectId` where `.objectChanges[].objectType` is  `0x2::package::UpgradeCap`
- `SUI_FEE_COIN_ID` the id of the SUI coin that we are going to use to pay the fee for the pool creation. Take any from the output of this command: `sui client gas --json`
- `ACCOUNT_ID1` - currently active address, assign the output of this command: `sui client active-address`. Repeat the same for the secondary account and assign the output to `ACCOUNT_ID1`
- `CLOCK_OBJECT_ID` - the id of the `Clock` object, default to `0x6`
- `BASE_COIN_TYPE` - the type of the SUI coin, default to `0x2::sui::SUI`
- `QUOTE_COIN_TYPE` - the type of the quote coin that we deployed for the sake of this tutorial. The coin is `WBTC` in the `wbtc` module in the `$PACKAGE_ID` package. So the value will look like this: `<PACKAGE_ID>::wbtc::WBTC`
- `WBTC_TREASURY_CAP_ID` it's the treasury cap id that is needed for token mint operations. In the publish output you should look for the object with `objectType` `0x2::coin::TreasuryCap<$PACKAGE_ID::wbtc::WBTC>` (replace `$PACKAGE_ID` with the actual package id) and this object also has `objectId` - that's the value that we are looking for.

