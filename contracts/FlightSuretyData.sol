pragma solidity >=0.4.24 <0.6.0;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/
    struct AirlineProfile {
        bool isRegistered;
        bool isFunded;
    }

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    mapping(address => AirlineProfile) private airlines;
    uint256 numAirlines;
    uint256 numFunded;
    uint256 numConsensus;
    uint256 fundAmt = 10;
    mapping(address => bool) public authorizedCallers;
    mapping(address => address[]) private regApproved;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
        ()
        public
    {
        contractOwner = msg.sender;
        airlines[contractOwner].isRegistered = true;
        airlines[contractOwner].isFunded = true;
        numAirlines = numAirlines.add(1);
        numFunded = numFunded.add(1);
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
        require(operational, "Contract is currently not operational");
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
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireAirlineRegistered( address _airline )
    {
        require(airlines[_airline].isRegistered, "Airline is not registered");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
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
    * When operational mode is disabled, all write transactions except for this one will fail
    */
    function setOperatingStatus
                            (
                                bool mode
                            )
                            external
                            requireContractOwner
    {
        require(mode != operational, "New mode must be different from existing mode");
        operational = mode;
    }

    function authorizeCaller(address callerAddress)
        external
        requireContractOwner
        requireIsOperational
    {
        authorizedCallers[callerAddress] = true;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/
//----------------------------------------------------------------------------------------------
// airline functions
   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function registerAirline
                            (
                                address airline
                            )
                            external
                            requireIsOperational
                            returns(bool)
    {
        airlines[airline].isRegistered = true;
        airlines[airline].isFunded = false;
        numAirlines = numAirlines.add(1);
        return(true);
    }

    /**
    * @dev determine if an address is an airline
    * @return A bool that is true if it is a funded airline
    */
    function isAirline( address airline )
                            external
                            view
                            returns(bool)
    {
        return airlines[airline].isFunded;
    }

    function GetAirlineCount() external view
    returns(uint256 count) {
        count = numAirlines;
        return count;
    }

    function GetFundedAirlineCount() external view
    returns(uint256 count) {
        count = numFunded;
        return count;
    }

   function GetNumVotes() external view
    returns(uint256 count) {
        count = numConsensus;
        return count;
    }

   function isRegisteredAirline(address _airline) external view
    returns(bool) {
        return airlines[_airline].isRegistered;
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */
    function fund
                            (
                                address _airline
                            )
                            public
                            payable
                            requireAirlineRegistered(_airline)
    {
//        recipient.transfer(msg.value); //// TODO causes test to fail; not funded
        airlines[_airline].isFunded = true;
        authorizedCallers[_airline] = true;
        numFunded = numFunded.add(1);
        numConsensus = numFunded.div(2);
    }
//----------------------------------------------------------------------------------------------
// flight functions
    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        string fltDate;
        address airline;
        string flt;
    }
    mapping(bytes32 => Flight) private flights;

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    function registerFlight
    (
        address _airline,
        string _flt,
        string _date
    )
                            external
                            requireIsOperational
                            requireAirlineRegistered(_airline)
                            returns(bool)
    {
        bytes32 key = getFlightKey(_airline, _flt, _date);
        require(isRegisteredFlight(key) == false, "isRegisteredFlight(key), setFlight function.");
        flights[key] = Flight({
            isRegistered : true,
            statusCode : 0,
            fltDate : _date,
            airline : _airline,
            flt : _flt
        });
        return(isRegisteredFlight(key));
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            string memory timestamp
                        )
                        public
                        pure
                        returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    function isRegisteredFlight(bytes32 key) public view returns(bool){
        return (flights[key].isRegistered);
    }

    function getFlight(bytes32 key) public view returns(bool, uint8, string memory, address, string memory){
        return (flights[key].isRegistered, flights[key].statusCode, flights[key].fltDate, flights[key].airline, flights[key].flt);
    }

    /** 
    * @dev Fallback function for funding smart contract.
    *
    */
    function()
                            external
                            payable
    {
        fund(msg.sender);
    }

//----------------------------------------------------------------------------------------------
// Insurance functions
    struct Insurance{
        uint256 insuranceAmount;
        address passenger;
        bool    isTaken;
    }
    
    mapping (bytes32 => Insurance) private manifestList;
    mapping (bytes32 => address[]) private passengerList;
    uint256 public constant insuranceFee = 1 ether;

   /**
    * @dev Buy insurance for a flight
    */
    function getManifestId (bytes32 flightKey, address passenger) internal view returns(bytes32) {
        return keccak256(abi.encodePacked(flightKey, passenger));
    }

    function buyInsurance
                            (
                                bytes32 fltKey,
                                address _passenger,
                                uint256 insuranceAmount
                            )
                            external
                            payable
                            returns(bool)
    {
        bytes32 manifestId = getManifestId(fltKey, _passenger);
        require(manifestList[manifestId].isTaken == false, "This insurance is already taken.");
        manifestList[manifestId].insuranceAmount = insuranceAmount;
        manifestList[manifestId].passenger = _passenger;
        manifestList[manifestId].isTaken = true;
        passengerList[fltKey].push(_passenger);
        return(true);
    }

    function getInsurance(bytes32 key, address _passenger) public view returns(uint256, bool){
        bytes32 manId = getManifestId(key, _passenger);
        return (manifestList[manId].insuranceAmount, manifestList[manId].isTaken);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    bytes32 _fltKey,
                                    uint creditAmount
                                )
                                external
    {
        for (uint i = 0; i < passengerList[_fltKey].length; i++) {
            bytes32 manifestId = getManifestId(_fltKey, passengerList[_fltKey][i]);
            if (manifestList[manifestId].isTaken == true) {
                manifestList[manifestId].insuranceAmount = manifestList[manifestId].insuranceAmount.mul(creditAmount).div(100);
            }
        }
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function payInsurance
                            (
                                bytes32 fltKey,
                                address _passenger
                            )
                            external
                            payable
    {
        bytes32 manifestId = getManifestId(fltKey, _passenger);
        require(manifestList[manifestId].isTaken == true, "Insurance was not taken.");
        Insurance memory insurance = manifestList[manifestId];
        require(address(this).balance > insurance.insuranceAmount,"address(this).balance < insurance.insuranceAmount");
        uint amount = insurance.insuranceAmount;
        insurance.insuranceAmount = 0;//reset
        address passenger = insurance.passenger;
        passenger.transfer(amount);
    }

    function getInsuranceAmount
                            (
                                bytes32 fltKey,
                                address _passenger
                            )
                            external
                            returns(uint256)
    {
        bytes32 manifestId = getManifestId(fltKey, _passenger);
        Insurance memory insurance = manifestList[manifestId];
        return(insurance.insuranceAmount);
    }

    function processFlightStatus
                            (
                                bytes32 flightKey,
                                uint8 _statusCode
                            )
                                external
    {
        // Check (modifiers)
        Flight storage flight = flights[flightKey];
        // Effect
        flight.statusCode = _statusCode;
    }
}

