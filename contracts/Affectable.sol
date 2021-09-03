pragma solidity ^0.7.4;
// "SPDX-License-Identifier: MIT"

interface Affectable {
    
    function submitEventStarted(uint8 currentEventPriceChangePercent) external; 
    function submitEventResult(int8 _result) external;
    
}