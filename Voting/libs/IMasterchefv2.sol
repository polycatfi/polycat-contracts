// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IMasterchefv2 {
    function userInfo(uint256 _pid, address _address) external view returns (uint256, uint256, uint256);
}