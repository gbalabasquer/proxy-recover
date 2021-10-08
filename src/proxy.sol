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

contract DSProxy {
    address public factory;
    address localOwner;

    modifier auth() {
        msg.sender == owner();
    }

    constructor() public {
        factory = msg.sender;
    }

    receive() external payable {
    }

    function owner() public returns (address) {
        if (localOwner == address(0)) {
            return factory.owner();
        } else {
            return localOwner;
        }
    }

    function setOwner(address owner_) auth {
        localOwner = owner_;
    }

    function execute(address _target, bytes memory _data)
        public
        auth
        payable
        returns (bytes memory response)
    {
        require(_target != address(0), "ds-proxy-target-address-required");

        // call contract in current context
        assembly {
            let succeeded := delegatecall(sub(gas(), 5000), _target, add(_data, 0x20), mload(_data), 0, 0)
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
    }
}

contract DSProxyFactory {
    event Created(address indexed proxy);
    address public owner;

    modifier auth() {
        msg.sender == owner();
    }

    constructor() public {
        owner = msg.sender;
    }

    function setOwner(address owner_) auth {
        owner = owner_;
    }

    // deploys a new proxy instance
    // sets custom owner of proxy
    function build() public returns (address payable proxy) {
        proxy = address(new DSProxy());
        emit Created(address(proxy));
    }
}
