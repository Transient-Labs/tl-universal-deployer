// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC1155Upgradeable} from "openzeppelin-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

contract ERC1155 is ERC1155Upgradeable, OwnableUpgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize(address initOwner, string memory uri, uint256 num) external initializer {
        __ERC1155_init(uri);
        __Ownable_init(initOwner);

        _mint(initOwner, 1, num, "");
    }
}
