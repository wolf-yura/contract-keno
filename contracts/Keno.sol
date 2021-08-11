// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IUnifiedLiquidityPool.sol";

contract Keno is Ownable, ReentrancyGuard {
    IUnifiedLiquidityPool public ULP;
    IERC20 public token;

    uint256 constant gameId = 4;
    uint256 constant tokenBet = 5 * 10**17; // .5 GBTS to make a bet

    /// @notice bettedGBTS keeps track of all GBTS brought in through ticket purchase
    uint256 totalBets;

    /// @notice wonGBTS keeps track of all GBTS won by players
    uint256 totalWinnings;

    /// @notice bought ticket
    event TicketBought(address buyer);

    /// @notice ticket played
    event TicketPlayed( address player, Ticket ticketPlayed, uint256 winnings, uint256[] drawn);

    /// @notice this is used to determine the winnings the player will receive
    uint256[][] winningTable; // divide by 100 to get proper multiplier

    constructor(IUnifiedLiquidityPool _ULP, IERC20 _GBTS) {
        ULP = _ULP;
        GBTS = _GBTS;
        winningTable.push()
        winningTable.push([0, 326]); // 0, 3.26
        winningTable.push([0, 0, 1141]); // 0, 0, 11.41
        winningTable.push([0, 0, 200, 2600]); //  0, 0, 2.00, 26.00
        winningTable.push([0, 0, 0, 800, 7200]); // 0, 0, 0, 8.00, 72.00
        winningTable.push([0, 0, 0, 100, 1600, 25490]); // 0, 0, 0, 1.00, 16.00, 254.90
        winningTable.push([0, 0, 0, 200, 200, 4500, 65000]); // 0, 0, 0, 2.00, 2.00, 45.00, 650.00
        winningTable.push([100, 0, 0, 0, 200, 1100, 15000, 425000]); //1.00, 0, 0, 0, 2.00, 11.00, 150.00, 4250.00
        winningTable.push([100, 0, 0, 0, 100, 500, 3500, 40000, 2140000]); // 1.00, 0, 0, 0, 1.00, 5.00, 35.00, 400.00, 21400.00
        winningTable.push([100, 0, 0, 0, 0, 300, 1600, 18000, 200000, 5000000]); // 1.00, 0, 0, 0, 0, 3.00, 16.00, 180.00, 2000.00, 50000.00
        winningTable.push([100, 0, 0, 0, 0, 300, 700, 2000, 50000, 1000000, 20000000]); //1.00, 0, 0, 0, 0, 3.00, 7.00, 20.00, 500.00, 10000.00, 200000.00
    }

    struct Ticket {
        uint256 choose;
        uint256[] chosen;
        bytes32 batchID;
        bool played;
        uint256[] drawn;
    }

    mapping(address => uint256) currentTicket;
    mapping(address => Ticket[]) playerTickets;

    /**
     * @dev External function for buying ticket.
     * @param _chosen Array of numbers chosen
     */
    function buyTicket(uint256[] _chosen) external nonReentrant {
        uint256 length = _chosen.length;
        require(length <= 10, "To Many chosen");
        require(length > 0, "No number chosen");
        require(
            token.transferFrom(msg.sender, address(ULP), tokenBet) == true,
            "Bet not transferred"
        );
        totalBets += tokenBet;
        Ticket memory ticket;
        ticket.choose = length;
        ticket.chosen = _chosen
        ticket.batchID = ULP.getRandomNumber();
        playerTickets[msg.sender].push(ticket);

        emit TicketBought(msg.sender);
    }


    /**
     * @dev External function to play.
     */
    function play() external nonReentrant {
        uint256 startingTicketNumber = currentTicket[msg.sender];
        require(
            startingTicketNumber < playerTickets[msg.sender].length,
            "No ticket to Play"
        );
        
        Ticket storage ticket = playerTickets[msg.sender][startingTicketNumber];

        currentTicket[msg.sender] = startingTicketNumber + 1;

        require(!ticket.played, "Ticket already Played");

        uint256 currentRandom = ULP.getNewRandomNumber(
            ticket.batchID
        );

        //Draws numbers using the Random Number returned
        mapping(uint256 => bool) draw;
        uint256 size = 0;
        uint256 count = startingTicketNumber;
        while (size < 15) {
            uint256 gameNumber = uint256(keccak256(abi.encode(currentRandom,address(msg.sender),gameId,count))) % 50;
            count += 1;
            if (!draw[gameNumber]) {
                draw[gameNumber] = true;
                ticket.drawn.push(gameNumber);
                size += 1;
            }
        }

        uint256 matches=0;
        //match the players choice with the draw
        for (uint32 i = 0; i < ticket.choose; i++) {
            if (draw[ticket[i]]) {
                matches += 1;
            }
        }

        uint256[] memory _choice = winningTable[ticket.choose]; //The multiplier array of the choose size
        uint256 multiplier = _choice[matches]; //Multiplier 
        uint256 amountToSend = 0;
        if(multiplier > 0){

            amountToSend = (multiplier * tokenBet) / 100;
        }

        ticket.played = true;

        if (amountToSend > 0) {
            totalWinnings += amountToSend;
            ULP.sendPrize(msg.sender, amountToSend);
        }
        emit TicketPlayed(msg.sender, ticket, amountToSend, ticket.drawn);
    }

}
