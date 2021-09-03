pragma solidity ^0.7.4;
// "SPDX-License-Identifier: MIT"

interface ISecondaryCollateralization {
    function buySeparately           (address destination, uint256 tokensAmount, bool isWhite, uint256 payment) external;    
    function buyBackSeparately       (address destination, uint256 tokensAmount, bool isWhite, uint256 payment) external;   
    function withdraw                (address destination, uint256 tokensAmount) external; 
    function withdrawCollateral      (address destination, uint256 tokensAmount) external;
    function addLiquidity            (address destination, uint256 tokensAmount) external;
    function changePoolAddress       (address poolAddress) external;      
    function changeGovernanceAddress (address governanceAddress) external;      
    function getCollateralization    () external view returns (uint256);
    function getStoredTokensAmount   () external view returns (uint256 white, uint256 black, uint256 bwt);
    function delegate                (address newCollateralization) external;
}