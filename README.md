# SecureStake: Clarity DeFi Lending Platform

## Overview
A decentralized lending platform built on Stacks blockchain using Clarity smart contracts, enabling users to lend, borrow, and manage crypto assets with robust collateralization and liquidation mechanisms.

## Features
- Collateralized lending
- Dynamic interest rate calculation
- Loan liquidation
- User loan tracking
- Secure token management

## Prerequisites
- Stacks blockchain
- Compatible wallet (e.g., Hiro Wallet)
- Clarity development environment

## Smart Contract Functionality

### Borrowing
- Minimum collateral ratio: 150%
- Interest rates based on collateral
- Maximum 10 active loans per user

### Liquidation
- Threshold: 125% collateral ratio
- Partial collateral seizure for under-collateralized loans

## Installation
1. Clone repository
2. Deploy token contracts
3. Deploy lending platform contract
4. Initialize contract parameters

## Configuration
- Modify `LENDING-TOKEN` and `COLLATERAL-TOKEN` with actual token contract principals
- Adjust `min-collateral-ratio` and `liquidation-threshold` as needed

## Security Considerations
- Extensive error handling
- Collateral ratio checks
- Transfer validations

## Future Improvements
- Advanced liquidation mechanisms
- More complex interest models
- Enhanced access controls

## Contributing
1. Fork repository
2. Create feature branch
3. Commit changes
4. Push and submit pull request
