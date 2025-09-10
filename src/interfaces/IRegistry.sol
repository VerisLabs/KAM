// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IAdapterGuardian } from "src/interfaces/modules/IAdapterGuardian.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";

interface IRegistry is IkRegistry, IAdapterGuardian {}