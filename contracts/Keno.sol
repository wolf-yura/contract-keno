// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IUnifiedLiquidityPool.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Keno is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Event emitted when user bought the tickets.
    event TicketsBought(address buyer, uint256 ticketNumber);

    /// @notice Event emitted when user played.
    event TicketPlayed(
        address player,
        Ticket ticketPlayed,
        uint256 winnings,
        bool[51] drawnTickets,
        uint256 ticketNumber
    );

    IUnifiedLiquidityPool public ULP;
    IERC20 public GBTS;

    uint256 private gameId;
    uint256 constant betAmount = 5 * 10**17; // .5 GBTS to make a bet

    /// @notice bettedGBTS keeps track of all GBTS brought in through ticket purchase
    uint256 public totalBettedAmount;

    /// @notice wonGBTS keeps track of all GBTS won by players
    uint256 public totalWinnings;

    /// @notice Determine the winnings the player will receive
    uint256[][] public winningTable;

    struct Ticket {
        uint256 length;
        uint256[] numbers;
        bytes32 batchID;
        bool[51] drawnTickets;
    }

    mapping(address => Ticket[]) private playerTickets;

    /**
     * @dev Constructor function
     * @param _ULP Interface of ULP
     * @param _GBTS Interface of GBTS
     * @param _gameId Id of current game
     */
    constructor(
        IUnifiedLiquidityPool _ULP,
        IERC20 _GBTS,
        uint256 _gameId
    ) {
        ULP = _ULP;
        GBTS = _GBTS;
        gameId = _gameId;

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
    }

    /**
     * @dev External function for buying tickets.
     * @param _chosenTicketNumbers Array of numbers chosen
     */
    function buyTicket(uint256[] memory _chosenTicketNumbers)
        external
        nonReentrant
    {
        require(
            _chosenTicketNumbers.length < 11 && _chosenTicketNumbers.length > 0,
            "Keno: Every ticket should have 1 to 11 numbers."
        );

        GBTS.safeTransferFrom(msg.sender, address(ULP), betAmount);
        totalBettedAmount += betAmount;
        uint256 _ticketNumber = playerTickets[msg.sender].length;
        Ticket memory ticket;
        ticket.length = _chosenTicketNumbers.length;
        ticket.numbers = _chosenTicketNumbers;
        ticket.batchID = ULP.requestRandomNumber();
        playerTickets[msg.sender].push(ticket);

        emit TicketsBought(msg.sender, _ticketNumber);
    }

    /**
     * @dev External function to play.
     * @param _ticketNumber Current Ticket Number
     */
    function play(uint256 _ticketNumber) external nonReentrant {
        require(
            _ticketNumber < playerTickets[msg.sender].length,
            "Keno: No ticket to play."
        );

        Ticket storage ticket = playerTickets[msg.sender][_ticketNumber];

        require(
            !ticket.drawnTickets[0],
            "Keno: Current ticket is already played."
        );

        uint256 randomNumber = ULP.getVerifiedRandomNumber(ticket.batchID);

        //Draw numbers using the Random Number Generator.
        uint32 size = 0;

        while (size < 15) {
            uint256 gameNumber = (uint256(
                keccak256(
                    abi.encode(
                        randomNumber,
                        address(msg.sender),
                        gameId,
                        _ticketNumber
                    )
                )
            ) % 50) + 1;

            _ticketNumber++;

            if (!ticket.drawnTickets[gameNumber]) {
                ticket.drawnTickets[gameNumber] = true;
                size++;
            }
        }

        uint256 matches = 0;
        //match the players choice with the draw
        for (uint32 i = 0; i < ticket.length; i++) {
            if (ticket.drawnTickets[ticket.numbers[i]]) {
                matches++;
            }
        }

        uint256[] memory selectedWinningTable = winningTable[ticket.length]; //The multiplier array of the choose size
        uint256 multiplier = selectedWinningTable[matches]; //Multiplier
        uint256 amountToSend = (multiplier * betAmount) / 100;

        if (amountToSend > 0) {
            totalWinnings += amountToSend;
            ULP.sendPrize(msg.sender, amountToSend);
        }

        ticket.drawnTickets[0] = true;

        emit TicketPlayed(
            msg.sender,
            ticket,
            amountToSend,
            ticket.drawnTickets,
            _ticketNumber
        );
    }
}
