// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/*             WHAT I LEARNED
* Approval is permission, not a transfer. So don't set a limit to it
*/

// Track Total Supply
// Ballances
// Allowance, allow someone to spend token on our bhalf

contract ExtendedRawErc20 {
    address private contractOwner;
    uint8 private constant SPAN_BLOCKS = 50; // how many block it waits until, the contract Owner could mint again

    uint256 private prevBlock;
    uint256 private totalTokenSupply; // This will be changes when minting/burning
    uint256 private maxTokenSupply;
    
    mapping(address => uint256) userBallance; // Default for unused addresses is 0
    mapping(address => mapping (address => uint256)) userAllowance; // tokenOwner -> spender -> amountAllowedToSpendOnBehalf

    error InsufficientBallance();
    error InsufficientAllowance();
    error TransferToZeroAddress();
    error TransferFromZeroAddress();

    event Transfer(address sender, address to, uint256 amount);
    event Approval(address sender, address spender, uint256 amount);

    constructor(uint256 supply, uint256 maxSupply) {
        totalTokenSupply = supply;
        maxTokenSupply = maxSupply;
        userBallance[msg.sender] = supply;
        contractOwner = msg.sender;
        emit Transfer(address(0), msg.sender, supply);
    }

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

    function mintTokens(uint256 amount) public onlyOwner {
        if((totalTokenSupply + amount) <= maxTokenSupply && block.number > (prevBlock + SPAN_BLOCKS)) {
            totalTokenSupply += amount;
            userBallance[msg.sender] += amount;
            prevBlock = block.number;

            emit Transfer(address(0), msg.sender, amount);
        } else {
            revert("Max Supply Reached, Or still not passed the time to mint again");
        }   
    }

    function burnTokens(uint256 amount) public {
        if(userBallance[msg.sender] < amount) revert("You don't have enough to burn");

        userBallance[msg.sender] -= amount;
        totalTokenSupply -= amount;

        emit Transfer(msg.sender, address(0), amount);
    }

    function burnTokensFor(address user, uint256 amount) public {
        if(userAllowance[user][msg.sender] < amount) revert("You don't have enough to burn");

        userAllowance[user][msg.sender] -= amount;
        userBallance[user] -= amount;
        totalTokenSupply -= amount;

        emit Transfer(user, address(0), amount);
    }

    function transferOwnership(address newOnwer) public onlyOwner {
        contractOwner = newOnwer;
    }

    function decimals() public pure returns(uint8) {
        return 18;
    }

    modifier onlyOwner() {
        if(msg.sender != contractOwner){
            revert("You can not call this function");
        }
        _;
    }
}