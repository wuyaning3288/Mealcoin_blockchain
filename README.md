# MealCoin‑AMM &nbsp;⭐️  
_A term‑gated automated‑market‑maker demo for teaching blockchain UX with MetaMask_

![MealCoin](./docs/mealcoin_banner.png)

## Table of Contents
1. [Overview](#overview)  
2. [Prerequisites](#prerequisites)  
3. [Project Setup](#project-setup)  
4. [Smart Contract (`contracts/MealCoinAMM.sol`)](#smart-contract)  
5. [Interaction Script (`scripts/interact.js`)](#interaction-script)  
6. [Run the Code Lab](#run-the-code-lab)  
7. [Visual Demo with MetaMask](#visual-demo-with-metamask)  
8. [License](#license)

---

## Overview
**MealCoinAMM** is an ERC‑20‑based automated‑market‑maker designed for a university setting:

* The **administration** can **open / close** a _secondary‑hand market_ at the start / end of every term.  
* While the market is **open**, students & vendors may add/remove liquidity and swap tokens freely.  
* When the market is **closed**, those actions are blocked; only fixed‑price meal purchases remain.  
* The project ships with a Hardhat script that showcases a full semester flow and logs results.  
* Every on‑chain transaction is visible in **MetaMask** on the Hardhat local network, enabling a live, _GUI‑driven_ classroom demo.

---

## Prerequisites
| Tool | Version |
|------|---------|
| Node.js | ≥ 16 |
| npm | latest |
| Hardhat | `@nomicfoundation/hardhat-toolbox` |
| MetaMask | Browser extension |

> **Tip:** install dependencies first, then start a local JSON‑RPC node:
> ```bash
> npx hardhat node
> ```

---

## Project Setup
```bash
# 1. Clone / init
git clone <your‑repo>.git mealcoin-amm
cd mealcoin-amm

# 2. Init npm & install Hardhat + toolbox
npm init -y
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox

# 3. Create an empty Hardhat project
npx hardhat init          # choose “empty hardhat.config.js”

# 4. hardhat.config.js  (minimal)
require("@nomicfoundation/hardhat-toolbox");
module.exports = {
  defaultNetwork: "localhost",
  networks: { localhost: { url: "http://127.0.0.1:8545" } },
  solidity: "0.8.0"
};
