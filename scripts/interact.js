// scripts/interact.js
// Demo script for MealCoinAMM – shows how the administration can open / close
// the secondary‑hand market each term.
// Run: npx hardhat run scripts/interact.js --network localhost

const { ethers } = require("hardhat");

async function main () {
  /* -------------------------------------------------------------
     0. Signers
  ------------------------------------------------------------- */
  const [admin, student, vendor] = await ethers.getSigners();
  console.log("Accounts:\n  Admin   =", admin.address,
              "\n  Student =", student.address,
              "\n  Vendor  =", vendor.address);

  /* -------------------------------------------------------------
     1. Deploy & open secondary market
  ------------------------------------------------------------- */
  const MealCoinAMM = await ethers.getContractFactory("MealCoinAMM");
  const amm = await MealCoinAMM.deploy(admin.address);
  await amm.waitForDeployment();
  console.log("Deployed MealCoinAMM at:", await amm.getAddress());

  // —— university starts a new term ——
  await (await amm.connect(admin).openSecondaryMarket()).wait();
  console.log("Secondary market OPENED\n");

  /* -------------------------------------------------------------
     2. Admin provides initial liquidity (market must be open)
  ------------------------------------------------------------- */
  const initialMlc  = ethers.parseEther("100000"); // 100 000 MLC
  const initialUsdc = ethers.parseEther("1000");   // 1 000  USDC
  await (await amm.connect(admin).disburseTo(admin.address, initialMlc)).wait();
  await (await amm.connect(admin).addLiquidity(initialUsdc, initialMlc)).wait();

  // Seed student with 100 USDC for testing swaps
  await (await amm.connect(admin).disburseUSDC(student.address, ethers.parseEther("100"))).wait();

  /* helper to print pool reserves */
  const showPool = async (tag) => {
    const rU = await amm.reserveUSDC();
    const rM = await amm.reserveMLC();
    console.log(`${tag}  Reserves  USDC=${ethers.formatEther(rU)}  MLC=${ethers.formatEther(rM)}`);
  };
  await showPool("After init  ⇒");

  /* -------------------------------------------------------------
     3. Student gets MLC airdrop and buys a meal block
  ------------------------------------------------------------- */
  await (await amm.connect(admin).disburseTo(student.address, ethers.parseEther("10000"))).wait();
  console.log("Student MLC after airdrop:", ethers.formatEther(await amm.balanceOf(student.address)));

  await (await amm.connect(student).purchaseFromVendor(vendor.address, 1)).wait();
  console.log("Vendor MLC after meal purchase:", ethers.formatEther(await amm.balanceOf(vendor.address)));

  /* -------------------------------------------------------------
     4. Vendor sells earned MLC back for USDC (swap)
  ------------------------------------------------------------- */
  const vendorMLC = await amm.balanceOf(vendor.address);
  await (await amm.connect(vendor).sellMealCoin(vendorMLC)).wait();
  console.log("Vendor USDC after selling meal‑coins:", ethers.formatEther(await amm.usdcBalance(vendor.address)));

  /* -------------------------------------------------------------
     5. Student demo – buy then sell via AMM
  ------------------------------------------------------------- */
  await (await amm.connect(student).buyMealCoin(ethers.parseEther("20"))).wait();
  console.log("Student MLC after buying 20 USDC:", ethers.formatEther(await amm.balanceOf(student.address)));

  await (await amm.connect(student).sellMealCoin(ethers.parseEther("1500"))).wait();
  console.log("Student USDC after selling 1 500 MLC:", ethers.formatEther(await amm.usdcBalance(student.address)));

  await showPool("Before close ⇒");

  /* -------------------------------------------------------------
     6. End of term – admin closes the secondary market
  ------------------------------------------------------------- */
  await (await amm.connect(admin).closeSecondaryMarket()).wait();
  console.log(" Secondary market CLOSED\n");

  /* -------------------------------------------------------------
     7. Admin may reopen temporarily to adjust liquidity, then close again
        (remove half of their LP shares as example)
  ------------------------------------------------------------- */
  const adminLP = await amm.lpShares(admin.address);
  const toRemove = adminLP / 2n;

  await (await amm.connect(admin).openSecondaryMarket()).wait();
  await (await amm.connect(admin).removeLiquidity(toRemove)).wait();
  await (await amm.connect(admin).closeSecondaryMarket()).wait();
  console.log("Admin removed", ethers.formatEther(toRemove), "LP shares and closed market again");

  await showPool("After close ⇒");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});