// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract SimpleNFT is ERC721 {
    constructor() ERC721("SimpleNFT", "SNFT") {}

    function mint(address to, uint256 tokenId) public {
        _safeMint(to, tokenId);
    }
}
