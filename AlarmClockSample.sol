/** 
 *  You will need testnet ETH and LINK.
 *     - BSC LINK faucet: https://linkfaucet.protofire.io/bsctest
 */

pragma solidity ^0.7.6;

import "https://raw.githubusercontent.com/smartcontractkit/chainlink/develop/evm-contracts/src/v0.6/ChainlinkClient.sol";

contract AlarmClockSample is ChainlinkClient {
  
    bool public alarmDone;
    
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
    
    /**
     * Network: Rinkeby
     * Oracle: Chainlink - 0x7AFe1118Ea78C1eae84ca8feE5C65Bc76CcF879e
     * Job ID: Chainlink - 4fff47c3982b4babba6a7dd694c9b204
     * Fee: 0.1 LINK
     */
    constructor() public {
        setPublicChainlinkToken();
        oracle = 0x7AFe1118Ea78C1eae84ca8feE5C65Bc76CcF879e;
        jobId = "4fff47c3982b4babba6a7dd694c9b204";
        fee = 0.1 * 10 ** 18; // 0.1 LINK
        alarmDone = false;
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