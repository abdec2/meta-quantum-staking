// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Staking is Ownable {
    using SafeMath for uint256;

    uint8 sixMonthAPR = 30;
    uint8 oneYearAPR = 60;
    uint8 threeYearAPR = 150;
    uint256 public totalStake;
    uint256 public totalRewards;

    struct stake {
        uint256 amount;
        uint timestamp;
    }

    address[] internal stakeholders;

    mapping(address => stake) internal stakes;
    mapping(address => uint256) internal rewards;

    IERC20 public myToken;

    constructor(address _myToken)
    { 
        myToken = IERC20(_myToken);
    }

    // ---------- STAKES ----------

    function createStake(uint256 _stake) public {
        require(_stake > 0, "stake value should not be zero");
        myToken.transferFrom(msg.sender, address(this), _stake);
        if(stakes[msg.sender].amount == 0) {
            addStakeholder(msg.sender);
            stakes[msg.sender] = stake(_stake, block.timestamp);
            totalStake = totalStake.add(_stake);
        } else {
            stake memory tempStake = stakes[msg.sender];
            tempStake.amount = tempStake.amount.add(_stake);
            stakes[msg.sender] = tempStake;
            totalStake = totalStake.add(_stake);
        }
    }

    function removeStake(uint256 _stake) public {
        require(_stake > 0, "stake value should not be zero");

        stake memory tempStake = stakes[msg.sender];
        tempStake.amount = tempStake.amount.sub(_stake);
        stakes[msg.sender] = tempStake;
        totalStake = totalStake.sub(_stake);
        if(stakes[msg.sender].amount == 0) removeStakeholder(msg.sender);
        myToken.transfer(msg.sender, _stake);
    }

    function stakeOf(address _stakeholder)
        public
        view
        returns(uint256)
    {
        return stakes[_stakeholder].amount;
    }


    // ---------- STAKEHOLDERS ----------

    function isStakeholder(address _address)
        public
        view
        returns(bool, uint256)
    {
        for (uint256 s = 0; s < stakeholders.length; s += 1){
            if (_address == stakeholders[s]) return (true, s);
        }
        return (false, 0);
    }

   
    function addStakeholder(address _stakeholder)
        public
    {
        (bool _isStakeholder, ) = isStakeholder(_stakeholder);
        if(!_isStakeholder) stakeholders.push(_stakeholder);
    }

    
    function removeStakeholder(address _stakeholder)
        public
    {
        (bool _isStakeholder, uint256 s) = isStakeholder(_stakeholder);
        if(_isStakeholder){
            stakeholders[s] = stakeholders[stakeholders.length - 1];
            stakeholders.pop();
        } 
    }
    // ---------- REWARDS ----------
   
    function rewardOf(address _stakeholder) 
        public
        view
        returns(uint256)
    {
        return rewards[_stakeholder];
    }

    
    function getTotalRewards()
        public
        view
        returns(uint256)
    {
        return totalRewards;
    }

    function calculateReward(address _stakeholder)
        public
        view
        returns(uint256)
    {
        uint256 calculatedReward = 0;
        uint stakeTimeStamp = stakes[_stakeholder].timestamp;
        uint diff = (block.timestamp - stakeTimeStamp);
        if(diff >= 144 weeks) {
            calculatedReward = stakes[_stakeholder].amount.div(100).mul(threeYearAPR);
        } else if(diff >= 48 weeks && diff < 144 weeks) {
            calculatedReward = stakes[_stakeholder].amount.div(100).mul(oneYearAPR);
        } else if(diff >= 24 weeks && diff < 48 weeks) {
            calculatedReward = stakes[_stakeholder].amount.div(100).mul(sixMonthAPR);
        } else {
            calculatedReward = 0;
        }
        return calculatedReward;
    }

    function distributeRewards() 
        public
        onlyOwner
    {
        for (uint256 s = 0; s < stakeholders.length; s += 1){
            address stakeholder = stakeholders[s];
            uint256 reward = calculateReward(stakeholder);
            rewards[stakeholder] = rewards[stakeholder].add(reward);
            totalRewards = totalRewards.add(reward);
        }
    }


    function withdrawReward() 
        public
    {
        uint256 reward = rewards[msg.sender];
        rewards[msg.sender] = 0;
        myToken.transferFrom(owner(), msg.sender, reward);
    }
}