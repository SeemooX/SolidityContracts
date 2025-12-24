// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/* What to mix/add this contract with:
                                        -> If bid happens in last X minutes → extend auction
                                        -> ERC721 Integration: Auction holds an NFT, Transfers NFT to winner after end
                                        -> Fee Mechanism: Platform fee (e.g., 2%), Remaining goes to seller
 */

/**       WHAT I LEARNED
 * For security reasons never ""auto-refund on bid"", store the value to return of an address in mapping, and let him call the withdraw himself, because of:
                                                                                                                                                            * Attacker bids
                                                                                                                                                            * Gets outbid
                                                                                                                                                            * Their refund requires interaction
                                                                                                                                                            * They use a malicious fallback
                                                                                                                                                            * If contract auto-refunds → auction breaks
 * Front-running means someone sees your transaction before it’s executed and sneaks in the same action with higher priority, blockchain-level reality, not a Solidity bug
 * Front-running = “I saw your bid before it was mined and beat you to it.”
 * Bid griefing = “I don’t want to win, I just want to break the auction.”
 */

contract EnglishAuction {
    address private seller;
    address private contractOwner;
    uint256 private immutable auctionStartTime;
    uint256 private immutable auctionEndTime;
    uint256 private immutable minimumBid;
    bool private isEnded; // Prevents double finalization
    address private highestBidder;
    uint256 private highestBid;
    mapping(address => uint256) pendingReturns; // This will be used to wait a time, then send the funds to the outbidding bidder
    uint256 private ownerportion;

    event AuctionStarted(
        uint256 startTime,
        uint256 endTime,
        uint256 minimumBid
    );
    event BidPlaced(address bidder, uint256 amount);
    event BidWithdrawn(address bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);

    constructor(
        address theSeller,
        uint256 startTime,
        uint256 endTime,
        uint256 minimum
    ) {
        seller = theSeller;
        contractOwner = msg.sender;
        auctionStartTime = startTime;
        auctionEndTime = endTime;
        minimumBid = minimum;
        emit AuctionStarted(auctionStartTime, auctionEndTime, minimumBid);
    }

    function placeBid() external payable {
        require(block.timestamp >= auctionStartTime);
        require(block.timestamp < auctionEndTime, "The auction time has ended");
        require(msg.sender != address(0), "Address is null");
        require(
            msg.value > highestBid,
            "The value you entered is not greater that the bidder"
        );
        require(msg.value >= minimumBid, "there is threshold to the bid");
        require(
            isEnded == false,
            "You can not bid, the time auction has ended"
        );

        pendingReturns[highestBidder] = highestBid;
        highestBid = msg.value;
        highestBidder = msg.sender;

        emit BidPlaced(msg.sender, highestBid);
    }

    function withdraw() external {
        require(
            pendingReturns[msg.sender] > 0,
            "You don't have any funds here"
        );
        uint256 amountToReturn = pendingReturns[msg.sender];
        pendingReturns[msg.sender] = 0;
        (bool ok, ) = msg.sender.call{value: amountToReturn}("");
        if (!ok) {
            revert("Something happend when withdrawing");
        }

        emit BidWithdrawn(msg.sender, amountToReturn);
    }

    function endAuction() external onlySeller {
        require(block.timestamp >= auctionEndTime, "Auction not ended yet");
        require(highestBid != 0, "No one bid");
        if (isEnded) {
            revert("You already called this function");
        }
        uint256 sellerPortion = (highestBid * 19) / 20; // 95% of the highestBid
        ownerportion = (highestBid * 1 / 20);
        highestBid = 0;
        (bool ok, ) = contractOwner.call{value: ownerportion}("");
        (bool ok1, ) = msg.sender.call{value: sellerPortion}("");
        isEnded = true;

        if (!ok1 && ok) {
            revert("Something happend when withdrawing");
        }
        emit AuctionEnded(highestBidder, sellerPortion + ownerportion);
    }

    function cancelAAuction() external onlySeller {
        /*  Must require no bids
            Must mark auction ended
            Must refund nothing (since no bids)
        */
    }

    function getTimeLeft() public view returns (uint256) {
        return auctionEndTime - block.timestamp;
    }

    modifier onlySeller() {
        if (seller != msg.sender) {
            revert("You are not the owner");
        }
        _;
    }
    
    /* function ownerPortion() external onlyOwner{
        require(auctionEndTime > block.timestamp, "You still cannt call this function");
        require(highestBid != 0, "No one bid");
        if(isEnded) {
            revert("You already called this function");
        }
        // I sent the money before, because i am sure the owner is an account
        ownerportion = highestBid * 1/50; // 95% of the highestBid
        (bool ok, ) = contractOwner.call{value: ownerportion}("");

        if(!ok) {
            revert("Something happend when withdrawing");
        }
    } */
    /* modifier onlyOwner() {
        if(contractOwner != msg.sender) {
            revert("You are not the owner");
        }
        _;
    } */
}
