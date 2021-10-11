// proxy.sol - execute actions atomically through the proxy's identity

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

interface ProxyOwnerRegistryLike {
    function getOwner(address) external view returns (address);
}

contract Proxy {
    address public factory;
    address localOwner;

    modifier auth() {
        require(msg.sender == owner(), "Proxy/not-owner");
        _;
    }

    event Execute(address indexed target_, bytes data_);
    event SetOwner(address indexed owner_);

    constructor() public {
        factory = msg.sender;
        localOwner = msg.sender;
    }

    receive() external payable {
    }

    function owner() public view returns (address owner_) {
        owner_ = localOwner != address(0) ? localOwner : ProxyFactory(factory).owner();
    }

    function setOwner(address owner_) external auth {
        localOwner = owner_;
        emit SetOwner(owner_);
    }

    function execute(address target_, bytes memory data_) external auth payable returns (bytes memory response) {
        require(target_ != address(0), "Proxy/target-address-required");

        // call contract in current context
        assembly {
            let succeeded := delegatecall(sub(gas(), 5000), target_, add(data_, 0x20), mload(data_), 0, 0)
            let size := returndatasize()

            response := mload(0x40)
            mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)

            switch iszero(succeeded)
            case 1 {
                // throw if delegatecall failed
                revert(add(response, 0x20), size)
            }
        }

        emit Execute(target_, data_);
    }
}

contract ProxyFactory {
    address public owner;
    ProxyOwnerRegistryLike public registry;

    modifier auth() {
        require(msg.sender == owner, "ProxyFactory/not-owner");
        _;
    }

    event Created(address indexed proxy, address indexed proxyOwner);
    event SetOwner(address indexed owner_);
    event SetRegistry(address indexed registry_);

    constructor() public {
        owner = msg.sender;
    }

    function setOwner(address owner_) external auth {
        owner = owner_;
        emit SetOwner(owner_);
    }
    
    function setRegistry(address registry_) external auth {
        registry = ProxyOwnerRegistryLike(registry_);
        emit SetRegistry(registry_);
    }

    function build() public returns (address payable proxy) {
        proxy = address(new Proxy());
        address proxyOwner = registry.getOwner(proxy);
        Proxy(proxy).setOwner(proxyOwner);
        emit Created(
            address(proxy),
            proxyOwner != address(0) ? proxyOwner : owner
        );
    }
}