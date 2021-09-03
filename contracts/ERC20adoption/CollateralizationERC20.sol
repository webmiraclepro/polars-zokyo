pragma solidity ^0.7.4;
// "SPDX-License-Identifier: Apache License 2.0"

import "./IERC20.sol";
import "./ICollateralizationERC20.sol";

contract Collateralization is ICollateralization {
    address public _poolAddress;
    address public _governanceAddress;
    address public _whiteTokenAddress;
    address public _blackTokenAddress;
    address public _collateralTokenAddress;
    
    event PoolAddressChanged(address previousAddress,address poolAddress);
    event GovernanceAddressChanged(address previousAddress, address governanceAddress);

    constructor (
        address poolAddress,
        address governanceAddress,
        address whiteTokenAddress,
        address blackTokenAddress,
        address collateralTokenAddress
    ) {
        require (whiteTokenAddress != address(0), "WHITE TOKEN ADDRESS SHOULD NOT BE NULL");
        require (blackTokenAddress != address(0), "BLACK TOKEN ADDRESS SHOULD NOT BE NULL");
        require (collateralTokenAddress != address(0), "COLLATERAL TOKEN ADDRESS SHOULD NOT BE NULL");

        _poolAddress = poolAddress == address(0) ? msg.sender : poolAddress;
        _governanceAddress  = governanceAddress  == address(0) ? msg.sender : governanceAddress;

        _whiteTokenAddress = whiteTokenAddress;
        _blackTokenAddress = blackTokenAddress;
        _collateralTokenAddress = collateralTokenAddress;
    }

    modifier onlyPool () {
        require (_poolAddress == msg.sender, "CALLER SHOULD BE THE POOL");
        _;
    }

    modifier onlyGovernance () {
        require (_governanceAddress == msg.sender, "CALLER SHOULD BE GOVERNANCE");
        _;
    }

    function buy (
        address destination,
        uint256 tokensAmount,
        uint256 payment) 
        public override onlyPool {
        require (destination != address(0), 
        "DESTINATION ADDRESS SHOULD NOT BE NULL");
        IERC20 whiteToken = IERC20(_whiteTokenAddress);
        IERC20 blackToken = IERC20(_blackTokenAddress);
        IERC20 collateralToken = IERC20(_collateralTokenAddress);
        require (whiteToken.balanceOf(address(this)) >= tokensAmount, 
        "NOT ENOUGH WHITE TOKENS ON COLLATERALIZATION CONTRACT BALANCE");
        require (blackToken.balanceOf(address(this)) >= tokensAmount, 
        "NOT ENOUGH BLACK TOKENS ON COLLATERALIZATION CONTRACT BALANCE");
        require (collateralToken.allowance(destination, address(this)) >= payment, 
        "NOT ENOUGH DELEGATED TOKENS");

        collateralToken.transferFrom(destination, address(this), payment);
        whiteToken.transfer(destination, tokensAmount);
        blackToken.transfer(destination, tokensAmount);
    }

    function buySeparately(
        address destination, 
        uint256 tokensAmount, 
        bool isWhite,
        uint256 payment) 
        public override onlyPool {
        require (destination != address(0), "DESTINATION ADDRESS SHOULD NOT BE NULL");
        IERC20 whiteToken = IERC20(_whiteTokenAddress);
        IERC20 blackToken = IERC20(_blackTokenAddress);
        IERC20 collateralToken = IERC20(_collateralTokenAddress);
        require (collateralToken.allowance(destination, address(this)) >= payment, 
        "NOT ENOUGH DELEGATED TOKENS");
        collateralToken.transferFrom(destination, address(this), payment);

        if (isWhite) {
            require (whiteToken.balanceOf(address(this)) >= tokensAmount, 
            "NOT ENOUGH WHITE TOKENS ON COLLATERALIZATION CONTRACT BALANCE");
            whiteToken.transfer(destination, tokensAmount);
        }
        else {
            require (blackToken.balanceOf(address(this)) >= tokensAmount, 
            "NOT ENOUGH BLACK TOKENS ON COLLATERALIZATION CONTRACT BALANCE");
            blackToken.transfer(destination, tokensAmount);
        }
    }

    function buyBack (
        address destination, 
        uint256 tokensAmount, 
        uint256 payment) 
        public override onlyPool {
        require (destination != address(0), "DESTINATION ADDRESS SHOULD NOT BE NULL");
        IERC20 whiteToken = IERC20(_whiteTokenAddress);
        IERC20 blackToken = IERC20(_blackTokenAddress);
        IERC20 collateralToken = IERC20(_collateralTokenAddress);
        require (collateralToken.balanceOf(address(this)) >= payment, 
        "NOT ENOUGH COLLATERALIZATION IN THe CONTRACT");
        require (whiteToken.allowance(destination, address(this)) >= tokensAmount, 
        "NOT ENOUGH DELEGATED WHITE TOKENS ON DESTINATION BALANCE");
        require (blackToken.allowance(destination, address(this)) >= tokensAmount, 
        "NOT ENOUGH DELEGATED BLACK TOKENS ON DESTINATION BALANCE");

        whiteToken.transferFrom(destination, address(this), tokensAmount);
        blackToken.transferFrom(destination, address(this), tokensAmount);

        collateralToken.transfer(destination, payment);
    }

    function buyBackSeparately(
        address destination, 
        uint256 tokensAmount, 
        bool isWhite, 
        uint256 payment) 
        public override onlyPool {
        require (destination != address(0), "DESTINATION ADDRESS SHOULD NOT BE NULL");
        IERC20 whiteToken = IERC20(_whiteTokenAddress);
        IERC20 blackToken = IERC20(_blackTokenAddress);
        IERC20 collateralToken = IERC20(_collateralTokenAddress);
        require (collateralToken.balanceOf(address(this)) >= payment, "NOT ENOUGH COLLATERALIZATION ON THE CONTRACT");

        if(tokensAmount > 0) {
            if (isWhite) {
                require (whiteToken.allowance(destination, address(this)) >= tokensAmount, 
                "NOT ENOUGH DELEGATED WHITE TOKENS ON DESTINATION BALANCE");
                whiteToken.transferFrom(destination, address(this), tokensAmount);
            } else {
                require (blackToken.allowance(destination, address(this)) >= tokensAmount, 
                "NOT ENOUGH DELEGATED BLACK TOKENS ON DESTINATION BALANCE");
                blackToken.transferFrom(destination, address(this), tokensAmount);
            }
        }
        collateralToken.transfer(destination, payment);
    }

    /*
    Function changes the pool address
    */
    function changePoolAddress (address poolAddress) public override onlyGovernance {
        require (poolAddress != address(0), "NEW POOL ADDRESS SHOULD NOT BE NULL");
        
        address previousAddress = _poolAddress;
        _poolAddress = poolAddress;

        emit PoolAddressChanged(previousAddress, poolAddress);
    }

    function changeGovernanceAddress(address governanceAddress) 
    public 
    override 
    onlyGovernance {
        require (governanceAddress != address(0), "NEW GOVERNANCE ADDRESS SHOULD NOT BE NULL");

        address previousAddress = _governanceAddress;
        _governanceAddress = governanceAddress;

        emit GovernanceAddressChanged(previousAddress, governanceAddress);
    }

    function getCollateralization() public override view returns (uint256) {
        return IERC20(_collateralTokenAddress).balanceOf(address(this));
    }

    function getStoredTokensAmount()
    override external view returns (uint256 white, uint256 black) {
        return (IERC20(_whiteTokenAddress).balanceOf(address(this)), IERC20(_blackTokenAddress).balanceOf(address(this)));
    }
}