pragma solidity ^0.6.8;
// SPDX-License-Identifier: MIT

import "./SafeMath.sol";
import "./SafeMathInt.sol";
import "./UInt256Lib.sol";


interface ICoinPriceOracle {
   function price() external returns (uint256 _price);  
}

interface IRebaseToken {
    function totalSupply() external view returns (uint256);

    function rebase(uint256 epoch, int256 supplyDelta) external returns (uint256);
}

contract MonetaryPolicy  {

    using SafeMath for uint256;
    using SafeMathInt for int256;
    using UInt256Lib for uint256;
   
    event LogRebase(
    uint256 indexed epoch,
    uint256 exchangeRate,
    int256 requestedSupplyAdjustment,
    uint256 timestampSec
    );

    ICoinPriceOracle public coinPrice;
    address owner_;
    IRebaseToken public rebaseToken;

    // If the current exchange rate is within this fractional distance from the target, no supply
    // update is performed. Fixed point number--same format as the rate.
    // (ie) abs(rate - targetRate) / targetRate < deviationThreshold, then no supply change.
    // DECIMALS Fixed point number.
    uint256 public deviationThreshold;

    // The rebase lag parameter, used to dampen the applied supply adjustment by 1 / rebaseLag
    // Check setRebaseLag comments for more details.
    // Natural number, no decimal places.
    uint256 public rebaseLag;

    // More than this much time must pass between rebase operations.
    uint256 public minRebaseTimeIntervalSec;

    // Block timestamp of last rebase operation
    uint256 public lastRebaseTimestampSec;

    // The rebase window begins this many seconds into the minRebaseTimeInterval period.
    // For example if minRebaseTimeInterval is 24hrs, it represents the time of day in seconds.
    uint256 public rebaseWindowOffsetSec;

    // The length of the time window where a rebase operation is allowed to execute, in seconds.
    uint256 public rebaseWindowLengthSec;

    // The number of rebase cycles since inception
    uint256 public epoch;


    uint256 private constant DECIMALS = 18;

    // Due to the expression in computeSupplyDelta(), MAX_RATE * MAX_SUPPLY must fit into an int256.
    // Both are 18 decimals fixed point numbers.
    uint256 private constant MAX_RATE = 10**6 * 10**DECIMALS;
    // MAX_SUPPLY = MAX_INT256 / MAX_RATE
    uint256 private constant MAX_SUPPLY = uint256(type(int256).max) / MAX_RATE;

    address public orchestrator;

    modifier onlyOrchestrator() {
        require(msg.sender == orchestrator);
        _;
    }



    modifier onlyOwner() {
        require(msg.sender == owner_,"Only the owner of the contract can use");
        _;
    }
    
    function triggerRebase() external onlyOrchestrator{
        require(inRebaseWindow());

        // This comparison also ensures there is no reentrancy.
        require(lastRebaseTimestampSec.add(minRebaseTimeIntervalSec) < block.timestamp);

        // Snap the rebase time to the start of this window.
        lastRebaseTimestampSec = block
            .timestamp
            .sub(block.timestamp.mod(minRebaseTimeIntervalSec))
            .add(rebaseWindowOffsetSec);

        epoch = epoch.add(1);

        uint256 exchangeRate  = coinPrice.price();

        if (exchangeRate > MAX_RATE) {
            exchangeRate = MAX_RATE;
        }

        int256 supplyDelta = computeSupplyDelta(exchangeRate, 1);

        // Apply the Dampening factor.
        supplyDelta = supplyDelta.div(rebaseLag.toInt256Safe());

        if (supplyDelta > 0 && rebaseToken.totalSupply().add(uint256(supplyDelta)) > MAX_SUPPLY) {
            supplyDelta = (MAX_SUPPLY.sub(rebaseToken.totalSupply())).toInt256Safe();
        }

        uint256 supplyAfterRebase = rebaseToken.rebase(epoch, supplyDelta);
        assert(supplyAfterRebase <= MAX_SUPPLY);
        emit LogRebase(epoch, exchangeRate, supplyDelta, block.timestamp);
    }

    function setRebaseCoin(IRebaseToken addr) external onlyOwner {
        rebaseToken = addr;
    }

    function setCoinPriceOracle(ICoinPriceOracle addr) external onlyOwner {
        coinPrice = addr;
    }

    function setOrchestrator(address orchestrator_) external onlyOwner {
        orchestrator = orchestrator_;
    }

    function setDeviationThreshold(uint256 deviationThreshold_) external onlyOwner {
        deviationThreshold = deviationThreshold_;
    }

    /**
     * @notice Sets the rebase lag parameter.
               It is used to dampen the applied supply adjustment by 1 / rebaseLag
               If the rebase lag R, equals 1, the smallest value for R, then the full supply
               correction is applied on each rebase cycle.
               If it is greater than 1, then a correction of 1/R of is applied on each rebase.
     * @param rebaseLag_ The new rebase lag parameter.
     */
    function setRebaseLag(uint256 rebaseLag_) external onlyOwner {
        require(rebaseLag_ > 0);
        rebaseLag = rebaseLag_;
    }

    /**
     * @notice Sets the parameters which control the timing and frequency of
     *         rebase operations.
     *         a) the minimum time period that must elapse between rebase cycles.
     *         b) the rebase window offset parameter.
     *         c) the rebase window length parameter.
     * @param minRebaseTimeIntervalSec_ More than this much time must pass between rebase
     *        operations, in seconds.
     * @param rebaseWindowOffsetSec_ The number of seconds from the beginning of
              the rebase interval, where the rebase window begins.
     * @param rebaseWindowLengthSec_ The length of the rebase window in seconds.
     */
    function setRebaseTimingParameters(
        uint256 minRebaseTimeIntervalSec_,
        uint256 rebaseWindowOffsetSec_,
        uint256 rebaseWindowLengthSec_
    ) external onlyOwner {
        require(minRebaseTimeIntervalSec_ > 0);
        require(rebaseWindowOffsetSec_ < minRebaseTimeIntervalSec_);

        minRebaseTimeIntervalSec = minRebaseTimeIntervalSec_;
        rebaseWindowOffsetSec = rebaseWindowOffsetSec_;
        rebaseWindowLengthSec = rebaseWindowLengthSec_;
    }

    constructor() public {
        owner_ = msg.sender;
    }

    function initialize(
        IRebaseToken rebaseToken_
    ) public {

        // deviationThreshold = 0.05e18 = 5e16
        deviationThreshold = 5 * 10**(DECIMALS - 2);

        rebaseLag = 30;
        minRebaseTimeIntervalSec = 1 days;
        rebaseWindowOffsetSec = 72000; // 8PM UTC
        rebaseWindowLengthSec = 15 minutes;
        lastRebaseTimestampSec = 0;
        epoch = 0;
        rebaseToken = rebaseToken_;
    }

    /**
     * @return If the latest block timestamp is within the rebase time window it, returns true.
     *         Otherwise, returns false.
     */
    function inRebaseWindow() public view returns (bool) {
        return (block.timestamp.mod(minRebaseTimeIntervalSec) >= rebaseWindowOffsetSec &&
            block.timestamp.mod(minRebaseTimeIntervalSec) <
            (rebaseWindowOffsetSec.add(rebaseWindowLengthSec)));
    }

    /**
     * @return Computes the total supply adjustment in response to the exchange rate
     *         and the targetRate.
     */
    function computeSupplyDelta(uint256 rate, uint256 targetRate) internal view returns (int256) {
        if (withinDeviationThreshold(rate, targetRate)) {
            return 0;
        }

        // supplyDelta = totalSupply * (rate - targetRate) / targetRate
        int256 targetRateSigned = targetRate.toInt256Safe();
        return
            rebaseToken.totalSupply().toInt256Safe().mul(rate.toInt256Safe().sub(targetRateSigned)).div(
                targetRateSigned
            );
    }

    /**
     * @param rate The current exchange rate, an 18 decimal fixed point number.
     * @param targetRate The target exchange rate, an 18 decimal fixed point number.
     * @return If the rate is within the deviation threshold from the target rate, returns true.
     *         Otherwise, returns false.
     */
    function withinDeviationThreshold(uint256 rate, uint256 targetRate)
        internal
        view
        returns (bool)
    {
        uint256 absoluteDeviationThreshold = targetRate.mul(deviationThreshold).div(10**DECIMALS);

        return
            (rate >= targetRate && rate.sub(targetRate) < absoluteDeviationThreshold) ||
            (rate < targetRate && targetRate.sub(rate) < absoluteDeviationThreshold);
    }

}