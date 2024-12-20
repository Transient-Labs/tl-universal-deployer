// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std-1.9.4/Script.sol";
import {Strings} from "@openzeppelin-contracts-5.0.2/utils/Strings.sol";

interface ICreate2Deployer {
    function deploy(uint256 value, bytes32 salt, bytes memory code) external;
    function computeAddress(bytes32 salt, bytes32 codeHash) external view returns (address);
}

contract Deploy is Script {
    using Strings for address;

    function run() public {
        // get environment variables
        ICreate2Deployer create2Deployer = ICreate2Deployer(vm.envAddress("CREATE2_DEPLOYER"));
        bytes memory constructorArgs = vm.envBytes("CONSTRUCTOR_ARGS");
        bytes32 salt = vm.envBytes32("SALT");

        // get bytecode
        bytes memory bytecode = abi.encodePacked(vm.getCode("TLUniversalDeployer.sol:TLUniversalDeployer"), constructorArgs);

        // deploy
        address deployedContract = create2Deployer.computeAddress(salt, keccak256(bytecode));
        vm.broadcast();
        create2Deployer.deploy(0, salt, bytecode);

        // save deployed contract address
        vm.writeLine("out.txt", deployedContract.toHexString());
    }
}
