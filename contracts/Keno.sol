// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IUnifiedLiquidityPool.sol";
import "./interfaces/IRandomNumberGenerator.sol";

/**
 * @title Keno Contract
 */
contract Keno is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    /// @notice Event emitted when the keno is deployed.
    event KenoDeployed();

    /// @notice Event emitted when user bought the tickets.
    event BetStarted(BetInfo betInfo);

    /// @notice Event emitted when user played.
    event BetFinished(BetInfo betInfo);

    /// @notice Event emitted when the bet amount is changed.
    event BetAmountChanged(uint256 newBetAmount);

    IUnifiedLiquidityPool public ULP;
    IRandomNumberGenerator public RNG;
    IERC20 public GBTS;

    uint256 public betAmount; // .5 GBTS to make a bet

    /// @notice bettedGBTS keeps track of all GBTS brought in through ticket purchase
    uint256 public totalBettedAmount;

    /// @notice wonGBTS keeps track of all GBTS won by players
    uint256 public totalWinnings;

    /// @notice Determine the winnings the player will receive
    uint256[][] public winningTable;

    struct BetInfo {
        address player;
        bytes32 requestId;
        uint256 length;
        uint256[] userNumbers;
        bool[51] gameNumbers;
    }

    mapping(bytes32 => BetInfo) public requestToBet;

    modifier onlyRNG() {
        require(
            msg.sender == address(RNG),
            "DiceRoll: Caller is not the RandomNumberGenerator"
        );
        _;
    }

    /**
     * @dev Constructor function
     * @param _ULP Interface of ULP
     * @param _GBTS Interface of GBTS
     * @param _RNG Interface of RandomNumberGenerator
     */
    constructor(
        IUnifiedLiquidityPool _ULP,
        IERC20 _GBTS,
        IRandomNumberGenerator _RNG
    ) {
        ULP = _ULP;
        GBTS = _GBTS;
        RNG = _RNG;

        betAmount = 5 * 10**17;

        winningTable.push();
        winningTable.push([0, 326]); // 0, 3.26
        winningTable.push([0, 0, 1141]); // 0, 0, 11.41
        winningTable.push([0, 0, 200, 2600]); //  0, 0, 2.00, 26.00
        winningTable.push([0, 0, 0, 800, 7200]); // 0, 0, 0, 8.00, 72.00
        winningTable.push([0, 0, 0, 100, 1600, 25490]); // 0, 0, 0, 1.00, 16.00, 254.90
        winningTable.push([0, 0, 0, 200, 200, 4500, 65000]); // 0, 0, 0, 2.00, 2.00, 45.00, 650.00
        winningTable.push([100, 0, 0, 0, 200, 1100, 15000, 425000]); //1.00, 0, 0, 0, 2.00, 11.00, 150.00, 4250.00
        winningTable.push([100, 0, 0, 0, 100, 500, 3500, 40000, 2140000]); // 1.00, 0, 0, 0, 1.00, 5.00, 35.00, 400.00, 21400.00
        winningTable.push([100, 0, 0, 0, 0, 300, 1600, 18000, 200000, 5000000]); // 1.00, 0, 0, 0, 0, 3.00, 16.00, 180.00, 2000.00, 50000.00
        winningTable.push(
            [100, 0, 0, 0, 0, 300, 700, 2000, 50000, 1000000, 20000000]
        ); //1.00, 0, 0, 0, 0, 3.00, 7.00, 20.00, 500.00, 10000.00, 200000.00

        emit KenoDeployed();
    }

    /**
     * @dev External function to bet.
     * @param _numbers Array of numbers chosen
     */
    function bet(uint256[] memory _numbers) external nonReentrant {
        require(
            _numbers.length < 11 && _numbers.length > 0,
            "Keno: Every ticket should have 1 to 10 numbers."
        );

        GBTS.safeTransferFrom(msg.sender, address(ULP), betAmount);

        totalBettedAmount += betAmount;

        bytes32 requestId = RNG.requestRandomNumber();
        bool[51] memory gameNumbers;

        requestToBet[requestId] = BetInfo(
            msg.sender,
            requestId,
            _numbers.length,
            _numbers,
            gameNumbers
        );

        emit BetStarted(requestToBet[requestId]);
    }

    /**
     * @dev External function to play. This function can be called by only RandomNumberGenerator.
     * @param _requestId Chainlink request Id
     * @param _randomNumber Chainlink random number
     */
    function play(bytes32 _requestId, uint256 _randomNumber) external onlyRNG {
        BetInfo storage betInfo = requestToBet[_requestId];

        require(
            !betInfo.gameNumbers[0],
            "Keno: Current ticket is already played."
        );

        //Draw numbers using the Random Number Generator.
        uint32 size = 0;

        while (size < 15) {
            uint256 gameNumber = (_randomNumber % 50) + 1;

            if (!betInfo.gameNumbers[gameNumber]) {
                betInfo.gameNumbers[gameNumber] = true;
                size++;
            }
        }

        uint256 matches = 0;
        //match the players choice with the draw
        for (uint32 i = 0; i < betInfo.length; i++) {
            if (betInfo.gameNumbers[betInfo.userNumbers[i]]) {
                matches++;
            }
        }

        uint256[] memory selectedWinningTable = winningTable[betInfo.length]; //The multiplier array of the choose size
        uint256 multiplier = selectedWinningTable[matches]; //Multiplier
        uint256 amountToSend = (multiplier * betAmount) / 100;

        if (amountToSend > 0) {
            totalWinnings += amountToSend;
            ULP.sendPrize(msg.sender, amountToSend);
        }

        betInfo.gameNumbers[0] = true;

        emit BetFinished(betInfo);
    }

    /**
     * @dev External function to change the bet amount. This function can be called by only owner.
     * @param _newBetAmount New bet amount
     */
    function changeBetAmount(uint256 _newBetAmount) external onlyOwner {
        betAmount = _newBetAmount;

        emit BetAmountChanged(_newBetAmount);
    }
}
