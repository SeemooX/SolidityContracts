// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/* 
* "selfdestruct" is a built in function in the EVM, its primary role is to delete delpoyed contract byteCode and clear its storage. So it is not safe to use unless you know what are you
* doing. it is called like the following "selfdestruct(payable(msg.sender)"; so here the contract runing this function is getting destroyed, and the eth balance in it is sent to "msg.sender"
*/

contract UpgradeableProxy {
    string private name;
    string private symbol;
    address private contractOwner;
    string[] private tokens;
    uint256 private currentId = 0;
    mapping (uint256 => string ) tokenIdToTokenURI;
    mapping (uint256 => address) userOwnership;
    mapping (address => uint256) userBalance;
    mapping (uint256 => address ) tokenApprovals;
    mapping (address => mapping(address => bool)) operatorApprovals;

    address private owner;
    mapping (address => bool) private isAdmin;

    address public implementation;

    event Admin_Changed(address indexed newAdmin);
    event Implementation_Updated(address indexed newImplementation);

    constructor(address _implementation){
        owner = msg.sender;
        isAdmin[msg.sender] = true;
        implementation = _implementation;
    }

    function updateImplementation(address newImplementation) external {
        require(isAdmin[msg.sender], "Only Admin could change the implementation contract address");
        implementation = newImplementation;
        emit Implementation_Updated(newImplementation);
    }

    function addAdmin(address newAdmin) public {
        require(owner == msg.sender, "Only the owner could call this addAdmin function");
        isAdmin[newAdmin] = true;
        emit Admin_Changed(newAdmin);
    }

    fallback() external payable {
        (bool ok, ) = address(implementation).delegatecall(msg.data);
        require(ok, "The call is not able to execute");
    }
    receive() external payable {
        if(msg.value > 0) {
            (bool ok,) = address(contractOwner).call{value: msg.value}("");
            require(ok, "Failed to send");
        }
    }
}