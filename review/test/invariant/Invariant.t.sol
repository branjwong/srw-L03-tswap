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

    uint256 kConstant;
    uint256 lastPoolWethBalance;
    uint256 lastPoolTokenBalance;

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

        calculateK();
        handler.deposit(100e18);

        kConstant = calculateK();
    }

    // This is called at the end of every fuzz step in invariant fuzz campaign.
    function statefulFuzz_testConstantProductFormulaAlwaysHolds() public {
        assertEq(
            kConstant,
            weth.balanceOf(address(pool)) * poolToken.balanceOf(address(pool))
        );
    }

    function calculateK() private view returns (uint256) {
        uint256 wethBalance = weth.balanceOf(address(pool));
        uint256 poolTokenBalance = poolToken.balanceOf(address(pool));
        uint256 k = wethBalance * poolTokenBalance;

        console.log("k: ", k);

        return k;
    }

    function expectedOutputDeltaWithoutFees(
        uint256 deltaInput,
        uint256 initialInput,
        uint256 initialOutput
    ) private returns (uint256) {
        uint256 alpha = deltaInput / initialInput;
        return (initialOutput * alpha) / (1 + alpha);
    }

    function expectedOutput(
        uint256 deltaInput,
        uint256 initialInput,
        uint256 initialOutput
    ) private returns (uint256) {
        uint256 delta = expectedOutputDeltaWithoutFees(
            deltaInput,
            initialInput,
            initialOutput
        );

        return initialOutput + delta;
    }
}
