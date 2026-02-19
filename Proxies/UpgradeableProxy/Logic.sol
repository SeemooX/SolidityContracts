// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract Logic {
    string private name;
    string private symbol;
    address private contractOwner;
    string[] private tokens;
    uint256 private currentId = 0;
    mapping (uint256 => string ) tokenIdToTokenURI;
    mapping (uint256 => address) userOwnership;
    mapping (address => uint256) userBalance; // How many tokens the user has
    mapping (uint256 => address ) tokenApprovals;
    mapping (address => mapping(address => bool)) operatorApprovals; // This will make an address have controle over another addresses all NFTs related to this contract assetes

    function initiatlize(string memory collectionName, string memory collectionSymbol) external {
        require(contractOwner == address(0), "Already initialized");
        name = collectionName;
        symbol = collectionSymbol;
        contractOwner = msg.sender;
    }

    function tokenURI(uint256 tokenID) public view returns(string memory) {
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
        operatorApprovals[msg.sender][operator] = approved; // The msg.sender is apporving the operator to take controle over his assets in this contract, by getting access controle
    }

    function isApprovedForAll(
        address owner,
        address operator
    ) public view returns (bool) {
        return operatorApprovals[owner][operator];
    }

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
        require(msg.sender != address(0), "You can not");
        require(userOwnership[currentId] == address(0));
        userOwnership[currentId] = msg.sender;
        currentId++;
        userBalance[msg.sender]++;
    }

    function burn(uint256 tokenId) external {
        require(msg.sender != address(0), "You can not");
        if (userOwnership[tokenId] != msg.sender) {
            revert("You don't have this NFT to burn");
        }
        userBalance[msg.sender]--;
        userOwnership[tokenId] = address(0);
    }

    function contractName() external view returns (string memory) {
        return name;
    }

    function contractSymbol() external view returns (string memory) {
        return symbol;
    }

    receive() external payable {
        if(msg.value > 0) {
            (bool ok,) = address(contractOwner).call{value: msg.value}("");
            require(ok, "Failed to send");
        }
    }
}