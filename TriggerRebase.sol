/** 
 *  You will need testnet ETH and LINK.
 *     - BSC LINK faucet: https://linkfaucet.protofire.io/bsctest
 */

pragma solidity ^0.7.6;

import "https://raw.githubusercontent.com/smartcontractkit/chainlink/develop/evm-contracts/src/v0.6/ChainlinkClient.sol";


import "./RebaseToken.sol";
import "./PriceConsumerV3.sol";

contract TriggerRebase is ChainlinkClient {
  
    bool public alarmDone;
    RebaseToken public rebaseC;
    PriceConsumerV3 public priceConsumerV3;
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
    uint32 public defaultDuration;
    /**
     * Network: Kovan
     * Oracle: Chainlink - 0xAA1DC356dc4B18f30C347798FD5379F3D77ABC5b
     * Job ID: Chainlink - 982105d690504c5d9ce374d040c08654
     * Fee: 0.1 LINK
     */
    constructor() public {
        setPublicChainlinkToken();
        oracle = 0xAA1DC356dc4B18f30C347798FD5379F3D77ABC5b;
        jobId = "982105d690504c5d9ce374d040c08654";
        fee = 0.1 * 10 ** 18; // 0.1 LINK
        alarmDone = false;
        defaultDuration = 60 * 60 * 24;
    }
    
    
    modifier onlyOwner() {
        require(msg.sender == owner_,"Only the owner of the contract can use");
        _;
    }
    
    
    function setRebaseC(RebaseToken addr) public onlyOwner {
        rebaseC = addr;
    }
    
    
    function setPriceConsumerV3(PriceConsumerV3 addr) public onlyOwner {
        priceConsumerV3 = addr;
    }
    
    /**
     * Create a Chainlink request to start an alarm and after
     * the time in seconds is up, return throught the fulfillAlarm
     * function
     */
    function requestAlarmClock(uint256 durationInSeconds) public returns (bytes32 requestId) 
    {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfillAlarm.selector);
        // This will return in 90 seconds
        request.addUint("until", block.timestamp + durationInSeconds);
        return sendChainlinkRequestTo(oracle, request, fee);
    }
    
    /**
     * Receive the response in the form of uint256
     */ 
    function fulfillAlarm(bytes32 _requestId, uint256 _volume) public recordChainlinkFulfillment(_requestId)
    {
        int supplyDelta = priceConsumerV3.getLatestPrice();
        rebaseC.rebase(block.timestamp, supplyDelta);
        requestAlarmClock(defaultDuration);
        alarmDone = true;
    }
    
    /**
     * Withdraw LINK from this contract
     * 
     * NOTE: DO NOT USE THIS IN PRODUCTION AS IT CAN BE CALLED BY ANY ADDRESS.
     * THIS IS PURELY FOR EXAMPLE PURPOSES ONLY.
     */
    function withdrawLink() external {
        LinkTokenInterface linkToken = LinkTokenInterface(chainlinkTokenAddress());
        require(linkToken.transfer(msg.sender, linkToken.balanceOf(address(this))), "Unable to transfer");
    }
}