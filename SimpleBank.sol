// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/* *     WHAT I LEARNED IN BUILDING THIS CONTRACT
* Ether enters a contract only in one way: A tx that sends Ether to a payable function.
* This Ether amount is exposed by solidiy as 'msg.value', since this last one is injected by the EVM itself
                                                                                                            msg.sender = sender
                                                                                                            msg.value  = value
* payable keyword: ALLOWS the contract to reciece Ether via that function marked as payable.
* The validator before all this, checks the msg.value with user account, if he actually has that amount, and our logic is an extra safety layer.
* The transfer of the real Ether token amount is done by the EVM itself
                                                                        sender.balance   -= msg.value
                                                                        contract.balance += msg.value
* Reetrancy happens when withdrawing funds from some contract so this needs to be checked:
                                                                                            ✔ State updated before external call
                                                                                            ✔ Classic Checks–Effects–Interactions pattern
                                                                                            ✔ No reentrancy vulnerability here
* read/write storage each iteration, gas explodes, Alterntive always try to use mapping
* Alawys do Event logging + off-chain aggregation:
                                                Emit events instead of iterating
                                                Read total balances off-chain
*
* Practical rules for @dev:
                                Always use storage for persistent state (balances, mappings, totals)
                                Use memory for temporary arrays/structs inside functions
                                Use calldata for external function inputs to save gas
                                Understand stack limits: too many local variables → stack overflow
                                Moving data between storage and memory costs gas
                                    Also: 
                                        Storage = blockchain hard drive
                                        Memory = temporary RAM
                                        Stack = CPU registers
                                        Calldata = packet sent from the caller, it is put at parameter only we can never change it inside the function
 * The type in the returns of the function must be memory, since calldata is input only, storage not advisable. We must specify the type of that data like where exaclty does it live in order for the EVM to get it.
 * Three ways to make a contract sends Ether: "The first to are not good and very dangerous to use"
                                            payable(msg.sender).transfer(amount);
                                            bool ok = payable(msg.sender).send(amount);
                                            (bool ok, ) = msg.sender.call{value: amount}("");
                                            require(ok);
 */

contract SimpleBank {
    address[] private users;

    // Mapping each user to his token balance
    mapping(address => uint256) userWallet;
    mapping(address => bool) isUser;

    function deposit() public payable checkUserExistence {
        require(msg.value > 0, "Zero deposit");

        userWallet[msg.sender] += msg.value;
    }

    function withdraw(uint256 withdrawedAmount) public checkUserExistence {
        if ((userWallet[msg.sender] - withdrawedAmount) < 0) {
            revert("You don't have money to make a withdrawel");
        }

        require(address(this).balance >= withdrawedAmount);

        userWallet[msg.sender] = userWallet[msg.sender] - withdrawedAmount;

        (bool ok, ) = msg.sender.call{value: withdrawedAmount}("");

        if (!ok) {
            revert("Currently Not able to send Eth");
        }
    }

    function externalBalance(address user) public view returns (uint256) {
        return user.balance;
    }

    function bankBalance(address user) public view returns (uint256) {
        return userWallet[user];
    }

    function totalDeposits() public view returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i < users.length; i++) {
            total += userWallet[users[i]];
        }
        return total;
    }

    // Bad logic since it uses loops, and reads from storage
    /* function totalDeposits() public view returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i < users.length; i++) {
            total += userWallet[users[i]];
        }
        return total;
    } */

    modifier checkUserExistence() {
        if (!isUser[msg.sender]) {
            isUser[msg.sender] = true;
            users.push(msg.sender);
        }
        _;
    }
}