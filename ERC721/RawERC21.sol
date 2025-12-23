// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/*
tokenURI() → URL
URL → JSON
JSON → image + attributes
*/

/* *           WHAT I LEARNED
* Solidity/EVM distinguished:
                            -> Externally Owned Accounts(EOAs), which are just wallets: wallets do not have code/bytecode
                            -> Contracts, which are just deployed bytcode: Contract does have the code/bytecode
* These two are the same: IERC721Receiver.onERC721Received.selector <==> IERC721Receiver.onERC721Received.selector
*/

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
    // The returned value is already applied on keccak, and wrapped in bytes4
}

contract RawERC721 {
    string private name;
    string private symbol;
    address private contractOwner;

    // This struct way, to do it after
    /* struct Owns {
        string[] tokensOwned;
        uint256 balance;
    } */

    string[] private tokens;
    uint256 private currentId = 0;
    mapping(uint256 => string) tokenIdToTokenURI;
    mapping(uint256 => address) userOwnership;
    mapping(address => uint256) userBalance;
    mapping(uint256 => address) tokenApprovals;
    mapping(address => mapping(address => bool)) operatorApprovals;
    /* mapping(address => Owns) userOwnership; */

    constructor(string memory collectionName, string memory collectionSymbol) {
        name = collectionName;
        symbol = collectionSymbol;
        contractOwner = msg.sender;
    }

    function tokenURI(uint256 tokenID) public view returns (string memory) {
        return tokenIdToTokenURI[tokenID];
    }

    function balanceOf(address user) external view returns (uint256) {
        require(user != address(0), "You entered a Null address");
        return userBalance[user];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        require(
            userOwnership[tokenId] != address(0),
            "The the token does not exist, or Burned"
        );
        return userOwnership[tokenId];
    }

    function setApproveForAll(address operator, bool approved) external {
        require(operator != msg.sender, "Cannot approve self");
        operatorApprovals[msg.sender][operator] = approved;
    }

    function isApprovedForAll(
        address owner,
        address operator
    ) public view returns (bool) {
        return operatorApprovals[owner][operator];
    }

    // Owner can approve
    // Approved operator can approve on owner’s behalf
    function approveToken(address spender, uint256 tokenId) external {
        require(spender != address(0), "You can not approve a Null address");
        require(userOwnership[tokenId] == msg.sender || operatorApprovals[userOwnership[tokenId]][msg.sender], "Not owner");
        tokenApprovals[tokenId] = spender;
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        require(
            operatorApprovals[from][msg.sender] == true || tokenApprovals[tokenId] == msg.sender || from == msg.sender,
            "You could not send this token"
        );
        require(
            from != address(0) && to != address(0),
            "You can not send or receive with an Null address"
        );
        require(userOwnership[tokenId] == from, "It is not right");
        require(userOwnership[tokenId] != address(0), "There is no token");
        tokenApprovals[tokenId] = address(0);
        userBalance[from]--;
        userOwnership[tokenId] = to;
        userBalance[to]++;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external {
        require(
            operatorApprovals[from][msg.sender] == true || tokenApprovals[tokenId] == msg.sender || from == msg.sender,
            "You could not send this token"
        );
        require(
            from != address(0) && to != address(0),
            "You can not send or receive with an Null address"
        );
        require(userOwnership[tokenId] == from, "It is not right");
        require(userOwnership[tokenId] != address(0), "There is no token");
        tokenApprovals[tokenId] = address(0);
        userBalance[from]--;
        userBalance[to]++;
        userOwnership[tokenId] = to;
        if (to.code.length > 0) {
            bytes4 data = IERC721Receiver(to).onERC721Received(
                msg.sender,
                from,
                tokenId,
                ""
            );
            if (
                bytes4(data) !=
                bytes4(
                    keccak256("onERC721Received(address,address,uint256,bytes)")
                )
            ) {
                revert("This contract address does not support ERC721");
            }
        }
    }

    function mint() external {
        // This is a basing minting we will, do whitlist ones after, and an account can mint one time..
        require(msg.sender != address(0), "You can not");
        require(userOwnership[currentId] == address(0));
        userOwnership[currentId] = msg.sender;
        // I didn't use minted[tokenId] = true, since the tokenId it determined to be always for one NFT, never another even when burned
        currentId++;
        userBalance[msg.sender]++;
        // I will add the events later
    }

    function burn(uint256 tokenId) external {
        require(msg.sender != address(0), "You can not");
        if (userOwnership[tokenId] != msg.sender) {
            revert("You don't have this NFT to burn");
        }
        userBalance[msg.sender]--;
        userOwnership[tokenId] = address(0);
        // I will add the events later
    }

    function contractName() external view returns (string memory) {
        return name;
    }

    function contractSymbol() external view returns (string memory) {
        return symbol;
    }

    /* modifier onlyOwner() {
        if(msg.sender != contractOwner) {
            revert("You can not call this function");
        }
        _;
    } */

        /* function approveTokens(
        address spender,
        uint256[] memory tokenIds
    ) external {
        require(spender != address(0), "You can not approve a Null address");
        for (uint i = 0; i < tokenIds.length; i++) {
            require(
                userOwnership[tokenIds[i]] == msg.sender,
                "You can not send or receive with an Null address"
            );
            tokenApprovals[tokenIds[i]] = spender;
        }
    } */
}
