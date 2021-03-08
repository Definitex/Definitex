pragma solidity ^0.6.6;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "Addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "Subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "Multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "Division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "Modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Staking
{
    using SafeMath for uint256;

    struct Staker
    {
        uint256 stake;
        uint256 stakeTime;
        uint256 reward;
    }
    mapping(address => Staker) public stakers;

    IERC20 public _stakingToken;
    uint256 public _interestPerDay = 1; // 0.1% per day
    uint256 public _fee = 5; // 0.5%

    event Stake(uint256 amount, uint256 totalStake);
    event StakeWithdrawal(uint256 amount, uint256 remainingStake);
    event RewardCollected(uint256 amount, uint256 totalReward);
    event RewardWithdrawal(uint256 amount, uint256 remainingReward);

    constructor(IERC20 stakingToken) public
    {
        require(address(stakingToken) != address(0));

        _stakingToken = stakingToken;
    }

    function calculateReward(address staker) public view returns (uint256)
    { return now.sub(stakers[staker].stakeTime).mul(stakers[staker].stake).mul(_interestPerDay).div(86400000); }

    function collectReward(address staker) private returns (uint256)
    {
        uint256 reward = calculateReward(staker);
        stakers[staker].reward = stakers[staker].reward.add(reward);
        stakers[staker].stakeTime = now;

        emit RewardCollected(reward, stakers[staker].reward);
        return stakers[staker].reward;
    }

    function stake(uint256 amount) public
    {
        if(stakers[msg.sender].stake > 0)
        { collectReward(msg.sender); }

        stakers[msg.sender].stakeTime = now;
        stakers[msg.sender].stake = stakers[msg.sender].stake.add(amount);

        _stakingToken.transferFrom(msg.sender, address(this), amount);
        emit Stake(amount, stakers[msg.sender].stake);
    }

    function withdraw() public
    { withdraw(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff); }

    function withdraw(uint256 amount) public
    {
        require(stakers[msg.sender].stake > 0 || stakers[msg.sender].reward > 0, "Nothing to withdraw from the contract");

        uint256 reward = collectReward(msg.sender);
        uint256 token_balance = _stakingToken.balanceOf(address(this));

        if(amount > stakers[msg.sender].stake)
        { amount = stakers[msg.sender].stake; }

        if(amount > token_balance)
        { amount = token_balance; }

        if(amount > 0)
        {
            uint256 fee = amount.mul(_fee).div(1000);
            uint256 withdraw_amount = amount.sub(fee);

            stakers[msg.sender].stake = stakers[msg.sender].stake.sub(amount);
            token_balance = token_balance.sub(withdraw_amount);
            _stakingToken.transfer(msg.sender, withdraw_amount);
            emit StakeWithdrawal(amount, stakers[msg.sender].stake);
        }

        if(reward > token_balance)
        { reward = token_balance; }

        if(reward > 0)
        {
            stakers[msg.sender].reward = stakers[msg.sender].reward.sub(reward);
            _stakingToken.transfer(msg.sender, reward);
            emit RewardWithdrawal(reward, stakers[msg.sender].reward);
        }
    }

    function withdrawStake() public
    { withdrawStake(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff); }

    function withdrawStake(uint256 amount) public
    {
        require(stakers[msg.sender].stake > 0, "No stake in the contract");

        collectReward(msg.sender);

        if(amount > stakers[msg.sender].stake)
        { amount = stakers[msg.sender].stake; }

        uint256 token_balance = _stakingToken.balanceOf(address(this));
        if(amount > token_balance)
        { amount = token_balance; }

        if(amount > 0)
        {
            uint256 fee = amount.mul(_fee).div(1000);
            uint256 withdraw_amount = amount.sub(fee);

            stakers[msg.sender].stake = stakers[msg.sender].stake.sub(amount);
            _stakingToken.transfer(msg.sender, withdraw_amount);
            emit StakeWithdrawal(amount, stakers[msg.sender].stake);
        }
    }

    function withdrawReward() public
    {
        uint256 reward = collectReward(msg.sender);
        require(reward > 0, "No reward in the contract");

        uint256 token_balance = _stakingToken.balanceOf(address(this));
        if(reward > token_balance)
        { reward = token_balance; }

        if(reward > 0)
        {
            stakers[msg.sender].reward = stakers[msg.sender].reward.sub(reward);
            _stakingToken.transfer(msg.sender, reward);
            emit RewardWithdrawal(reward, stakers[msg.sender].reward);
        }
    }
}
