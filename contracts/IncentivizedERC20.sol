// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.6;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";

/**
 * @title ERC20
 * @notice Basic ERC20 implementation
 * @dev inspired by the Openzeppelin ERC20 implementation
 **/
abstract contract IncentivizedERC20 is Context, IERC20 {
  using SafeMath for uint256;

  mapping(address => uint256) internal balances;
  mapping(address => mapping(address => uint256)) private _allowances;
  uint256 internal totalSupply_;

  /**
   * @return The total supply of the token
   **/
  function totalSupply() public view virtual override returns (uint256) {
    return totalSupply_;
  }

    /**
   * @return The balance of the token
   **/
  function balanceOf(address account) public view virtual override returns (uint256) {
    return balances[account];
  }

  function transfer(address receiver, uint256 numTokens) public override returns (bool) {
    require(numTokens <= balances[msg.sender], "transfer more than balance");
    balances[msg.sender] = balances[msg.sender].sub(numTokens);
    balances[receiver] = balances[receiver].add(numTokens);
    emit Transfer(msg.sender, receiver, numTokens);
    return true;
  }

  /**
   * @dev Returns the allowance of spender on the tokens owned by owner
   * @param owner The owner of the tokens
   * @param spender The user allowed to spend the owner's tokens
   * @return The amount of owner's tokens spender is allowed to spend
   **/
  function allowance(address owner, address spender)
    public
    view
    virtual
    override
    returns (uint256)
  {
    return _allowances[owner][spender];
  }

  /**
   * @dev Allows `spender` to spend the tokens owned by _msgSender()
   * @param spender The user allowed to spend _msgSender() tokens
   * @return `true`
   **/
  function approve(address spender, uint256 amount) public virtual override returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  function transferFrom(
    address owner,
    address buyer,
    uint256 numTokens
  ) public override returns (bool) {
    require(numTokens <= balances[owner], "transfer more than balance");
    require(numTokens <= _allowances[owner][msg.sender], "transfer more than allowed");

    balances[owner] = balances[owner].sub(numTokens);
    _allowances[owner][msg.sender] = _allowances[owner][msg.sender].sub(numTokens);
    balances[buyer] = balances[buyer].add(numTokens);
    emit Transfer(owner, buyer, numTokens);
    return true;
  }

  function _mint(address account, uint256 amount) internal virtual {
    require(account != address(0), "ERC20: mint to the zero address");

    uint256 oldTotalSupply = totalSupply_;
    totalSupply_ = oldTotalSupply.add(amount);

    uint256 oldAccountBalance = balances[account];
    balances[account] = oldAccountBalance.add(amount);
  }

  function _burn(address account, uint256 amount) internal virtual {
    require(account != address(0), "ERC20: burn from the zero address");

    uint256 oldTotalSupply = totalSupply_;
    totalSupply_ = oldTotalSupply.sub(amount);

    uint256 oldAccountBalance = balances[account];
    balances[account] = oldAccountBalance.sub(amount, "ERC20: burn amount exceeds balance");
  }

  function _approve(
    address owner,
    address spender,
    uint256 amount
  ) internal virtual {
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }
}
