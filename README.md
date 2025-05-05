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

## Smart Contract  
`contracts/MealCoinAMM.sol` (**excerpt**)

```solidity
// SPDX‑License‑Identifier: MIT
pragma solidity ^0.8.0;

contract MealCoinAMM is ERC20, Ownable {
    /* ---------- storage ---------- */
    mapping(address => uint256) public usdcBalance;
    mapping(address => uint256) public lpShares;
    uint256 public totalLPShares;
    uint256 public reserveUSDC;
    uint256 public reserveMLC;

    bool     public secondaryMarketOpen;            // term‑level switch
    uint256  public constant MEAL_BLOCK_COST = 1_500 * 10**18;

    /* ---------- admin controls ---------- */
    function openSecondaryMarket()  external onlyOwner { … }
    function closeSecondaryMarket() external onlyOwner { … }

    /* ---------- AMM ops (gated) ---------- */
    function addLiquidity(uint256 usdcAmt, uint256 mlcAmt)
        external onlyWhenMarketOpen returns (uint256) { … }

    function buyMealCoin(uint256 usdcAmt)
        external onlyWhenMarketOpen returns (uint256) { … }

    function sellMealCoin(uint256 mlcAmt)
        external onlyWhenMarketOpen returns (uint256) { … }

    /* ---------- utilities ---------- */
    function disburseTo(address to, uint256 amt)   external onlyOwner { … }
    function purchaseFromVendor(address vendor, uint256 count) external { … }
}
### 🚀 Highlights

| Feature                                   | Purpose                                                                                      |
|-------------------------------------------|----------------------------------------------------------------------------------------------|
| `secondaryMarketOpen`                     | Global on/off switch, toggled by **admin** at the start / end of each term                  |
| `onlyWhenMarketOpen`                      | Modifier that guards **all** pool & swap functions                                           |
| `openSecondaryMarket()` / `closeSecondaryMarket()` | Emit `SecondaryMarketOpened / Closed` events so the front‑end can listen                     |
| Constant‑product pricing                  | Simple `x × y = k` AMM math inside `buyMealCoin` / `sellMealCoin`                            |
| Fixed‑price purchases                     | 1 meal block = 1 500 MLC, always payable even when the secondary market is closed            |

---
## 🛠 Interaction Script  
`scripts/interact.js` (**core steps**)

```js
const { ethers } = require("hardhat");
const toWei = (n) => ethers.parseEther(n);

async function main() {
  const [admin, student, vendor] = await ethers.getSigners();

  /* ① Deploy & open market */
  const AMM = await ethers.getContractFactory("MealCoinAMM");
  const amm = await AMM.deploy(admin.address);
  await amm.openSecondaryMarket();

  /* ② Admin adds 1 000 USDC + 100 000 MLC liquidity */
  await amm.disburseTo(admin.address, toWei("100000"));
  await amm.addLiquidity(toWei("1000"), toWei("100000"));

  /* ③ Airdrop 10 000 MLC → student buys one meal (14 MLC) */
  await amm.disburseTo(student.address, toWei("10000"));
  await amm.purchaseFromVendor(vendor.address, 1);

  /* ④ Vendor swaps MLC→USDC; student round‑trips USDC→MLC→USDC */
  await amm.sellMealCoin(await amm.balanceOf(vendor.address));
  await amm.buyMealCoin(toWei("20"));
  await amm.sellMealCoin(toWei("1500"));

  /* ⑤ Admin closes market, reopens, withdraws half LP, closes again */
  await amm.closeSecondaryMarket();
  await amm.openSecondaryMarket();
  const half = (await amm.lpShares(admin.address)) / 2n;
  await amm.removeLiquidity(half);
  await amm.closeSecondaryMarket();
}

main().catch(console.error);

### ▶️ Run the full flow

```bash
npx hardhat run scripts/interact.js --network localhost

## 🛠 Sample Console

```bash
After init ⇒  USDC=1000   MLC=100000
Vendor MLC: 1500
Vendor USDC: 14.78
Student MLC: 10519.45
Student USDC: 94.93
Before close ⇒  USDC=990.28  MLC=100 980.54
Market CLOSED
Admin withdrew half LP & closed again
After close ⇒  USDC=495.14  MLC=50 490.27

## 🏃‍♂️ Run the Code Lab

| Step                | Command |
|---------------------|---------|
| **Compile contracts** | ```bash\nnpx hardhat compile\n``` |
| **Start local node**  | ```bash\nnpx hardhat node\n``` |
| **Execute script**    | ```bash\nnpx hardhat run scripts/interact.js --network localhost\n``` |


## 👀 Visual Demo with MetaMask

1. **Switch to the Hardhat network**  
   *MetaMask → Networks dropdown → “Hardhat (127.0.0.1:8545)”*

2. **Import the MealCoin (MLC) token**  
   *Assets → **Import Token** → paste the deployed contract address → Next → Add*

3. **Watch the Activity tab**  
   * All key actions — **admin opens/closes the market, adds/removes liquidity, swaps, fixed‑price meal purchases** — appear as signed transactions in real time.

4. **Reset for a fresh demo**  
   *MetaMask → Settings → Advanced → **Clear Activity Tab***  

> With the Hardhat network and MLC imported, every step of the script becomes a **GUI‑first classroom demonstration**, eliminating the need to show raw `console.log` output.

