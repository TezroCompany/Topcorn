/**
 * SPDX-License-Identifier: MIT
 **/

pragma solidity = 0.8.16;

import "../../AppStorage.sol";
import "../../../interfaces/ITopcorn.sol";
import "../../ReentrancyGuard.sol";
import "../../../libraries/LibClaim.sol";

/**
 * @title Pod Transfer
 **/
contract PodTransfer is ReentrancyGuard {
    event PlotTransfer(address indexed from, address indexed to, uint256 indexed plotId, uint256 start, uint256 pods);
    event PodApproval(address indexed owner, address indexed spender, uint256 pods);

    /**
     * Getters
     **/

    /// @notice Public function for granting allowance permissions for a spender for a particular owner's pods. ()
    /// @param owner address of the pods owner
    /// @param spender address of the account to grant allowance permissions
    /// @return uint256 allowance amount of pods for spender
    function allowancePods(address owner, address spender) public view returns (uint256) {
        return s.a[owner].field.podAllowances[spender];
    }

    /**
     * Internal
     **/

    /// @notice Internal function that handles the business logic for transferring plot of pods from one account to another using internal functions
    /// @param from address of the pod sending account
    /// @param to address of the pod receiving account
    /// @param index plot id index for storage
    /// @param start starting pod plot spot for this plot transfer
    /// @param amount number of pods to transfer
    function _transferPlot(
        address from,
        address to,
        uint256 index,
        uint256 start,
        uint256 amount
    ) internal {
        require(from != to, "Field: Cannot transfer Pods to oneself.");
        insertPlot(to, index + start, amount);
        
        removePlot(from, index, start, amount + start);
        emit PlotTransfer(from, to, index, start, amount);
    }

    /// @notice Internal function that handles the adding of pods to a specified account's plot.
    /// @param account address of the account to add pods to
    /// @param id the id of the account plot to add pods to
    /// @param amount number of pods to add to a specified account's plot
    function insertPlot(
        address account,
        uint256 id,
        uint256 amount
    ) internal {
        s.a[account].field.plots[id] = amount;
    }

    /// @notice Internal function that handles the business logic of the removal of pods from a specified account's plot.
    /// @param account address of the account to remove pods from
    /// @param id the id of the account plot to add pods from
    /// @param start starting pod plot spot for this plot removal
    /// @param end ending pod plot spot for this plot removal
    function removePlot(
        address account,
        uint256 id,
        uint256 start,
        uint256 end
    ) internal {
        uint256 amount = s.a[account].field.plots[id];
        if (start == 0) delete s.a[account].field.plots[id];
        else s.a[account].field.plots[id] = start;
        if (end != amount) s.a[account].field.plots[id + end] = amount - end;
    }

    /// @notice Internal function for decreasing the allowance amount of pods of an account for a specified spender account.
    /// @param owner address of the pods owner
    /// @param spender address of the account with allowance permissions
    /// @param amount allowance number of pods for decrease
    function decrementAllowancePods(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        uint256 currentAllowance = allowancePods(owner, spender);
        require(currentAllowance >= amount, "Field: Insufficient approval.");
        setAllowancePods(owner, spender, currentAllowance - amount);
    }

    /// @notice Internal function for setting the allowance amount of pods of an account for a specified spender account.
    /// @param owner address of the pods owner
    /// @param spender address of the account with allowance permissions
    /// @param amount allowance number of pods to set for spender
    function setAllowancePods(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        s.a[owner].field.podAllowances[spender] = amount;
    }

    /// @notice Internal function that returns the ITopcorn object for the TopCorn stablecoin.
    /// @return ITopcorn the ITopcorn object of the TopCorn stablecoin
    function topcorn() internal view returns (ITopcorn) {
        return ITopcorn(s.c.topcorn);
    }
}
