// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract Karma is IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _debts;
    mapping(address => mapping(address => uint256)) private _allowances;

    string private _name;
    string private _symbol;
    uint private _cycleReward;

    constructor(string memory name_, string memory symbol_, uint cycleReward) {
        _name = name_;
        _symbol = symbol_;
        _cycleReward = cycleReward;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    // totalSupply is meaningless
    function totalSupply() public view virtual override returns (uint256) {
        return 0;
    }

    function balanceOf(
        address account
    ) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function debtOf(
        address debtor,
        address creditor
    ) public view virtual returns (uint256) {
        return _debts[debtor][creditor];
    }

    function transfer(
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public virtual override returns (bool) {
        require(spender != address(0), "ERC20: approve to the zero address");

        address owner = msg.sender;
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function mineCycle(
        address[] memory nodes,
        uint256 amount
    ) public virtual returns (bool) {
        // checking debts in cycle from 0..n
        for (uint i = 0; i < nodes.length - 1; i++) {
            require(
                _debts[nodes[i]][nodes[i + 1]] >= amount,
                "Karma: Not enough debt for the cycle"
            );
        }

        // checking the last debt (end of cycle)
        require(
            _debts[nodes[nodes.length - 1]][nodes[0]] >= amount,
            "Karma: Not enough debt for the cycle"
        );

        // decreasing the debts and balances and pay cyleReward
        for (uint i = 0; i < nodes.length - 1; i++) {
            _debts[nodes[i]][nodes[i + 1]] -= amount;
            _balances[nodes[i]] -= amount;
            _transfer(nodes[i], msg.sender, _cycleReward);
        }

        _debts[nodes[nodes.length - 1]][nodes[0]] -= amount;
        _balances[nodes[nodes.length - 1]] -= amount;
        _transfer(nodes[nodes.length - 1], msg.sender, _cycleReward);

        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(to != address(0), "ERC20: transfer to the zero address");

        _balances[from] += amount;
        _debts[from][to] += amount;

        emit Transfer(from, to, amount);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "ERC20: insufficient allowance"
            );

            uint256 newAmount = currentAllowance - amount;
            _allowances[owner][spender] = newAmount;
            emit Approval(owner, spender, newAmount);
        }
    }
}
