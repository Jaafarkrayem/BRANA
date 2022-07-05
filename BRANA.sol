// SPDX-License-Identifier: MIT


//Branaverse Project
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

pragma solidity = 0.8.15;


contract Branaverse is ERC20 {
    using SafeMath for uint256;
    address private owner;

    address public constant theCompany = 0xFF0031ACB7b45BA08B2b089C8671044237C3d70c;
    address public constant developmentAddress = 0x67Add7657E44AeE4e56345922B85E9334711b194;
    address public constant deadAddress = 0x000000000000000000000000000000000000dEaD;
    address public constant zeroAddress = address(0x0);

    uint256 internal sSBlock;uint256 internal sEBlock;uint256 internal sTot;
    uint256 internal sPrice;
    uint256 internal fractions = 10** decimals();
    uint256 public max = 20 * fractions;
    uint256 public min = max.div(100);
    uint256 public privateLimit = 1000000;
    uint256 public constant maxSupply = 1000000000000000000000000000;

    event PrivateSale(uint256 Amount, uint256 Price, bool Success);
    event PrivateSaleStarted(uint256 endBlockNumber, uint256 Price);
    event PrivateSaleEnded(uint256 blockNumber);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event WithdrawalBNB(uint256 _amount, uint256 decimal, address to); 
    event WithdrawalToken(address _tokenAddr, uint256 _amount,uint256 decimals, address to);

    modifier onlyOwner(){
        require(msg.sender == owner,"Only Owner");
        _;
    }


constructor () ERC20("Brana", "BRANA") payable {
    owner = msg.sender;
    _mint (address(this), maxSupply.mul(10).div(100)); // 10%
    _mint (theCompany, maxSupply.mul(89).div(100)); // 89%
    _mint (theCompany, maxSupply.mul(1).div(200)); // 0.5%
    _mint (developmentAddress, maxSupply.mul(1).div(200)); // 0.5%
        
}
   function transferOwnership(address _newOwner) external onlyOwner{
       require(_newOwner != address(0));
       owner = _newOwner;
       emit OwnershipTransferred(owner, _newOwner);
   }
   function privateSale(address) public payable returns (bool success){
    require(balanceOf(address(msg.sender)) <= privateLimit * fractions , "You reached your private sale limit");  
    require(sSBlock <= block.number && block.number <= sEBlock, "Private Sale has ended or did not start yet");

    uint256 _eth = msg.value;
    uint256 _tkns;
    
    require ( _eth >= min && _eth <= max , "Less than Minimum or More than Maximum");
    _tkns = (sPrice.mul(_eth)).div(1 ether);
    sTot ++;
    
    _transfer(address(this), msg.sender, _tkns); 
    emit PrivateSale(_tkns, sPrice, true);
    return true;
    
  }
  function viewSale() public view returns(uint256 StartBlock, uint256 EndBlock, uint256 SaleCount, uint256 SalePrice){
    return(sSBlock, sEBlock, sTot,  sPrice);
  }
  function startSale(uint256 _sEBlock, uint256 _sPrice) public onlyOwner{
      require(_sEBlock != 0 && _sPrice !=0,"Operation prohibited");
   sEBlock = _sEBlock; sPrice =_sPrice * fractions;
   emit PrivateSaleStarted(_sEBlock, _sPrice);
  }
  function endSale () public onlyOwner{
          sEBlock = block.number;
          emit PrivateSaleEnded(sEBlock);
  }
  function changeMinMaxPrivateSale(uint256 minAmount, uint256 maxAmount) external onlyOwner {
      require(minAmount != 0 && maxAmount != 0,"Zero!");
      min = minAmount;
      max = maxAmount;
  }
  function setPrivateLimit(uint256 _limit) external onlyOwner {
      require(_limit != 0,"Zero");
      privateLimit = _limit;
  }
/*
  @dev: this function is used if any investor send tokens 
  directly to the contract then the owner will be able to send them back
*/
  function withdrawalToken(address _tokenAddr, uint256 _amount, uint256 decimal, address to) external onlyOwner() {
  require(_tokenAddr != address(0),"address zero!");
        uint256 dcml = 10 ** decimal;
        ERC20 token = ERC20(_tokenAddr);
        emit WithdrawalToken(_tokenAddr, _amount, decimal, to);
        token.transfer(to, _amount*dcml); 
    }
/*
  @dev: this function is used to withdraw tokens of private sale
  or if any investor send BNB directly by mistake to the contract 
  then the owner will be able to send them back.
*/
  function withdrawalBNB(uint256 _amount, uint256 decimal, address to) external onlyOwner() {
        require(address(this).balance >= _amount);
        uint256 dcml = 10 ** decimal;
        emit WithdrawalBNB(_amount, decimal, to);
        payable(to).transfer(_amount*dcml);      
    }

    receive() external payable {}
}

/**********************************************************
 Proudly Developed by MetaIdentity ltd. Copyright 2022 
**********************************************************/
