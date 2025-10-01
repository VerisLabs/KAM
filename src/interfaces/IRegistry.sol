// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { IkRegistry } from "kam/src/interfaces/IkRegistry.sol";
import { IAdapterGuardian } from "kam/src/interfaces/modules/IAdapterGuardian.sol";
import { IProcessRouterModule } from "kam/src/interfaces/modules/IProcessRouterModule.sol";

interface IRegistry is IkRegistry, IAdapterGuardian, IProcessRouterModule { }
