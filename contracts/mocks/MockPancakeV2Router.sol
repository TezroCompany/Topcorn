/*
 SPDX-License-Identifier: MIT
*/

pragma solidity = 0.8.16;

import "../interfaces/pancake/IPancakePair.sol";
import "./MockPancakeswapV2Pair.sol";
import "./MockWBNB.sol";
import "hardhat/console.sol";

/**
 * @title Mock Pancake V2 Router
 **/
contract MockPancakeV2Router {
    address private _pair;
    address payable private _wbnb;

    constructor() {
        _wbnb = payable(new MockWBNB());
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        )
    {
        if ((deadline == 0) && false) console.log(""); // For testing

        (amountToken, amountETH) = _addLiquidity(token, _wbnb, amountTokenDesired, msg.value, amountTokenMin, amountETHMin);
        MockToken(token).transferFrom(msg.sender, address(this), amountToken);
        liquidity = MockPancakeswapV2Pair(_pair).mint(to);
        if (msg.value > amountETH) {
            (bool success, ) = msg.sender.call{value: msg.value - amountETH}("");
            require(success, "MockPancakeV2Router: Refund failed.");
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        if ((deadline == 0) && false) console.log(""); // For testing

        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        MockToken(tokenA).transferFrom(msg.sender, address(this), amountA);
        MockToken(tokenB).transferFrom(msg.sender, address(this), amountB);
        liquidity = IPancakePair(_pair).mint(to);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public virtual returns (uint256 amountA, uint256 amountB) {
        if (tokenB == address(0) && (deadline == 0) && false) console.log(""); // For testing

        IPancakePair(_pair).transferFrom(msg.sender, _pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = IPancakePair(_pair).burn(to);
        (amountA, amountB) = tokenA == IPancakePair(_pair).token0() ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, "PancakeV2Router: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "PancakeV2Router: INSUFFICIENT_B_AMOUNT");
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        if (tokenB == address(0) && false) console.log(""); // For testing

        (uint256 reserve0, uint256 reserve1, ) = IPancakePair(_pair).getReserves();
        (uint256 reserveA, uint256 reserveB) = tokenA == IPancakePair(_pair).token0() ? (reserve0, reserve1) : (reserve1, reserve0);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired && amountBOptimal > 0) {
                require(amountBOptimal >= amountBMin, "MockPancakeV2Router: INSUFFICIENT_B_AMOUNT.");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = quote(amountBDesired, reserveB, reserveA);
                require(amountAOptimal <= amountADesired, "MockPancakeV2Router: INSUFFICIENT_A_AMOUNT.");
                require(amountAOptimal >= amountAMin, "MockPancakeV2Router: INSUFFICIENT_A_AMOUNT.");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory) {
        if (to == address(0) && (deadline == 0) && false) console.log(""); // For testing

        uint256 amountOut = getAmountOut(amountIn, path);
        require(amountOut >= amountOutMin, "MockPancakeV2Router: INSUFFICIENT_INPUT_AMOUNT.");
        MockToken(path[0]).burnFrom(msg.sender, amountIn);
        MockToken(path[1]).mint(msg.sender, amountOut);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
        return amounts;
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        if (to == address(0) && (deadline == 0) && false) console.log(""); // For testing

        amounts = getAmountsIn(amountOut, path);
        require(amounts[0] <= amountInMax, "PancakeV2Router: EXCESSIVE_INPUT_AMOUNT");
        MockToken(path[0]).burnFrom(msg.sender, amounts[0]);
        MockToken(path[1]).mint(msg.sender, amounts[1]);
    }

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        if ((deadline == 0) && false) console.log(""); // For testing

        require(path[0] == _wbnb, "PancakeV2Router: INVALID_PATH");
        amounts = getAmountsIn(amountOut, path);
        require(amounts[0] <= msg.value, "PancakeV2Router: EXCESSIVE_INPUT_AMOUNT");
        MockWBNB(_wbnb).deposit{value: amounts[0]}();
        MockWBNB(_wbnb).burn(amounts[0]);
        MockToken(path[1]).mint(to, amounts[1]);
        // refund dust eth, if any
        if (msg.value > amounts[0]) {
            (bool success, ) = msg.sender.call{value: msg.value - amounts[0]}(new bytes(0));
            require(success, "TransferHelper::safeTransferETH: BNB transfer failed");
        }
    }

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        if (to == address(0) && (deadline == 0) && false) console.log(""); // For testing

        require(path[0] == _wbnb, "PancakeV2Router: INVALID_PATH");
        uint256 amountOut = getAmountOut(msg.value, path);
        amounts = new uint256[](2);
        amounts[0] = msg.value;
        amounts[1] = amountOut;
        require(amounts[1] >= amountOutMin, "PancakeV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        MockWBNB(_wbnb).deposit{value: amounts[0]}();
        MockWBNB(_wbnb).burn(amounts[0]);
        MockToken(path[1]).mint(msg.sender, amounts[1]);
    }

    function getAmountOut(uint256 amountIn, address[] calldata path) internal view returns (uint256 amountOut) {
        (uint256 reserve0, uint256 reserve1, ) = IPancakePair(_pair).getReserves();
        (uint256 reserveIn, uint256 reserveOut) = path[0] == IPancakePair(_pair).token0() ? (reserve0, reserve1) : (reserve1, reserve0);
        require(amountIn > 0, "MockPancakeV2Router: INSUFFICIENT_INPUT_AMOUNT.");
        require(reserveIn > 0 && reserveOut > 0, "MockPancakeV2Router: INSUFFICIENT_LIQUIDITY.");
        uint256 numerator = amountIn * reserveOut;
        uint256 denominator = reserveIn + amountIn;
        amountOut = numerator / denominator;
    }

    function getReserves(address tokenA, address tokenB) internal view returns (uint256 reserveA, uint256 reserveB) {
        if (tokenB == address(0) && false) console.log(""); // For testing

        (uint256 reserve0, uint256 reserve1, ) = IPancakePair(_pair).getReserves();
        (reserveA, reserveB) = tokenA == IPancakePair(_pair).token0() ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "PancakeV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "PancakeV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 numerator = reserveIn * amountOut;
        uint256 denominator = reserveOut - amountOut;
        amountIn = (numerator / denominator) + 1;
    }

    function getAmountsIn(uint256 amountOut, address[] memory path) public view returns (uint256[] memory amounts) {
        require(path.length == 2, "PancakeV2Library: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[1] = amountOut;
        (uint256 reserveIn, uint256 reserveOut) = getReserves(path[0], path[1]);
        amounts[0] = getAmountIn(amounts[1], reserveIn, reserveOut);
    }

    function pair() public view returns (address) {
        return _pair;
    }

    function setPair(address ppair) public {
        _pair = ppair;
        MockPancakeswapV2Pair(_pair).setToken2(_wbnb);
    }

    function WETH() public view returns (address) {
        return _wbnb;
    }

    function setWBNB(address payable __wbnb) public {
        _wbnb = __wbnb;
    }

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountB) {
        require(amountA > 0, "MockPancakeV2Router: INSUFFICIENT_AMOUNT.");
        require(reserveA > 0 && reserveB > 0, "MockPancakeV2Router: INSUFFICIENT_LIQUIDITY.");
        amountB = (amountA * reserveB) / reserveA;
    }
}
