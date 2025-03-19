// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { PackedUserOperation } from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { IEntryPoint } from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MinimalAccount } from "src/ethereum/MinimalAccount.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;
    
    function run() public {
        // Setup
        HelperConfig helperConfig = new HelperConfig();
        address dest = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // Arbitrum mainnet USDC address
        uint256 value = 0;

        bytes memory functionData = abi.encodeWithSelector(
            IERC20.approve.selector,
            0xCd77572F2301b68B8340cb447bB2D233439EAC1C, //my wallet
            1e18
        );

        bytes memory executeCalldata = abi.encodeWithSelector(
            MinimalAccount.execute.selector,
            dest,
            value,
            functionData
        );

        PackedUserOperation memory userOp = generateSignedUserOperation(
            executeCalldata,
            helperConfig.getConfig(),
            0x03Ad95a54f02A40180D45D76789C448024145aaF // MinimalAccountのaddressを記入する(これは違う),実際にDeployMinimalをdeolyしてMinimalAccountのaddressを記入する
        );
        PackedUserOperation[] memory ops = new PackedUserOperation[](1); // サイズ1の配列
        ops[0] = userOp;

        // Send transaction
        vm.startBroadcast();
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(
            ops, //署名つきのUserOperation
            payable(helperConfig.getConfig().account) //accountはbeneficiary:受益者
        );
        vm.stopBroadcast();
    }

    //UserOperationを生成し、署名する関数
    function generateSignedUserOperation(bytes memory callData, HelperConfig.NetworkConfig memory config, address minimalAccount)
        public view returns (PackedUserOperation memory userOp) 
    {
        // Step 1. Generate the unsigned data
        uint256 nonce = vm.getNonce(minimalAccount) - 1; // config.account → minimalAccount, 最後に成功したトランザクション
        userOp = _generateUnsignedUserOperation(callData, minimalAccount, nonce); // unsignedUserOp = userOp, config.account → minimalAccount
        // Step 2. Sign and return it
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp); //userOpのハッシュ
        bytes32 digest = userOpHash.toEthSignedMessageHash(); //eth_signのメッセージハッシュ
        // 3. Sign it
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            (v, r, s) = vm.sign(config.account, digest); //digest を config.account の秘密鍵で署名し、署名の v, r, s の3つの値を取得する処理
        }
        userOp.signature = abi.encodePacked(r, s, v); // Note: the order
        return userOp;
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