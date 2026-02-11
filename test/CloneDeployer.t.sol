// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std-1.14.0/Test.sol";
import {Ownable} from "@openzeppelin-contracts-5.0.2/access/Ownable.sol";
import {CloneDeployer} from "src/CloneDeployer.sol";
import {ERC721} from "test/utils/ERC721.sol";

contract CloneDeployerTest is Test {
    CloneDeployer public cloneDeployer;
    ERC721 public erc721Implementation;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ContractDeployed(
        address indexed sender,
        address indexed deployedContract,
        address indexed implementation
    );
    bytes32 internal constant CONTRACT_DEPLOYED_TOPIC =
        keccak256("ContractDeployed(address,address,address)");

    function setUp() public {
        cloneDeployer = new CloneDeployer(address(this));
        erc721Implementation = new ERC721();
    }

    function test_constructor(address initOwner) public {
        vm.assume(initOwner != address(0));

        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferred(address(0), initOwner);
        CloneDeployer dep = new CloneDeployer(initOwner);

        assertEq(dep.owner(), initOwner);
        assertEq(dep.VERSION(), "1.1.0");
    }

    function test_deploy_emitsAndInitializesClone(address sender, address initOwner, string memory name, string memory symbol)
        public
    {
        vm.assume(initOwner != address(0));

        bytes memory initCode = abi.encodeWithSelector(ERC721.initialize.selector, initOwner, name, symbol);

        vm.recordLogs();
        vm.prank(sender);
        cloneDeployer.deploy(address(erc721Implementation), initCode);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 matchingLogIndex = _findContractDeployedLog(logs, address(cloneDeployer));
        Vm.Log memory deployedLog = logs[matchingLogIndex];

        assertEq(address(uint160(uint256(deployedLog.topics[1]))), sender);
        assertEq(address(uint160(uint256(deployedLog.topics[3]))), address(erc721Implementation));

        address clone = address(uint160(uint256(deployedLog.topics[2])));
        assertTrue(clone != address(0));
        assertTrue(clone != address(erc721Implementation));
        assertGt(clone.code.length, 0);

        ERC721 deployedClone = ERC721(clone);
        assertEq(deployedClone.owner(), initOwner);
        assertEq(deployedClone.name(), name);
        assertEq(deployedClone.symbol(), symbol);
        assertEq(deployedClone.balanceOf(initOwner), 1);
        assertEq(deployedClone.ownerOf(1), initOwner);
    }

    function test_deploy_createsUniqueClonesOnRepeatedCalls(address sender, address initOwner, string memory name, string memory symbol)
        public
    {
        vm.assume(initOwner != address(0));

        bytes memory initCode = abi.encodeWithSelector(ERC721.initialize.selector, initOwner, name, symbol);

        vm.recordLogs();
        vm.startPrank(sender);
        cloneDeployer.deploy(address(erc721Implementation), initCode);
        cloneDeployer.deploy(address(erc721Implementation), initCode);
        vm.stopPrank();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        address[] memory deployedContracts = _extractDeployedContracts(logs, address(cloneDeployer), 2);
        address firstClone = deployedContracts[0];
        address secondClone = deployedContracts[1];

        assertTrue(firstClone != secondClone);
        assertGt(firstClone.code.length, 0);
        assertGt(secondClone.code.length, 0);

        assertEq(ERC721(firstClone).owner(), initOwner);
        assertEq(ERC721(secondClone).owner(), initOwner);
    }

    function test_deploy_revertsWhenInitializationFails(address sender) public {
        bytes memory invalidInitCode = abi.encodeWithSignature("doesNotExist()");

        vm.prank(sender);
        vm.expectRevert(CloneDeployer.InitializationFailed.selector);
        cloneDeployer.deploy(address(erc721Implementation), invalidInitCode);
    }

    function test_deploy_revertsWhenInitializerReverts(address sender) public {
        bytes memory invalidInitCode = abi.encodeWithSelector(ERC721.initialize.selector, address(0), "Name", "SYM");

        vm.prank(sender);
        vm.expectRevert(CloneDeployer.InitializationFailed.selector);
        cloneDeployer.deploy(address(erc721Implementation), invalidInitCode);
    }

    function test_deploy_callableByNonOwner(
        address ownerAddress,
        address nonOwner,
        address initOwner,
        string memory name,
        string memory symbol
    ) public {
        vm.assume(ownerAddress != address(0));
        vm.assume(nonOwner != ownerAddress);
        vm.assume(initOwner != address(0));

        CloneDeployer dep = new CloneDeployer(ownerAddress);
        bytes memory initCode = abi.encodeWithSelector(ERC721.initialize.selector, initOwner, name, symbol);

        vm.recordLogs();
        vm.prank(nonOwner);
        dep.deploy(address(erc721Implementation), initCode);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 matchingLogIndex = _findContractDeployedLog(logs, address(dep));
        assertEq(address(uint160(uint256(logs[matchingLogIndex].topics[1]))), nonOwner);
    }

    function test_transferOwnership_isOwnerOnly(address hacker, address newOwner) public {
        vm.assume(hacker != address(this));

        vm.prank(hacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, hacker));
        cloneDeployer.transferOwnership(newOwner);
    }

    function _findContractDeployedLog(Vm.Log[] memory logs, address emitter) internal pure returns (uint256) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == emitter && logs[i].topics[0] == CONTRACT_DEPLOYED_TOPIC) {
                return i;
            }
        }

        revert("ContractDeployed log not found");
    }

    function _extractDeployedContracts(Vm.Log[] memory logs, address emitter, uint256 expectedCount)
        internal
        pure
        returns (address[] memory)
    {
        address[] memory deployedContracts = new address[](expectedCount);
        uint256 found;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == emitter && logs[i].topics[0] == CONTRACT_DEPLOYED_TOPIC) {
                if (found >= expectedCount) revert("unexpected ContractDeployed count");
                deployedContracts[found] = address(uint160(uint256(logs[i].topics[2])));
                found++;
            }
        }

        if (found != expectedCount) revert("missing ContractDeployed logs");
        return deployedContracts;
    }
}
