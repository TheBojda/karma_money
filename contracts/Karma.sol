// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Karma is IERC20, IERC20Metadata, EIP712 {
    mapping(address => mapping(address => uint256)) private _debts;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _nonces;
    mapping(address => uint256) private _cycleRewards;

    event CycleRewardChanged(address indexed owner, uint256 value);

    string private _name;
    string private _symbol;

    bytes32 constant TRANSFER_REQUEST_TYPEHASH =
        keccak256(
            "TransferRequest(address from,address to,uint256 amount,uint256 nonce)"
        );

    bytes32 constant APPROVE_REQUEST_TYPEHASH =
        keccak256(
            "ApproveRequest(address owner,address spender,uint256 amount,uint256 nonce)"
        );

    bytes32 constant SET_CYCLE_REWARD_REQUEST_TYPEHASH =
        keccak256(
            "SetCycleRewardRequest(address owner,uint256 amount,uint256 nonce)"
        );

    constructor(
        string memory name_,
        string memory symbol_
    ) EIP712("Karma Request", "1") {
        _name = name_;
        _symbol = symbol_;
    }

    // --- meta data ---

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    // --- ERC20 methods ---

    // totalSupply is meaningless
    function totalSupply() public view virtual override returns (uint256) {
        return 0;
    }

    function balanceOf(
        address account
    ) public view virtual override returns (uint256) {
        return _balances[account];
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
        _approve(msg.sender, spender, amount);
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

    // --- karma methods ---

    function debtOf(
        address debtor,
        address creditor
    ) public view virtual returns (uint256) {
        return _debts[debtor][creditor];
    }

    function mineCycle(address[] memory nodes) public virtual returns (bool) {
        // store the last debt (end of cycle) as min
        uint256 min = _debts[nodes[nodes.length - 1]][nodes[0]];

        // checking debts in cycle from 0..n, and find the min value
        for (uint i = 0; i < nodes.length - 1; i++) {
            uint256 debt = _debts[nodes[i]][nodes[i + 1]];
            min = debt < min ? debt : min;
        }

        // if minimal debt is 0, then it is an invalid cycle
        require(min > 0, "Karma: Invalid cycle");

        // decreasing the debts and balances and pay cyleReward
        for (uint i = 0; i < nodes.length - 1; i++) {
            address target = nodes[i];
            _debts[target][nodes[i + 1]] -= min;
            _balances[target] -= min;
            _transfer(target, msg.sender, _cycleRewards[target]);
        }

        // ... last node
        address last_target = nodes[nodes.length - 1];
        _debts[last_target][nodes[0]] -= min;
        _balances[last_target] -= min;
        _transfer(last_target, msg.sender, _cycleRewards[last_target]);

        return true;
    }

    function cycleRewardOf(
        address account
    ) public view virtual returns (uint256) {
        return _cycleRewards[account];
    }

    function setCycleReward(uint256 amount) public virtual returns (bool) {
        _setCycleReward(msg.sender, amount);
        return true;
    }

    // --- meta transactions ---

    function getNonce(address owner) public view virtual returns (uint256) {
        return _nonces[owner];
    }

    function metaTransfer(
        address from,
        address to,
        uint256 amount,
        uint256 nonce,
        bytes calldata signature
    ) public virtual returns (bool) {
        (address recoveredAddress, ECDSA.RecoverError err) = ECDSA.tryRecover(
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        TRANSFER_REQUEST_TYPEHASH,
                        from,
                        to,
                        amount,
                        _useNonce(from, nonce)
                    )
                )
            ),
            signature
        );

        require(
            err == ECDSA.RecoverError.NoError && recoveredAddress == from,
            "Signature error"
        );

        _transfer(recoveredAddress, to, amount);
        return true;
    }

    function metaApprove(
        address owner,
        address spender,
        uint256 amount,
        uint256 nonce,
        bytes calldata signature
    ) public virtual returns (bool) {
        (address recoveredAddress, ECDSA.RecoverError err) = ECDSA.tryRecover(
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        APPROVE_REQUEST_TYPEHASH,
                        owner,
                        spender,
                        amount,
                        _useNonce(owner, nonce)
                    )
                )
            ),
            signature
        );

        require(
            err == ECDSA.RecoverError.NoError && recoveredAddress == owner,
            "Signature error"
        );

        _approve(owner, spender, amount);
        return true;
    }

    function metaSetCycleReward(
        address owner,
        uint256 amount,
        uint256 nonce,
        bytes calldata signature
    ) public virtual returns (bool) {
        (address recoveredAddress, ECDSA.RecoverError err) = ECDSA.tryRecover(
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        SET_CYCLE_REWARD_REQUEST_TYPEHASH,
                        owner,
                        amount,
                        _useNonce(owner, nonce)
                    )
                )
            ),
            signature
        );

        require(
            err == ECDSA.RecoverError.NoError && recoveredAddress == owner,
            "Signature error"
        );

        _setCycleReward(owner, amount);
        return true;
    }

    // --- internal methods ---

    function _setCycleReward(address owner, uint256 amount) internal virtual {
        _cycleRewards[owner] = amount;

        emit CycleRewardChanged(owner, amount);
    }

    function _useNonce(
        address owner,
        uint256 nonce
    ) internal virtual returns (uint256) {
        uint256 currentNonce = _nonces[owner];
        require(currentNonce == nonce, "Invalid nonce");
        return _nonces[owner]++;
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

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;

        emit Approval(owner, spender, amount);
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
