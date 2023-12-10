const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  const usdtAddress = "0xC2C527C0CACF457746Bd31B2a698Fe89de2b6d49"; // Replace with the address of your USDT token on Goerli
  const uniswapRouterAddress = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"; // Replace with the address of the Uniswap V2 Router on Goerli
  const oracle = "0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e"; // Replace with the address of the Chainlink ETH/USD Price Feed on Goerli
  const vrfCoordinator = "0x2ca8e0c643bde4c2e08ab1fa0da3401adad7734d"
  const subscriptionId = 15556;
  const link = "0x326c977e6efc84e512bb9c30f76e30c160ed06fb"
  const keyHash = "0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15"
  // 150 gwei
  const fee = 150 * 10 ** 9

  const DollarCostAveraging= await ethers.getContractFactory('DollarCostAveraging');
  const dollarCostAveraging = await DollarCostAveraging.deploy(usdtAddress, uniswapRouterAddress, oracle, vrfCoordinator, subscriptionId, link, keyHash, fee);
 
  await dollarCostAveraging.deployed();
  
  console.log("Deployed DollarCostAveraging contract to:", dollarCostAveraging.address);
}

main().catch((error) => {
  console.error(error);
});