// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { IRegistry } from "kam/src/interfaces/IRegistry.sol";
import { IAdapterGuardian } from "kam/src/interfaces/modules/IAdapterGuardian.sol";
import { IProcessRouter } from "kam/src/interfaces/modules/IProcessRouter.sol";

interface IkRegistry is IRegistry, IAdapterGuardian, IProcessRouter { }
