// SPDX-License-Identifier: MIT
/// @author KRogLA (https://github.com/krogla)
pragma solidity ^0.8.0;

/**
 * @dev Common shared errors
 */

error AlreadyExists();
error NotExists();
error ZeroAddress();
error ZeroAmount();
error OutOfBounds();
error NonceMissmatch();
error CallerIsNotOwnerNorApproved();
error TransferWhilePaused();
error WrongInputParams();
error NotEnoughMoney();
error FailedToTransferMoney();
error StartDateNotDefined();
error SaleNotStarted();
error NoMoreRemainAmount();
error InsufficientAmount();
error TokenNotDefined();