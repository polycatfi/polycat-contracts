// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol";

import "./libs/IMasterchef.sol";
import "./libs/IMasterchefv2.sol";
import "./libs/IUniPair.sol";
import "./libs/IVaultChef.sol";

contract CalculateFish is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    address public constant fishAddress = 0x3a3Df212b7AA91Aa0402B9035b098891d276572B;
    address public constant masterchefv2 = 0xB026DeD2d4Bc2b94aDd2B724A65D3FE744592827;

    struct Token {
        address token;
        uint16 pid;
    }

    address[] public walletLP;

    address[] public masterChefs;

    address[] public vaultChefs;

    mapping(address => Token[]) public masterChefTokens;

    mapping(address => Token[]) public vaultChefTokens;

    function calculateFish(address _user) external view returns (uint256) {
        return _calculateWallet(_user).add(_calculateMasterchef(_user)).add(_calculateVaultchef(_user));
    }
    
    function _calculateWallet(address _user) internal view returns (uint256) {
        uint256 totalFish;
        for (uint16 i = 0; i < walletLP.length; i++) {
            if (walletLP[i] == fishAddress) {
                uint256 userAmt = IERC20(walletLP[i]).balanceOf(_user);
                totalFish = totalFish.add(userAmt);
            } else {
                bool fishExists = IUniPair(walletLP[i]).token0() == fishAddress || IUniPair(walletLP[i]).token1() == fishAddress;

                if (fishExists) {
                    uint256 userLP = IERC20(walletLP[i]).balanceOf(_user);
                    uint256 totalSupply = IUniPair(walletLP[i]).totalSupply();
                    uint256 fishSupply = IERC20(fishAddress).balanceOf(walletLP[i]);
                    totalFish = totalFish.add(fishSupply.mul(userLP).div(totalSupply));
                }
            }
        }
        return totalFish;
    }
    
    function _calculateMasterchef(address _user) internal view returns (uint256) {
        uint256 totalFish;
        for (uint16 i = 0; i < masterChefs.length; i++) {
            for (uint16 j = 0; j < masterChefTokens[masterChefs[i]].length; j++) {
                Token storage token = masterChefTokens[masterChefs[i]][j];
                if (token.token == fishAddress) {
                    (uint256 userAmt,) = IMasterchef(masterChefs[i]).userInfo(token.pid, _user);
                    totalFish = totalFish.add(userAmt);
                } else {
                    bool fishExists = IUniPair(token.token).token0() == fishAddress || IUniPair(token.token).token1() == fishAddress;

                    if (fishExists) {
                        uint256 userLP;
                        if (masterChefs[i] == masterchefv2) {
                            (userLP,,) = IMasterchefv2(masterChefs[i]).userInfo(token.pid, _user);
                        } else {
                            (userLP,) = IMasterchef(masterChefs[i]).userInfo(token.pid, _user);
                        }
                        uint256 totalSupply = IUniPair(token.token).totalSupply();
                        uint256 fishSupply = IERC20(fishAddress).balanceOf(token.token);
                        totalFish = totalFish.add(fishSupply.mul(userLP).div(totalSupply));
                    }
                }
            }
        }
        return totalFish;
    }
    
    function _calculateVaultchef(address _user) internal view returns (uint256) {
        uint256 totalFish;
        for (uint16 i = 0; i < vaultChefs.length; i++) {
            for (uint16 j = 0; j < vaultChefTokens[vaultChefs[i]].length; j++) {
                Token storage token = vaultChefTokens[vaultChefs[i]][j];
                if (token.token == fishAddress) {
                    uint256 userAmt = IVaultChef(vaultChefs[i]).stakedWantTokens(token.pid, _user);
                    totalFish = totalFish.add(userAmt);
                } else {
                    bool fishExists = IUniPair(token.token).token0() == fishAddress || IUniPair(token.token).token1() == fishAddress;

                    if (fishExists) {
                        uint256 userLP = IVaultChef(vaultChefs[i]).stakedWantTokens(token.pid, _user);
                        uint256 totalSupply = IUniPair(token.token).totalSupply();
                        uint256 fishSupply = IERC20(fishAddress).balanceOf(token.token);
                        totalFish = totalFish.add(fishSupply.mul(userLP).div(totalSupply));
                    }
                }
            }
        }
        return totalFish;
    }
    
    function addWalletLP(address _lp) external onlyOwner {
        bool exists;
        for (uint16 i = 0; i < walletLP.length; i++) {
            if (walletLP[i] == _lp) { exists = true; }
        }
        require(!exists, "LP exists");
        
        walletLP.push(_lp);
    }
    
    function addMasterChefToken(address _masterchef, address _token, uint16 _pid) external onlyOwner {
        bool exists;
        for (uint16 i = 0; i < masterChefs.length; i++) {
            if (masterChefs[i] == _masterchef) { exists = true; }
        }
        if (!exists) { masterChefs.push(_masterchef); }

        exists = false;
        for (uint16 i = 0; i < masterChefTokens[_masterchef].length; i++) {
            Token storage token = masterChefTokens[_masterchef][i];
            if (token.pid == _pid) { exists = true; }
        }
        require(!exists, "pid exists");

        masterChefTokens[_masterchef].push(Token({
            token: _token,
            pid: _pid
        }));

        exists = false;
        for (uint16 i = 0; i < walletLP.length; i++) {
            if (walletLP[i] == _token) { exists = true; }
        }
        if (!exists) { walletLP.push(_token); }
    }
    
    function addVaultChefToken(address _vaultchef, address _token, uint16 _pid) external onlyOwner {
        bool exists;
        for (uint16 i = 0; i < vaultChefs.length; i++) {
            if (vaultChefs[i] == _vaultchef) { exists = true; }
        }
        if (!exists) { vaultChefs.push(_vaultchef); }

        exists = false;
        for (uint16 i = 0; i < vaultChefTokens[_vaultchef].length; i++) {
            Token storage token = vaultChefTokens[_vaultchef][i];
            if (token.pid == _pid) { exists = true; }
        }
        require(!exists, "pid exists");

        vaultChefTokens[_vaultchef].push(Token({
            token: _token,
            pid: _pid
        }));

        exists = false;
        for (uint16 i = 0; i < walletLP.length; i++) {
            if (walletLP[i] == _token) { exists = true; }
        }
        if (!exists) { walletLP.push(_token); }
    }
}