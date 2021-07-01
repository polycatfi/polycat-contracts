// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IAaveStake {
    function depositETH(address lendingPool, address onBehalfOf, uint16 referralCode) external payable;
    
    function withdrawETH(address lendingPool, uint256 amount, address onBehalfOf) external;

    function repayETH(address lendingPool, uint256 amount, uint256 rateMode, address onBehalfOf) external payable;

    function borrowETH(address lendingPool, uint256 amount, uint256 interesRateMode, uint16 referralCode) external;
    
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external payable;
    
    function withdraw(address asset, uint256 amount, address to) external;

    function borrow(address asset, uint256 amount, uint256 interesRateMode, uint16 referralCode, address onBehalfOf) external;

    function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external payable;
    
    function getUserAccountData(address user) external view returns (uint256, uint256, uint256, uint256, uint256, uint256);
    
    
    function claimRewards(address[] calldata assets, uint256 amount, address to) external returns (uint256);
}