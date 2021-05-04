pragma solidity ^0.6.8;
// SPDX-License-Identifier: MIT

import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";
import "./RebaseToken.sol";


contract CoinPriceOracle is ChainlinkClient {
  
    uint256 public price;
    
    address owner_;
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
    uint32 public defaultDuration;


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
    }
    

    modifier onlyOwner() {
        require(msg.sender == owner_,"Only the owner of the contract can use");
        _;
    }

    function requestPriceData() external returns (bytes32 requestId) 
    {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        
        // Set the URL to perform the GET request on
        request.add("get", "https://coin-price-random-walk-git-main-alphone.vercel.app/api/price");
        
       
        request.add("path", "price");
        
        // Multiply the result by 1000000000000000000 to remove decimals
        int timesAmount = 10**18;
        request.addInt("times", timesAmount);
        
        // Sends the request
        return sendChainlinkRequestTo(oracle, request, fee);
    }
    
    /**
     * Receive the response in the form of uint256
     */ 
    function fulfill(bytes32 _requestId, uint256 _price) public recordChainlinkFulfillment(_requestId)
    {
        price = _price;
    }
    
    /**
     * Withdraw LINK from this contract
     * 
     * NOTE: DO NOT USE THIS IN PRODUCTION AS IT CAN BE CALLED BY ANY ADDRESS.
     * THIS IS PURELY FOR EXAMPLE PURPOSES ONLY.
     */
    function withdrawLink() external onlyOwner {
        LinkTokenInterface linkToken = LinkTokenInterface(chainlinkTokenAddress());
        require(linkToken.transfer(msg.sender, linkToken.balanceOf(address(this))), "Unable to transfer");
    }
}