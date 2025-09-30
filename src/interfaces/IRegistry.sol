// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IkRegistry } from "kam/src/interfaces/IkRegistry.sol";
import { IAdapterGuardian } from "kam/src/interfaces/modules/IAdapterGuardian.sol";

interface IRegistry is IkRegistry, IAdapterGuardian { }
