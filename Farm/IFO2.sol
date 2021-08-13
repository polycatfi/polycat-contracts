// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/utils/ReentrancyGuard.sol";

import "./Governor.sol";

contract IFO is ReentrancyGuard, Governor {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // Info of each user.
  struct UserInfo {
      uint256 amount;   // How many tokens the user has provided.
      bool claimed;  // default false
  }

  uint256 public startBlock;
  uint256 public endBlock;

  // The token used to buy offeringToken e.g. USDC
  address public purchaseToken;
  uint256 public purchaseDecimal;
  // The token used to burn during buy e.g. FISH
  address public burnToken;
  uint256 public burnDecimal;
  // purchaseToken:burnToken
  uint256 public tokenRatio;

  // The offered token
  IERC20 public offeringToken;
  // The total amount of burnToken needed to buy all offeringTokens
  // We use burnToken as the purchaseToken amount is based on burnToken*tokenRatio
  uint256 public raisingAmount;
  // The total amount of offeringTokens to sell
  uint256 public offeringAmount;
  // Total raised amount of burnToken, can be higher than raisingAmount
  uint256 public totalAmount;
  
  mapping (address => UserInfo) public userInfo;
  address[] public addressList;


  event Deposit(address indexed user, uint256 amount);
  event Harvest(address indexed user, uint256 offeringAmount, uint256 excessAmount);

  constructor(
      address _purchaseToken,
      address _burnToken,
      uint256 _tokenRatio,
      IERC20 _offeringToken,
      uint256 _startBlock,
      uint256 _endBlock,
      uint256 _offeringAmount,
      uint256 _raisingAmount,
      address _govAddress
  ) public {
      purchaseToken = _purchaseToken;
      purchaseDecimal = uint256(10) ** ERC20(purchaseToken).decimals();
      burnToken = _burnToken;
      burnDecimal = uint256(10) ** ERC20(burnToken).decimals();
      tokenRatio = _tokenRatio;
      offeringToken = _offeringToken;
      startBlock = _startBlock;
      endBlock = _endBlock;
      offeringAmount = _offeringAmount;
      raisingAmount = _raisingAmount;
      govAddress = _govAddress;
  }

  function setOfferingAmount(uint256 _offerAmount) external onlyGov {
    require (block.number < startBlock, 'Cannot change after start');
    offeringAmount = _offerAmount;
  }

  function setRaisingAmount(uint256 _raisingAmount) external onlyGov {
    require (block.number < startBlock, 'Cannot change after start');
    raisingAmount = _raisingAmount;
  }

  function deposit(uint256 _amount) external nonReentrant {
    require (block.number > startBlock && block.number < endBlock, 'Has not started');
    require (_amount > 0, 'Cannot deposit zero');
    IERC20(burnToken).safeTransferFrom(address(msg.sender), address(this), _amount);
    IERC20(purchaseToken).safeTransferFrom(address(msg.sender), address(this), _amount.mul(tokenRatio).mul(purchaseDecimal).div(burnDecimal));
    if (userInfo[msg.sender].amount == 0) {
      addressList.push(address(msg.sender));
    }
    userInfo[msg.sender].amount = userInfo[msg.sender].amount.add(_amount);
    totalAmount = totalAmount.add(_amount);
    emit Deposit(msg.sender, _amount);
  }

  function harvest() external nonReentrant {
    require (block.number > endBlock, 'Has not ended yet');
    require (userInfo[msg.sender].amount > 0, 'Have you participated?');
    require (!userInfo[msg.sender].claimed, 'Nothing to harvest');
    uint256 offeringTokenAmount = getOfferingAmount(msg.sender);
    uint256 refundingTokenAmount = getRefundingAmount(msg.sender);
    offeringToken.safeTransfer(address(msg.sender), offeringTokenAmount);
    if (refundingTokenAmount > 0) {
      IERC20(burnToken).safeTransfer(address(msg.sender), refundingTokenAmount);
      IERC20(purchaseToken).safeTransfer(address(msg.sender), refundingTokenAmount.mul(tokenRatio).mul(purchaseDecimal).div(burnDecimal));
    }
    userInfo[msg.sender].claimed = true;
    emit Harvest(msg.sender, offeringTokenAmount, refundingTokenAmount);
  }

  function hasHarvest(address _user) external view returns(bool) {
      return userInfo[_user].claimed;
  }

  // allocation 100000 means 0.1(10%), 1 means 0.000001(0.0001%), 1000000 means 1(100%)
  function getUserAllocation(address _user) public view returns(uint256) {
    return userInfo[_user].amount.mul(1e36).div(totalAmount).div(1e18);
  }

  // get the amount of IFO token you will get
  function getOfferingAmount(address _user) public view returns(uint256) {
    if (totalAmount > raisingAmount) {
      uint256 allocation = getUserAllocation(_user);
      return offeringAmount.mul(allocation).div(1e18);
    }
    else {
      // userInfo[_user] / (raisingAmount / offeringAmount)
      return userInfo[_user].amount.mul(offeringAmount).div(raisingAmount);
    }
  }

  // get the amount of lp token you will be refunded
  function getRefundingAmount(address _user) public view returns(uint256) {
    if (totalAmount <= raisingAmount) {
      return 0;
    }
    uint256 allocation = getUserAllocation(_user);
    uint256 payAmount = raisingAmount.mul(allocation).div(1e18);
    return userInfo[_user].amount.sub(payAmount);
  }

  function getAddressListLength() external view returns(uint256) {
    return addressList.length;
  }

  function beforeWithdraw() external onlyGov {
    require (block.number < startBlock, 'Dont rugpull');
    offeringToken.safeTransfer(address(msg.sender), offeringToken.balanceOf(address(this)));
  }

  function finalWithdraw() external onlyGov {
    require (block.number > endBlock, 'Dont rugpull');
    if (totalAmount < raisingAmount) {
        IERC20(burnToken).safeTransfer(address(msg.sender), totalAmount);
        IERC20(purchaseToken).safeTransfer(address(msg.sender), totalAmount.mul(tokenRatio).mul(purchaseDecimal).div(burnDecimal));
        offeringToken.safeTransfer(address(msg.sender), offeringAmount.mul(raisingAmount.sub(totalAmount)).div(raisingAmount));
    } else {
        IERC20(burnToken).safeTransfer(address(msg.sender), raisingAmount);
        IERC20(purchaseToken).safeTransfer(address(msg.sender), raisingAmount.mul(tokenRatio).mul(purchaseDecimal).div(burnDecimal));
    }
  }

  // If something breaks
  function updateEndBlock(uint256 _endBlock) external onlyGov {
    endBlock = _endBlock;
  }
}