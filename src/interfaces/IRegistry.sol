// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IkRegistry } from "src/interfaces/IkRegistry.sol";
import { IAdapterGuardian } from "src/interfaces/modules/IAdapterGuardian.sol";
import { IVaultReader } from "src/interfaces/modules/IVaultReader.sol";
import { IProcessRouterModule } from "src/interfaces/IProcessRouterModule.sol";

interface IRegistry is IkRegistry, IVaultReader, IAdapterGuardian, IProcessRouterModule { }
