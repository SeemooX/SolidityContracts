// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract FixedVault {
    
    mapping(address => uint256) userBallance;
    mapping(address => bool) userLock;

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

        if(userLock[msg.sender]){
            revert("You can not call this function currently");
        }
        userLock[msg.sender] = true;

        userBallance[msg.sender] -= withdrawedAmount;
        (bool ok, ) = msg.sender.call{value: withdrawedAmount}("");


        if(!ok) {
            userBallance[msg.sender] += withdrawedAmount;
            revert("Something went wrong when sending your funds");
        }
        userLock[msg.sender] = false;
    }

    function myBallanceInVault() external view returns(uint256) {
        return (userBallance[msg.sender]);
    }

    // We are not going to put any of receive or fallback, since we don't want to anyone to send ether to our vault except form the send function
}