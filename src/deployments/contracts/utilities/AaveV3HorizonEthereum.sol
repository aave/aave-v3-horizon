// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
library AaveV3HorizonEthereum {
  address internal constant CONFIG_ENGINE = 0x366D1e3F41Ad5CC699bb8FC0B41323C68d895E2c;
  address internal constant POOL_ADDRESSES_PROVIDER = 0x5D39E06b825C1F2B80bf2756a73e28eFAA128ba0;
  address internal constant POOL = 0xAe05Cd22df81871bc7cC2a04BeCfb516bFe332C8;
  address internal constant POOL_CONFIGURATOR = 0x83Cb1B4af26EEf6463aC20AFbAC9c0e2E017202F;
  address internal constant ACL_MANAGER = 0xEFD5df7b87d2dCe6DD454b4240b3e0A4db562321;
  address internal constant AAVE_PROTOCOL_DATA_PROVIDER =
    0x53519c32f73fE1797d10210c4950fFeBa3b21504;
  address internal constant RWA_ATOKEN_IMPLEMENTATION = 0x8CA2a49c7Df42E67F9A532F0d383D648fB7Fe4C9;
  address internal constant VARIABLE_DEBT_TOKEN_IMPLEMENTATION =
    0x15F03E5dE87c12cb2e2b8e5d6ECEf0a9E21ab269;
}
