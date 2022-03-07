//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "@openzeppelin/contracts/utils/Counters.sol";

import "hardhat/console.sol";

contract simpleNFT is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("TEST NFT", "TTFT") {
        console.log("Done initialized");
    }

    function simpleMint() external {
        uint256 newItemId = _tokenIds.current();
        _tokenIds.increment();

        _safeMint(msg.sender, newItemId);

        console.log("Minted");
    }
}
