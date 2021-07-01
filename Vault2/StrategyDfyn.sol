// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./libs/IStakingRewards.sol";

import "./BaseStrategyLPSingle.sol";

contract StrategyDfyn is BaseStrategyLPSingle {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public depositAddress;

    constructor(
        address _vaultChefAddress,
        address _depositAddress,
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

        wantAddress = _wantAddress;
        token0Address = IUniPair(wantAddress).token0();
        token1Address = IUniPair(wantAddress).token1();

        uniRouterAddress = 0xA102072A4C07F06EC3B4900FDC4C7B80b6c57429;
        depositAddress = _depositAddress;
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
        IStakingRewards(depositAddress).stake(_amount);
    }
    
    function _vaultWithdraw(uint256 _amount) internal override {
        IStakingRewards(depositAddress).withdraw(_amount);
    }
    
    function _vaultHarvest() internal override {
        IStakingRewards(depositAddress).getReward();
    }
    
    
    function vaultSharesTotal() public override view returns (uint256) {
        return IStakingRewards(depositAddress).balanceOf(address(this));
    }
    
    function wantLockedTotal() public override view returns (uint256) {
        return IERC20(wantAddress).balanceOf(address(this))
            .add(IStakingRewards(depositAddress).balanceOf(address(this)));
    }

    function _resetAllowances() internal override {
        IERC20(wantAddress).safeApprove(depositAddress, uint256(0));
        IERC20(wantAddress).safeIncreaseAllowance(
            depositAddress,
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
        IStakingRewards(depositAddress).withdraw(vaultSharesTotal());
    }
}