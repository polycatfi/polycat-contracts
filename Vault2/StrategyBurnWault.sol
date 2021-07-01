// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./libs/IWault.sol";

import "./BaseStrategyLP.sol";

contract StrategyBurnWault is BaseStrategyLP {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public masterchefAddress;
    uint256 public pid;

    constructor(
        address _vaultChefAddress,
        address _masterchefAddress,
        address _uniRouterAddress,
        uint256 _pid,
        address _wantAddress,
        address _earnedAddress,
        address[] memory _earnedToWmaticPath,
        address[] memory _earnedToUsdcPath,
        address[] memory _earnedToFishPath,
        address[] memory _earnedToToken0Path,
        address[] memory _earnedToToken1Path,
        address[] memory _token0ToEarnedPath,
        address[] memory _token1ToEarnedPath
    ) public {
        govAddress = msg.sender;
        vaultChefAddress = _vaultChefAddress;
        masterchefAddress = _masterchefAddress;
        uniRouterAddress = _uniRouterAddress;

        wantAddress = _wantAddress;
        token0Address = IUniPair(wantAddress).token0();
        token1Address = IUniPair(wantAddress).token1();

        pid = _pid;
        earnedAddress = _earnedAddress;

        earnedToWmaticPath = _earnedToWmaticPath;
        earnedToUsdcPath = _earnedToUsdcPath;
        earnedToFishPath = _earnedToFishPath;
        earnedToToken0Path = _earnedToToken0Path;
        earnedToToken1Path = _earnedToToken1Path;
        token0ToEarnedPath = _token0ToEarnedPath;
        token1ToEarnedPath = _token1ToEarnedPath;

        transferOwnership(vaultChefAddress);
        
        _resetAllowances();
    }

    function _vaultDeposit(uint256 _amount) internal override {
        IWault(masterchefAddress).deposit(pid, _amount, true);
    }
    
    function _vaultWithdraw(uint256 _amount) internal override {
        IWault(masterchefAddress).withdraw(pid, _amount, true);
    }
    
    function vaultSharesTotal() public override view returns (uint256) {
        (uint256 amount,) = IWault(masterchefAddress).userInfo(pid, address(this));
        return amount;
    }
    
    function wantLockedTotal() public override view returns (uint256) {
        return IERC20(wantAddress).balanceOf(address(this))
            .add(vaultSharesTotal());
    }
    
    function earn() external override nonReentrant whenNotPaused onlyGov {
        // Harvest farm tokens
        IWault(masterchefAddress).claim(pid);

        // Converts farm tokens into want tokens
        uint256 earnedAmt = IERC20(earnedAddress).balanceOf(address(this));

        if (earnedAmt > 0) {
            earnedAmt = distributeFees(earnedAmt);
            earnedAmt = buyBack(earnedAmt);
    
            lastEarnBlock = block.number;
        }
    }
    
    function buyBack(uint256 _earnedAmt) internal override returns (uint256) {
        if (_earnedAmt > 0) {
            _safeSwap(
                _earnedAmt,
                earnedToFishPath,
                buyBackAddress
            );
        }
    }

    function _resetAllowances() internal override {
        IERC20(wantAddress).safeApprove(masterchefAddress, uint256(0));
        IERC20(wantAddress).safeIncreaseAllowance(
            masterchefAddress,
            uint256(-1)
        );

        IERC20(earnedAddress).safeApprove(uniRouterAddress, uint256(0));
        IERC20(earnedAddress).safeIncreaseAllowance(
            uniRouterAddress,
            uint256(-1)
        );

        IERC20(token0Address).safeApprove(uniRouterAddress, uint256(0));
        IERC20(token0Address).safeIncreaseAllowance(
            uniRouterAddress,
            uint256(-1)
        );

        IERC20(token1Address).safeApprove(uniRouterAddress, uint256(0));
        IERC20(token1Address).safeIncreaseAllowance(
            uniRouterAddress,
            uint256(-1)
        );

        IERC20(usdcAddress).safeApprove(rewardAddress, uint256(0));
        IERC20(usdcAddress).safeIncreaseAllowance(
            rewardAddress,
            uint256(-1)
        );
    }
    
    function _emergencyVaultWithdraw() internal override {
        IWault(masterchefAddress).emergencyWithdraw(pid);
    }
}