/** 
 *  You will need testnet ETH and LINK.
 *     - BSC LINK faucet: https://linkfaucet.protofire.io/bsctest
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";

interface IMonetaryPolicy {
   function triggerRebase() external;
}

interface ICoinPriceOracle {
   function requestPriceData() external returns (bytes32 requestId);  
}

contract Orchestrator is ChainlinkClient {
  
    address owner_;
    IMonetaryPolicy public monetaryPolicy;
    ICoinPriceOracle public coinPriceOracle;
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
    uint32 public defaultDuration;
    uint32 public defaultCoinPriceLead;
    uint256 public lastRebaseTimestampSec;

    /**
     * Network: Binance Smart Chain Testnet
     * Oracle: Chainlink - 0x3b3D60B4a33B8B8c7798F7B3E8964b76FBE1E176
     * Job ID: Chainlink - 76bea30a605846cea6af93dbae70ed39
     * Fee: 0.1 LINK
     */
    constructor() public {
        owner_ = msg.sender;
        setPublicChainlinkToken();
        oracle = 0x3b3D60B4a33B8B8c7798F7B3E8964b76FBE1E176;
        jobId = "76bea30a605846cea6af93dbae70ed39";
        fee = 0.1 * 10 ** 18; // 0.1 LINK
        defaultDuration = 60 * 60 * 24;
        defaultCoinPriceLead = 60 * 5;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner_,"Only the owner of the contract can use");
        _;
    }

    function setMonetaryPolicy(IMonetaryPolicy addr) external onlyOwner {
        monetaryPolicy = addr;
    }

    function setCoinPriceOracle(ICoinPriceOracle addr) external onlyOwner {
        coinPriceOracle = addr;
    }

    function setDefaultDuration(uint32 _duration) external onlyOwner {
        defaultDuration = _duration;
    }

    function setDefaultCoinPriceLead(uint32 _duration) external onlyOwner {
        defaultCoinPriceLead = _duration;
    }
    
    function initialRebaseRequest(uint256 durationInSeconds) external onlyOwner returns (bytes32 requestId) 
    {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfillRebase.selector);
        if(lastRebaseTimestampSec == 0){
            lastRebaseTimestampSec = block.timestamp;
        }
        lastRebaseTimestampSec = lastRebaseTimestampSec + durationInSeconds;
        request.addUint("until", lastRebaseTimestampSec);
        return sendChainlinkRequestTo(oracle, request, fee);
    }
    
    function rebaseRequest() private returns (bytes32 requestId) 
    {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfillRebase.selector);
        require(lastRebaseTimestampSec != 0, "lastRebaseTimestampSec not initialized");
        lastRebaseTimestampSec = lastRebaseTimestampSec + defaultDuration;
        request.addUint("until", lastRebaseTimestampSec);
        return sendChainlinkRequestTo(oracle, request, fee);
    }
    
    // must not be called before calling rebaseRequest
    function coinPriceRequest() private returns (bytes32 requestId) 
    {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfillPriceQuery.selector);
        require(lastRebaseTimestampSec != 0, "lastRebaseTimestampSec not initialized");
        // schedules coin price retrieval defaultCoinPriceLead seconds before rebase
        request.addUint("until", lastRebaseTimestampSec - defaultCoinPriceLead);
        return sendChainlinkRequestTo(oracle, request, fee);
    }
    
    function fulfillRebase(bytes32 _requestId) public recordChainlinkFulfillment(_requestId)
    {
        monetaryPolicy.triggerRebase();
        rebaseRequest();
        coinPriceRequest();
    }
    
    function fulfillPriceQuery(bytes32 _requestId) public recordChainlinkFulfillment(_requestId)
    {
        coinPriceOracle.requestPriceData();
    }
    
    /**
     * Withdraw LINK from this contract
     * 
     * NOTE: DO NOT USE THIS IN PRODUCTION AS IT CAN BE CALLED BY ANY ADDRESS.
     * THIS IS PURELY FOR EXAMPLE PURPOSES ONLY.
     */
    function withdrawLink() external onlyOwner{
        LinkTokenInterface linkToken = LinkTokenInterface(chainlinkTokenAddress());
        require(linkToken.transfer(msg.sender, linkToken.balanceOf(address(this))), "Unable to transfer");
    }
}