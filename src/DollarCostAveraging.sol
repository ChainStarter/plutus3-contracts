pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

contract DollarCostAveraging  is VRFConsumerBaseV2, AutomationCompatibleInterface {

  event PlanCreated(address indexed user, uint256 frequency, uint256 amount);
  event PlanUpdated(address indexed user, uint256 frequency, uint256 amount);
  event PlanStoped(address indexed user);
  event PlanStarted(address indexed user);
  event PlanTriggered(address indexed user, uint256 amount, uint256 ethReceived);



  struct Plan {
    uint256 index;
    uint256 frequency;
    uint256 amount;
    uint startAt;
    uint times;
    uint status;
  }

  mapping(address => Plan) public plans;
  mapping(uint256 => address) public users;
  mapping(uint256 => address) public userRandomRequestId;
  mapping(address => uint256) public nextTriggerTime;

  ERC20 public usdt;
  LinkTokenInterface public link;
  VRFCoordinatorV2Interface public coordinator;
  uint64 subscriptionId;
  IUniswapV2Router02 public uniswapRouter;
  AggregatorV2V3Interface public oracle;
  uint256 public nonce;

  bytes32 internal keyHash;
  uint256 internal fee;

  constructor(
        address _usdt,
        address _uniswapRouter,
        address _oracle,
        address _vrfCoordinator,
        uint64 _subscriptionId,
        address _link,
        bytes32 _keyHash,
        uint256 _fee
    ) VRFConsumerBaseV2(_vrfCoordinator) {
    usdt = ERC20(_usdt);
    uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    oracle = AggregatorV2V3Interface(_oracle);
    nonce = 1;
    keyHash = _keyHash;
    fee = _fee;

    link = LinkTokenInterface(_link);
    coordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
    subscriptionId = _subscriptionId;
  }

  function getAllowance(address user) public view returns (uint256) {
    return usdt.allowance(user, address(this));
  }

  function createPlan(uint256 frequency, uint256 amount) public {
    require(plans[msg.sender].index == 0, "Plan is exist");
    require(frequency > 0, "Frequency must be greater than 0");
    require(amount > 0, "Amount must be greater than 0");

    users[nonce] = msg.sender;
    
    plans[msg.sender] = Plan({
      index: nonce++,
      frequency: frequency,
      amount: amount,
      startAt: block.timestamp,
      times: 0,
      status: 0
    });
    emit PlanCreated(msg.sender, frequency, amount);
 
    startPlan();
  }

  function updatePlan(uint256 frequency, uint256 amount) public {
    require(plans[msg.sender].index > 0, "Plan is exist");
    require(frequency > 0, "Frequency must be greater than 0");
    require(amount > 0, "Amount must be greater than 0");

    plans[msg.sender].amount = amount;
    plans[msg.sender].frequency = frequency;

    emit PlanUpdated(msg.sender, frequency, amount);
  }

  function startPlan() public {    
    require(plans[msg.sender].index > 0, "Plan is not exist");
    require(plans[msg.sender].amount > 0, "Amount must be greater than 0");
    require(getAllowance(msg.sender) >= plans[msg.sender].amount, "Total must be greater than amount");
    

    plans[msg.sender].startAt = block.timestamp;
    plans[msg.sender].times = 0;
    plans[msg.sender].status = 1;
    emit PlanStarted(msg.sender);

    requestRandom(msg.sender);
  }

  function stopPlan() public {
    require(plans[msg.sender].index > 0, "Plan is not exist");

    plans[msg.sender].status = 0;
    emit PlanStoped(msg.sender);
  }

  function requestRandom(address user) private {
    uint256 requestId = coordinator.requestRandomWords(
        keyHash,
        subscriptionId,
        3,
        350000,
        1
       );
    userRandomRequestId[requestId] = user;
  }

  function triggerPlan(address user) public {
    require(plans[user].status == 1, "Plan is not active");
    require(getAllowance(user) >= plans[user].amount, "Cannot trigger more than remaining amount");
    require(block.timestamp >=  nextTriggerTime[user], "Cannot trigger before next trigger time");

    uint256 amount = plans[user].amount;

    (, int256 ethPrice, , , ) = oracle.latestRoundData();

    // decimals
    uint256 ethPriceDecimals = oracle.decimals();

    uint256 ethAmount = (amount * 1e18) / uint256(ethPrice) /  10 ** (18 - ethPriceDecimals);

    uint256 slippage = (ethAmount * 5) / 1000;

    uint256 minEthAmount = ethAmount - slippage;

    SafeERC20.safeTransferFrom(usdt, user, address(this), amount);

    SafeERC20.safeIncreaseAllowance(usdt, address(uniswapRouter), amount);

    address[] memory path = new address[](2);
    path[0] = address(usdt); // USDT
    path[1] = uniswapRouter.WETH(); // WETH
    //Uniswap V2
    (uint[] memory amounts) = uniswapRouter.swapExactTokensForETH(amount, minEthAmount, path, address(this), block.timestamp + 1 hours);

    uint256 ethReceived = amounts[1]; 

    plans[user].times++;

    emit PlanTriggered(user, amount, ethReceived);

    payable(user).transfer(ethReceived);

    requestRandom(user);
  }

   // Chainlink VRF Callback
  function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
      address user = userRandomRequestId[_requestId];
      nextTriggerTime[user] = plans[user].startAt + plans[user].times * plans[user].frequency + (_randomWords[0] % plans[user].frequency);
  }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
      address user = users[block.number % (nonce - 1) + 1];
      upkeepNeeded = false;
      if(block.timestamp > nextTriggerTime[user] && nextTriggerTime[user] > 0){
        upkeepNeeded = true;
      }
      
      performData = abi.encode(user);
      return (upkeepNeeded, performData);
    }

    function performUpkeep(bytes calldata performData) external override {
        (address user) = abi.decode(
            performData,
            (address)
        );
        triggerPlan(user);
    }

  receive() external payable {}
}