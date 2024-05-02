# Health Marketplace Module

The Health Marketplace module facilitates the management of health services, allowing patients to interact with healthcare providers in a decentralized manner. It offers functionalities for creating, booking, performing, and disputing health services, as well as handling payments and refunds.

## Struct Definitions

### HealthService
- **id**: Unique identifier for the health service.
- **patient**: Address of the patient requesting the service.
- **provider**: Optional address of the healthcare provider assigned to perform the service.
- **description**: Description of the health service.
- **price**: Price of the health service.
- **escrow**: Balance of SUI tokens held in escrow for the service.
- **servicePerformed**: Boolean indicating whether the service has been performed.
- **dispute**: Boolean indicating whether there is a dispute regarding the service.

### HealthcareProvider
- **id**: Unique identifier for the healthcare provider.
- **provider_address**: Address of the healthcare provider.
- **name**: Name of the healthcare provider.
- **specialties**: Specialties offered by the healthcare provider.
- **location**: Address or geographic coordinates of the healthcare provider.
- **contact_info**: Contact information for the healthcare provider.

### MedicalRecord
- **id**: Unique identifier for the medical record.
- **patient**: Address of the patient associated with the medical record.
- **diagnosis**: Details of the diagnosis.
- **treatment**: Details of the treatment.
- **prescriptions**: Details of the prescriptions.

## Public - Entry Functions

### create_service
Creates a new health service listing with the provided description and price.

### request_service
Requests a health service, assigning the patient as the requester.

### perform_service
Marks a health service as performed by the assigned healthcare provider.

### dispute_service
Initiates a dispute regarding a health service.

### resolve_service_dispute
Resolves a dispute regarding a health service, either refunding the patient or paying the provider.

### pay_for_service
Finalizes the payment for a health service performed by the provider.

### cancel_service
Cancels a health service, refunding the patient if not yet performed.

### update_service_description
Updates the description of a health service.

### update_service_price
Updates the price of a health service.

### add_funds_to_service
Adds funds to the escrow balance for a health service.

### request_refund_for_service
Requests a refund for a health service that has not been performed.

### update_service_provider
Updates the healthcare provider assigned to a health service.

### book_appointment
Books an appointment with a specific healthcare provider.

### cancel_appointment
Cancels a previously booked appointment.

## Setup

### Prerequisites

1. Rust and Cargo: Install Rust and Cargo on your development machine by following the official Rust installation instructions.

2. SUI Blockchain: Set up a local instance of the SUI blockchain for development and testing purposes. Refer to the SUI documentation for installation instructions.

### Build and Deploy

1. Clone the Health Marketplace repository and navigate to the project directory on your local machine.

2. Compile the smart contract code using the Rust compiler:

   ```bash
   cargo build --release
   ```

3. Deploy the compiled smart contract to your local SUI blockchain node using the SUI CLI or other deployment tools.

4. Note the contract address and other relevant identifiers for interacting with the deployed contract.

## Usage

### Creating a Health Service

To create a new health service listing, invoke the `create_service` function with the required service details, including description and price.

### Requesting a Service

Patients can request healthcare services by placing bids on available listings using the `request_service` function.

### Performing a Service

Healthcare providers can mark services as performed using the `perform_service` function upon completing the service for the patient.

### Managing Disputes

In case of disputes, either party can initiate dispute resolution procedures using the `dispute_service` function to seek a fair resolution.

### Completing a Transaction

Upon successful service delivery, patients can finalize the transaction by paying for the service using the `pay_for_service` function.

### Additional Functions

- **Updating Service Details**: Patients can update service descriptions or prices using the `update_service_description` and `update_service_price` functions, respectively.
- **Adding Funds to Service**: Patients can add funds to the escrow balance for a specific service using the `add_funds_to_service` function.
- **Requesting Refund**: Patients can request a refund for a service that has not been performed using the `request_refund_for_service` function.
- **Updating Service Provider**: Patients can update the assigned healthcare provider for a service using the `update_service_provider` function.

## Interacting with the Smart Contract

### Using the SUI CLI

1. Use the SUI CLI to interact with the deployed smart contract, providing function arguments and transaction contexts as required.

2. Monitor transaction outputs and blockchain events to track the status of service listings and transactions.

### Using Web Interfaces (Optional)

1. Develop web interfaces or applications that interact with the smart contract using JavaScript libraries such as Web3.js or Ethers.js.

2. Implement user-friendly interfaces for creating service listings, placing bids, and managing transactions on the Health Marketplace platform.

## Conclusion

The Health Marketplace Smart Contract offers a decentralized solution for managing healthcare services, promoting accessibility, transparency, and efficiency in the healthcare industry. By leveraging blockchain technology, patients and healthcare providers can engage in secure and transparent transactions, ultimately improving the overall healthcare experience for all stakeholders.
