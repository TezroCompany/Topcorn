/*
 SPDX-License-Identifier: MIT
*/

pragma solidity = 0.8.16;
import "./MockToken.sol";

/**
 * @title Mock WBNB
 **/
contract MockWBNB is MockToken {
    constructor() MockToken("Wrapped BNB", "WBNB") {}

    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) public {
        require(balanceOf(msg.sender) >= wad);
        _transfer(msg.sender, address(this), wad);
        (bool success, ) = msg.sender.call{value: wad}("");
        require(success, "MockWBNB: Transfer failed.");
        emit Withdrawal(msg.sender, wad);
    }
}
