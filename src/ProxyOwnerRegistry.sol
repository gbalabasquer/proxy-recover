// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2021 Dai Foundation
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.6.12;

contract ProxyOwnerRegistry {
    address public owner;
    mapping (address => address) public registry;

    modifier auth() {
        require(msg.sender == owner, "Proxy/not-owner");
        _;
    }

    event SetOwner(address indexed owner_);
    event SetProxyOwner(address indexed proxy, address indexed proxyOwner);

    constructor() public {
        owner = msg.sender;
    }

    function setOwner(address owner_) external auth {
        owner = owner_;
        emit SetOwner(owner_);
    }

    function setProxyOwner(address proxy, address proxyOwner) external auth {
        registry[proxy] = proxyOwner;
        emit SetProxyOwner(proxy, proxyOwner);
    }

    function getOwner(address proxy) external view returns (address proxyOwner) {
        proxyOwner = registry[proxy];
    }
}
