// SPDX-License-Identifier: MIT

/*****************************
BRANAVERSE Marketing WALLET
*****************************/

import "./BRANA.sol";

pragma solidity = 0.8.13;

contract BranaMarketingWallet {
    using SafeMath for uint256;

    address public constant zeroAddress = address(0x0);
    address public constant deadAddress = 0x000000000000000000000000000000000000dEaD;
    
    Branaverse public BRANA;
    address private owner;
    uint256 public constant monthly = 30 days;
    uint256 public adminCount;
    uint256 public MarketingVault;
    uint256 public walletCount;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 public constant hPercent = 100; //100%
    uint256 private _status;
    uint256 public mP = 5; /* Monthy percentage */
    

    event MarketingWalletAdded(address Wallet, uint256 Amount);
    event BRANAClaimed(address Wallet, address Operator, uint256 Amount);
    event ChangeOwner(address NewOwner);
    event WithdrawalBNB(uint256 _amount, uint256 decimal, address to); 
    event WithdrawalBRANA(uint256 _amount,uint256 decimal, address to);
    event WithdrawalBEP20(address _tokenAddr, uint256 _amount,uint256 decimals, address to);
    
    struct MarketingWallet{
        uint256 falseAmount; //represents the actual amount locked in order to keep track of monthly percentage to unlock
        uint256 amount;
        uint256 monthLock;
        uint256 lockTime;
        uint256 timeStart;
    }
 
    mapping(address => bool) public adminHolder;
    mapping(address => MarketingWallet) public Receiver;

    modifier onlyOwner (){
        require(msg.sender == owner, "Only BRANA owner");
        _;
    }

    modifier isAdminHolder(address _admin){
        require(adminHolder[_admin] == true, "Not an Admin!");
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
        BRANA = _BRANA;
        _status = _NOT_ENTERED;
        adminHolder[msg.sender] = true;
        adminCount = 1;
    }
    function transferOwnership(address _newOwner)external onlyOwner{
        require(_newOwner != zeroAddress,"Zero Address");
        emit ChangeOwner(_newOwner);
        owner = _newOwner;
    }
    function setMonthlyPercentage(uint256 _mP) external onlyOwner{
        require(_mP > 0 && mP <= 100,"Min 1% Max 100%");
        mP = _mP;
    }
    function addAdmin(address _admin) external onlyOwner{
        require(_admin != zeroAddress,"Zero Address");
        adminHolder[_admin] = true;
        adminCount++;
    }
    function removeAdmin(address _admin) external onlyOwner{
        require(_admin != owner,"Can't remove owner!");
        adminHolder[_admin] = false;
        adminCount--;
    }
    function lockWallet(address _receiver, uint256 _amount, uint256 _lockTime) external onlyOwner{
        require(_receiver != zeroAddress && _receiver != deadAddress,"Zero Address Dead!");
        uint256 availableAmount = BRANA.balanceOf(address(this)).sub(MarketingVault);
        require(availableAmount >= _amount,"No BRANA");
        uint256 lockTime = _lockTime.mul(1 days);
        require(_amount > 0, "Amount!");
        if(Receiver[_receiver].amount > 0){
            Receiver[_receiver].amount += _amount;
            Receiver[_receiver].falseAmount = Receiver[_receiver].amount;
            MarketingVault += _amount;
            return;
        }
        emit MarketingWalletAdded(_receiver, _amount);
        Receiver[_receiver].falseAmount = _amount;
        Receiver[_receiver].amount = _amount;
        Receiver[_receiver].lockTime = lockTime.add(block.timestamp);
        Receiver[_receiver].timeStart = block.timestamp;
        Receiver[_receiver].monthLock = lockTime.add(block.timestamp);
        MarketingVault += _amount;
        walletCount ++;
    }
    function claimMonthlyAmount(address _receiver) external isAdminHolder(msg.sender) nonReentrant{
        uint256 totalTimeLock = Receiver[_receiver].monthLock;
        uint256 mainAmount = Receiver[_receiver].falseAmount;
        uint256 remainAmount = Receiver[_receiver].amount;
        require(totalTimeLock <= block.timestamp, "Not yet");
        require(remainAmount > 0, "No BRANA");  
        uint256 amountAllowed = mainAmount.mul(mP).div(hPercent);
        Receiver[_receiver].amount = remainAmount.sub(amountAllowed);
        Receiver[_receiver].monthLock += monthly;
        MarketingVault -= amountAllowed;
        if(Receiver[_receiver].amount == 0){
            delete Receiver[_receiver]; 
            walletCount--;
        }
        emit BRANAClaimed(_receiver, msg.sender, amountAllowed);
        BRANA.transfer(_receiver, amountAllowed);
    }
    function claimRemainings(address _receiver) external isAdminHolder(msg.sender) nonReentrant{
        uint256 fullTime = hPercent.div(mP).mul(monthly);
        uint256 totalTimeLock = Receiver[_receiver].lockTime.add(fullTime);
        require(totalTimeLock <= block.timestamp, "Not yet");
        uint256 remainAmount = Receiver[_receiver].amount;
        Receiver[_receiver].amount = 0;
        MarketingVault -= remainAmount;
        delete Receiver[_receiver];
        emit BRANAClaimed(_receiver, msg.sender, remainAmount);
        BRANA.transfer(_receiver, remainAmount);
        walletCount--;
    }
    function changeReceiver(address _oldReceiver, address _newReceiver)external onlyOwner{
        Receiver[_newReceiver].falseAmount = Receiver[_oldReceiver].falseAmount;
        Receiver[_newReceiver].amount = Receiver[_oldReceiver].amount;
        Receiver[_newReceiver].lockTime = Receiver[_oldReceiver].lockTime;
        Receiver[_newReceiver].timeStart = Receiver[_oldReceiver].timeStart;
        Receiver[_newReceiver].monthLock = Receiver[_oldReceiver].monthLock;
        delete Receiver[_oldReceiver];
    }
    function withdrawalBRANA(uint256 _amount, uint256 decimal, address to) external onlyOwner() {
        uint256 amount = BRANA.balanceOf(address(this)).sub(MarketingVault);
        require(amount > 0 && _amount <= amount, "No BRANA!");// can only withdraw what is not locked for Marketing Wallet.
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
