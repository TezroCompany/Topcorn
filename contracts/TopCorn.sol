/*
 SPDX-License-Identifier: MIT
*/

pragma solidity = 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title TopCorn is the ERC-20 Stablecoin for Farmer.
 **/
contract TopCorn is Ownable, ERC20Burnable {
    constructor() ERC20("TopCorn", "CORN") {}

    function mint(address account, uint256 amount) public onlyOwner returns (bool) {
        _mint(account, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        uint256 allow = allowance(sender, _msgSender());
        if (allow != type(uint256).max) {
            require(allow >= amount, "TopCorn: Transfer amount exceeds allowance.");
            _approve(sender, _msgSender(), allow - amount);
        }
        return true;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}
