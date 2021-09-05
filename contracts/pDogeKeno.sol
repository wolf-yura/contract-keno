import "./interfaces/IRandomNumberGenerator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract pDogekeno{

using SafeERC20 for IERC20;

    /// @notice Event emitted when user bought the tickets.
    event TicketsBought(address buyer, uint256 ticketNumber);

    /// @notice Event emitted when user played.
    event TicketPlayed(
        address player,
        Ticket ticketPlayed,
        uint256 winnings,

    );

    /// @notice Event emitted when betAmount changes. 
    event betChanged(uint256 bet, uint256 upper, uint256 lower);

    event addToken(address provider, uint256 amount);

    event tokenRemoved(address provider, uint256 amount)

    IRandomNumberGenerator public RNG;
    IERC20 public pdoge;

    uint256 betAmount;
    uint256 upperBound;
    uint256 lowerBound;
    uint256 burnedPdoge;

    uint256 lastCollected;

    /// @notice bettedGBTS keeps track of all pdoge brought in through ticket purchase
    uint256 public totalBettedAmount;

    /// @notice wonGBTS keeps track of all pdoge won by players
    uint256 public totalWinnings;

    /// @notice Determine the winnings the player will receive
    uint256[][] public winningTable;

    uint256 nextCollection;
    address private lpWallet;
    bool lpSet;
    bool pSet;
    address pWallet;
    modifier onlyRNG() {
        require(
            msg.sender == address(RNG),
            "DiceRoll: Caller is not the RandomNumberGenerator"
        );
        _;
    }

    modifier isTime() {

        require(block.timestamp >= nextCollection,"Keno: Not time to collect");
        _;
    }

    struct Ticket {
        address player;
        uint256 length;
        uint256[70] numbers;
        bytes32 ticketID;
        uint256 ticketNumber;
        uint256 betAmount;
        bool[70] drawnTickets;
    }

    mapping(address => bytes32[]) public playerTickets;
    mapping(bytes32 => Ticket) private tickets;

    mapping(address => uint256) provider;

    /**
     * @dev Constructor function
     * @param _RNG Interface of RNG
     * @param _pdoge Interface of pdoge

     */
    constructor(
        IRandomNumberGenerator _RNG,
        IERC20 _pdoge
    ) {
        RNG = _RNG;
        pdoge = _pdoge;

        winningTable.push();
        winningTable.push([0, 35]); // 0, 3.26
        winningTable.push([0, 0, 155]); // 0, 0, 11.41
        winningTable.push([0, 0, 0, 690]); //  0, 0, 2.00, 26.00
        winningTable.push([0, 0, 0, 160, 770]); // 0, 0, 0, 8.00, 72.00
        winningTable.push([0, 0, 0, 40, 450, 770]); // 0, 0, 0, 1.00, 16.00, 254.90
        winningTable.push([0, 0, 0, 34, 70, 690, 6990]); // 0, 0, 0, 2.00, 2.00, 45.00, 650.00
        winningTable.push([10, 0, 0, 0, 200, 70, 7770, 77770]); //1.00, 0, 0, 0, 2.00, 11.00, 150.00, 4250.00
         
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
            _chosenTicketNumbers.length < 8 && _chosenTicketNumbers.length > 0,
            "Keno: Every ticket should have 1 to 7 numbers."
        );

        pdoge.safeTransferFrom(msg.sender, address(this), betAmount);
        totalBettedAmount += betAmount;
        uint256 _ticketNumber = playerTickets[msg.sender].length;
        Ticket memory ticket;
        ticket.player = msg.sender;
        ticket.length = _chosenTicketNumbers.length;
        ticket.numbers = _chosenTicketNumbers;
        bytes32 _ticketID = RNG.requestRandomNumber();
        ticket.ticketID = _ticketID;
        ticket.betAmount = betAmount;
        ticket.ticketNumber = _ticketNumber;
        playerTickets[msg.sender].push(_ticketID);
        tickets[ticketID] = ticket;
        calculateBetAmount();
        emit TicketsBought(msg.sender, _ticketNumber);
    }

    /**
     * @dev External called by RNG.
     * @param _ticketID  Ticket Number
     * @param _randomness Random Number from RNG
     */
    function play(bytes32 _ticketID, uint256 _randomness) external onlyRNG {
        
        //Draw numbers using the Random Number Generator.
        Ticket storage ticket = tickets[_ticketID];
        uint32 size = 0;
        uint256 count = 0;
        while (size < 17) {
            uint256 gameNumber = (uint256(
                keccak256(
                    abi.encode(
                        _randomness,
                        count
                    )
                )
            ) % 69) + 1;
            count++;

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
        uint256 amountToSend = (multiplier * ticket.betAmount) / 10;

        if (amountToSend > 0) {
            totalWinnings += amountToSend;
            pdoge.safeTransfer(ticket.player, amountToSend);
        }

        ticket.drawnTickets[0] = true;

        emit TicketPlayed(
            ticket.player,
            ticket,
            amountToSend
        );
    }


    function calculateBetAmount() private{

        uint256 contractBal =pdoge.balanceOf(address(this))
        if(betAmount == 0){
          betAmount = contractBal/100000
         upperBound = contractBal * 2;
          lowerBound = contractBal/5;
        }
        if(upperBound < contractBal){
          upperBound = 3 * upperBound;
            lowerBound = 3 * lowerBound;
          betAmount = 2 * betAmount;
        }
        if(lowerBound > contractBal){

           betAmount = betAmount/2;
           upperBound = upperbound/3;
           lowerBound = lowerBound/3;
        }
    emit betChange(betAmount, upperBound, lowerBound);
    }


    function addToken(uint256 _amount) nonReentrant{

        uint256 weightToAdd;
        uint256 conBal =pdoge.balanceOf(address(this));
        if(conBal==0){
            weightToAdd = _amount;
        }else{
            weightToAdd = (_amount * totalWeight) / conBal;
        }
        pdoge.safeTransferFrom(msg.sender, address(this), _amount);
        totalWeight += weightToAdd;
        provider[msg.sender] += weightToAdd;
        lastCollected += _amount;
        calculateBetAmount();
        emit addToken(msg.sender, _amount);
    }

    function removeToken(uint256 _amount) nonReentrant{

        require(provider[msg.sender] > 0, "Keno: User has not provided");
        uint256 conBal = pdoge.balanceOf(address(this));
        uint256 userTokens = (provider[msg.sender] * conBal) / totalWeight;
        require(userTokens >= _amount, "Keno: Not enough tokens.");

        uint256 weightToRemove;

        if(_amount == userTokens){
            weightToRemove = provider[msg.sender];
            provider[msg.sender] = 0;
        }else{
            weightToRemove = _amount * provider[msg.sender] / userTokens;
            provider[msg.sender] = provider[msg.sender] - weightToRemove;
        }
        totalWeight = totalWeight - weightToRemove;
        lastCollected -= _amount;
        pdoge.safeTransfer(msg.sender, _amount);
        calculateBetAmount();
        emit tokenRemoved(msg.sender, _amount);
    }


    function LPbuilder()external isTime{

        nextCollection += 7 * days;
        if(lastCollected <= pdoge.balanceOf(address(this))){
            uint256 tenthOfPercent = (pdoge.balanceOf(address(this)) - lastCollected)/1000;
            lastCollected = pdoge.balanceOf(address(this));
            if(lpSet){
                pdoge.safeTransfer(lpWallet, (tenthOfPercent * 35));
            }
            if(pSet){
                pdoge.safeTransfer(pWallet, (tenthOfPercent*25));
            }
            pdoge.safeTransfer(address(0x000000000000000000000000000000000000dEaD), (tenthOfPercent * 20));
            burnedPdoge += (tenthOfPercent * 20);
        }
    }

    function setAddresses(address _addy, bool p_LP) onlyOwner{

        if(p_LP && !pSet){
            pWallet = _addy;
            pSet = true;
        }
        if(!(p_LP || lpSet)){ //True only when both are false
            lpWallet = _addy;
            lpSet = true;
        }

    }

    function viewUserToken() view return(uint256) external {

        return (provider[msg.sender] * pdoge.balanceOf(address(this))) / totalWeight;

    }

    function changeWallet(address _addy)external nonReentrant{

        require((msg.sender == lpWallet) || (msg.sender == pWallet), "Keno: Not proper");
        if(msg.sender == lpWallet){
            lpWallet= _addy;
        }
        if(msg.sender == pWallet){
            pWallet == _addy;
        }
    }
}
