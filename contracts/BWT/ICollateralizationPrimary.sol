pragma solidity ^0.7.4;
// "SPDX-License-Identifier: MIT"

interface ICollateralizationPrimary {
    function buy                     (address destination, uint256 tokensAmount, uint256 payment) external; 
    function buyBack                 (address destination, uint256 tokensAmount, uint256 payment) external;     
    function changePoolAddress       (address poolAddress) external;      
    function changeGovernanceAddress (address governanceAddress) external;      
    function getCollateralization    () external view returns (uint256);
    function getBwtSupply() external view returns (uint256); 
    function changeBwtOwner(address newOwner) external;
}