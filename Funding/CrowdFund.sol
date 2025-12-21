// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// Goal!
// Contributors send ETH
// Funds are Locked
// Outcome is deterministic
// No one can cheat, including the creator

contract CrowdFund {
    uint256 private immutable i_deadLine;
    uint256 private immutable i_goalAmount;

    address private contractOwner;
    mapping(address => uint256) userDonation;
    uint256 private totalCurrentFunds;
    bool creatorAllowed = false;
    bool getRefundAfterFail = false;

    enum fundingState {
        Funding,
        Successful,
        Failed,
        Closed
    }

    uint256 state;

    constructor(uint256 deadline, uint256 goalAmount) {
        i_deadLine = deadline; // This will be in timestamp not blocknumbers, and must be in future
        i_goalAmount = goalAmount; // goal amount must be above 0
        contractOwner = msg.sender;
        state = uint8(fundingState.Funding);
        require(deadline > block.timestamp, "Deadline must be in future");
        require(goalAmount > 0, "Goal must be > 0");
        require(msg.sender != address(0), "Invalid owner"); // optional but good
    }

    function contribute() external payable deadlineCheck checkAmountSent {
        require(state == uint8(fundingState.Funding), "Campaign ended");
        totalCurrentFunds += msg.value;
        userDonation[msg.sender] += msg.value;
    }

    function refund(uint256 amount) external /* deadlineCheck */ {
        if (amount > userDonation[msg.sender]) {
            revert("You don't have that amount to refunds it");
        } else if (userDonation[msg.sender] == 0) {
            revert("You don't have any finds here");
        } else if (getRefundAfterFail) {
            // In case the fund failed, then everyone could retrieve his money all
            userDonation[msg.sender] -= amount;
            totalCurrentFunds -= amount;
            (bool ok, ) = (msg.sender).call{value: amount}("");
            if (!ok) {
                userDonation[msg.sender] += amount;
                totalCurrentFunds += amount;
                revert("Something happened in transfer");
            }
        } /* else { // If someone funded, and tried to retrieve his money before the completion of time, then we take from him 25%
            uint256 amountRefunded = (amount * 3/4);
            userDonation[msg.sender] -= amount;
            totalCurrentFunds -= amountRefunded;
            (bool ok, ) = (msg.sender).call{value: amountRefunded}("");
            if(!ok) {
                userDonation[msg.sender] += amount;
                totalCurrentFunds += amount;
                revert("Something happened in transfer");
            }
        } */
    }

    function currentStatus()
        public
        view
        returns (uint256, uint256, uint256, bool)
    {
        return (
            totalCurrentFunds,
            i_goalAmount,
            i_deadLine - block.timestamp,
            totalCurrentFunds >= i_goalAmount
        );
    }

    function successCheck() external {
        require(state == uint8(fundingState.Funding), "Already finalized");
        if (
            totalCurrentFunds >= i_goalAmount && i_deadLine <= block.timestamp
        ) {
            state = uint8(fundingState.Successful);
            creatorAllowed = true;
        } else {
            revert("still");
        }
    }

    function failCheck() external {
        require(state == uint8(fundingState.Funding), "Already finalized");
        if (totalCurrentFunds < i_goalAmount && i_deadLine <= block.timestamp) {
            state = uint8(fundingState.Failed);
            getRefundAfterFail = true;
        } else {
            revert("still");
        }
    }

    function withdrawFund() external onlyOnwer {
        if (state != 3) {
            if (creatorAllowed && state == 1) {
                // This will automatically say that the time passed and the goal reached
                uint256 prevTotalCurrentFunds = totalCurrentFunds;
                totalCurrentFunds = 0;
                (bool ok, ) = (msg.sender).call{value: prevTotalCurrentFunds}(
                    ""
                );
                if (!ok) {
                    totalCurrentFunds = prevTotalCurrentFunds;
                    revert("Something happending when transfering");
                }
            }
            state = uint8(fundingState.Closed);
        } else {
            revert("You already called this function");
        }
    }

    modifier deadlineCheck() {
        if (i_deadLine < block.timestamp) {
            revert("You can not contribute, the funding is finished");
        }
        _;
    }

    modifier onlyOnwer() {
        if (contractOwner != msg.sender) {
            revert("You are not allowed to call this");
        }
        _;
    }

    modifier checkAmountSent() {
        if (msg.value <= 0) {
            revert("You have to send ETHER");
        }
        _;
    }

    receive() external payable deadlineCheck {
        require(state == uint8(fundingState.Funding), "Campaign ended");
        totalCurrentFunds += msg.value;
        userDonation[msg.sender] += msg.value;
    }
    fallback() external payable deadlineCheck {
        require(state == uint8(fundingState.Funding), "Campaign ended");
        totalCurrentFunds += msg.value;
        userDonation[msg.sender] += msg.value;
    }
}