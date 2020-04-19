pragma solidity >=0.4.25 < 0.7.0;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codes
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    // Amounts to be taken care
    uint256 private constant MAX_INSURANCE_AMOUNT = 1;
    uint256 private constant REGISTRATION_AMOUNT = 10;

    FlightSuretyData flightSuretyData;      // The data contract state variable

    /********************************************************************************************/
    /*                                       EMITTING METHODS                                   */
    /********************************************************************************************/

    event AirlineRegistered(bool status, string info, uint votes);
    event FlightRegistered(uint8 status, string info, bytes32 key);
    event InsuranceClaimed(address customer, uint amount);

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
        // Modify to call data contract's status
        require(isOperational(), "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    modifier requireFlightToBeInFuture(uint256 timestamp)
    {
        require(timestamp > now, "Flight already dispatched");
        _;
    }

    modifier isExistingActiveAirline()
    {
        flightSuretyData.isActiveAndFunded(msg.sender);
        _;
    }

    modifier checkForRefund(uint256 amount)
    {
        require(msg.value >= amount, "Amount id not enough");
        _;
        uint256 refund = msg.value - amount;

        if (refund > 0) {
            msg.sender.transfer(refund);
        }
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    */
    constructor
    (
        address dataContract
    )
    public
    {
        flightSuretyData = FlightSuretyData(dataContract);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational()
    public
    view
    returns(bool)
    {
        return flightSuretyData.isOperational();
    }

    function setOperational(bool mode) external
    {
        flightSuretyData.setOperatingStatus(mode);
    }

    function calculateInsurancePayAmount()
    internal
    returns(uint256 amount)
    {
        amount = msg.value;
        if (amount < MAX_INSURANCE_AMOUNT) {
            amount = MAX_INSURANCE_AMOUNT;
        }
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     */
    function registerAirline
    (
        string calldata name,
        address airline
    )
    external
    requireIsOperational
    isExistingActiveAirline
    {
        (bool success, string memory message) = flightSuretyData.registerAirline(name, airline);

        emit AirlineRegistered(success, message, 0);

        if (flightSuretyData.isActive(airline)) {
            emit AirlineRegistered(true, "Airline accepted, waiting for funding", 0);
        }
    }

    function fundAirline
    (
    )
    public
    payable
    {
        flightSuretyData.fund();
        emit AirlineRegistered(true, "Airline funded, good to go", 0);
    }

    function voteAirline
    (
        address airline
    )
    requireIsOperational
    public
    {
        uint votes = flightSuretyData.voteAirline(airline);

        emit AirlineRegistered(true, "Airline has a new vote", votes);

        if (flightSuretyData.isActive(airline)) {
            emit AirlineRegistered(true, "Airline accepted, waiting for funding", votes);
        }
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight
    (
        string calldata flight,
        uint256 timestamp
    )
    requireIsOperational
    requireFlightToBeInFuture(timestamp)
    external
    {
        bytes32 key = flightSuretyData.registerFlight(flight, timestamp);

        emit FlightRegistered(STATUS_CODE_UNKNOWN, "Flight registered", key);
    }

    /**
     * @dev Called after oracle has updated flight status
     */
    function processFlightStatus
    (
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    )
    requireIsOperational
    internal
    {
        bytes32 key = flightSuretyData.getFlightKey(airline, flight, timestamp);

        emit FlightStatusInfo(airline, flight, timestamp, statusCode);

        if (statusCode == STATUS_CODE_LATE_AIRLINE) {
            flightSuretyData.creditInsurees(key);
        }
    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
    (
        address airline,
        string calldata flight,
        uint256 timestamp
    )
    requireIsOperational
    external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
            requester: msg.sender,
            isOpen: true
            });

        emit OracleRequest(index, airline, flight, timestamp);
    }

    /**
     *  @dev Buy an insurance for a future flight
    */
    function buyInsurance
    (
        address airline,
        string calldata flight,
        uint256 timestamp
    )
    requireIsOperational
    requireFlightToBeInFuture(timestamp)
    checkForRefund(calculateInsurancePayAmount())
    external
    payable
    {
        flightSuretyData.buy(airline, flight, timestamp, calculateInsurancePayAmount());
    }

    /**
     *  @dev Receive a payment if allotted
    */
    function receivePayout()
    requireIsOperational
    external
    payable
    {
        uint256 amount = flightSuretyData.pay(msg.sender);

        emit InsuranceClaimed(msg.sender, amount);
    }

    /**
     *  @dev function just for testing that the contract is working well
    */
    function setTestingMode
    (
        bool mode
    )
    requireIsOperational
    view
    public
    returns(bool)
    {
        return mode;
    }

    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
        // This lets us group responses and identify
        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);

    // Register an oracle with the contract
    function registerOracle
    (
    )
    checkForRefund(REGISTRATION_FEE)
    external
    payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
            isRegistered: true,
            indexes: indexes
            });
    }

    function getMyIndexes
    (
    )
    view
    external
    returns(uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
    (
        uint8 index,
        address airline,
        string calldata flight,
        uint256 timestamp,
        uint8 statusCode
    )
    requireIsOperational
    external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");

        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
    (
        address account
    )
    requireIsOperational
    internal
    returns(uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
    (
        address account
    )
    requireIsOperational
    internal
    returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

    // endregion
}

contract FlightSuretyData {
    function isOperational() external view returns(bool);
    function setOperatingStatus(bool mode) external;
    function registerAirline(string calldata name, address airline) external payable returns(bool success, string memory message);
    function voteAirline(address airline) external returns(uint);
    function registerFlight(string calldata flight, uint256 timestamp) external returns(bytes32 key);
    function buy(address airline, string calldata flight, uint256 timestamp, uint256 insuranceAmount) external;
    function creditInsurees(bytes32 key) external;
    function pay(address payable receiver) external payable returns(uint256 amount);
    function fund() public payable;
    function getFlightKey(address airline, string calldata flight, uint256 timestamp) external returns(bytes32);
    function isActiveAndFunded(address airline) external view returns(bool);
    function isActive(address airline) external view returns(bool);
    function isFunded(address airline) external view returns(bool);
}