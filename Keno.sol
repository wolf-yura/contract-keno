pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IUnifiedLiquidityPool.sol";

contract Keno is Ownable, ReentrancyGuard{

    IUnifiedLiquidityPool public ULP;
    IERC20 public GBTS;

    uint256 constant gameId = 4;
    uint256 constant gbtsBet = 5 * 10**17; // .5 GBTS to make a bet
    
    /// @notice bought ticket
    event TicketBought(address buyer)

    /// @notice ticket played
    event TicketPlayed(address player, Ticket ticketPlayed, uint256 winnings)

    /// @notice this is used to determine the winnings the player will receive
    mapping(uint32 => uint256[]) winningTable; // divide by 100 to get proper multiplier

    constructor(IUnifiedLiquidityPool _ULP, IERC20 _GBTS){

        ULP = _ULP;
        GBTS = _GBTS;

        winningTable[1] = [0, 326];
        winningTable[2] = [0,0,1141];
        winningTable[3] = [0,0,200,2600];        
        winningTable[4] = [0,0,0,800,7200];
        winningTable[5] = [0,0,0,100,1600,25490];
        winningTable[6] = [0,0,0,200,200,4500,65000];
        winningTable[7] = [100,0,0,0,200,1100,15000,425000];
        winningTable[8] = [100,0,0,0,100,500,3500,40000,2140000];
        winningTable[9] = [100,0,0,0,0,300,1600,18000,200000,5000000];
        winningTable[10] =[100,0,0,0,0,300,700,2000,50000,1000000,20000000];
    }

    struct Ticket{
        uint32 choose;
        uint32[] chosen;
        uint256 gameRandomNumber;
    }
    mapping(address => uint256) currentTicket;
    mapping(address => Ticket[]) playerTickets;

    /// @dev player buys a ticket
    /// @param _chosen is an array of the numbers choosens
    function buyTicket(uint32[] _chosen) external nonReentrant{
        uint32 length = choosen.length;
        require(length <= 10, "To Many chosen");
        require(length > 0, "No number chosen");
        require(GBTS.transferFrom(msg.sender, address(ULP), gbtsBet) == true, "Bet not transferred")
        Ticket memory ticket = Ticket(length, _chosen,  ULP.getRandomNumber())
        playerTickets[msg.sender].push(ticket));

        emit TicketBought(msg.sender)

    }
    /// @dev internal function to pay any winnings
    /// @param _matches the total number of matches made with the draw

    function payWinnings(uint32 _matches) internal{
        Ticket storage ticket = playerTicket[msg.sender][currentTicket[msg.sender]];
        uint256 multiplier = winningTable[ticket.choose][_matches];
        currentTicket[msg.sender] += 1;
        uint256 amountToSend = (multiplier * gbtsBet)/100;
        if(amountToSend > 0){
            ULP.sendPrize(
                msg.sender,
                amountToSend
            );        
        }
        emit TicketPlayed(msg.sender, ticket, amountToSend);
    }

    /// @dev Player calls to play the tickets bought

   function play() external nonReentrant{
        uint256 startingTicketNumber = currentTicket[msg.sender];
        Ticket[] ticketsBought = playerTicket[msg.sender];
        require(startingTicketNumber <= ticketsBought.length, "No ticket to Play");
        uint256 currentRandom = ULP.getNewRandomNumber(ticketsBought[startingTicketNumber].gameRandomNumber);
        mapping(uint32=>bool) drawNumbers = draw(currentRandom);

        for(int32 i =0; i < ticketBought[startingTicketNumber].choose; i++){
            


        }



        }

   }
    /// @dev internal function to get the drawn Numbers
    /// @param random used to calculate the drawn numbers
    /// @return sends a mapping bool back of selected number

    function draw(uint256 random) internal view return(mapping(uint32=>bool)){
        mapping(uint32=>bool) draw;
        uint32 size = 0;
        uint256 count =0;
        while(size<15){
            uint32 gameNumber = uint32(keccak256(abi.encode(newRandomNumber, address(msg.sender), gameId, count))) % 50;
            count += 1;
            if(!draw[gameNumber]){
                draw[gameNumber] = true;
                size +=1;
            }
        }
        return draw;
    }


}