// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Ownable} from "openzeppelin/access/Ownable.sol";
import {Clones} from "openzeppelin/proxy/Clones.sol";

/// @title TLUniversalDeployer.sol
/// @notice Transient Labs universal deployer - a contract factory allowing for easy deployment of TL contracts
/// @dev This contract uses deterministic contract deployments (CREATE2)
/// @author transientlabs.xyz
/// @custom:version 1.0.0
contract TLUniversalDeployer is Ownable {

    /*//////////////////////////////////////////////////////////////////////////
                                Custom Types
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Struct defining a contract version that is deployable
    /// @param id A human readable string showing the version identifier
    /// @param address The implementation address
    struct ContractVersion {
        string id;
        address implementation;
    }

    /// @dev Struct defining a contract that is deployable
    /// @param created A boolean spcifying if the cloneable contract struct has been created or not
    /// @param type_ The contract type (human readable - ex: ERC721TL)
    /// @param versions An array of `ContractVersion` structs that are deployable
    struct DeployableContract {
        bool created;
        string type_;
        ContractVersion[] versions;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                State Variables
    //////////////////////////////////////////////////////////////////////////*/

    string public constant VERSION = "1.0.0";
    mapping(bytes32 => DeployableContract) private _deployableContracts; // keccak256(name) -> DeployableContract
    bytes32[] private _deployableContractKeys;

    /*//////////////////////////////////////////////////////////////////////////
                                    Events
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Event emitted whenever a contract is deployed
    /// @param sender The msg sender
    /// @param deployedContract The address of the deployed contract
    /// @param implementation The address of the implementation contract
    /// @param type_ The type of contract deployed
    /// @param version The version of contract deployed
    event ContractDeployed(address indexed sender, address indexed deployedContract, address indexed implementation, string type_, string version);

    /*//////////////////////////////////////////////////////////////////////////
                                Custom Errors
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Not a valid contract name
    error InvalidDeployableContract();

    /// @dev Initialization failed
    error InitializationFailed();

    /// @dev Contract already created
    error ContractAlreadyCreated();

    /*//////////////////////////////////////////////////////////////////////////
                                Constructor
    //////////////////////////////////////////////////////////////////////////*/

    /// @param initOwner The initial owner of the contract
    constructor(address initOwner) Ownable(initOwner) {}

    /*//////////////////////////////////////////////////////////////////////////
                                Deploy Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to deploy the latest version of a deployable contract
    /// @param contractType The contract type to deploy
    /// @param initializationCode The initialization code to call after contract deployment
    function deploy(string calldata contractType, bytes calldata initializationCode) external {
        // get DeployableContract
        bytes32 dcId = keccak256(bytes(contractType));
        DeployableContract memory dc = _deployableContracts[dcId];

        // verify contract is valid
        if (!dc.created) revert InvalidDeployableContract();
        if (dc.versions.length == 0) revert InvalidDeployableContract();

        // get latest version
        ContractVersion memory cv = dc.versions[dc.versions.length - 1];

        // deploy
        _deploy(dc, cv, initializationCode);
    }

    /// @notice Function to deploy the latest version of a cloneable contract
    /// @param contractType The contract type to deploy
    /// @param initializationCode The initialization code to call after contract deployment
    /// @param versionIndex The indeex of the `ContractVersion` to deploy
    function deploy(string calldata contractType, bytes calldata initializationCode, uint256 versionIndex) external {
        // get DeployableContract
        bytes32 dcId = keccak256(bytes(contractType));
        DeployableContract memory dc = _deployableContracts[dcId];

        // verify cloneable contract is valid
        if (!dc.created) revert InvalidDeployableContract();
        if (dc.versions.length == 0) revert InvalidDeployableContract();
        if (versionIndex >= dc.versions.length) revert InvalidDeployableContract();

        // get latest version
        ContractVersion memory cv = dc.versions[versionIndex];

        // deploy
        _deploy(dc, cv, initializationCode);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Admin Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to add a contract type
    /// @dev Restricted to only owner
    function addDeployableContract(string calldata type_, ContractVersion calldata version) external onlyOwner {
        // get DeployableContract
        bytes32 dcId = keccak256(bytes(type_));
        DeployableContract storage dc = _deployableContracts[dcId];

        // check to see if it's been created or not
        if (dc.created) revert ContractAlreadyCreated();

        // save to storage
        dc.created = true;
        dc.type_ = type_;
        dc.versions.push(version);
        _deployableContractKeys.push(dcId);
    }

    /// @notice Function to add a contract version
    /// @dev Restricted to only owner
    /// @dev Does not check if the version exists or not
    function addContractVersion(string calldata type_, ContractVersion calldata version) external onlyOwner {
        // get DeployableContract
        bytes32 dcId = keccak256(bytes(type_));
        DeployableContract storage dc = _deployableContracts[dcId];

        // verify contract is valid
        if (!dc.created) revert InvalidDeployableContract();

        // add version
        dc.versions.push(version);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Public Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to get contracts that can be deployed
    function getDeployableContracts() external view returns (DeployableContract[] memory) {
        DeployableContract[] memory dcs = new DeployableContract[](_deployableContractKeys.length);
        for (uint256 i = 0; i < _deployableContractKeys.length; i++) {
            dcs[i] = _deployableContracts[_deployableContractKeys[i]];
        }

        return dcs;
    }

    /// @notice Function to get a specific contract type
    /// @dev Does not revert for a `contractType` that doesn't exist
    /// @param contractType The contract type to look up
    function getDeployableContract(string calldata contractType) external view returns (DeployableContract memory) {
        bytes32 dcId = keccak256(bytes(contractType));
        DeployableContract memory dc = _deployableContracts[dcId];

        return dc;
    }

    /// @notice Function to predict the address at which a contract would be deployed
    /// @dev Predicts for the latest implementation
    /// @param contractType The contract type to deploy
    /// @param initializationCode The initialization code to call after contract deployment
    function predictDeployedContractAddress(string calldata contractType, bytes calldata initializationCode) external view returns (address) {
        // get DeployableContract
        bytes32 dcId = keccak256(bytes(contractType));
        DeployableContract memory dc = _deployableContracts[dcId];

        // verify contract is valid
        if (!dc.created) revert InvalidDeployableContract();
        if (dc.versions.length == 0) revert InvalidDeployableContract();

        // get latest version
        ContractVersion memory cv = dc.versions[dc.versions.length - 1];

        // create salt by hashing the sender and init code
        bytes32 salt = keccak256(abi.encodePacked(
            msg.sender, 
            initializationCode
        ));

        // predict
        return Clones.predictDeterministicAddress(cv.implementation, salt);
    }

    /// @notice Function to predict the address at which a contract would be deployed
    /// @dev Predicts for a specific implementation
    /// @param contractType The contract type to deploy
    /// @param initializationCode The initialization code to call after contract deployment
    /// @param versionIndex The indeex of the `ContractVersion` to deploy
    function predictDeployedContractAddress(string calldata contractType, bytes calldata initializationCode, uint256 versionIndex) external view returns (address) {
        // get DeployableContract
        bytes32 dcId = keccak256(bytes(contractType));
        DeployableContract memory dc = _deployableContracts[dcId];

        // verify contract is valid
        if (!dc.created) revert InvalidDeployableContract();
        if (dc.versions.length == 0) revert InvalidDeployableContract();
        if (versionIndex >= dc.versions.length) revert InvalidDeployableContract();

        // get latest version
        ContractVersion memory cv = dc.versions[versionIndex];

        // create salt by hashing the sender and init code
        bytes32 salt = keccak256(abi.encodePacked(
            msg.sender, 
            initializationCode
        ));

        // predict
        return Clones.predictDeterministicAddress(cv.implementation, salt);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Private Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Private function to deploy contracts
    function _deploy(DeployableContract memory dc, ContractVersion memory cv, bytes memory initializationCode) private {
        // create salt by hashing the sender and init code
        bytes32 salt = keccak256(abi.encodePacked(
            msg.sender, 
            initializationCode
        ));

        // clone
        address deployedContract = Clones.cloneDeterministic(cv.implementation, salt);

        // initialize
        (bool success, ) = deployedContract.call(initializationCode);
        if (!success) revert InitializationFailed();

        // emit event
        emit ContractDeployed(msg.sender, deployedContract, cv.implementation, dc.type_, cv.id);
    }
}