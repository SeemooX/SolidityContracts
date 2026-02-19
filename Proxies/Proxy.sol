// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract Proxy {
    uint256 public counter;
    address public owner;
    uint256 public value;
    bool public flag;

    address public implementation;

    constructor(address _logic, address _value) {
    implementation = _logic;

    (bool ok, ) = _logic.delegatecall(
        abi.encodeWithSignature(
            "initialize(address,uint256)",
            msg.sender,
            _value
        )
    );
    require(ok, "Initialization failed");
    }

    function incrementCounter() public {
        (bool ok, ) = address(implementation).delegatecall(
            abi.encodeWithSignature("incrementCounter()")
        );
        require(ok, "Increment failed");
    }

    function toggleFlag() public {
        (bool ok, ) = address(implementation).delegatecall(
            abi.encodeWithSignature("toggleFlag()")
        );
        require(ok, "Toggle failed");
    }

    function updateOwner(address _owner) public {
        (bool ok, ) = address(implementation).delegatecall(
            abi.encodeWithSignature("updateOwner(address)", _owner)
        );
        require(ok, "Update Owner failed");
    }

    function setValue(uint256 _value) public {
        (bool ok, ) = address(implementation).delegatecall(
            abi.encodeWithSignature("setValue(uint256)", _value)
        );
        require(ok, "Update Value failed");
    }

    function receiveEth() public payable {
        (bool ok,) = address(implementation).delegatecall(
            abi.encodeWithSignature("receiveEth()")
        );
        require(ok, "Receive Eth failed");
    }

    function changeImplementation(address newImplementation) public {
        require(msg.sender == owner, "Not Owner");
        implementation = newImplementation;
    }

    fallback() external payable {
        (bool ok, ) = address(implementation).delegatecall(msg.data);
        require(ok, "delegation failed");
    }
    
    receive() external payable {
    }
}
