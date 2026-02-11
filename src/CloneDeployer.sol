// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Ownable} from "@openzeppelin-contracts-5.0.2/access/Ownable.sol";
import {Clones} from "@openzeppelin-contracts-5.0.2/proxy/Clones.sol";

/// @title CloneDeployer.sol
/// @notice A contract that facilitates deploying ERC-1167 minimal proxies
/// @author transientlabs.xyz
/// @custom:version 1.1.0
contract CloneDeployer is Ownable {

    /*//////////////////////////////////////////////////////////////////////////
                                State Variables
    //////////////////////////////////////////////////////////////////////////*/

    string public constant VERSION = "1.1.0";

    /*//////////////////////////////////////////////////////////////////////////
                                    Events
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Event emitted whenever a contract is deployed
    /// @param sender The msg sender
    /// @param deployedContract The address of the deployed contract
    /// @param implementation The address of the implementation contract
    event ContractDeployed(
        address indexed sender,
        address indexed deployedContract,
        address indexed implementation
    );

    /*//////////////////////////////////////////////////////////////////////////
                                    Errors
    //////////////////////////////////////////////////////////////////////////*/
    error InitializationFailed();

    /*//////////////////////////////////////////////////////////////////////////
                                Constructor
    //////////////////////////////////////////////////////////////////////////*/

    /// @param initOwner The initial owner of the contract
    constructor(address initOwner) Ownable(initOwner) {}

    /*//////////////////////////////////////////////////////////////////////////
                                Deploy Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to deploy an ERC-1167 proxy
    /// @param implementationAddress The contract address that is the implementation
    /// @param initializationCode The initialization code to call after contract deployment
    function deploy(address implementationAddress, bytes calldata initializationCode) external {
        // clone
        address deployedContract = Clones.clone(implementationAddress);

        // initialize
        (bool success,) = deployedContract.call(initializationCode);
        if (!success) revert InitializationFailed();

        // emit event
        emit ContractDeployed(msg.sender, deployedContract, implementationAddress);
    }
}
