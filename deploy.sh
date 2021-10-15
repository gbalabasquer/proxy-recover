#!/usr/bin/env bash
set -e

export SETH_ASYNC=yes

for i in {3..100}
do
    ETH_NONCE=$i ETH_GAS=740000 ETH_GAS_PRICE=$(seth --to-wei 1.05 "gwei") seth send "$ETH_FROM"
done

# ETH_NONCE=234 ETH_GAS=20000000 ETH_GAS_PRICE=$(seth --to-wei 1.05 "gwei") dapp create ProxyFactory
