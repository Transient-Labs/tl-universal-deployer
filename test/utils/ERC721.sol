// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC721Upgradeable} from "@openzeppelin-contracts-upgradeable-5.0.2/token/ERC721/ERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin-contracts-upgradeable-5.0.2/access/OwnableUpgradeable.sol";

contract ERC721 is ERC721Upgradeable, OwnableUpgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize(address initOwner, string memory name, string memory symbol) external initializer {
        __ERC721_init(name, symbol);
        __Ownable_init(initOwner);

        _mint(initOwner, 1);
    }
}
