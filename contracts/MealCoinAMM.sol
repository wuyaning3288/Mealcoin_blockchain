// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MealCoin automated‑market‑maker (AMM)
 * @dev University‑style AMM where the administration can open / close a secondary‑hand market
 *      at the beginning / end of every term.  When the secondary market is closed, no‐one can
 *      add / remove liquidity or swap – the admin acts as the only liquidity source via
 *      the primary disbursement functions.  Once `openSecondaryMarket()` is called, students
 *      and vendors regain full control of the AMM until `closeSecondaryMarket()` is invoked.
 */
contract MealCoinAMM is ERC20, Ownable {
    /* --------------------------------------------------------------------------
                                    Storage
    -------------------------------------------------------------------------- */
    // Simulated USDC balances for each address (for demo purposes)
    mapping(address => uint256) public usdcBalance;

    // LP‑share bookkeeping
    mapping(address => uint256) public lpShares;
    uint256 public totalLPShares;

    // Reserves held by the pool
    uint256 public reserveUSDC;
    uint256 public reserveMLC;

    // Term‑level market switch
    bool public secondaryMarketOpen;   // false by default

    // Fixed cost per meal block (1 500 MLC)
    uint256 public constant MEAL_BLOCK_COST = 1_500 * 10 ** 18;

    /* --------------------------------------------------------------------------
                                     Events
    -------------------------------------------------------------------------- */
    event Disbursed(address indexed to, uint256 amount);
    event MealPurchased(address indexed student, address indexed vendor, uint256 amount);
    event SecondaryMarketOpened(uint256 blockNumber);
    event SecondaryMarketClosed(uint256 blockNumber);

    /* --------------------------------------------------------------------------
                                   Modifiers
    -------------------------------------------------------------------------- */

    /**
     * @dev Throws when called while the secondary market is closed.
     */
    modifier onlyWhenMarketOpen() {
        require(secondaryMarketOpen, "Secondary market is closed");
        _;
    }

    /* --------------------------------------------------------------------------
                                  Constructor
    -------------------------------------------------------------------------- */

    constructor(address initialOwner) ERC20("MealCoin", "MLC") Ownable(initialOwner) {
        // Seed the admin with test USDC so they can provide initial liquidity
        usdcBalance[initialOwner] = 10_000 * 10 ** 18;
    }

    /* --------------------------------------------------------------------------
                                Internal helpers
    -------------------------------------------------------------------------- */
    function _min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /* --------------------------------------------------------------------------
                         Admin controls for secondary market
    -------------------------------------------------------------------------- */

    /**
     * @notice Opens the secondary market – students & vendors can now add/remove liquidity and swap.
     * @dev Can only be called by the university admin (owner).  Emits `SecondaryMarketOpened`.
     */
    function openSecondaryMarket() external onlyOwner {
        require(!secondaryMarketOpen, "Secondary market already open");
        secondaryMarketOpen = true;
        emit SecondaryMarketOpened(block.number);
    }

    /**
     * @notice Closes the secondary market – swaps & liquidity operations are disabled.
     * @dev Can only be called by the university admin (owner).  Emits `SecondaryMarketClosed`.
     */
    function closeSecondaryMarket() external onlyOwner {
        require(secondaryMarketOpen, "Secondary market not open");
        secondaryMarketOpen = false;
        emit SecondaryMarketClosed(block.number);
    }

    /* --------------------------------------------------------------------------
                              AMM ‑ liquidity & swaps
    -------------------------------------------------------------------------- */

    // Add liquidity (only when market is open)
    function addLiquidity(uint256 usdcAmount, uint256 mlcAmount)
        external
        onlyWhenMarketOpen
        returns (uint256 liquidity)
    {
        require(usdcAmount > 0 && mlcAmount > 0, "Amount must be > 0");
        require(usdcBalance[msg.sender] >= usdcAmount, "Insufficient USDC balance");
        require(balanceOf(msg.sender) >= mlcAmount, "Insufficient MLC balance");

        if (totalLPShares == 0) {
            liquidity = _sqrt(usdcAmount * mlcAmount);
        } else {
            uint256 liquidityFromUSDC = usdcAmount * totalLPShares / reserveUSDC;
            uint256 liquidityFromMLC  = mlcAmount  * totalLPShares / reserveMLC;
            liquidity = _min(liquidityFromUSDC, liquidityFromMLC);
        }
        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");

        // Move assets into the pool
        usdcBalance[msg.sender]    -= usdcAmount;
        usdcBalance[address(this)] += usdcAmount;
        _transfer(msg.sender, address(this), mlcAmount);

        // Update reserves & shares
        reserveUSDC += usdcAmount;
        reserveMLC  += mlcAmount;
        totalLPShares       += liquidity;
        lpShares[msg.sender] += liquidity;

        return liquidity;
    }

    // Remove liquidity (only when market is open)
    function removeLiquidity(uint256 shareAmount)
        external
        onlyWhenMarketOpen
        returns (uint256 amountUSDC, uint256 amountMLC)
    {
        require(shareAmount > 0, "Amount must be > 0");
        require(shareAmount <= lpShares[msg.sender], "Not enough LP shares");

        amountUSDC = shareAmount * reserveUSDC / totalLPShares;
        amountMLC  = shareAmount * reserveMLC  / totalLPShares;
        require(amountUSDC > 0 && amountMLC > 0, "INSUFFICIENT_LIQUIDITY_BURNED");

        // Update bookkeeping
        lpShares[msg.sender]  -= shareAmount;
        totalLPShares         -= shareAmount;
        reserveUSDC           -= amountUSDC;
        reserveMLC            -= amountMLC;

        // Transfer assets
        usdcBalance[address(this)] -= amountUSDC;
        usdcBalance[msg.sender]    += amountUSDC;
        _transfer(address(this), msg.sender, amountMLC);

        return (amountUSDC, amountMLC);
    }

    // Swap USDC → MLC (only when market is open)
    function buyMealCoin(uint256 usdcAmount)
        external
        onlyWhenMarketOpen
        returns (uint256 mlcOut)
    {
        require(usdcAmount > 0, "Amount must be > 0");
        require(reserveUSDC > 0 && reserveMLC > 0, "Pool is empty");
        require(usdcBalance[msg.sender] >= usdcAmount, "Insufficient USDC balance");

        mlcOut = (usdcAmount * reserveMLC) / (reserveUSDC + usdcAmount);
        require(mlcOut > 0, "Output too low");

        // Execute swap
        usdcBalance[msg.sender]    -= usdcAmount;
        usdcBalance[address(this)] += usdcAmount;
        _transfer(address(this), msg.sender, mlcOut);

        reserveUSDC += usdcAmount;
        reserveMLC  -= mlcOut;
    }

    // Swap MLC → USDC (only when market is open)
    function sellMealCoin(uint256 mlcAmount)
        external
        onlyWhenMarketOpen
        returns (uint256 usdcOut)
    {
        require(mlcAmount > 0, "Amount must be > 0");
        require(reserveUSDC > 0 && reserveMLC > 0, "Pool is empty");
        require(balanceOf(msg.sender) >= mlcAmount, "Insufficient MLC balance");

        usdcOut = (mlcAmount * reserveUSDC) / (reserveMLC + mlcAmount);
        require(usdcOut > 0, "Output too low");

        _transfer(msg.sender, address(this), mlcAmount);
        usdcBalance[address(this)] -= usdcOut;
        usdcBalance[msg.sender]    += usdcOut;

        reserveMLC  += mlcAmount;
        reserveUSDC -= usdcOut;
    }

    /* --------------------------------------------------------------------------
                           Admin‑only disbursement helpers
    -------------------------------------------------------------------------- */

    function disburseTo(address to, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        _mint(to, amount);
        emit Disbursed(to, amount);
    }

    function disburseUSDC(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Zero address");
        require(amount > 0, "Amount must be > 0");
        usdcBalance[to] += amount;
    }

    /* --------------------------------------------------------------------------
                       Fixed‑price meal purchase (no market check)
    -------------------------------------------------------------------------- */

    function purchaseFromVendor(address vendor, uint256 mealCount) external {
        require(mealCount > 0, "mealCount must be > 0");
        uint256 cost = mealCount * MEAL_BLOCK_COST;
        require(balanceOf(msg.sender) >= cost, "Not enough MLC to purchase");

        _transfer(msg.sender, vendor, cost);
        emit MealPurchased(msg.sender, vendor, cost);
    }
}
