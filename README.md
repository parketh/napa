![Group 1 (5)](https://github.com/parketh/napa/assets/27808560/a90777b4-e84c-4feb-b7c0-7db47ced87e4)

# 🔆 𝐧𝐚𝐩𝐚
Napa is an on-chain options order book protocol written in Cairo for the Starknet / Madara stack.

It is deployed as an appchain via the Napa Madara appchain [repo](https://github.com/parketh/napa-appchain) for high throughput and gasless trading (e.g. free order placement and cancellation).

The project was created during the [2023 Starknet Summit](https://summit23.starknet.io/) Hacker House in Palo Alto as an exploration of the [Madara appchain SDK](https://github.com/keep-starknet-strange/madara).

## Overview

Napa is a decentralised options derivative exchange. It allow option buyers and sellers to gain or reduce exposure to single-sided movements in the price of an underlying token pair, either as: 
- **cCall buyers**, who receive exposure to _increases_ in the price of an underlying asset above a certain strike price, in exchange for a premium
- **Call sellers**, who earn a premium in exchange for the obligation to pay a counterparty in the event the price of an underlying asset moves above a certain strike price
- **Put buyers**, who receive exposure to _reductions_ in the price of an underlying asset below a certain strike price, in exchange for a premium
- **Put sellers**, who earn a premium in exchange for the obligation to pay a counterparty in the event the price of an underlying asset moves below a certain strike price

Profits and losses are cash-settled in USDC, meaning market participants can efficiently trade and manage risks without holding the underlying asset.

To enable cash settlement, option sellers must post margin to cover their payment obligation. In the event the market moves against them, and their obligation rises above the value of their margin, the position will be liquidated.

Margin is evaluated at the user account level (commonly referred to as cross margin). This reduces the risk of liquidation but means a worsening of one position can have knock-on effects for other positions in a user's portfolio.

The current version of the protocol has been built with certain concessions for simplicity:
  - Each account can only have at most one open position at a given time
  - Liquidation involves a position being transferred to the protocol owner, rather than being liquidated through the orderbook or through incentives offered to third party liquidators
  - The oracle price is mocked and must be manually updated through the `set_oracle_price` and `set_latest_oracle_price` functions

These can be upgraded in future versions of the protocol.

## Technical architecture

Napa runs on a singleton contract design, with `manager.cairo` being the primary entrypoint for all interactions with the protocol. The table below summarises key actions across the lifecycle of a user's interaction with the protocol.



## Requirements

- Rust
- Cairo
- Scarb

## Setup / Installation

