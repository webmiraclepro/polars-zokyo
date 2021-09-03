pragma solidity ^0.7.4;
// "SPDX-License-Identifier: Apache License 2.0"

import "IERC20.sol";
import "ICollateralization.sol";

contract Collateralization is ICollateralization {
    address public _poolAddress;
    address public _governanceAddress;
    address public _whiteTokenAddress;
    address public _blackTokenAddress;

    IERC20  _whiteToken;
    IERC20  _blackToken;
    
    event PoolAddressChanged(address previousAddress,address poolAddress);
    event GovernanceAddressChanged(address previousAddress, address governanceAddress);

    constructor (
        address poolAddress,
        address governanceAddress,
        address whiteTokenAddress,
        address blackTokenAddress
    ) {
        require (whiteTokenAddress != address(0), "WHITE TOKEN ADDRESS SHOULD BE NOT NULL");
        require (blackTokenAddress != address(0), "BLACK TOKEN ADDRESS SHOULD BE NOT NULL");

        _poolAddress = poolAddress == address(0) ? msg.sender : poolAddress;
        _governanceAddress  = governanceAddress  == address(0) ? msg.sender : governanceAddress;

        _whiteTokenAddress = whiteTokenAddress;
        _blackTokenAddress = blackTokenAddress;
        _whiteToken        = IERC20(whiteTokenAddress);
        _blackToken        = IERC20(blackTokenAddress);
    }

    modifier onlyPool () {
        require (_poolAddress == msg.sender, "CALLER SHOULD BE THE POOL");
        _;
    }

    modifier onlyGovernance () {
        require (_governanceAddress == msg.sender, "CALLER SHOULD BE GOVERNANCE");
        _;
    }
    
    fallback() external payable {}

    function buy (
        address destination, 
        uint256 tokensAmount) 
        public 
        override 
        onlyPool 
        payable {
        require (destination != address(0), "DESTINATION ADDRESS SHOULD BE NOT NULL");
        require (_whiteToken.balanceOf(address(this)) >= tokensAmount, "NOT ENOUGH WHITE TOKENS ON COLLATERALIZATION CONTRACT BALANCE");
        require (_blackToken.balanceOf(address(this)) >= tokensAmount, "NOT ENOUGH BLACK TOKENS ON COLLATERALIZATION CONTRACT BALANCE");

        _whiteToken.transfer(destination, tokensAmount);
        _blackToken.transfer(destination, tokensAmount);
    }

    function buySeparately(
        address destination, 
        uint256 tokensAmount, 
        bool isWhite) 
        public 
        override 
        onlyPool 
        payable {
        require (destination != address(0), "DESTINATION ADDRESS SHOULD BE NOT NULL");

        if (isWhite) {
            require (_whiteToken.balanceOf(address(this)) >= tokensAmount, "NOT ENOUGH WHITE TOKENS ON COLLATERALIZATION CONTRACT BALANCE");
            _whiteToken.transfer(destination, tokensAmount);
        }
        else {
            require (_blackToken.balanceOf(address(this)) >= tokensAmount, "NOT ENOUGH BLACK TOKENS ON COLLATERALIZATION CONTRACT BALANCE");
            _blackToken.transfer(destination, tokensAmount);
        }
    }

    function buyBack (
        address payable destination, 
        uint256 tokensAmount, 
        uint256 ethAmount) 
        public 
        override 
        onlyPool{
        require (destination != address(0), "DESTINATION ADDRESS SHOULD BE NOT NULL");
        require (address(this).balance >= ethAmount, "NOT ENOUGH ETH ON COLLATERALIZATION CONTRACT BALANCE");
        require (_whiteToken.allowance(destination, address(this)) >= tokensAmount, "NOT ENOUGH DELEGATED WHITE TOKENS ON DESTINATION BALANCE");
        require (_blackToken.allowance(destination, address(this)) >= tokensAmount, "NOT ENOUGH DELEGATED BLACK TOKENS ON DESTINATION BALANCE");

        _whiteToken.transferFrom(destination, address(this), tokensAmount);
        _blackToken.transferFrom(destination, address(this), tokensAmount);

        destination.transfer(ethAmount);
    }

    function buyBackSeparately(
        address payable destination, 
        uint256 tokensAmount, 
        bool isWhite, 
        uint256 ethAmount) 
        public 
        override 
        onlyPool {
        require (destination != address(0), "DESTINATION ADDRESS SHOULD BE NOT NULL");
        require (address(this).balance >= ethAmount, "NOT ENOUGH ETH ON COLLATERALIZATION CONTRACT BALANCE");

        if(tokensAmount > 0) {
            if (isWhite) {
                require (_whiteToken.allowance(destination, address(this)) >= tokensAmount, "NOT ENOUGH DELEGATED WHITE TOKENS ON DESTINATION BALANCE");
                _whiteToken.transferFrom(destination, address(this), tokensAmount);
            } else {
                require (_blackToken.allowance(destination, address(this)) >= tokensAmount, "NOT ENOUGH DELEGATED BLACK TOKENS ON DESTINATION BALANCE");
                _blackToken.transferFrom(destination, address(this), tokensAmount);
            }
        }

        destination.transfer(ethAmount);
    }

    /*
    Function changes the pool address
    */
    function changePoolAddress (address poolAddress) public override onlyGovernance {
        require (poolAddress != address(0), "NEW POOL ADDRESS SHOULD BE NOT NULL");
        
        address previousAddress = _poolAddress;
        _poolAddress = poolAddress;

        emit PoolAddressChanged(previousAddress, poolAddress);
    }

    function changeGovernanceAddress(address governanceAddress) 
    public 
    override 
    onlyGovernance {
        require (governanceAddress != address(0), "NEW GOVERNANCE ADDRESS SHOULD BE NOT NULL");

        address previousAddress = _governanceAddress;
        _governanceAddress = governanceAddress;

        emit GovernanceAddressChanged(previousAddress, governanceAddress);
    }

    function getStoredEthereumAmount() public override view returns (uint256) {
        return address(this).balance;
    }

    function getStoredTokensAmount()
    override
    external 
    view 
    returns (uint256 white, uint256 black) {
        uint256 whiteTokensAmount = _whiteToken.balanceOf(address(this));
        uint256 blackTokensAmount = _blackToken.balanceOf(address(this));

        return (whiteTokensAmount, blackTokensAmount);
    }
}