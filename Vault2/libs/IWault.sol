// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IWault {
    function deposit(uint256 _pid, uint256 _amount, bool _withdrawRewards) external;

    function withdraw(uint256 _pid, uint256 _amount, bool _withdrawRewards) external;

    function emergencyWithdraw(uint256 _pid) external;
    
    function userInfo(uint256 _pid, address _address) external view returns (uint256, uint256);
    
    function claim(uint256 _pid) external;
}