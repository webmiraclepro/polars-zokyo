pragma solidity ^0.7.4;
// "SPDX-License-Identifier: MIT"

import "./Eventable.sol";
import "./IPendingOrders.sol";

contract EventLifeCycle {
    
    address public _governanceAddress;
    address public _secondaryPoolAddress;
    address public _oracleAddress;
    address public _pendingOrdersAddress;
    GameEvent public _queuedEvent;
    GameEvent public _ongoingEvent;
    bool eventIsInProgress = false;
    
    event GovernanceAddressChanged(address);
    event OracleAddressChanged(address);
    event SecondaryPoolAddressChanged(address);
    event PendingOrdersAddressChanged(address);
    event GameEventStarted(uint time, uint eventId);
    event GameEventEnded(int8 result, uint eventId);
    event NewGameEventAdded(uint8 priceChangePercent, uint eventStartTimeExpected, uint eventEndTimeExpected,
        string blackTeam, string whiteTeam, string eventType, string eventSeries, string eventName, uint eventid);
        
    ISecondaryPool _secondaryPool;
    IPendingOrders _pendingOrders;
    
    constructor(
        address governanceAddress,
        address oracleAddress,
        address secondarypoolAddress,
        address pendingOrdersAddress
    ) {
        _governanceAddress = governanceAddress;
        _oracleAddress = oracleAddress;
        _secondaryPoolAddress = secondarypoolAddress;
        _secondaryPool = ISecondaryPool(_secondaryPoolAddress);
        _pendingOrdersAddress = pendingOrdersAddress;
        _pendingOrders = IPendingOrders(_pendingOrdersAddress);
    }
        
    modifier onlyGovernance () {
        require (_governanceAddress == msg.sender, "Caller should be Governance");
        _;
    }
    
    modifier onlyOracle () {
        require (_oracleAddress == msg.sender, "Caller should be Oracle");
        _;
    }
    
    struct GameEvent {
        uint8 priceChangePart;       // in 0.0001 parts percent of a percent dose
        uint eventStartTimeExpected; // in seconds since 1970
        uint eventEndTimeExpected;   // in seconds since 1970
        string blackTeam;
        string whiteTeam;
        string eventType;
        string eventSeries;
        string eventName;
        uint eventId;
    }
    
    function addNewEvent(
        uint8 priceChangePart_, // in 0.0001 parts percent of a percent dose
        uint eventStartTimeExpected_,
        uint eventEndTimeExpected_,
        string calldata blackTeam_,
        string calldata whiteTeam_,
        string calldata eventType_,
        string calldata eventSeries_,
        string calldata eventName_,
        uint eventId_
    ) external onlyGovernance returns (uint) {
            
        _queuedEvent.priceChangePart = priceChangePart_;
        _queuedEvent.eventStartTimeExpected = eventStartTimeExpected_;
        _queuedEvent.eventEndTimeExpected = eventEndTimeExpected_;
        _queuedEvent.blackTeam = blackTeam_;
        _queuedEvent.whiteTeam = whiteTeam_;
        _queuedEvent.eventType = eventType_;
        _queuedEvent.eventSeries = eventSeries_;
        _queuedEvent.eventName = eventName_;
        _queuedEvent.eventId = eventId_;
        
        emit NewGameEventAdded(
            _queuedEvent.priceChangePart, 
            _queuedEvent.eventStartTimeExpected, 
            _queuedEvent.eventEndTimeExpected,
            _queuedEvent.blackTeam, 
            _queuedEvent.whiteTeam, 
            _queuedEvent.eventType, 
            _queuedEvent.eventSeries, 
            _queuedEvent.eventName, 
            _queuedEvent.eventId
        );
        
        return eventId_;
    }
        
    function startEvent() external onlyOracle {
        require(
            eventIsInProgress == false,
            "FINISH PREVIOUS EVENT TO START NEW EVENT"
        );
        _ongoingEvent = _queuedEvent;
        _pendingOrders.eventStart(_ongoingEvent.eventId);
        _secondaryPool.submitEventStarted(_ongoingEvent.priceChangePart);
        eventIsInProgress = true;
        emit GameEventStarted(block.timestamp, _ongoingEvent.eventId);
    }
    
    function addAndStartEvent(
        uint8 priceChangePart_, // in 0.0001 parts percent of a percent dose
        uint eventStartTimeExpected_,
        uint eventEndTimeExpected_,
        string calldata blackTeam_,
        string calldata whiteTeam_,
        string calldata eventType_,
        string calldata eventSeries_,
        string calldata eventName_,
        uint eventId_
    ) external onlyOracle returns(uint) {        
        require(
            eventIsInProgress == false,
            "FINISH PREVIOUS EVENT TO START NEW EVENT"
        );
        _queuedEvent.priceChangePart = priceChangePart_;
        _queuedEvent.eventStartTimeExpected = eventStartTimeExpected_;
        _queuedEvent.eventEndTimeExpected = eventEndTimeExpected_;
        _queuedEvent.blackTeam = blackTeam_;
        _queuedEvent.whiteTeam = whiteTeam_;
        _queuedEvent.eventType = eventType_;
        _queuedEvent.eventSeries = eventSeries_;
        _queuedEvent.eventName = eventName_;
        _queuedEvent.eventId = eventId_;
        
        emit NewGameEventAdded(
            _queuedEvent.priceChangePart, 
            _queuedEvent.eventStartTimeExpected, 
            _queuedEvent.eventEndTimeExpected,
            _queuedEvent.blackTeam, 
            _queuedEvent.whiteTeam, 
            _queuedEvent.eventType, 
            _queuedEvent.eventSeries, 
            _queuedEvent.eventName, 
            _queuedEvent.eventId
        );
        
        _ongoingEvent = _queuedEvent;
        _pendingOrders.eventStart(_ongoingEvent.eventId);
        _secondaryPool.submitEventStarted(_ongoingEvent.priceChangePart);
        eventIsInProgress = true;
        emit GameEventStarted(block.timestamp, _ongoingEvent.eventId);
        
        return eventId_;
    }
    
    /**
     * Receive event results. Receives result of an event in value between -1 and 1. -1 means 
     * Black won,1 means white-won, 0 means draw. 
     */
    function endEvent(int8 _result) external onlyOracle {
        require(
            eventIsInProgress == true,
            "THERE IS NO ONGOING EVENT TO FINISH"
        );
        _secondaryPool.submitEventResult(_result);
        _pendingOrders.eventEnd(_ongoingEvent.eventId);
        emit GameEventEnded(_result, _ongoingEvent.eventId);
        eventIsInProgress = false;
    }
    
    function changeGovernanceAddress(address governanceAddress) public onlyGovernance {
        require (
            governanceAddress != address(0),
            "NEW GOVERNANCE ADDRESS SHOULD NOT BE NULL"
        );
        _governanceAddress = governanceAddress;
        emit GovernanceAddressChanged(governanceAddress);
    }
    
    function changeOracleAddress(address oracleAddress) public onlyGovernance {
        require (
            oracleAddress != address(0),
            "NEW ORACLE ADDRESS SHOULD NOT BE NULL"
        );
        _oracleAddress = oracleAddress;
        emit OracleAddressChanged(oracleAddress);
    }
    
    function changeSecondaryPoolAddress(address poolAddress) public onlyGovernance {
        require (
            poolAddress != address(0),
            "NEW SECONDARYPOOLADDRESS SHOULD NOT BE NULL"
        );
        _secondaryPoolAddress = poolAddress;
        emit SecondaryPoolAddressChanged(poolAddress);
    }
    
    function changePendingOrdersAddress(address pendingOrdersAddress) public onlyGovernance {
        require (
            pendingOrdersAddress != address(0),
            "NEW PENDINGORDERS ADDRESS SHOULD NOT BE NULL"
        );
        _pendingOrdersAddress = pendingOrdersAddress;
        emit PendingOrdersAddressChanged(pendingOrdersAddress);
    }
        
}