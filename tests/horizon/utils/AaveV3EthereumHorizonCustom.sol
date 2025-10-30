// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
library AaveV3EthereumHorizonCustom {
  address public constant HORIZON_OPS = 0xE6ec1f0Ae6Cd023bd0a9B4d0253BDC755103253c;
  address public constant HORIZON_EMERGENCY = 0x13B57382c36BAB566E75C72303622AF29E27e1d3;
  address public constant HORIZON_EXECUTOR = 0x09e8E1408a68778CEDdC1938729Ea126710E7Dda;

  // horizon deployments
  address internal constant RWA_ATOKEN_IMPLEMENTATION = 0x8CA2a49c7Df42E67F9A532F0d383D648fB7Fe4C9;

  // horizon assets
  address public constant VBILL_UNDERLYING = 0x2255718832bC9fD3bE1CaF75084F4803DA14FF01;
  address public constant VBILL_PRICE_FEED = 0x5ed77a9D9b7cc80E9d0D7711024AF38C2643C1c4;

  // oracle param registry
  address public constant PARAM_REGISTRY = 0x69D55D504BC9556E377b340D19818E736bbB318b;
}
