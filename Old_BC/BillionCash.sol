// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract BillionCash is Ownable {
    using SafeMath for uint256;
    mapping(address => uint256) public _BCTokenBalances;
    mapping(address => mapping(address => uint256)) public _allowed;
    string constant tokenName = "BillionCash";
    string constant tokenSymbol = "BC";
    uint8 constant tokenDecimals = 18;
    uint256 _totalSupply = 50000 * 10**uint256(tokenDecimals);
    address marketingwallet;
    address adminAddress;
    uint256 public constant PERCENTS_DIVIDER = 1000;
    uint256 public constant FEE_PERCENT = 50;

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    constructor(
        address _developmentWallet,
        address _marketingWallet
    ) {
        adminAddress = _developmentWallet;
        marketingwallet = _marketingWallet;
        _mint(marketingwallet, _totalSupply);
    }

    function name() public pure returns (string memory) {
        return tokenName;
    }

    function symbol() public pure returns (string memory) {
        return tokenSymbol;
    }

    function decimals() public pure returns (uint8) {
        return tokenDecimals;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address owner) public view returns (uint256) {
        return _BCTokenBalances[owner];
    }

    function transfer(address to, uint256 value) public returns (bool) {
        require(value <= _BCTokenBalances[msg.sender]);
        require(to != address(0));

        uint256 BCTokenForFee = value.mul(FEE_PERCENT).div(PERCENTS_DIVIDER);
        uint256 tokensToTransfer = value
            .sub(BCTokenForFee)
            .sub(BCTokenForFee)
            .sub(BCTokenForFee);

        _BCTokenBalances[msg.sender] = _BCTokenBalances[msg.sender].sub(value);
        _BCTokenBalances[to] = _BCTokenBalances[to].add(tokensToTransfer);
        _BCTokenBalances[adminAddress] = _BCTokenBalances[adminAddress].add(
            BCTokenForFee
        ).add(BCTokenForFee);
        _BCTokenBalances[marketingwallet] = _BCTokenBalances[marketingwallet].add(
            BCTokenForFee
        );

        emit Transfer(msg.sender, to, tokensToTransfer);
        emit Transfer(msg.sender, adminAddress, BCTokenForFee);
        emit Transfer(msg.sender, marketingwallet, BCTokenForFee);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        returns (uint256)
    {
        return _allowed[owner][spender];
    }

    function approve(address spender, uint256 value) public returns (bool) {
        require(spender != address(0));
        _allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public returns (bool) {
        require(value <= _BCTokenBalances[from]);
        require(value <= _allowed[from][msg.sender]);
        require(to != address(0));

        _BCTokenBalances[from] = _BCTokenBalances[from].sub(value);

        uint256 BCTokenForFee = value.mul(FEE_PERCENT).div(PERCENTS_DIVIDER);
        uint256 tokensToTransfer = value
            .sub(BCTokenForFee)
            .sub(BCTokenForFee)
            .sub(BCTokenForFee);

        _BCTokenBalances[to] = _BCTokenBalances[to].add(tokensToTransfer);
        _BCTokenBalances[adminAddress] = _BCTokenBalances[adminAddress].add(
            BCTokenForFee
        ).add(BCTokenForFee);
        _BCTokenBalances[marketingwallet] = _BCTokenBalances[marketingwallet].add(
            BCTokenForFee
        );
        _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);

        emit Transfer(msg.sender, adminAddress, BCTokenForFee);
        emit Transfer(msg.sender, marketingwallet, BCTokenForFee);

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        returns (bool)
    {
        require(spender != address(0));
        _allowed[msg.sender][spender] = (
            _allowed[msg.sender][spender].add(addedValue)
        );
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        returns (bool)
    {
        require(spender != address(0));
        _allowed[msg.sender][spender] = (
            _allowed[msg.sender][spender].sub(subtractedValue)
        );
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }

    function _mint(address account, uint256 amount) internal {
        require(amount != 0);
        _BCTokenBalances[account] = _BCTokenBalances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function setDevelopmentAddress(address  _developmentAddress) external onlyOwner {
        adminAddress = _developmentAddress;
    }
    function setMarketAddress(address  _marketAddress) external onlyOwner {
        marketingwallet = _marketAddress;
    }
}
