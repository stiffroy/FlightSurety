# FlightSurety

FlightSurety is a sample application project for Udacity's Blockchain course.

## Pre-requisite

To run this project one needs to have Ganache UI (preferred as the transactions and account balances can be easily seen) with a minimum of 50 accounts
`account[0]` is the owner account and `account[1]` is the first registered airline account at the time of deployment.

The `firstAirline` variable in the `migrations/2_deploy_contracts.js` should be changes to the address for the first flight (preferably `account[1]`).

Accounts from `account[20]` to `account[49]` (30 accounts) are registered for the oracles in this project.

NOTE: `account[11]` is taken as the customer account in this project.

`npm install`

## Install

This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle), dApp scaffolding (using HTML, CSS and JS) and server app scaffolding.

To install, download or clone the repo, then:

`npm install`

`truffle compile`

## Develop Client

To run truffle tests:

`truffle test ./test/flightSurety.js`

`truffle test ./test/oracles.js`

To use the dapp:

`truffle migrate`
`npm run dapp`

To view dapp:

`http://localhost:8000`

## Develop Server

`npm run server`
`truffle test ./test/oracles.js`

## Deploy

To build dapp for prod:
`npm run dapp:prod`

Deploy the contents of the ./dapp folder


## Resources

* [How does Ethereum work anyway?](https://medium.com/@preethikasireddy/how-does-ethereum-work-anyway-22d1df506369)
* [BIP39 Mnemonic Generator](https://iancoleman.io/bip39/)
* [Truffle Framework](http://truffleframework.com/)
* [Ganache Local Blockchain](http://truffleframework.com/ganache/)
* [Remix Solidity IDE](https://remix.ethereum.org/)
* [Solidity Language Reference](http://solidity.readthedocs.io/en/v0.4.24/)
* [Ethereum Blockchain Explorer](https://etherscan.io/)
* [Web3Js Reference](https://github.com/ethereum/wiki/wiki/JavaScript-API)