// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IkRegistry } from "kam/src/interfaces/IkRegistry.sol";
import { IAdapterGuardian } from "kam/src/interfaces/modules/IAdapterGuardian.sol";
import { IProcessRouterModule } from "kam/src/interfaces/modules/IProcessRouterModule.sol";

interface IRegistry is IkRegistry, IAdapterGuardian, IProcessRouterModule { }
