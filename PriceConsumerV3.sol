pragma solidity ^0.7.6;

import "https://github.com/smartcontractkit/chainlink/blob/master/evm-contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";

contract PriceConsumerBSCV3 {

    AggregatorV3Interface internal priceFeed;

    /**
     * Network: BSC Testnet
     * Aggregator: ETH/USD
     * Address: 0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7
     */
    constructor() public {
        priceFeed = AggregatorV3Interface(0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7);
    }
    

    /**
     * Returns the latest price
     */
    function getLatestPrice() public view returns (int) {
        (
            uint80 roundID, 
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return price;
    }
}