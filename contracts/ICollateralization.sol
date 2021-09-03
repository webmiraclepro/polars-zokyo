pragma solidity ^0.7.4;
// "SPDX-License-Identifier: MIT"

interface ICollateralization {
    function buy                     (address destination, uint256 tokensAmount)                                  payable external; 
    function buySeparately           (address destination, uint256 tokensAmount, bool isWhite)                    payable external;    
    function buyBack                 (address payable destination, uint256 tokensAmount, uint256 ethAmount)               external;     
    function buyBackSeparately       (address payable destination, uint256 tokensAmount, bool isWhite, uint256 ethAmount) external;   
    function changePoolAddress       (address poolAddress)                                                        external;      
    function changeGovernanceAddress (address governanceAddress)                                                  external;      
    function getStoredEthereumAmount ()                                                                           external view returns (uint256);
    function getStoredTokensAmount   ()                                                                           external view returns (uint256 white, uint256 black);
}