// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeployAaveV3MarketBatchedBase} from './misc/DeployAaveV3MarketBatchedBase.sol';

import {VTestnetInput} from 'src/deployments/inputs/VTestnetInput.sol';
// import {VTestnetInputSuperstate} from 'src/deployments/inputs/VTestnetInputSuperstate.sol';
import {SepoliaTestnetInput} from 'src/deployments/inputs/SepoliaTestnetInput.sol';

contract Default is DeployAaveV3MarketBatchedBase, SepoliaTestnetInput {}
