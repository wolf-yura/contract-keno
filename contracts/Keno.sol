// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IUnifiedLiquidityPool.sol";

contract Keno is Ownable, ReentrancyGuard {
    IUnifiedLiquidityPool public ULP;
    IERC20 public GBTS;

    uint256 constant gameId = 4;
    uint256 constant gbtsBet = 5 * 10**17; // .5 GBTS to make a bet

    /// @notice bettedGBTS keeps track of all GBTS brought in through ticket purchase
    uint256 bettedGBTS;

    /// @notice wonGBTS keeps track of all GBTS won by players
    uint256 wonGBTS;

    /// @notice bought ticket
    event TicketBought(address buyer);

    /// @notice ticket played
    event TicketPlayed(
        address player,
        Ticket ticketPlayed,
        uint256 winnings,
        mapping(uint32 => bool) drawn
    );

    /// @notice this is used to determine the winnings the player will receive
    mapping(uint32 => uint256[]) winningTable; // divide by 100 to get proper multiplier

    constructor(IUnifiedLiquidityPool _ULP, IERC20 _GBTS) {
        ULP = _ULP;
        GBTS = _GBTS;

        winningTable[1] = [0, 326]; // 0, 3.26
        winningTable[2] = [0, 0, 1141]; // 0, 0, 11.41
        winningTable[3] = [0, 0, 200, 2600]; //  0, 0, 2.00, 26.00
        winningTable[4] = [0, 0, 0, 800, 7200]; // 0, 0, 0, 8.00, 72.00
        winningTable[5] = [0, 0, 0, 100, 1600, 25490]; // 0, 0, 0, 1.00, 16.00, 254.90
        winningTable[6] = [0, 0, 0, 200, 200, 4500, 65000]; // 0, 0, 0, 2.00, 2.00, 45.00, 650.00
        winningTable[7] = [100, 0, 0, 0, 200, 1100, 15000, 425000]; //1.00, 0, 0, 0, 2.00, 11.00, 150.00, 4250.00
        winningTable[8] = [100, 0, 0, 0, 100, 500, 3500, 40000, 2140000]; // 1.00, 0, 0, 0, 1.00, 5.00, 35.00, 400.00, 21400.00
        winningTable[9] = [100, 0, 0, 0, 0, 300, 1600, 18000, 200000, 5000000]; // 1.00, 0, 0, 0, 0, 3.00, 16.00, 180.00, 2000.00, 50000.00
        winningTable[10] = [
            100,
            0,
            0,
            0,
            0,
            300,
            700,
            2000,
            50000,
            1000000,
            20000000
        ]; //1.00, 0, 0, 0, 0, 3.00, 7.00, 20.00, 500.00, 10000.00, 200000.00
    }

    struct Ticket {
        uint32 choose;
        uint32[] chosen;
        uint256 gameRandomNumber;
        bool played;
    }

    mapping(address => uint256) currentTicket;
    mapping(address => Ticket[]) playerTickets;

    /**
     * @dev External function for buying ticket.
     * @param _chosen Array of numbers chosen
     */
    function buyTicket(uint32[] _chosen) external nonReentrant {
        uint32 length = _chosen.length;
        require(length <= 10, "To Many chosen");
        require(length > 0, "No number chosen");
        require(
            GBTS.transferFrom(msg.sender, address(ULP), gbtsBet) == true,
            "Bet not transferred"
        );
        bettedGBTS += gbtsBet;
        Ticket memory ticket = Ticket(length, _chosen, ULP.getRandomNumber());
        playerTickets[msg.sender].push(ticket);

        emit TicketBought(msg.sender);
    }

    /**
     * @dev Internal function to pay any winnings.
     * @param _matches Total number of matches made with the draw
     * @param _draw Mapping of draw
     */
    function payWinnings(uint32 _matches, mapping(uint32 => bool) _draw)
        internal
    {
        Ticket storage ticket = playerTickets[msg.sender][
            currentTicket[msg.sender]
        ];
        uint256 multiplier = winningTable[ticket.choose][_matches];
        currentTicket[msg.sender] += 1;
        uint256 amountToSend = (multiplier * gbtsBet) / 100;
        ticket.played = true;

        if (amountToSend > 0) {
            wonGBTS += amountToSend;
            ULP.sendPrize(msg.sender, amountToSend);
        }
        emit TicketPlayed(msg.sender, ticket, amountToSend, _draw);
    }

    /**
     * @dev External function to play.
     */
    function play() external nonReentrant {
        uint256 startingTicketNumber = currentTicket[msg.sender];
        Ticket[] ticketsBought = playerTickets[msg.sender];
        require(
            startingTicketNumber <= ticketsBought.length,
            "No ticket to Play"
        );

        uint256 currentRandom = ULP.getNewRandomNumber(
            ticketsBought[startingTicketNumber].gameRandomNumber
        );
        mapping(uint32 => bool) drawNumbers = draw(
            currentRandom,
            startingTicketNumber
        );

        uint32 matches;
        uint32[] ticket = ticketBought[startingTicketNumber].chosen;
        for (uint32 i = 0; i < ticketBought[startingTicketNumber].choose; i++) {
            if (drawNumbers[ticket[i]]) {
                matches += 1;
            }
        }
        payWinnings(matches, drawNumbers);
    }

    /**
     * @dev Internal function to draw.
     * @param random random number
     * @param ticket Ticket number
     */
    function draw(uint256 random, uint256 ticket)
        internal
        view
        returns (mapping(uint32 => bool))
    {
        mapping(uint32 => bool) draw;
        uint32 size = 0;
        uint256 count = ticket;
        while (size < 15) {
            uint32 gameNumber = uint32(
                keccak256(
                    abi.encode(
                        newRandomNumber,
                        address(msg.sender),
                        gameId,
                        count
                    )
                )
            ) % 50;
            count += 1;
            if (!draw[gameNumber]) {
                draw[gameNumber] = true;
                size += 1;
            }
        }
        return draw;
    }
}
