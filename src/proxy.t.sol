// proxy.t.sol - test for proxy.sol

// Copyright (C) 2017  DappHub, LLC

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.6.12;

import "ds-test/test.sol";
import "./proxy.sol";
import "./ProxyOwnerRegistry.sol";

// Test Contract Used
contract TestProxyActions {
    function getBytes32() public pure returns (bytes32) {
        return bytes32("Hello");
    }
    function getBytes32AndUint() public pure returns (bytes32, uint) {
        return (bytes32("Bye"), 150);
    }
    function getMultipleValues(uint amount) public pure returns (bytes32[] memory result) {
        result = new bytes32[](amount);
        for (uint i = 0; i < amount; i++) {
            result[i] = bytes32(i);
        }
    }
    function get48Bytes() public pure returns (bytes memory result) {
        assembly {
            result := mload(0x40)
            mstore(result, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
            mstore(add(result, 0x20), "AAAAAAAAAAAAAAAA")
            return(result, 0x30)
        }
    }

    function fail() public pure {
        require(false, "Fail test case");
    }
}

contract TestProxyActionsFullAssembly {
    fallback() external {
        assembly {
            let message := mload(0x40)
            mstore(message, "Fail test case")
            revert(message, 0xe)
        }
    }
}

contract TestProxyActionsWithdrawFunds {
    function withdraw(uint256 amount) public {
        msg.sender.transfer(amount);
    }
}

contract ProxyTest is DSTest {
    ProxyFactory factory;
    ProxyOwnerRegistry registry;
    Proxy proxy;

    function setUp() public {
        factory = new ProxyFactory();
        registry = new ProxyOwnerRegistry();
        assertEq(factory.owner(), address(this));
        assertEq(registry.owner(), address(this));
        factory.setRegistry(address(registry));
        proxy = Proxy(factory.build());
    }

    // build a proxy from ProxyFactory and verify logging
    function test_ProxyFactoryBuildProc() public {
        address payable proxyAddr = factory.build();
        assertTrue(proxyAddr != address(0));
        proxy = Proxy(proxyAddr);

        assertEq(proxy.owner(), address(this));
        assertEq(proxy.factory(), address(factory));

        uint codeSize;
        assembly {
            codeSize := extcodesize(proxyAddr)
        }
        //verify proxy was deployed successfully
        assertTrue(codeSize != 0);

        //verify proxy ownership
        assertEq(proxy.owner(), address(this));
        assertEq(proxy.factory(), address(factory));
    }

    function test_ProxyFactoryChangeOwnership() public {
        assertEq(factory.owner(), address(this));
        assertEq(proxy.owner(), address(this));
        factory.setOwner(address(123));
        assertEq(factory.owner(), address(123));
        assertEq(proxy.owner(), address(123));
    }

    function test_ProxyFactoryChangeOwnershipButNotProxy() public {
        assertEq(factory.owner(), address(this));
        assertEq(proxy.owner(), address(this));
        proxy.setOwner(address(456));
        assertEq(factory.owner(), address(this));
        assertEq(proxy.owner(), address(456));
        factory.setOwner(address(123));
        assertEq(factory.owner(), address(123));
        assertEq(proxy.owner(), address(456));
    }

    function test_ProxyFactoryBuildWithRegistryOwner() public {
        // HEVM deterministic address
        registry.setProxyOwner(0x566B72091192CCd7013AdF77E2a1b349564acC21, address(123));
        address payable proxyAddr = factory.build();
        assertEq(Proxy(proxyAddr).owner(), address(123));
    }

    // execute an action through proxy and verify caching
    function test_ProxyExecute() public {
        bytes memory data = abi.encodeWithSignature("getBytes32()");

        address proxyActions = address(new TestProxyActions());

        //deploy and call the contracts code
        bytes memory response = proxy.execute(proxyActions, data);

        bytes32 response32;

        assembly {
            response32 := mload(add(response, 32))
        }

        //verify we got correct response
        assertEq32(response32, bytes32("Hello"));
    }

    // execute an action through proxy which returns more than 1 value
    function test_ProxyExecute2Values() public {
        bytes memory data = abi.encodeWithSignature("getBytes32AndUint()");

        address proxyActions = address(new TestProxyActions());

        //deploy and call the contracts code
        bytes memory response = proxy.execute(proxyActions, data);

        bytes32 response32;
        uint responseUint;

        assembly {
            response32 := mload(add(response, 0x20))
            responseUint := mload(add(response, 0x40))
        }

        //verify we got correct response
        assertEq32(response32, bytes32("Bye"));
        assertEq(responseUint, uint(150));
    }

    // execute an action through proxy which returns multiple values in a bytes32[] format
    function test_ProxyExecuteMultipleValues() public {
        bytes memory data = abi.encodeWithSignature("getMultipleValues(uint256)", 10000);

        address proxyActions = address(new TestProxyActions());

        //deploy and call the contracts code
        bytes memory response = proxy.execute(proxyActions, data);

        uint size;
        bytes32 response32;

        assembly {
            size := mload(add(response, 0x40))
        }

        assertEq(size, 10000);

        for (uint i = 0; i < size; i++) {
            assembly {
                response32 := mload(add(response, mul(32, add(i, 3))))
            }
            assertEq32(response32, bytes32(i));
        }
    }

    // execute an action through proxy which returns a value not multiple of 32
    function test_ProxyExecuteNot32Multiple() public {
        bytes memory data = abi.encodeWithSignature("get48Bytes()");

        address proxyActions = address(new TestProxyActions());

        //deploy and call the contracts code
        bytes memory response = proxy.execute(proxyActions, data);

        bytes memory test = new bytes(48);
        test = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";

        assertEq0(response, test);
    }

    // execute an action through proxy which reverts via solidity require
    function test_ProxyExecuteFailMethod() public {
        address payable target = address(proxy);
        address proxyActions = address(new TestProxyActions());
        bytes memory data = abi.encodeWithSignature("execute(address,bytes)", bytes32(uint(address(proxyActions))), abi.encodeWithSignature("fail()"));

        bool succeeded;
        bytes memory sig;
        bytes memory message;

        assembly {
            succeeded := call(sub(gas(), 5000), target, 0, add(data, 0x20), mload(data), 0, 0)

            let size := returndatasize()

            let response := mload(0x40)
            mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)

            size := 0x4
            sig := mload(0x40)
            mstore(sig, size)
            mstore(0x40, add(sig, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            returndatacopy(add(sig, 0x20), 0, size)

            size := mload(add(response, 0x44))
            message := mload(0x40)
            mstore(message, size)
            mstore(0x40, add(message, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            returndatacopy(add(message, 0x20), 0x44, size)
        }
        assertTrue(!succeeded);
        assertEq0(sig, abi.encodeWithSignature("Error(string)"));
        assertEq0(message, "Fail test case");
    }

    // execute an action through proxy which reverts via a pure assembly function
    function test_ProxyExecuteFailMethodAssembly() public {
        address payable target = address(proxy);
        address proxyActions = address(new TestProxyActionsFullAssembly());
        bytes memory data = abi.encodeWithSignature("execute(address,bytes)", bytes32(uint(address(proxyActions))), hex"");

        bool succeeded;
        bytes memory response;

        assembly {
            succeeded := call(sub(gas(), 5000), target, 0, add(data, 0x20), mload(data), 0, 0)

            let size := returndatasize()

            response := mload(0x40)
            mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)
        }
        assertTrue(!succeeded);
        assertEq0(response, "Fail test case");
    }

    // deposit ETH to Proxy
    function test_ProxyDepositETH() public {
        assertEq(address(proxy).balance, 0);
        (bool success,) = address(proxy).call{value: 10}("");
        assertTrue(success);
        assertEq(address(proxy).balance, 10);
    }

    // withdraw ETH from Proxy
    function test_ProxyWithdrawETH() public {
        (bool success,) = address(proxy).call{value: 10}("");
        assertTrue(success);
        assertEq(address(proxy).balance, 10);
        uint256 myBalance = address(this).balance;
        address withdrawFunds = address(new TestProxyActionsWithdrawFunds());
        bytes memory data = abi.encodeWithSignature("withdraw(uint256)", 5);
        proxy.execute(withdrawFunds, data);
        assertEq(address(proxy).balance, 5);
        assertEq(address(this).balance, myBalance + 5);
    }

    receive() external payable {
    }
}
