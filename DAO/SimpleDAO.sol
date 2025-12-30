// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/* The contract is the following: 
 - Who can propose?
 - Who can vote?
 - How are votes counted?
 - How is a decision executed safely?

  The DAO contract should support:
    Proposal creation
    Voting on proposals
    Vote counting
    Quorum enforcement
    Proposal lifecycle management
    Proposal execution
    Safety checks (anti-abuse)
*/

interface IERC20Token {
    function balanceOf(address account) external  view returns(uint256);
    function totalSupply() external view returns(uint256);
}

contract SimpleDAO {
    uint256 public constant VOTING_DURATION = 20; // blocks
    uint256 public constant EXECUTION_WINDOW = 20; // blocks
    uint256 public constant QUORUM_PERCENT = 20; // 20%

    IERC20Token immutable token;

    uint256 public proposalCount;

    mapping(address => uint256) public lastProposalBlock;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(address => bool) private executionLock;

    /* mapping(uint256 => address[]) private forVotes; // proposalId -> addressesVoted for
    mapping(uint256 => address[]) private againstVotes; // proposalId -> addressesVoted against
    mapping(uint256 => address[]) private totalVotes; // proposalId -> addressesVoted */

    struct Proposal {
        address target;
        uint256 value;
        bytes data;
        string description;

        uint256 creationBlock;
        uint256 votingDeadline;
        uint256 executionDeadline;

        uint256 snapshotTotalSupply;
        uint256 forVotes;
        uint256 againstVotes;

        ProposalStatus status;
    }

    // This is proposal lifecycle States
    /*  Pending → created, voting not started
        Active → voting open
        Succeeded → quorum met & votes passed
        Defeated → quorum not met or rejected
        Executed → action already performed
        Expired → not executed in time
    */
    enum ProposalStatus {
        PENDING,
        ACTIVE,
        SUCCEEDED,
        DEFEATED,
        EXECUTED,
        EXPIRED
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address tokenAddress) {
        token = IERC20Token(tokenAddress);
    }

    /*//////////////////////////////////////////////////////////////
                          PROPOSAL CREATION
    //////////////////////////////////////////////////////////////*/

    // This function should:
    /*
        -> Who can create proposals
        -> Porposal cooldown: "One proposal per address per X blocks"
        ->
    */
    function createProposal(
        address target,
        uint256 value,
        bytes calldata data,
        string calldata description
    ) external {
        require(token.balanceOf(msg.sender) > 10, "Insufficient tokens");
        require(target != address(0), "Invalid target");
        require(block.number > lastProposalBlock[msg.sender] + 20, "Cooldown");

        uint256 id = proposalCount++;

        Proposal storage p = proposals[id];

        p.target = target;
        p.value = value;
        p.data = data;
        p.description = description;

        p.creationBlock = block.number;
        p.votingDeadline = block.number + VOTING_DURATION;
        p.executionDeadline = p.votingDeadline + EXECUTION_WINDOW; // This is the time span we give the proposal to execute it, else it would be Expired

        // SNAPSHOT
        p.snapshotTotalSupply = token.totalSupply();

        p.status = ProposalStatus.PENDING;

        lastProposalBlock[msg.sender] = block.number;
    }

    function activateProposal(uint256 proposalId) public {
        require(block.number >= proposals[proposalId].creationBlock);
        proposals[proposalId].status = ProposalStatus.ACTIVE;
    }

    /*//////////////////////////////////////////////////////////////
                                VOTING
    //////////////////////////////////////////////////////////////*/

    // This function should
    /*
        -> Check balance when proposal was created
    */
    function vote(uint256 proposalId, bool support) external {
        Proposal storage p = proposals[proposalId];

        require(p.status == ProposalStatus.ACTIVE, "Not active");
        require(block.number <= p.votingDeadline, "Voting ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        uint256 weight = token.balanceOf(msg.sender);
        require(weight > 0, "No voting power");

        hasVoted[proposalId][msg.sender] = true;

        if (support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }
    }

    /*//////////////////////////////////////////////////////////////
                        FINALIZE / QUORUM CHECK
    //////////////////////////////////////////////////////////////*/

    function finalizeProposal(uint256 proposalId) public {
        Proposal storage p = proposals[proposalId];

        require(p.status == ProposalStatus.ACTIVE, "Already finalized");
        require(block.number > p.votingDeadline, "Voting not ended");

        uint256 totalVotes = p.forVotes + p.againstVotes;
        uint256 quorum = (p.snapshotTotalSupply * QUORUM_PERCENT) / 100;

        if (totalVotes < quorum) {
            p.status = ProposalStatus.DEFEATED;
            return;
        }

        if (p.forVotes > p.againstVotes) {
            p.status = ProposalStatus.SUCCEEDED;
        } else {
            p.status = ProposalStatus.DEFEATED;
        }
    }

    /*//////////////////////////////////////////////////////////////
                            EXECUTION
    //////////////////////////////////////////////////////////////*/

    function executeProposal(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];

        require(p.status == ProposalStatus.SUCCEEDED, "Not executable");
        require(block.number <= p.executionDeadline, "Execution expired");
        require(!executionLock[msg.sender], "Reentrancy"); // The same we did in previous contract, 

        // EFFECTS FIRST
        executionLock[msg.sender] = true;
        p.status = ProposalStatus.EXECUTED;

        (bool ok, ) = p.target.call{value: p.value}(p.data);
        require(ok, "Execution failed");

        executionLock[msg.sender] = false;
    }

    /*//////////////////////////////////////////////////////////////
                            HOUSEKEEPING
    //////////////////////////////////////////////////////////////*/

    function expireProposal(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];

        require(
            p.status == ProposalStatus.SUCCEEDED ||
            p.status == ProposalStatus.ACTIVE,
            "Cannot expire"
        );

        require(block.number > p.executionDeadline, "Still executable");

        p.status = ProposalStatus.EXPIRED;
    }

    receive() external payable {}
}