// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/*             WHAT I LEARNED
* Approval is permission, not a transfer. So don't set a limit to it
* Wallet are getting helps from events "Transfer events are how wallets know balances changed without scanning all storage for retrieving account data."
* Decimals only tell UI how to show it (1 token instead of 1_000_000_000_000_000_000 units)
* EVM does not use floating points. Solidity stores everything as integers.
* The decimals function is just metadata for display.
*/

// Track Total Supply
// Ballances
// Allowance, allow someone to spend token on our bhalf

contract RawErc20 {
    uint256 private totalTokenSupply; // This will be changes when minting/burning
    
    mapping(address => uint256) userBallance; // Default for unused addresses is 0
    mapping(address => mapping (address => uint256)) userAllowance; // tokenOwner -> spender -> amountAllowedToSpendOnBehalf

    error InsufficientBallance();
    error InsufficientAllowance();
    error TransferToZeroAddress();
    error TransferFromZeroAddress();

    event Transfer(address sender, address to, uint256 amount);
    event Approval(address sender, address spender, uint256 amount);

    function totalSupply() public view returns(uint256) {
        return (totalTokenSupply);
    }

    function balanceOf(address owner) public view returns(uint256) {
        return (userBallance[owner]);
    }

    function allowance(address owner, address spender) public view returns(uint256) {
        return (userAllowance[owner][spender]);
    }

    function transfer(address to, uint256 amount) public {
        require(to != address(0), TransferToZeroAddress());
        require(userBallance[msg.sender] >= amount, InsufficientBallance());

        userBallance[msg.sender] -= amount;
        userBallance[to] += amount;
        
        emit Transfer(msg.sender, to, amount);
    }

    function approve(address spender, uint256 amount) public {
        require(spender != address(0), TransferToZeroAddress());
        /* require(userBallance[msg.sender] > amount, InsufficientBallance()); */ // This line is false, since it we can approve eny amount, event more than we currently own

        userAllowance[msg.sender][spender] = amount;
        
        emit Approval(msg.sender, spender, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public {
        require(from != address(0), TransferFromZeroAddress());
        require(to != address(0), TransferToZeroAddress());
        require(userBallance[from] >= amount, InsufficientBallance());

        if(userAllowance[from][msg.sender] >= amount ) {
            userBallance[from] -= amount;
            userBallance[to] += amount;
            userAllowance[from][msg.sender] -= amount;
            emit Transfer(from, to, amount);
        } else {
            revert InsufficientAllowance();
        }
    }

    function decimals() public pure returns(uint8) {
        return 18;
    }

    function increaseAllowance(address spender, uint256 amount) public {
        require(userAllowance[msg.sender][spender] >= amount);
        userAllowance[msg.sender][spender] += amount;
    }
}