pragma solidity ^0.7.4;
// "SPDX-License-Identifier: MIT"

interface ICollateralization {
    function buy                     (address destination, uint256 tokensAmount, uint256 payment) external; 
    function buySeparately           (address destination, uint256 tokensAmount, bool isWhite, uint256 payment) external;    
    function buyBack                 (address destination, uint256 tokensAmount, uint256 payment) external;     
    function buyBackSeparately       (address destination, uint256 tokensAmount, bool isWhite, uint256 payment) external;   
    function changePoolAddress       (address poolAddress) external;      
    function changeGovernanceAddress (address governanceAddress) external;      
    function getCollateralization    () external view returns (uint256);
    function getStoredTokensAmount   () external view returns (uint256 white, uint256 black);
}