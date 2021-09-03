pragma solidity ^0.7.4;

// "SPDX-License-Identifier: MIT"

import "./DSMath.sol";
import "./SafeMath.sol";
import "./IERC20.sol";
import "./Ownable.sol";
import "./ISecondaryPool.sol";

contract PendingOrders is DSMath, Ownable {

	using SafeMath for uint256;

	struct Order {
		address orderer;	// address of user placing order
		uint amount;
		bool isWhite;		// TRUE for white side, FALSE for black side
		uint eventId;
		bool isPending;		// TRUE when placed, FALSE when canceled
	}

	// ordersCount count number of orders so far, and is id of very last order
	uint public ordersCount;

	// Max and min prices are defined manually as following since it's meaningless in this contract
	uint constant _maxPrice = 100 * WAD;
	uint constant _minPrice = 0;

	// indicates fee percentage of 0.01%, which can be changed by owner
	uint public _FEE = 1e14;

	uint _collectedFee;

	IERC20 public _collateralToken;
	ISecondaryPool public _secondaryPool;

	address public _feeWithdrawAddress;
	address public _eventContractAddress;
	address public _secondaryPoolAddress;

	// mapping from order ID to Order detail
	mapping(uint => Order) Orders;

	// mapping from user address to order IDs for that user
	mapping(address => uint[]) ordersOfUser;
	
	struct detail {
	    uint whiteAmount;		// total amount of collateral for white side of the event
	    uint blackAmount;		// total amount of collateral for black side of the event
	    uint whitePriceBefore;	// price of white token before the event
	    uint blackPriceBefore;	// price of black token before the event
	    uint whitePriceAfter;	// price of white token after the event
	    uint blackPriceAfter;	// price of black token after the event
	    bool isExecuted;		// TRUE before the event, FALSE after the event
	}
	
	// mapping from event ID to detail for that event
	mapping(uint => detail) detailForEvent;

	event orderCreated(uint);
	event orderCanceled(uint);
	event collateralWithdrew(uint);
	event contractOwnerChanged(address);
	event secondaryPoolAddressChanged(address);
	event eventContractAddressChanged(address);
	event feeWithdrawAddressChanged(address);
	event feeWithdrew(uint);
	event feeChanged(uint);

	constructor (
		address secondaryPoolAddress,
		address collateralTokenAddress,
		address feeWithdrawAddress,
		address eventContractAddress
	) {
		require(
			secondaryPoolAddress != address(0),
			"SECONDARY POOL ADDRESS SHOULD NOT BE NULL"
		);
		require(
			collateralTokenAddress != address(0),
			"COLLATERAL TOKEN ADDRESS SHOULD NOT BE NULL"
		);
		require(
			feeWithdrawAddress != address(0),
			"FEE WITHDRAW ADDRESS SHOULD NOT BE NULL"
		);
		require(
			eventContractAddress != address(0),
			"EVENT ADDRESS SHOULD NOT BE NULL"
		);
		_secondaryPoolAddress = secondaryPoolAddress;
		_secondaryPool = ISecondaryPool(_secondaryPoolAddress);
		_collateralToken = IERC20(collateralTokenAddress);
		_feeWithdrawAddress = feeWithdrawAddress;
		_eventContractAddress = eventContractAddress;
	}

	// Modifier to ensure call has been made by event contract
	modifier onlyEventContract {
        require(
            msg.sender == _eventContractAddress,
            "CALLER SHOULD BE EVENT CONTRACT"
        );
        _;
    }

    function createOrder(uint _amount, bool _isWhite, uint _eventId) external returns(uint) {
    	require(
			_collateralToken.balanceOf(msg.sender) >= _amount,
			"NOT ENOUGH COLLATERAL IN USER'S ACCOUNT"
		);

		// orderId starts with 1
		ordersCount++;
		Orders[ordersCount] = Order(
			msg.sender,
			_amount,
			_isWhite,
			_eventId,
			true
		);
		_isWhite
			? detailForEvent[_eventId].whiteAmount = detailForEvent[_eventId].whiteAmount.add(_amount)
			: detailForEvent[_eventId].blackAmount = detailForEvent[_eventId].blackAmount.add(_amount);
			
		ordersOfUser[msg.sender].push(ordersCount);

		_collateralToken.transferFrom(msg.sender, address(this), _amount);
		emit orderCreated(ordersCount);
		return ordersCount;
    }

    function cancelOrder(uint _orderId) external {
        Order memory _Order = Orders[_orderId];
    	require(
    		_Order.isPending,
			"ORDER HAS ALREADY BEEN CANCELED"
		);
		require(
		    !detailForEvent[_Order.eventId].isExecuted,
		    "ORDER HAS ALREADY BEEN EXECUTED"
		);
		require(
			msg.sender == _Order.orderer,
			"NOT ALLOWED TO CANCEL THE ORDER"
		);
		_collateralToken.transfer(
			_Order.orderer,
			_Order.amount
		);
		_Order.isWhite
			? detailForEvent[_Order.eventId].whiteAmount = detailForEvent[_Order.eventId].whiteAmount.sub(_Order.amount)
			: detailForEvent[_Order.eventId].blackAmount = detailForEvent[_Order.eventId].blackAmount.sub(_Order.amount);
		Orders[_orderId].isPending = false;
		emit orderCanceled(_orderId);
    }

    function eventStart(uint _eventId) external onlyEventContract {
    	_secondaryPool.buyWhite(_maxPrice, detailForEvent[_eventId].whiteAmount);
    	_secondaryPool.buyBlack(_maxPrice, detailForEvent[_eventId].blackAmount);
    	detailForEvent[_eventId].whitePriceBefore = _secondaryPool._whitePrice();
    	detailForEvent[_eventId].blackPriceBefore = _secondaryPool._blackPrice();
    }

    function eventEnd(uint _eventId) external onlyEventContract {
    	_secondaryPool.sellWhite(_minPrice, detailForEvent[_eventId].whiteAmount);
    	_secondaryPool.sellBlack(_minPrice, detailForEvent[_eventId].blackAmount);
    	detailForEvent[_eventId].whitePriceAfter = _secondaryPool._whitePrice();
    	detailForEvent[_eventId].blackPriceAfter = _secondaryPool._blackPrice();
    	detailForEvent[_eventId].isExecuted = true;
    }

    function withdrawCollateral() external returns(uint) {
    	
    	// total amount of collateral token that should be returned to user
    	// feeAmount should be subtracted before actual return
        uint totalWithdrawAmount;

        uint[] memory _orders = ordersOfUser[msg.sender];
        for (uint i = 0; i < _orders.length; i++) {
            uint _oId = _orders[i]; // order ID
            uint _eId = Orders[_oId].eventId; // event ID

            // calculate and sum up collaterals to be returned
            // exclude canceled orders, only include executed orders
            if (Orders[_oId].isPending && detailForEvent[_eId].isExecuted) {
                uint withdrawAmount = Orders[_oId].isWhite
                	? calculateNewAmount(
                		Orders[_oId].amount,
                		detailForEvent[_eId].whitePriceBefore,
                		detailForEvent[_eId].whitePriceAfter)
                	: calculateNewAmount(
                		Orders[_oId].amount,
                		detailForEvent[_eId].blackPriceBefore,
                		detailForEvent[_eId].blackPriceAfter);
                totalWithdrawAmount = totalWithdrawAmount.add(withdrawAmount);
            }

            // pop IDs of canceled or executed orders from ordersOfUser array
            if (!Orders[_oId].isPending || detailForEvent[_eId].isExecuted) {
                delete ordersOfUser[msg.sender][i];
                ordersOfUser[msg.sender][i] = ordersOfUser[msg.sender][ordersOfUser[msg.sender].length - 1];
                ordersOfUser[msg.sender].pop();
            }
        }
        
        uint feeAmount = wmul(totalWithdrawAmount, _FEE);
        uint userWithdrawAmount = totalWithdrawAmount.sub(feeAmount);
        
        _collectedFee = _collectedFee.add(feeAmount);

        _collateralToken.transfer(msg.sender, userWithdrawAmount);
        emit collateralWithdrew(userWithdrawAmount);
        
        return totalWithdrawAmount;
    }

    function calculateNewAmount(
    	uint originAmount,
    	uint priceBefore,
    	uint priceAfter
    ) internal pure returns(uint newAmount) {
    	newAmount = wmul(wdiv(originAmount, priceBefore), priceAfter);
    }

    function changeContractOwner(address _newOwnerAddress) external onlyOwner {
		require(
			_newOwnerAddress != address(0),
			"NEW OWNER ADDRESS SHOULD NOT BE NULL"
		);
		transferOwnership(_newOwnerAddress);
		emit contractOwnerChanged(_newOwnerAddress);
	}

	function changeSecondaryPoolAddress(address _newPoolAddress) external onlyOwner {
		require(
			_newPoolAddress != address(0),
			"NEW SECONDARYPOOL ADDRESS SHOULD NOT BE NULL"
		);
		_secondaryPoolAddress = _newPoolAddress;
		emit secondaryPoolAddressChanged(_secondaryPoolAddress);
	}

	function changeEventContractAddress(address _newEventAddress) external onlyOwner {
		require(
			_newEventAddress != address(0),
			"NEW EVENT ADDRESS SHOULD NOT BE NULL"
		);
		_eventContractAddress = _newEventAddress;
		emit eventContractAddressChanged(_eventContractAddress);
	}

	function changeFeeWithdrawAddress(address _newFeeWithdrawAddress) external onlyOwner {
		require(
			_newFeeWithdrawAddress != address(0),
			"NEW WITHDRAW ADDRESS SHOULD NOT BE NULL"
		);
		_feeWithdrawAddress = _newFeeWithdrawAddress;
		emit feeWithdrawAddressChanged(_feeWithdrawAddress);
	}

	function withdrawFee() external onlyOwner {
	    require(
	        _collateralToken.balanceOf(address(this)) >= _collectedFee,
	        "INSUFFICIENT TOKEN(THAT IS LOWER THAN EXPECTED COLLECTEDFEE) IN PENDINGORDERS CONTRACT"
	    );
		_collateralToken.transfer(_feeWithdrawAddress, _collectedFee);
		_collectedFee = 0;
		emit feeWithdrew(_collectedFee);
	}

	function changeFee(uint _newFEE) external onlyOwner {
		_FEE = _newFEE;
		emit feeChanged(_FEE);
	}

}