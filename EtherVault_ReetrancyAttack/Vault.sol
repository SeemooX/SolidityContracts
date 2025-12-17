// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
A loop does not work because it executes entirely inside one call frame, and the vault’s state changes are only observed after calls return.
Reentrancy works because when the vault sends Ether, the EVM transfers execution control to the attacker contract before updating the vault’s internal state.
The attacker’s receive() executes in a new call frame and recursively calls withdrawFunds() while the vault still believes the balance is unchanged.

Reentrancy is not about calling again — it’s about control leaving the contract before state is updated.
 */

contract Vault {

    mapping(address => uint256) userBallance;

    event DepositMade(address sender, uint256 amountSent);

    function putToVault() external payable {
        require(msg.value > 0, "You didn't send any Ether or You passed a negative number");
        userBallance[msg.sender] += msg.value;
        emit DepositMade(msg.sender, msg.value);
    }

    function withdrawFunds(uint256 withdrawedAmount) external {
        if(userBallance[msg.sender] < withdrawedAmount) {
            revert("You don't have this amount in your balance");
        }

        (bool ok, ) = msg.sender.call{value: withdrawedAmount}("");


        if(ok) {
            userBallance[msg.sender] -= withdrawedAmount;
        } else {
            revert("Something went wrong when sending your funds");
        }
    }

    function myBallanceInVault() external view returns(uint256) {
        return (userBallance[msg.sender]);
    }

    // This built in  functions bellow are automatically called when a contract tries to send Ether to  another contract
    receive() external payable {
        userBallance[msg.sender] += msg.value;
        emit DepositMade(msg.sender, msg.value);
    }
    fallback() external payable {
        userBallance[msg.sender] += msg.value;
        emit DepositMade(msg.sender, msg.value);
    }
}