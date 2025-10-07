// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { IRegistry } from "kam/src/interfaces/IRegistry.sol";
import { IAdapterGuardian } from "kam/src/interfaces/modules/IAdapterGuardian.sol";

interface IkRegistry is IRegistry, IAdapterGuardian { }
