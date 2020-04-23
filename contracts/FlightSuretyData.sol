pragma solidity >=0.4.25 < 0.7.0;

contract FlightSuretyData {
    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/
    address private contractOwner;      // Account used to deploy contract
    bool private operational = true;    // Blocks all state changes throughout the contract if false

    // The state variables for Airlines
    struct Airline {
        string name;
        bool isActive;
        bool funded;
    }
    mapping(address => Airline) public airlines;
    mapping(address => address[]) private airlineToVote;
    struct AirlineList {
        string name;
        address addr;
    }
    AirlineList[] private airlinesList;

    // The state variables for Flight
    struct Flight {
        string name;
        uint8 statusCode;
        uint256 departureTime;
        uint256 updatedTimestamp;
        address airline;
    }
    mapping(bytes32 => Flight) private flights;
    struct FlightList {
        string name;
        bytes32 key;
    }
    FlightList[] private flightsList;

    // The state variables for Insurance
    struct Insurance {
        string ticket;
        string flight;
        address buyer;
        uint256 amount;
    }
    mapping(bytes32 => Insurance[]) private insureList;
    mapping(address => uint256) private payoutList;

    // The flight status code from the oracle
    uint8 private constant STATUS_CODE_UNKNOWN = 0;

    /********************************************************************************************/
    /*                                          Constructor                                     */
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

    /********************************************************************************************/
    /*                                    FUNCTIONS FOR MODIFIERS                               */
    /********************************************************************************************/

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
        bytes memory name = bytes(airlines[airline].name);
        return name.length > 0;
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
     * @dev Modifier that requires the airline to be a new one
     */
    function getAirlineByName
    (
        string calldata name
    )
    external
    view
    returns(address)
    {
        address airlineAddress = address(0);

        for (uint i = 0; i < airlinesList.length; i++) {
            if (keccak256(bytes(airlinesList[i].name)) == keccak256(bytes(name))) {
                airlineAddress = airlinesList[i].addr;
            }
        }

        return airlineAddress;
    }

    function getFlightKeyByName
    (
        string memory flight
    )
    internal
    view
    returns(bytes32 key)
    {
        key = '';
        for (uint8 i = 0; i < flightsList.length; i++) {
            if (keccak256(bytes(flight)) == keccak256(bytes(flightsList[i].name))) {
                key = flightsList[i].key;
            }
        }
    }

    function stringToBytes32
    (
        string memory source
    )
    public
    pure
    returns (bytes32 result)
    {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /***************************************** Airlines Starts **********************************/

    /**
     * @dev Register the first airline
     *      It is automatically done by at the time of contract deployment
     */
    function registerFirstAirline
    (
        address airline
    )
    internal
    {
        airlines[airline] = Airline({
            name: "First Flight",
            isActive: true,
            funded: false
        });
    }

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     */
    function registerAirline
    (
        string calldata name,
        address airline
    )
    external
    returns(bool success, string memory message)
    {
        success = false;
        airlines[airline] = Airline({
            name: name,
            isActive: false,
            funded: false
        });

        if (airlinesList.length > 0 && airlinesList.length <=4) {
            airlines[airline].isActive = true;
            success = true;
            message = "Airline registered successfully";
        } else {
            address[] memory blankArray;
            airlineToVote[airline] = blankArray;
            success = true;
            message = "Airline waiting to be voted";
        }
    }

    /**
     * @dev Add an airline to the registration queue
     */
    function voteAirline
    (
        address airline,
        address voter
    )
    external
    returns(uint)
    {
        bool alreadyVoted = false;

        for(uint8 i = 0; i < airlineToVote[airline].length; i++) {
            if (airlineToVote[airline][i] == voter) {
                alreadyVoted = true;
            }
        }

        if (!alreadyVoted) {
            airlineToVote[airline].push(voter);
        }

        if (airlineToVote[airline].length > airlinesList.length/2) {
            airlines[airline].isActive = true;
            delete(airlineToVote[airline]);
        }

        return airlineToVote[airline].length;
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     */
    function fund
    (
        address airline
    )
    public
    payable
    {
        require(this.isActive(airline), "You still need some more votes");
        require(!this.isFunded(airline), "You are already funded");

        airlines[airline].funded = true;
        airlinesList.push(AirlineList({
            name: airlines[airline].name,
            addr: airline
        }));
    }

    /**
     * @dev Get Airline information
     */
    function getAirlineInfo
    (
        address airline
    )
    external
    view
    returns(string memory, bool, bool, uint256)
    {
        return (
            airlines[airline].name,
            airlines[airline].funded,
            airlines[airline].isActive,
            airlineToVote[airline].length
        );
    }

    /**
     * @dev Get all Airline name
     */
    function getAirlineTotal()
    external
    view
    returns(uint)
    {
        return airlinesList.length;
    }

    /**
     * @dev Get all Airline name
     */
    function getAllAirlineName()
    external
    view
    returns(bytes32[] memory)
    {
        bytes32[] memory allAirlines = new bytes32[](airlinesList.length);

        for(uint i = 0; i < airlinesList.length; i++) {
            allAirlines[i] = stringToBytes32(airlinesList[i].name);
        }

        return allAirlines;
    }

    /****************************************** Airlines Ends ***********************************/

    /****************************************** Flight Starts ***********************************/

    /**
     *  @dev register a new flight by an active airline
     */
    function registerFlight
    (
        address airline,
        string calldata flight,
        uint256 timestamp
    )
    external
    returns(bool success, string memory message)
    {
        success = false;
        bytes32 key = getFlightKey(airline, flight, timestamp);
        flights[key] = Flight({
            name: flight,
            statusCode: STATUS_CODE_UNKNOWN,
            departureTime: timestamp,
            updatedTimestamp: now,
            airline: airline
        });
        flightsList.push(FlightList({
            name: flight,
            key: key
        }));

        success = true;
        message = "Flight registered successfully";
    }

    /**
     * @dev Get all Airline name
     */
    function getAllFlightsName()
    external
    view
    returns(bytes32[] memory)
    {
        bytes32[] memory allFlights;

        for(uint i = 0; i < flightsList.length; i++) {
            allFlights[i] = stringToBytes32(flightsList[i].name);
        }

        return allFlights;
    }

    /**
     * @dev Supporting functions to get the keys for saving the flight
     */
    function getFlightKey
    (
        address airline,
        string memory flight,
        uint256 timestamp
    )
    internal
    pure
    returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /******************************************* Flight Ends ************************************/

    /**************************************** Insurance Starts **********************************/

    /**
     * @dev Buy insurance for a flight
     */
    function buy
    (
        string calldata flight,
        string calldata ticket,
        uint256 insuranceAmount,
        address payable buyer
    )
    external
    {
        Insurance memory insurance = Insurance({
            ticket: ticket,
            flight: flight,
            buyer: buyer,
            amount: insuranceAmount
        });
        address(this).transfer(insuranceAmount);
        bytes32 key = getFlightKeyByName(flight);
        insureList[key].push(insurance);
    }

    /**
     * @dev Credits payouts to insurees
     */
    function creditInsurees
    (
        string calldata flight
    )
    external
    {
        bytes32 key = getFlightKeyByName(flight);
        Insurance[] memory insurances = insureList[key];

        for(uint i = 0; i < insurances.length; i++) {
            address customer = insurances[i].buyer;
            uint256 amount = insurances[i].amount;

            if (payoutList[customer] == 0) {
                payoutList[customer] = amount;
            } else {
                payoutList[customer] += amount;
            }
        }
    }

    /**
     * @dev Transfers eligible payout funds to insuree
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

    /***************************************** Insurance Ends ***********************************/

    /**
     * @dev Fallback function for funding smart contract.
     */
    function()
    external
    payable
    {
        fund(msg.sender);
    }
}
