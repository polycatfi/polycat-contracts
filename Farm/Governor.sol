// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

contract Governor {
    address public govAddress;

    modifier onlyGov() {
        require(msg.sender == govAddress, "!gov");
        _;
    }

    function setGov(address _govAddress) external onlyGov {
        govAddress = _govAddress;
    }
}