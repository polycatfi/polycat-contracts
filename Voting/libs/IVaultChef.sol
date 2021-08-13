// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IVaultChef {
     function stakedWantTokens(uint256 _pid, address _user) external view returns (uint256);
}