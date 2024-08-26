![Group 1 (6)](https://github.com/parketh/napa/assets/27808560/bcffd1dc-6797-4b59-8e04-841768a8f3ce)

# 🔆 𝐧𝐚𝐩𝐚
Napa is an on-chain options derivative exchange protocol written in Cairo for the Starknet / Madara stack.

It is deployed as an appchain via the Napa Madara appchain [repo](https://github.com/parketh/napa-appchain) for high throughput and gasless trading (e.g. free order placement and cancellation).

The project was created during the [2023 Starknet Summit](https://summit23.starknet.io/) Hacker House in Palo Alto as an exploration of the [Madara appchain SDK](https://github.com/keep-starknet-strange/madara).

## Requirements

- Rust
- [Cairo v2.2.0](https://github.com/starkware-libs/cairo)
- [Scarb 0.7.0](https://docs.swmansion.com/scarb/)

## Overview

Napa is a decentralised options derivative exchange. 

It allow option buyers and sellers to gain or reduce exposure to single-sided movements in the price of an underlying token pair as: 

- `Call buyers`, who are paid when the price of an underlying asset _increases_ above a certain strike price, in exchange for a premium
- `Call sellers`, who earn a premium in exchange for the obligation to pay out any price increases above a certain strike price
- `Put buyers`, who are paid when the price of an underlying asset _falls_ below a certain strike price, in exchange for a premium
- `Put sellers`, who earn a premium in exchange for the obligation to pay out any price reductions below a certain strike price

Option buyers and sellers place limit and market orders on an on-chain order book to locate counterparties.

## Settlement, margin and liquidations

Profits and losses are cash-settled in USDC, meaning market participants are not required to hold the underlying asset.

To enable cash settlement, option sellers must post margin to cover their position. In the event the market moves against them and their obligation rises above the value of their margin, the position will be liquidated.

Margin is evaluated at the user account level (commonly referred to as 'cross margin'). This reduces the risk of liquidation but increases interactions between positions in a user's portfolio.

The current version of the protocol has been built with certain simplifications:
1. `Positions`: Each account can only have at most one open position at a given time
2. `Liquidation`: Liquidation involves a position being transferred to the protocol owner, rather than being liquidated through the orderbook or through incentives offered to third party liquidators
3. `Mark price`: The oracle price is mocked and must be manually updated through the `set_oracle_price` and `set_latest_oracle_price` functions

These may be upgraded in future versions of the protocol.

## Technical architecture

Napa matches option buyers and sellers through an on-chain Central Limit Order Book (CLOB), which stores:
- A doubly linked list of limit prices
- At each price, a singly linked list of orders

A list architecture is preferred over tree-based architectures to minimise the number of storage rewrites.

Unlike other options protocols like [Aevo](https://www.aevo.xyz/), the matching engine of Napa is written on-chain. It is deployed on an app-chain rather than L2 Starknet to retain high performance and enable free order placement and cancellation.

## Contract

Napa runs on a singleton contract design, with `manager.cairo` being the main entrypoint for user interactions with the protocol. The table below summarises key user actions:

| Action  | Function | User Type |
| ------------- | ------------- | ------------- | 
| Deposit collateral  | `deposit`  | Trader |
| Withdraw collateral  | `withdraw`  | Trader |
| Place limit order  | `place_limit`  | Trader |
| Place market order  | `place_market`  | Trader |
| Settle expired position | `settle`  | Trader |
| Liquidate expired position | `liquidate`  | Trader |
| Transfer contract ownership | `transfer_owner`  | Admin |
| Set parameters for token pair | `set_token_params`  | Admin |
| Set oracle prices | `set_oracle_price`, `set_latest_oracle_price` | Developer |
