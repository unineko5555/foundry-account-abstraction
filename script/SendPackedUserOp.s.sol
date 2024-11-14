// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";

contract SendPackedUserOp is Script {

    // address sender;
    // uint256 nonce;
    
    function run() public {}

    function generateSignedUserOperation(bytes memory callData, address sender)
        public view returns (PackedUserOperation memory unsignedUserOp) 
    {
        // Step 1. Generate the unsigned data
        uint256 nonce = vm.getNonce(sender);
        unsignedUserOp = _generateUnsignedUserOperation(callData, sender, nonce);
        // Step 2. Sign and return it
    }

    function _generateUnsignedUserOperation(bytes memory callData, address sender, uint256 nonce)
        internal pure returns (PackedUserOperation memory) 
    {

        uint128 verificationGasLimit = 16777216; //　最大ガス量
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;

        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            // 128bit左にシフト(32byteのうち16byteにセット)、これはバイト列の前半に置くため。残りの16byteにcallGasLimitを置く。
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}