#!/usr/bin/env bash
set -e

for i in {1..233}
do
    ETH_NONCE=$($i) ETH_GAS=21000 seth send "$ETH_FROM"
done

ETH_NONCE=234 ETH_GAS=2000000 dapp create ProxyFactory
