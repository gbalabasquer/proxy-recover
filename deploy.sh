#!/usr/bin/env bash
set -e

export SETH_ASYNC=yes

for i in {0..233}
do
    ETH_NONCE=$i ETH_GAS=740000 seth send "$ETH_FROM"
done

ETH_NONCE=234 ETH_GAS=20000000 dapp create ProxyFactory
