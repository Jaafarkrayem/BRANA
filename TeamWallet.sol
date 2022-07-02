// SPDX-License-Identifier: MIT

/************************
BRANAVERSE Team WALLET
************************/

import "./BRANA.sol";

pragma solidity = 0.8.13;

contract BranaTeamWallet {
    using SafeMath for uint256;

    address public constant zeroAddress = address(0x0);
    address public constant deadAddress = 0x000000000000000000000000000000000000dEaD;
    
    Branaverse public BRANA;
    address private owner;
    uint256 public constant monthly = 30 days;
    uint256 public teamCount;
    uint256 private IDteam;
    uint256 public teamVault;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 public constant hPercent = 100; //100%
    uint256 private _status;
    uint256 public mP = 5; /* Monthy percentage */
    

    event TeamAdded(address Team, uint256 Amount);
    event BRANAClaimed(address Team, uint256 Amount);
    event ChangeOwner(address NewOwner);
    event WithdrawalBNB(uint256 _amount, uint256 decimal, address to); 
    event WithdrawalBRANA(uint256 _amount,uint256 decimal, address to);
    event WithdrawalBEP20(address _tokenAddr, uint256 _amount,uint256 decimals, address to);
    
    struct VaultTeam{
        uint256 teamID;
        uint256 falseAmount; //represents the actual amount locked in order to keep track of monthly percentage to unlock
        uint256 amount;
        uint256 monthLock;
        uint256 lockTime;
        uint256 timeStart;
    }
 
    mapping(address => bool) public Team;
    mapping(address => VaultTeam) public team;


    mapping(address => bool) public blackList; 
    

    modifier onlyOwner (){
        require(msg.sender == owner, "Only BRANA owner can add Team");
        _;
    }

    modifier isTeam(address _team){
        require(Team[_team] == true, "Not a team member!");
        _;
    }

    modifier isNotBlackListed(address _team){
        require(blackList[_team] != true, "Your wallet is Blacklisted!");
        _;
    }
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
    constructor(Branaverse _BRANA) {
        owner = msg.sender;
        teamCount = 0;
        IDteam = 0;
        BRANA = _BRANA;
        _status = _NOT_ENTERED;
    }
    function transferOwnership(address _newOwner)external onlyOwner{
        require(_newOwner != zeroAddress,"Zero Address");
        emit ChangeOwner(_newOwner);
        owner = _newOwner;
    }
    function setMonthlyPercentage(uint256 _mP) external onlyOwner{
        require(_mP > 0 && mP <= 30,"Min 1% Max 30%");
        mP = _mP;
    }
    function addToBlackList(address _team) external onlyOwner{
        blackList[_team] = true;
    }
    function removeFromBlackList(address _team) external onlyOwner{
        blackList[_team] = false;
    }
    function addTeam(address _team, uint256 _amount, uint256 _lockTime) external onlyOwner{
        require(_team != zeroAddress && _team != deadAddress,"Zero Address Dead!");
        uint256 availableAmount = BRANA.balanceOf(address(this)).sub(teamVault);
        require(availableAmount >= _amount,"No BRANA");
        uint256 lockTime = _lockTime.mul(1 days);
        require(_amount > 0, "Amount!");
        if(team[_team].amount > 0){
            team[_team].amount += _amount;
            team[_team].falseAmount = team[_team].amount;
            teamVault += _amount;
            return;
        }
        require(lockTime > monthly.mul(3), "Please set a time in the future more than 90 days!");
        emit TeamAdded(msg.sender, _amount);
        IDteam++;
        team[_team].teamID = IDteam;
        team[_team].falseAmount = _amount;
        team[_team].amount = _amount;
        team[_team].lockTime = lockTime.add(block.timestamp);
        team[_team].timeStart = block.timestamp;
        team[_team].monthLock = lockTime.add(block.timestamp);
        Team[_team] = true;
        teamVault += _amount;
        teamCount++;
    }
    function claimMonthlyAmount() external isTeam(msg.sender) isNotBlackListed(msg.sender) nonReentrant{
        uint256 totalTimeLock = team[msg.sender].monthLock;
        uint256 mainAmount = team[msg.sender].falseAmount;
        uint256 remainAmount = team[msg.sender].amount;
        require(totalTimeLock <= block.timestamp, "Not yet");
        require(remainAmount > 0, "No BRANA");  
        uint256 amountAllowed = mainAmount.mul(mP).div(hPercent);
        team[msg.sender].amount = remainAmount.sub(amountAllowed);
        team[msg.sender].monthLock += monthly;
        teamVault -= amountAllowed;
        if(team[msg.sender].amount == 0){
            Team[msg.sender] = false;
            delete team[msg.sender]; 
            teamCount--;
        }
        emit BRANAClaimed(msg.sender, amountAllowed);
        BRANA.transfer(msg.sender, amountAllowed);
    }
    function claimRemainings() external isTeam(msg.sender) isNotBlackListed(msg.sender) nonReentrant{
        uint256 fullTime = hPercent.div(mP).mul(monthly);
        uint256 totalTimeLock = team[msg.sender].lockTime.add(fullTime);
        require(totalTimeLock <= block.timestamp, "Not yet");
        uint256 remainAmount = team[msg.sender].amount;
        team[msg.sender].amount = 0;
        teamVault -= remainAmount;
        Team[msg.sender] = false;
        delete team[msg.sender];
        emit BRANAClaimed(msg.sender, remainAmount);
        BRANA.transfer(msg.sender, remainAmount);
        teamCount--;
    }
    function withdrawalBRANA(uint256 _amount, uint256 decimal, address to) external onlyOwner() {
        uint256 amount = BRANA.balanceOf(address(this)).sub(teamVault);
        require(amount > 0 && amount >= _amount, "No BRANA!");// can only withdraw what is not locked for team members.
        uint256 dcml = 10 ** decimal;
        emit WithdrawalBRANA( _amount, decimal, to);
        BRANA.transfer(to, _amount*dcml);
    }
    function withdrawalBEP20(address _tokenAddr, uint256 _amount, uint256 decimal, address to) external onlyOwner() {
        uint256 dcml = 10 ** decimal;
        ERC20 token = ERC20(_tokenAddr);
        require(token != BRANA, "No!"); //Can't withdraw BRANA using this function!
        emit WithdrawalBEP20(_tokenAddr, _amount, decimal, to);
        token.transfer(to, _amount*dcml); 
    }  
    function withdrawalBNB(uint256 _amount, uint256 decimal, address to) external onlyOwner() {
        require(address(this).balance >= _amount,"Balanace"); //No BNB balance available
        uint256 dcml = 10 ** decimal;
        emit WithdrawalBNB(_amount, decimal, to);
        payable(to).transfer(_amount*dcml);      
    }
    receive() external payable {}
}


/****************************************************
Proudly Developed by MetaIdentity ltd. Copyright 2022
****************************************************/
