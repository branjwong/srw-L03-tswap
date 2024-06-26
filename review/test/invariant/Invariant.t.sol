// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {TSwapPool, PoolFactory, IERC20} from "../../src/PoolFactory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Handler} from "./Handler.t.sol";

contract TSwapTest is StdInvariant, Test {
    PoolFactory poolFactory;
    TSwapPool pool;
    ERC20Mock poolToken;
    ERC20Mock weth;

    uint256 minimumDepositAmount;
    Handler handler;

    address owner = makeAddr("owner");

    address liquidityProvider = makeAddr("liquidityProvider");
    address user = makeAddr("user");

    function setUp() public {
        weth = new ERC20Mock();
        poolToken = new ERC20Mock();

        poolFactory = new PoolFactory(address(weth));
        pool = TSwapPool(poolFactory.createPool(address(poolToken)));

        weth.mint(liquidityProvider, 200e18);
        poolToken.mint(liquidityProvider, 200e18);

        weth.mint(user, 10e18);
        poolToken.mint(user, 10e18);

        minimumDepositAmount = pool.getMinimumWethDepositAmount();

        handler = new Handler(
            pool,
            poolToken,
            weth,
            liquidityProvider,
            user,
            minimumDepositAmount
        );

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = handler.swapExactInputWeth.selector;
        selectors[1] = handler.swapExactInputPoolToken.selector;

        targetSelector(
            FuzzSelector({addr: address(handler), selectors: selectors})
        );
        targetContract(address(handler));

        handler.deposit(100e18);
    }

    // This is called at the end of every fuzz step in invariant fuzz campaign.
    // function statefulFuzz_testConstantProductFormulaAlwaysHolds() public {
    //     assertEq(handler.previousKConstant(), handler.calculateK());
    // }

    // This is called at the end of every fuzz step in invariant fuzz campaign.
    function statefulFuzz_deltaWithoutFees() public {
        uint256 initalWeth = handler.previousWethBalance();
        uint256 initialPoolToken = handler.previousPoolTokenBalance();
        uint256 finalWeth = weth.balanceOf(address(pool));
        uint256 finalPoolToken = poolToken.balanceOf(address(pool));

        if (initalWeth > finalWeth) {
            testSwapWithoutFees(
                initalWeth - finalWeth,
                initalWeth,
                initialPoolToken,
                finalPoolToken
            );
        } else {
            testSwapWithoutFees(
                initialPoolToken - finalPoolToken,
                initialPoolToken,
                initalWeth,
                finalWeth
            );
        }
    }

    function testSwapWithoutFees(
        uint256 deltaInput,
        uint256 initialInput,
        uint256 initialOutput,
        uint256 finalOutput
    ) private {
        uint256 expectedDeltaOutput = handler.expectedOutputDeltaWithoutFees(
            deltaInput,
            initialInput,
            initialOutput
        );

        uint256 actualDeltaOutput = finalOutput - initialOutput;

        assertEq(expectedDeltaOutput, actualDeltaOutput);
    }

    // function statefulFuzz_deltaWithFees() public {
    //     uint256 initalWeth = handler.previousWethBalance();
    //     uint256 initialPoolToken = handler.previousPoolTokenBalance();
    //     uint256 finalWeth = weth.balanceOf(address(pool));
    //     uint256 finalPoolToken = poolToken.balanceOf(address(pool));

    //     if (initalWeth > finalWeth) {
    //         testSwapWithFees(
    //             initalWeth - finalWeth,
    //             initalWeth,
    //             initialPoolToken,
    //             finalPoolToken
    //         );
    //     } else {
    //         testSwapWithFees(
    //             initialPoolToken - finalPoolToken,
    //             initialPoolToken,
    //             initalWeth,
    //             finalWeth
    //         );
    //     }
    // }

    function testSwapWithFees(
        uint256 deltaInput,
        uint256 initialInput,
        uint256 initialOutput,
        uint256 finalOutput
    ) private {
        uint256 expectedDeltaOutput = handler.expectedOutputDeltaWithFees(
            deltaInput,
            initialInput,
            initialOutput
        );

        uint256 actualDeltaOutput = finalOutput - initialOutput;

        assertEq(expectedDeltaOutput, actualDeltaOutput);
    }
}
