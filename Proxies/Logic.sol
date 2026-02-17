// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract Logic {
    uint256 public counter;
    address public owner;
    uint256 public value;
    bool public flag;

    function initialize(address _owner, uint256 _value) public {
        require(owner == address(0), "Already initialized");
        owner = _owner;
        value = _value;
    }

    function incrementCounter() public {
        counter += 1;
    }
    
    function toggleFlag() public {
        flag = !flag;
    }

    function updateOwner(address _owner) public onlyOwner{
        owner = _owner;
    }

    function setValue(uint256 _value) public {
        value = _value;
    }

    function receiveEth() public payable{
        value = msg.value;
    }

    modifier onlyOwner {
        require(owner == msg.sender, "You are not the owner");
        _;
    }
}
