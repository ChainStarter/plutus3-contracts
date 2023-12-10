const { ethers } = require("hardhat");
const { expect } = require("chai");

const usdtAddress = "0xC2C527C0CACF457746Bd31B2a698Fe89de2b6d49"; // Replace with the address of your USDT token on Goerli
const uniswapRouterAddress = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"; // Replace with the address of the Uniswap V2 Router on Goerli

describe("DollarCostAveraging", function () {
  let deployer;
  let dollarCostAveraging;
  let usdt;
  let uniswapRouter;

  beforeEach(async function () {
    [deployer] = await ethers.getSigners();
    usdt = await ethers.getContractAt(usdtAddress, deployer.address);
    uniswapRouter = await ethers.getContractAt(uniswapRouterAddress, deployer.address);

    const DollarCostAveraging = await ethers.getContractFactory("DollarCostAveraging");
    dollarCostAveraging = await DollarCostAveraging.deploy(usdtAddress, uniswapRouterAddress, {
      signer: deployer
    });
  });

  it("should create a plan", async function () {
    const frequency = 1;
    const amount = 100;
    const total = 1000;

    await expect(dollarCostAveraging.createPlan(frequency, amount, total)).to.not.be.reverted;

    const plan = await dollarCostAveraging.plans(deployer.address);
    expect(plan.frequency).to.equal(frequency);
    expect(plan.amount).to.equal(amount);
    expect(plan.total).to.equal(total);
    expect(plan.lastTriggeredAt).to.equal(0);
  });

  it("should trigger a plan", async function () {
    const frequency = 1;
    const amount = 100;
    const total = 1000;

    await dollarCostAveraging.createPlan(frequency, amount, total);

    await expect(dollarCostAveraging.triggerPlan(deployer.address)).to.not.be.reverted;

    const plan = await dollarCostAveraging.plans(deployer.address);
    expect(plan.total).to.equal(total - amount);
    expect(plan.lastTriggeredAt).to.be.greaterThan(0);
  });
});