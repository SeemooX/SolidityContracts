//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**    WHAT I HAVE LEARNED
* This is used to compare string "keccak256(bytes(roleToAssign)) == keccak256(bytes("Admin"))"
*You’ve learned what it takes:
                                Track admin count
                                Prevent last-admin removal
                                Transfer admin safel
                                Replace string roles with enum
                                Provide owner recovery
* If the owner is compromised, only pre-designed controls like pausing, multisig, timelocks, and emergency roles can prevent damage — nothing else can be added afterward.
*/

contract RoleBasedAccess {
    address private contractOwner; // In case this account is comprimised how to modify, the contract to change this one ?
    uint256 private adminCount;

    enum contractRoles {
        Admin,
        Operator,
        User
    }

    struct Roles {
        bool Admin;
        bool Operator;
        bool User;
    }

    event AdminRoleGranted(address userToAssignRoleTo);
    event OperatorRoleGranted(address userToAssignRoleTo);
    event AdminRoleRevoked(address userToRevoke);
    event OperatorRoleRevoked(address userToRevoke);
    event NoLongerUser(address userToRevoke);
    event AdminTransferred(address newAdmin);

    error YouNeedToBeAdmin();
    error YouNeedToBeOperator();
    error YouAreNotallowedToCallThis();

    mapping(address => Roles) userToRole;

    constructor() {
        contractOwner = msg.sender;
        userToRole[contractOwner].User = true;
        userToRole[contractOwner].Admin = true;
        userToRole[contractOwner].Operator = true;
        adminCount = 1;
    }

    function assignRole(
        address userToAssignRoleTo,
        contractRoles roleToAssign
    ) public OnlyAdmin {
        if (!userToRole[userToAssignRoleTo].User) {
            userToRole[userToAssignRoleTo].User = true;
        }

        if (!userToRole[userToAssignRoleTo].Admin) {
            revert("This user is already an Admin");
        }

        if (uint8(roleToAssign) == 1) {
            // We use the keccak hashing, because it is gas efficient
            userToRole[userToAssignRoleTo].Admin = true;
            adminCount++;
            emit AdminRoleGranted(userToAssignRoleTo);
        } else if (
            uint8(roleToAssign) == 2
        ) {
            userToRole[userToAssignRoleTo].Operator = true;
            emit OperatorRoleGranted(userToAssignRoleTo);
        }
    }

    function revokeRole(
        address userToRevoke,
        contractRoles roleToRemove
    ) public OnlyAdmin {
        if (
            uint8(roleToRemove) != 0 &&
            uint8(roleToRemove) != 1 &&
            uint8(roleToRemove) != 2
        ) {
            revert("You entered the role name wrong");
        }

        if (userToRevoke == msg.sender) {
            revert("You cannot romove your roles by yourself");
        }

        if (adminCount == 1) {
            revert("You cannot revoke, addressNumber issue");
        }

        if (
            userToRole[userToRevoke].User &&
            uint8(roleToRemove) == 0 
        ) {
            userToRole[userToRevoke].User = false;
            if(userToRole[userToRevoke].Admin){
                adminCount--;
            }
            userToRole[userToRevoke].Admin = false;
            userToRole[userToRevoke].Operator = false;
            
            emit NoLongerUser(userToRevoke);
        } else if (
            userToRole[userToRevoke].Admin &&
            uint8(roleToRemove) == 1
        ) {
            userToRole[userToRevoke].Admin = false;
            adminCount--;
            emit AdminRoleRevoked(userToRevoke);
        } else if (
            userToRole[userToRevoke].Operator &&
            uint8(roleToRemove) == 2
        ) {
            userToRole[userToRevoke].Operator = false;
            emit OperatorRoleRevoked(userToRevoke);
        }
    }

    function queryRole(
        address userToQuery
    ) public view returns (bool isUser, bool isAdmin, bool isOperator) {
        return (
            userToRole[userToQuery].User,
            userToRole[userToQuery].Admin,
            userToRole[userToQuery].Operator
        );
    }

    function transferAdmin(address newAdmin) external OnlyAdmin {
        require(
            newAdmin != address(0) && adminCount > 0 && newAdmin != msg.sender
        );
        userToRole[msg.sender].Admin = false;
        adminCount--;

        if (!userToRole[newAdmin].Admin) {
            userToRole[newAdmin].Admin = true;
            adminCount++;
            emit AdminTransferred(newAdmin);
        }
    }

    function transferOwnership(address newOwner) external OnlySuperAdmin {
        require(newOwner != address(0));
        contractOwner = newOwner;
    }

    modifier OnlyAdmin() {
        if (!userToRole[msg.sender].Admin) {
            revert YouNeedToBeAdmin();
        }
        _;
    }

    modifier OnlySuperAdmin() {
        if (msg.sender != contractOwner) {
            revert YouAreNotallowedToCallThis();
        }
        _;
    }

    modifier OnlyOperator() {
        if (!userToRole[msg.sender].Operator) {
            revert YouNeedToBeOperator();
        }
        _;
    }
}
