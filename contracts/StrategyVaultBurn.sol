// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/utils/Pausable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/utils/ReentrancyGuard.sol";

import "./libs/IDragonLair.sol";
import "./libs/IStakingRewards.sol";
import "./libs/IStrategyFish.sol";
import "./libs/IUniPair.sol";
import "./libs/IUniRouter02.sol";

contract StrategyVaultBurn is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public quickSwapAddress;
    address public constant dragonLairAddress = 0xf28164A485B0B2C90639E47b0f377b4a438a16B1;
    address public wantAddress;
    
    address public constant uniRouterAddress = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
    address public constant dQuickAddress = 0xf28164A485B0B2C90639E47b0f377b4a438a16B1;
    address public constant quickAddress = 0x831753DD7087CaC61aB5644b308642cc1c33Dc13;
    address public constant wmaticAddress = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address public constant fishAddress = 0x3a3Df212b7AA91Aa0402B9035b098891d276572B;
    address public vaultChefAddress;
    address public govAddress;

    uint256 public lastEarnBlock = block.number;
    uint256 public wantLockedTotal = 0;
    uint256 public sharesTotal = 0;

    address public constant buyBackAddress = 0x000000000000000000000000000000000000dEaD;

    uint256 public slippageFactor = 950; // 5% default slippage tolerance
    uint256 public constant slippageFactorUL = 995;

    address[] public quickToFishPath;

    constructor(
        address _vaultChefAddress,
        address _quickSwapAddress,
        address _wantAddress
    ) public {
        govAddress = msg.sender;
        vaultChefAddress = _vaultChefAddress;
        wantAddress = _wantAddress;
        quickSwapAddress = _quickSwapAddress;
        quickToFishPath = [quickAddress, wmaticAddress, fishAddress];

        transferOwnership(vaultChefAddress);
        
        _resetAllowances();
    }
    
    event SetSettings(
        uint256 _slippageFactor
    );
    
    modifier onlyGov() {
        require(msg.sender == govAddress, "!gov");
        _;
    }

    function deposit(address _userAddress, uint256 _wantAmt) external onlyOwner nonReentrant whenNotPaused returns (uint256) {
        IERC20(wantAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            _wantAmt
        );

        sharesTotal = sharesTotal.add(_wantAmt);
        wantLockedTotal = sharesTotal;

        IStakingRewards(quickSwapAddress).stake(_wantAmt);

        return _wantAmt;
    }

    function withdraw(address _userAddress, uint256 _wantAmt) external onlyOwner nonReentrant returns (uint256) {
        require(_wantAmt > 0, "_wantAmt is 0");

        IStakingRewards(quickSwapAddress).withdraw(_wantAmt);

        uint256 wantAmt = IERC20(wantAddress).balanceOf(address(this));
        if (_wantAmt > wantAmt) {
            _wantAmt = wantAmt;
        }

        if (wantLockedTotal < _wantAmt) {
            _wantAmt = wantLockedTotal;
        }

        sharesTotal = sharesTotal.sub(_wantAmt);
        wantLockedTotal = sharesTotal;

        IERC20(wantAddress).safeTransfer(vaultChefAddress, _wantAmt);

        return _wantAmt;
    }

    function lair() external nonReentrant whenNotPaused onlyGov {
        IStakingRewards(quickSwapAddress).getReward();

        uint256 earnedAmt = IERC20(quickAddress).balanceOf(address(this));
        if (earnedAmt > 0) {
            IDragonLair(dragonLairAddress).enter(earnedAmt);
        }

        lastEarnBlock = block.number;
    }

    function burn() external nonReentrant whenNotPaused onlyGov {
        uint256 lairBalance = IERC20(dQuickAddress).balanceOf(address(this));
        if (lairBalance > 0) {
            IDragonLair(dragonLairAddress).leave(lairBalance);
            
            uint256 earnedAmt = IERC20(quickAddress).balanceOf(address(this));
            if (earnedAmt > 0) {
                _safeSwap(
                    earnedAmt,
                    quickToFishPath,
                    buyBackAddress
                );
            }
        }
    }

    function pause() external onlyGov {
        _pause();
    }

    function unpause() external onlyGov {
        _unpause();
        _resetAllowances();
    }

    function _resetAllowances() internal {
        IERC20(wantAddress).safeApprove(quickSwapAddress, uint256(0));
        IERC20(wantAddress).safeIncreaseAllowance(
            quickSwapAddress,
            uint256(-1)
        );

        IERC20(quickAddress).safeApprove(dragonLairAddress, uint256(0));
        IERC20(quickAddress).safeIncreaseAllowance(
            dragonLairAddress,
            uint256(-1)
        );

        IERC20(quickAddress).safeApprove(uniRouterAddress, uint256(0));
        IERC20(quickAddress).safeIncreaseAllowance(
            uniRouterAddress,
            uint256(-1)
        );
    }

    function resetAllowances() external onlyGov {
        _resetAllowances();
    }
    
    function setSettings(
        uint256 _slippageFactor
    ) external onlyGov {
        require(_slippageFactor <= slippageFactorUL, "_slippageFactor too high");
        slippageFactor = _slippageFactor;

        emit SetSettings(
            _slippageFactor
        );
    }

    function setGov(address _govAddress) external onlyGov {
        govAddress = _govAddress;
    }
    
    function _safeSwap(
        uint256 _amountIn,
        address[] memory _path,
        address _to
    ) internal {
        uint256[] memory amounts = IUniRouter02(uniRouterAddress).getAmountsOut(_amountIn, _path);
        uint256 amountOut = amounts[amounts.length.sub(1)];

        IUniRouter02(uniRouterAddress).swapExactTokensForTokens(
            _amountIn,
            amountOut.mul(slippageFactor).div(1000),
            _path,
            _to,
            now.add(600)
        );
    }
}