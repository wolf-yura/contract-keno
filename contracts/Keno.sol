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
    event BetFinished(BetInfo betInfo, uint256 matches, uint256 prize);

    /// @notice Event emitted when the bet amount is changed.
    event BetAmountChanged(uint256 newBetAmount);

    IUnifiedLiquidityPool public ULP;
    IRandomNumberGenerator public RNG;
    IERC20 public GBTS;

    uint256 public betAmount; // 100 GBTS to make a bet

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

        betAmount = 100 * 10**18;

        winningTable.push();
        winningTable.push([0, 220]); // 0, 2.2
        winningTable.push([0, 0, 1030]); // 0, 0, 10.3
        winningTable.push([0, 0, 100, 2450]); //  0, 0, 1.00, 24.50
        winningTable.push([0, 0, 0, 700, 6900]); // 0, 0, 0, 7.00, 69.00
        winningTable.push([0, 0, 0, 100, 1600, 22900]); // 0, 0, 0, 1.00, 16.00, 229.00
        winningTable.push([0, 0, 0, 100, 200, 3900, 55400]); // 0, 0, 0, 1.00, 2.00, 39.00, 554.00
        winningTable.push([0, 0, 0, 0, 100, 1400, 22100, 199900]); //0, 0, 0, 0, 1.00, 14.00, 221.00, 1999.00

        emit KenoDeployed();
    }

    /**
     * @dev External function to bet.
     * @param _numbers Array of numbers chosen
     */
    function bet(uint256[] memory _numbers) external nonReentrant {
        require(
            _numbers.length < 8 && _numbers.length > 0,
            "Keno: Every ticket should have 1 to 7 numbers."
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

        //Draw numbers using the Random Number Generator.
        uint256 size = 0;
        uint256 nonce = betInfo.length;

        while (size < 15) {
            uint256 gameNumber = (uint256(
                keccak256(abi.encode(_randomNumber, address(msg.sender), nonce))
            ) % 50) + 1;

            nonce++;

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

        emit BetFinished(betInfo, matches, amountToSend);
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
