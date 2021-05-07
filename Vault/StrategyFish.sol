// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/utils/EnumerableSet.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/utils/Pausable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/utils/ReentrancyGuard.sol";

contract StrategyFish is Ownable, ReentrancyGuard, Pausable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    struct UserInfo {
        uint256 shares; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.

        /**
         * We do some fancy math here. Basically, any point in time, the amount of USDC
         * entitled to a user but is pending to be distributed is:
         *
         *   amount = user.shares / sharesTotal * wantLockedTotal
         *   pending reward = (amount * pool.accUsdPerShare) - user.rewardDebt
         *
         * Whenever a user deposits or withdraws want tokens to a pool. Here's what happens:
         *   1. The pool's `accUsdPerShare` (and `lastRewardBlock`) gets updated.
         *   2. User receives the pending reward sent to his/her address.
         *   3. User's `amount` gets updated.
         *   4. User's `rewardDebt` gets updated.
         */
    }

    address public constant usdcAddress = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public constant wantAddress = 0x3a3Df212b7AA91Aa0402B9035b098891d276572B;

    address public vaultChefAddress;
    address public govAddress; // timelock contract

    mapping(address => UserInfo) public userInfo;
    uint256 public sharesTotal = 0;
    uint256 public wantLockedTotal = 0; // Will always be the same as sharesTotal
    uint256 public accUsdPerShare = 0;

    constructor(
        address _vaultChefAddress
    ) public {
        govAddress = msg.sender;
        vaultChefAddress = _vaultChefAddress;

        transferOwnership(vaultChefAddress);
    }
    
    modifier onlyGov() {
        require(msg.sender == govAddress, "!gov");
        _;
    }

    function deposit(address _userAddress, uint256 _wantAmt) external onlyOwner nonReentrant whenNotPaused returns (uint256) {
        UserInfo storage user = userInfo[_userAddress];
        
        uint256 pending = user.shares.mul(accUsdPerShare).div(1e18).sub(user.rewardDebt);
        if (pending > 0) {
            if (pending > 0) {
                IERC20(usdcAddress).safeTransfer(_userAddress, pending);
            }
        }

        IERC20(wantAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _wantAmt
        );

        sharesTotal = sharesTotal.add(_wantAmt);
        wantLockedTotal = sharesTotal;
        user.shares = user.shares.add(_wantAmt);
        
        user.rewardDebt = user.shares.mul(accUsdPerShare).div(1e18);

        return _wantAmt;
    }

    function withdraw(address _userAddress, uint256 _wantAmt) external onlyOwner nonReentrant returns (uint256) {
        require(_wantAmt > 0, "_wantAmt <= 0");
        UserInfo storage user = userInfo[_userAddress];
        
        uint256 pending = user.shares.mul(accUsdPerShare).div(1e18).sub(user.rewardDebt);
        if (pending > 0) {
            IERC20(usdcAddress).safeTransfer(_userAddress, pending);
        }

        uint256 wantAmt = IERC20(wantAddress).balanceOf(address(this));
        if (_wantAmt > wantAmt) {
            _wantAmt = wantAmt;
        }
        
        sharesTotal = sharesTotal.sub(_wantAmt);
        wantLockedTotal = sharesTotal;

        IERC20(wantAddress).safeTransfer(vaultChefAddress, _wantAmt);
        if (_wantAmt > user.shares) {
            user.shares = 0;
        } else {
            user.shares = user.shares.sub(_wantAmt);
        }
        
        user.rewardDebt = user.shares.mul(accUsdPerShare).div(1e18);

        return _wantAmt;
    }
    
    function depositReward(uint256 _depositAmt) external returns (bool) {
        IERC20(usdcAddress).safeTransferFrom(msg.sender, address(this), _depositAmt);
        if (sharesTotal == 0) {
            return false;
        }
        accUsdPerShare = accUsdPerShare.add(_depositAmt.mul(1e18).div(sharesTotal));
        
        return true;
    }

    function pause() external onlyGov {
        _pause();
    }

    function unpause() external onlyGov {
        _unpause();
    }

    function setGov(address _govAddress) external onlyGov {
        govAddress = _govAddress;
    }
}