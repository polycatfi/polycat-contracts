// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IAdamantStake {
    function strategy() external view returns (address);
    
    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function withdrawAll() external;

    function claim() external;
    
    function getRatio() external view returns (uint256);
    
    function totalSupply() external view returns (uint256);
    
    function balance() external view returns (uint256);
    
    
    
    function getReward() external;
    
    function withdrawableBalance(address user) external view returns (uint256, uint256);
}