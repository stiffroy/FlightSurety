pragma solidity >=0.4.25 < 0.7.0;

contract FlightSuretyData {
    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;      // Account used to deploy contract
    bool private operational = true;    // Blocks all state changes throughout the contract if false

    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    struct Airline {
        string name;
        bool isActive;
        bool funded;
    }
    mapping(address => Airline) public airlines;
    uint8 private airlinesCount = 0;
    mapping(address => address[]) private airlineToVote;

    struct Insurance {
        address buyer;
        uint256 amount;
    }
    mapping(bytes32 => Insurance[]) private insureList;
    mapping(address => uint256) private payoutList;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
    (
        address firstAirline
    )
    public
    {
        registerFirstAirline(firstAirline);
        contractOwner = msg.sender;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational()
    {
        require(this.isOperational(), "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
    * @dev Modifier that requires the sender to be an active airline
    */
    modifier requireIsAnActiveAirline()
    {
        require(this.isAirline(msg.sender), "Caller is not an existing airline");
        require(this.isActiveAndFunded(msg.sender), "Caller is not yet an active airline");
        _;
    }

    /**
    * @dev Modifier that requires the airline to be a new one
    */
    modifier isNewAirline(address airline)
    {
        require(bytes(airlines[airline].name).length == 0, "Airline already registered");
        _;
    }

    /**
    * @dev Modifier that requires vote for the airline to be registered
    */
    modifier requireVoting()
    {
        require(airlinesCount > 4, "Airline don't need votes to register");
        _;
    }

    /**
    * @dev Modifier that requires the voter to be an active airline
    */
    modifier requireVoterToBeActive()
    {
        require(this.isActiveAndFunded(msg.sender), "Airline cannot vote");
        _;
    }

    /**
    * @dev Modifier requires the airline is not yet active
    */
    modifier requireAirlineNotActive(address _airline)
    {
        require(!this.isActive(_airline), "Airline already active");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */
    function isOperational()
    external
    view
    returns(bool)
    {
        return operational;
    }

    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */
    function setOperatingStatus
    (
        bool mode
    )
    external
    requireContractOwner
    {
        require(this.isOperational() != mode, "Nothing to change");
        operational = mode;
    }

    /**
    * @dev To check if the airline is an active and funded member
    */
    function isActiveAndFunded
    (
        address airline
    )
    external
    view
    returns(bool)
    {
        return this.isActive(airline) && this.isFunded(airline);
    }

    /**
    * @dev To check if the airline is an active and funded member
    */
    function isActive
    (
        address airline
    )
    external
    view
    returns(bool)
    {
        return airlines[airline].isActive;
    }

    /**
    * @dev To check if the airline is an active and funded member
    */
    function isFunded
    (
        address airline
    )
    external
    view
    returns(bool)
    {
        return airlines[airline].funded;
    }

    /**
    * @dev To check that the airline to be a new one
    */
    function isAirline
    (
        address airline
    )
    external
    view
    returns(bool)
    {
        return bytes(airlines[airline].name).length != 0;
    }

    /**
    * @dev Modifier that requires the airline to be a new one
    */
    function getAirline
    (
        address airline
    )
    external
    view
    returns(string memory name)
    {
        name = airlines[airline].name;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function registerFirstAirline
    (
        address airline
    )
    internal
    {
        airlines[airline] = Airline({
            name: "First Airline",
            isActive: true,
            funded: false
        });
        airlinesCount++;
    }

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function registerAirline
    (
        string calldata name,
        address airline
    )
    external
    isNewAirline(airline)
    requireIsAnActiveAirline
    returns(bool success, string memory message)
    {
        success = false;
        if (airlinesCount > 0 && airlinesCount <=4) {
            airlines[airline] = Airline({
                name: name,
                isActive: true,
                funded: false
            });
            success = true;
            message = "Airline registered successfully";
        } else {
            airlines[airline] = Airline({
                name: name,
                isActive: false,
                funded: false
            });
            address[] memory blankArray;
            airlineToVote[airline] = blankArray;
            success = true;
            message = "Airline waiting to be voted";
        }
    }

    /**
     * @dev Add an airline to the registration queue
     *
     */
    function voteAirline
    (
        address airline
    )
    external
    requireVoting
    requireVoterToBeActive
    requireAirlineNotActive(airline)
    returns(uint)
    {
        bool canVote = true;

        for(uint8 i = 0; i < airlineToVote[airline].length; i++) {
            if (airlineToVote[airline][i] == msg.sender) {
                canVote = false;
            }
        }

        if (canVote) {
            airlineToVote[airline].push(msg.sender);
        }

        if (airlineToVote[airline].length > airlinesCount/2) {
            airlines[airline].isActive = true;
        }

        return airlineToVote[airline].length;
    }

    /**
     *  @dev register a new flight by an active airline
    */
    function registerFlight
    (
        string calldata flight,
        uint256 timestamp
    )
    external
    requireIsAnActiveAirline
    returns(bytes32 key)
    {
        key = this.getFlightKey(msg.sender, flight, timestamp);

        flights[key] = Flight({
            isRegistered: true,
            statusCode: STATUS_CODE_UNKNOWN,
            updatedTimestamp: timestamp,
            airline: msg.sender
            });
    }

    /**
     * @dev Buy insurance for a flight
     */
    function buy
    (
        address airline,
        string calldata flight,
        uint256 timestamp,
        uint256 insuranceAmount
    )
    external
    {
        bytes32 key = this.getFlightKey(airline, flight, timestamp);

        Insurance memory insurance = Insurance({
            buyer: msg.sender,
            amount: insuranceAmount
            });
        insureList[key].push(insurance);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
    (
        bytes32 key
    )
    external
    {
        for(uint256 i = 0; i < insureList[key].length; i++) {
            address customer = insureList[key][i].buyer;
            uint256 amount = insureList[key][i].amount;

            if (payoutList[customer] == 0) {
                payoutList[customer] = amount;
            } else {
                payoutList[customer] += amount;
            }
        }
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
    */
    function pay
    (
        address payable receiver
    )
    external
    payable
    returns(uint256 amount)
    {
        require(payoutList[receiver] > 0, "Nothing to payout");
        amount = payoutList[receiver];
        payoutList[receiver] = 0;
        receiver.transfer(amount);
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     */
    function fund
    (
    )
    public
    payable
    {
        require(this.isActive(msg.sender), "You still need some more votes");
        require(!this.isFunded(msg.sender), "You are already funded");

        airlines[msg.sender].funded = true;
        airlinesCount++;
    }

    function getFlightKey
    (
        address airline,
        string calldata flight,
        uint256 timestamp
    )
    external
    pure
    returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function()
    external
    payable
    {
        fund();
    }
}
