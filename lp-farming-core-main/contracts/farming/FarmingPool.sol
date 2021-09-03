pragma solidity ^0.7.4;
// "SPDX-License-Identifier: Apache License 2.0"

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interfaces/IReservoir.sol";

/**
 *  Based on Sushi MasterChef:
 *  https://github.com/sushiswap/sushiswap/blob/1e4db47fa313f84cd242e17a4972ec1e9755609a/contracts/MasterChef.sol
 */
contract FarmingPool {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of tokens
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accTokensPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accTokensPerShare` (and `lastReward`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;            // Address of LP token contract.
        uint256 allocPoint;        // How many allocation points assigned to this pool. Tokens to distribute per second.
        uint256 lastReward;        // Last timestamp that tokens distribution occurs.
        uint256 accTokensPerShare; // Accumulated tokens per share, times MULTIPLIER. See below.
    }

    // 10**18 multiplier.
    uint256 private constant MULTIPLIER = 1e18;

    // Max pools total supply: 1,000,000,000.
    uint256 private constant MAX_POOLS_SUPPLY = 1e9 * MULTIPLIER;

    // The REWARD TOKEN
    IERC20 public token;
    // tokens created per second.
    uint256 public tokensPerSecond;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;
    // The timestamp when token mining starts.
    uint256 public start;

    // Token reservoir
    IReservoir public tokenReservoir;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        IERC20 _token,
        uint256 _tokensPerSecond,
        uint256 _start,
        uint256[2] memory _allocPoints,
        IERC20[2] memory _lpTokens
    ) {
        token = _token;
        tokensPerSecond = _tokensPerSecond;
        start = _start;

        // add pools
        _addPool(_allocPoints[0], _lpTokens[0]);
        _addPool(_allocPoints[1], _lpTokens[1]);
    }

    // Initialize tokenReservoir after creation (only once)
    function initializeTokenReservoir(IReservoir _tokenReservoir) external {
        require(tokenReservoir == IReservoir(0), "TokenReservoir has already been initialized");
        tokenReservoir = _tokenReservoir;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Return reward multiplier over the given _from to _to timestamp.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        // safe gas costs: always 2 pools
        uint256 totalPoolsBalance;
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            totalPoolsBalance = totalPoolsBalance.add(poolInfo[pid].lpToken.balanceOf(address(this)));
        }

        totalPoolsBalance = (totalPoolsBalance > MAX_POOLS_SUPPLY) ? MAX_POOLS_SUPPLY : totalPoolsBalance;
        return _getWeeklyMultiplier(_from, _to).mul(totalPoolsBalance).div(MAX_POOLS_SUPPLY);
    }

    // View function to see pending tokens on frontend.
    function pendingTokens(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accTokensPerShare = pool.accTokensPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.timestamp > pool.lastReward && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastReward, block.timestamp);
            uint256 tokenReward = multiplier.mul(tokensPerSecond).mul(pool.allocPoint).div(totalAllocPoint).div(MULTIPLIER);
            tokenReward = _availableTokens(tokenReward); // amount available for transfer
            accTokensPerShare = accTokensPerShare.add(tokenReward.mul(MULTIPLIER).div(lpSupply));
        }
        return user.amount.mul(accTokensPerShare).div(MULTIPLIER).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Safe gas costs: always 2 pools.
    function updatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            _updatePool(pid);
        }
    }

    // Deposit LP tokens to FarmingPool for token allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePools(); // safe gas costs: always 2 pools
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accTokensPerShare).div(MULTIPLIER).sub(user.rewardDebt);
            if(pending > 0) {
                _safeTokenTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accTokensPerShare).div(MULTIPLIER);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from FarmingPool.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePools(); // safe gas costs: always 2 pools
        uint256 pending = user.amount.mul(pool.accTokensPerShare).div(MULTIPLIER).sub(user.rewardDebt);
        if(pending > 0) {
            _safeTokenTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accTokensPerShare).div(MULTIPLIER);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Return reward multiplier over the given _from to _to timestamp. Only weekly decrease.
    function _getWeeklyMultiplier(uint256 _from, uint256 _to) internal view returns (uint256) {
        if (_from >= _to) {
            return 0;
        }

        // coef decreases linearly over the first 11 weeks
        uint256 coef = _to.sub(start).div(7 days);
        coef = (coef < 11) ? coef : 11;
        uint256 curPeriodStart = start.add(coef.mul(7 days));
        uint256 curFrom = (_from < curPeriodStart) ? curPeriodStart : _from;

        // safe sub (coef <= 11) and recursion (iterations are limited)
        return _to.sub(curFrom).mul(12 - coef).mul(MULTIPLIER).add(_getWeeklyMultiplier(_from, curPeriodStart.sub(1)));
    }

    // Return available tokens on token reservoir.
    function _availableTokens(uint256 requestedTokens) internal view returns (uint256) {
        uint256 reservoirBalance = token.balanceOf(address(tokenReservoir));
        uint256 tokensAvailable = (requestedTokens > reservoirBalance)
            ? reservoirBalance
            : requestedTokens;

        return tokensAvailable;
    }

    // Add a new lp to the pool.
    function _addPool(uint256 _allocPoint, IERC20 _lpToken) internal {
        uint256 lastReward = block.timestamp > start ? block.timestamp : start;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastReward: lastReward,
            accTokensPerShare: 0
        }));
    }

    // Update reward variables of the given pool to be up-to-date.
    function _updatePool(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastReward) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastReward = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastReward, block.timestamp);
        uint256 tokenReward = multiplier.mul(tokensPerSecond).mul(pool.allocPoint).div(totalAllocPoint).div(MULTIPLIER);
        tokenReward = tokenReservoir.drip(tokenReward); // transfer tokens from tokenReservoir
        pool.accTokensPerShare = pool.accTokensPerShare.add(tokenReward.mul(MULTIPLIER).div(lpSupply));
        pool.lastReward = block.timestamp;
    }

    // Safe token transfer function, just in case if rounding error causes pool to not have enough tokens.
    function _safeTokenTransfer(address _to, uint256 _amount) internal {
        uint256 tokenBal = token.balanceOf(address(this));
        if (_amount > tokenBal) {
            token.transfer(_to, tokenBal);
        } else {
            token.transfer(_to, _amount);
        }
    }
}
