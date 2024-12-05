// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std-1.9.4/Test.sol";
import {Strings} from "@openzeppelin-contracts-5.0.2/utils/Strings.sol";
import {Clones, Ownable, TLUniversalDeployer} from "src/TLUniversalDeployer.sol";
import {ERC721} from "test/utils/ERC721.sol";
import {ERC1155} from "test/utils/ERC1155.sol";

contract TLUniversalDeployerTest is Test {
    using Strings for uint256;

    TLUniversalDeployer public tlud;
    ERC721 public erc721;
    ERC1155 public erc1155;
    ERC721 public erc721v2;
    ERC1155 public erc1155v2;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ContractDeployed(
        address indexed sender,
        address indexed deployedContract,
        address indexed implementation,
        string cType,
        string version
    );

    function setUp() public {
        tlud = new TLUniversalDeployer(address(this));
        erc721 = new ERC721();
        erc1155 = new ERC1155();
        erc721v2 = new ERC721();
        erc1155v2 = new ERC1155();
    }

    /// @dev Test constructor
    function test_constructor(address initOwner) public {
        // limit fuzz
        vm.assume(initOwner != address(0));

        // deploy
        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferred(address(0), initOwner);
        TLUniversalDeployer dep = new TLUniversalDeployer(initOwner);

        // test init values
        assertEq(dep.owner(), initOwner);
        string[] memory dcs = dep.getDeployableContracts();
        assertEq(dcs.length, 0);
    }

    /// @dev Test access controlled functions
    function test_accessControl(address hacker, string memory id, address implementation) public {
        // limit fuzz
        vm.assume(hacker != address(this));

        // create contract version
        TLUniversalDeployer.ContractVersion memory cv =
            TLUniversalDeployer.ContractVersion({id: id, implementation: implementation});

        // test if hacker can access admin functions
        vm.startPrank(hacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, hacker));
        tlud.addDeployableContract("ERC721", cv);
        vm.stopPrank();

        // invariant
        string[] memory dcs = tlud.getDeployableContracts();
        assertEq(dcs.length, 0);
    }

    /// @dev Test adding contract types
    function test_addDeployableContract(uint256 numContracts) public {
        // limit fuzz
        if (numContracts > 200) {
            numContracts = numContracts % 200;
        }

        // variables
        string memory contractType;
        string[] memory dcs;
        TLUniversalDeployer.ContractVersion memory cv;
        TLUniversalDeployer.DeployableContract memory dc;

        // loop and create
        for (uint256 i = 0; i < numContracts; i++) {
            contractType = string(abi.encodePacked("Contract_", i.toString()));
            cv = TLUniversalDeployer.ContractVersion("1", address(uint160(i)));
            tlud.addDeployableContract(contractType, cv);
            dcs = tlud.getDeployableContracts();
            dc = tlud.getDeployableContract(contractType);
            assertEq(dcs[dcs.length - 1], contractType);
            assertTrue(dc.created);
            assertEq(dc.cType, contractType);
            assertEq(dc.versions.length, 1);
            assertEq(dc.versions[0].id, "1");
            assertEq(dc.versions[0].implementation, address(uint160(i)));
        }

        // invariant
        assertEq(dcs.length, numContracts);
    }

    /// @dev Test adding contract versions
    function test_addDeployableContract_versions(uint256 numVersions) public {
        // limit fuzz
        if (numVersions > 200) {
            numVersions = numVersions % 200;
        }
        if (numVersions == 0) {
            numVersions = 1;
        }
        // variables
        string[] memory dcs;
        TLUniversalDeployer.ContractVersion memory cv;
        TLUniversalDeployer.DeployableContract memory dc;

        // create first version
        cv = TLUniversalDeployer.ContractVersion("0", address(0));
        tlud.addDeployableContract("DC", cv);
        dc = tlud.getDeployableContract("DC");

        // loop and add versions
        for (uint256 i = 1; i < numVersions; i++) {
            cv = TLUniversalDeployer.ContractVersion(i.toString(), address(uint160(i)));
            tlud.addDeployableContract("DC", cv);
            dcs = tlud.getDeployableContracts();
            assertEq(dcs.length, 1);
            dc = tlud.getDeployableContract("DC");
            cv = dc.versions[i];
            assertEq(cv.id, i.toString());
            assertEq(cv.implementation, address(uint160(i)));
        }

        // invariant
        assertEq(dc.versions.length, numVersions);
    }

    /// @dev Test deploying latest contracts
    function test_deploy_latest(
        address sender,
        address initOwnerOne,
        address initOwnerTwo,
        string memory name,
        string memory symbol,
        string memory uri,
        uint256 num
    ) public {
        // limit fuzz
        vm.assume(initOwnerOne != address(0));
        vm.assume(initOwnerTwo != address(0));
        vm.assume(initOwnerTwo.code.length == 0); // 1155 can't be minted to contract

        // create init codes
        bytes memory init721 = abi.encodeWithSelector(ERC721.initialize.selector, initOwnerOne, name, symbol);
        bytes memory init1155 = abi.encodeWithSelector(ERC1155.initialize.selector, initOwnerTwo, uri, num);

        // try deploying invalid deployable contracts
        vm.expectRevert(TLUniversalDeployer.InvalidDeployableContract.selector);
        tlud.deploy("ERC721", init721);
        vm.expectRevert(TLUniversalDeployer.InvalidDeployableContract.selector);
        tlud.predictDeployedContractAddress(sender, "ERC721", init721);
        vm.expectRevert(TLUniversalDeployer.InvalidDeployableContract.selector);
        tlud.deploy("ERC1155", init1155);
        vm.expectRevert(TLUniversalDeployer.InvalidDeployableContract.selector);
        tlud.predictDeployedContractAddress(sender, "ERC1155", init1155);

        // created deployable contracts
        TLUniversalDeployer.ContractVersion memory cv;
        cv = TLUniversalDeployer.ContractVersion("1", address(erc721));
        tlud.addDeployableContract("ERC721", cv);
        cv = TLUniversalDeployer.ContractVersion("2", address(erc721v2));
        tlud.addDeployableContract("ERC721", cv);
        cv = TLUniversalDeployer.ContractVersion("1", address(erc1155));
        tlud.addDeployableContract("ERC1155", cv);
        cv = TLUniversalDeployer.ContractVersion("2", address(erc1155v2));
        tlud.addDeployableContract("ERC1155", cv);

        // predict contract addresses
        address c721 = tlud.predictDeployedContractAddress(sender, "ERC721", init721);
        address c1155 = tlud.predictDeployedContractAddress(sender, "ERC1155", init1155);

        // deploy contracts
        vm.startPrank(sender);
        vm.expectEmit(true, true, true, true);
        emit ContractDeployed(sender, c721, address(erc721v2), "ERC721", "2");
        tlud.deploy("ERC721", init721);

        vm.expectEmit(true, true, true, true);
        emit ContractDeployed(sender, c1155, address(erc1155v2), "ERC1155", "2");
        tlud.deploy("ERC1155", init1155);
        vm.stopPrank();

        // check deployed contract data
        ERC721 d721 = ERC721(c721);
        assertEq(d721.owner(), initOwnerOne);
        assertEq(d721.name(), name);
        assertEq(d721.symbol(), symbol);
        assertEq(d721.balanceOf(initOwnerOne), 1);
        assertEq(d721.ownerOf(1), initOwnerOne);

        ERC1155 d1155 = ERC1155(c1155);
        assertEq(d1155.owner(), initOwnerTwo);
        assertEq(d1155.uri(1), uri);
        assertEq(d1155.balanceOf(initOwnerTwo, 1), num);

        // try deploying again (reverts)
        vm.startPrank(sender);
        vm.expectRevert(Clones.ERC1167FailedCreateClone.selector);
        tlud.deploy("ERC721", init721);

        vm.expectRevert(Clones.ERC1167FailedCreateClone.selector);
        tlud.deploy("ERC1155", init1155);
        vm.stopPrank();

        // try deploying with invalid init code (reverts)
        vm.startPrank(sender);
        vm.expectRevert(TLUniversalDeployer.InitializationFailed.selector);
        tlud.deploy("ERC721", init1155);

        vm.expectRevert(TLUniversalDeployer.InitializationFailed.selector);
        tlud.deploy("ERC1155", init721);
        vm.stopPrank();
    }

    /// @dev Test deploying specific contract version
    function test_deploy_specificVersion(
        address sender,
        address initOwnerOne,
        address initOwnerTwo,
        string memory name,
        string memory symbol,
        string memory uri,
        uint256 num
    ) public {
        // limit fuzz
        vm.assume(initOwnerOne != address(0));
        vm.assume(initOwnerTwo != address(0));
        vm.assume(initOwnerTwo.code.length == 0); // 1155 can't be minted to contract

        // create init codes
        bytes memory init721 = abi.encodeWithSelector(ERC721.initialize.selector, initOwnerOne, name, symbol);
        bytes memory init1155 = abi.encodeWithSelector(ERC1155.initialize.selector, initOwnerTwo, uri, num);

        // try deploying invalid deployable contracts
        vm.expectRevert(TLUniversalDeployer.InvalidDeployableContract.selector);
        tlud.deploy("ERC721", init721, 0);
        vm.expectRevert(TLUniversalDeployer.InvalidDeployableContract.selector);
        tlud.predictDeployedContractAddress(sender, "ERC721", init721, 0);
        vm.expectRevert(TLUniversalDeployer.InvalidDeployableContract.selector);
        tlud.deploy("ERC1155", init1155, 0);
        vm.expectRevert(TLUniversalDeployer.InvalidDeployableContract.selector);
        tlud.predictDeployedContractAddress(sender, "ERC1155", init1155, 0);

        // created deployable contracts
        TLUniversalDeployer.ContractVersion memory cv;
        cv = TLUniversalDeployer.ContractVersion("1", address(erc721));
        tlud.addDeployableContract("ERC721", cv);
        cv = TLUniversalDeployer.ContractVersion("2", address(erc721v2));
        tlud.addDeployableContract("ERC721", cv);
        cv = TLUniversalDeployer.ContractVersion("1", address(erc1155));
        tlud.addDeployableContract("ERC1155", cv);
        cv = TLUniversalDeployer.ContractVersion("2", address(erc1155v2));
        tlud.addDeployableContract("ERC1155", cv);

        // try deploying invalid deployable contracts - invalid index
        vm.expectRevert(TLUniversalDeployer.InvalidDeployableContract.selector);
        tlud.deploy("ERC721", init721, 2);
        vm.expectRevert(TLUniversalDeployer.InvalidDeployableContract.selector);
        tlud.predictDeployedContractAddress(sender, "ERC721", init721, 2);
        vm.expectRevert(TLUniversalDeployer.InvalidDeployableContract.selector);
        tlud.predictDeployedContractAddress(sender, "ERC1155", init1155, 2);

        // predict contract addresses
        address c721 = tlud.predictDeployedContractAddress(sender, "ERC721", init721, 0);
        address c1155 = tlud.predictDeployedContractAddress(sender, "ERC1155", init1155, 0);

        // deploy contracts
        vm.startPrank(sender);
        vm.expectEmit(true, true, true, true);
        emit ContractDeployed(sender, c721, address(erc721), "ERC721", "1");
        tlud.deploy("ERC721", init721, 0);

        vm.expectEmit(true, true, true, true);
        emit ContractDeployed(sender, c1155, address(erc1155), "ERC1155", "1");
        tlud.deploy("ERC1155", init1155, 0);
        vm.stopPrank();

        // check deployed contract data
        ERC721 d721 = ERC721(c721);
        assertEq(d721.owner(), initOwnerOne);
        assertEq(d721.name(), name);
        assertEq(d721.symbol(), symbol);
        assertEq(d721.balanceOf(initOwnerOne), 1);
        assertEq(d721.ownerOf(1), initOwnerOne);

        ERC1155 d1155 = ERC1155(c1155);
        assertEq(d1155.owner(), initOwnerTwo);
        assertEq(d1155.uri(1), uri);
        assertEq(d1155.balanceOf(initOwnerTwo, 1), num);

        // try deploying again (reverts)
        vm.startPrank(sender);
        vm.expectRevert(Clones.ERC1167FailedCreateClone.selector);
        tlud.deploy("ERC721", init721, 0);

        vm.expectRevert(Clones.ERC1167FailedCreateClone.selector);
        tlud.deploy("ERC1155", init1155, 0);
        vm.stopPrank();

        // try deploying with invalid init code (reverts)
        vm.startPrank(sender);
        vm.expectRevert(TLUniversalDeployer.InitializationFailed.selector);
        tlud.deploy("ERC721", init1155, 0);

        vm.expectRevert(TLUniversalDeployer.InitializationFailed.selector);
        tlud.deploy("ERC1155", init721, 0);
        vm.stopPrank();
    }
}
