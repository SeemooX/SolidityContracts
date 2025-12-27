// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**         WHAT I LEARNED
* 1. At first i have made a fatal error, by giving to each caller a pending transaction, which is not the case where we limit the caller to one tx until gets approved.
* 2. Transcation are independent and each user could make how much he want of txs, not only one per execution
*
* 3. Dynamlic way to use the contructor the enter whatever you want, "The constructor is the same as normal function, we could check also there"
*
*
 */

contract MultiSigWallet {
    uint256 private immutable threshold; // The threshold, of required confirmations to execute the function code
    uint256 private txCount = 0;

    struct txState {
        bool exists;
        bool executed;
        address destination;
        uint256 value;
        bytes data;
    }

    mapping(address => uint256) private owners; // This will identify address that are owners
    mapping(uint256 => uint256) validationNumberPerAddress;
    mapping(uint256 => txState) stateOfTxs;
/*  mapping(address => txState) private stateOfTxs; // Why i made this, because the address has only one transaction at the time if one is created, he could not make another one unitl the last gets executed*/
    mapping(uint256 => mapping(address => bool)) doubleConfirmationResolve; // txID -> owner/caller -> isApproved

    event EthDeposited(address sender);

    constructor(
        address[] memory _owners, uint256 _threshold
    ) {
        require(_owners.length > 0, "No owners");
        require(threshold <= _owners.length && threshold > 0, "Invalis threshold");

        for(uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Zero address");
            require(owners[_owners[i]] == 0, "Zero address");
            
            owners[_owners[i]] = 1;
        }
        threshold = _threshold;
        require(threshold <= 10 && threshold > 0); // This is the threshold <= ownerCount, since ownerCount here is made statically
    }

    // This function will ONLY propose
    function submitTx(
        address destination,
        uint256 value,
        string calldata data
    ) external onlyOwners {
        // Proposal
        uint256 transactionId = txCount;
        txCount++;
            stateOfTxs[transactionId].exists = true; // True means that this transaction is submitted and exists in the system
            stateOfTxs[transactionId].destination = destination;
            stateOfTxs[transactionId].value = value;
            stateOfTxs[transactionId].data = bytes(data);
    }

    function confirmTx(uint256 transactionId) external onlyOwners{
        if(stateOfTxs[transactionId].exists && !doubleConfirmationResolve[transactionId][msg.sender] && transactionId < txCount){
            doubleConfirmationResolve[transactionId][msg.sender] = true;
            validationNumberPerAddress[transactionId]++; // This increments the validation number, of the tx submitted
        } else {
            revert("You can not approve twice, or the caller has not submitted anything");
        }
    }

    function revokeTx(uint256 transactionId) external onlyOwners{
        if(stateOfTxs[transactionId].exists && doubleConfirmationResolve[transactionId][msg.sender]){
            doubleConfirmationResolve[transactionId][msg.sender] = false;
            validationNumberPerAddress[transactionId]--;
        }
    }

    function executeTx(uint256 transactionId) external onlyOwners {
        if(stateOfTxs[transactionId].exists && !stateOfTxs[transactionId].executed) {
            if(validationNumberPerAddress[transactionId] >= threshold){
                address dest = stateOfTxs[transactionId].destination;
                uint256 val = stateOfTxs[transactionId].value;
                bytes memory dataCall = stateOfTxs[transactionId].data;
                stateOfTxs[transactionId].executed = true;
                stateOfTxs[transactionId].destination = address(0);
                stateOfTxs[transactionId].value = 0;
                stateOfTxs[transactionId].data = bytes("");
                validationNumberPerAddress[transactionId] = 0;

                (bool ok, ) = (dest).call{value: val}(dataCall);
                if(!ok){
                    revert("something happend when transfering");
                }
            } else {
                revert("You still not at the point of achieving the threshold");
            }
        } else {
            revert("You don't have any pending transaction");
        }
    }

    receive() external payable {
        emit EthDeposited(msg.sender);
    }
    fallback() external payable {
        emit EthDeposited(msg.sender);
    }

    modifier onlyOwners() {
        if (owners[msg.sender] == 0) {
            revert("You can not send this transaction");
        }
        _;
    }
}
