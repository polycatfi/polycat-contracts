// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IFirebird {
    function deposit(uint256 _pid, uint256 _amount) external;
    
    function depositWithRef(uint256 _pid, uint256 _amount, address _referrer) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function emergencyWithdraw(uint256 _pid) external;
    
    function userInfo(uint256 _pid, address _address) external view returns (uint256, uint256);
    
    function harvest(uint256 _pid, address _to) external;
}