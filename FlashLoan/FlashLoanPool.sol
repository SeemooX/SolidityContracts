// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/* 
* !!!!!!!!!!!!!!!! Atomiciy in execution, there will never be a function run when another one is running !!!!!!!!!!!!!!!!
*/

interface IBorrowerInterface {
    function onFlashLoan(
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external;
}

interface IERC20 {
    function balanceOf(address owner) external view returns (uint256);
    function transfer(address to, uint256 amount) external;
    function transferFrom(address from, address to, uint256 amount) external;
    function approve(address spender, uint256 amount) external;
}

contract FlashLoanPool {
    uint256 public constant FEE_POURCENTAGE = 3e17;
    address private immutable contractOwner;
    bool private _entered;

    mapping(address => uint256) TotaltokenLiquidity; // Maps a token to the amoun token it has on the pool
    mapping(address => mapping(address => uint256)) ProviderQuantity; // Maps a user to tokens he potentially has, an each one of the token maps to the amount provided by the user

    error Repayment_Missing();

    constructor(address _owner, address firstToken, uint256 firstAmount) {
        require(
            IERC20(firstToken).balanceOf(msg.sender) > firstAmount,
            "You don't have enough amount of this token"
        );
        contractOwner = _owner;
    }

    function deposit(address tokenAddress, uint256 amount) external {
        require(
            IERC20(tokenAddress).balanceOf(msg.sender) >= amount,
            "You don't have enough amount to provide"
        );
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        TotaltokenLiquidity[tokenAddress] += amount;
        ProviderQuantity[msg.sender][tokenAddress] += amount;
    }

    function withdraw(address tokenAddress, uint256 amount) external {
        require(
            ProviderQuantity[msg.sender][tokenAddress] >= amount,
            "You don't have this amount"
        );
        IERC20(tokenAddress).transfer(msg.sender, amount);
        TotaltokenLiquidity[tokenAddress] -= amount;
        ProviderQuantity[msg.sender][tokenAddress] -= amount;
    }

    function flashLoan(
        address tokenAddress,
        uint256 amount,
        bytes calldata data
    ) external nonReentrant {
        uint256 balanceBefore = IERC20(tokenAddress).balanceOf(address(this));

        require(balanceBefore >= amount, "Not enough liquidity");

        // Transfer loan
        IERC20(tokenAddress).transfer(msg.sender, amount);

        // Callback
        IBorrowerInterface(msg.sender).onFlashLoan(
            tokenAddress,
            amount,
            FEE_POURCENTAGE,
            data
        );

        uint256 fee = amount * FEE_POURCENTAGE / 1e18;
        uint256 balanceAfter = IERC20(tokenAddress).balanceOf(address(this));

        require(balanceAfter >= balanceBefore + fee, "Repayment missing");
    }

    modifier nonReentrant() {
        require(!_entered, "Reetrant Call");
        _entered = true;
        _;
        _entered= false;
    }
}
