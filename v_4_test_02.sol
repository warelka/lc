pragma solidity 0.4.25;



library SafeMath {

    function mul(uint256 _a, uint256 _b) internal pure returns (uint256) {
        if (_a == 0) {
            return 0;
        }

        uint256 c = _a * _b;
        require(c / _a == _b);

        return c;
    }

    function div(uint256 _a, uint256 _b) internal pure returns (uint256) {
        require(_b > 0);
        uint256 c = _a / _b;

        return c;
    }

    function sub(uint256 _a, uint256 _b) internal pure returns (uint256) {
        require(_b <= _a);
        uint256 c = _a - _b;

        return c;
    }

    function add(uint256 _a, uint256 _b) internal pure returns (uint256) {
        uint256 c = _a + _b;
        require(c >= _a);

        return c;
    }
}

contract Ownable {
    address private _owner;

    constructor () internal {
        _owner = msg.sender;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        _owner = newOwner;
    }
}

contract Adminable is Ownable {
    mapping (address => bool) public admin;

    modifier restricted() {
        require(isOwner() || admin[msg.sender]);
        _;
    }

    constructor() public {
        admin[msg.sender] = true;
    }

    function setAdmin(address addr) public onlyOwner {
        admin[addr] = true;
    }

    function deleteAdmin(address addr) public onlyOwner {
        admin[addr] = false;
    }
}

contract ERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowed;

    uint256 private _totalSupply;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowed[owner][spender];
    }

    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);
        _transfer(from, to, value);
        emit Approval(from, msg.sender, _allowed[from][msg.sender]);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = _allowed[msg.sender][spender].add(addedValue);
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = _allowed[msg.sender][spender].sub(subtractedValue);
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0));

        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(from, to, value);
    }

    function _mint(address account, uint256 value) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.add(value);
        _balances[account] = _balances[account].add(value);
        emit Transfer(address(0), account, value);
    }

    function _burn(address account, uint256 value) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    function _burnFrom(address account, uint256 value) internal {
        _allowed[account][msg.sender] = _allowed[account][msg.sender].sub(value);
        _burn(account, value);
        emit Approval(account, msg.sender, _allowed[account][msg.sender]);
    }
}

contract Token is ERC20 {

    string private _name = "token";
    string private _symbol = "tkn";
    uint8 private _decimals = 0;

    uint256 constant INITIAL_SUPPLY = 1000000 * (10 ** 0);

    constructor() public {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function burn(uint256 value) public {
        _burn(msg.sender, value);
    }

    function burnFrom(address from, uint256 value) public {
        _burnFrom(from, value);
    }

    function name() public view returns(string) {
      return _name;
    }

    function symbol() public view returns(string) {
      return _symbol;
    }

    function decimals() public view returns(uint8) {
      return _decimals;
    }
}

contract ProjectToken is Token, Ownable {
    EventMaster public EM;

    event EMAddrChanged(address oldAddr, address newAddr);

    function setEventMaster(address EM_Addr) external onlyOwner {
        emit EMAddrChanged(EM, EM_Addr);
        EM = EventMaster(EM_Addr);
    }

    function verifiedTransfer(address to, uint256 value) external returns(bool) {
        require(EM.verified(msg.sender));
        _transfer(tx.origin, to, value);
        return true;
    }
}

contract FundRaising {
    using SafeMath for uint256;

    address public admin;

    ProjectToken token;
    EventMaster EM;
    MarketPlace public MP;

    uint256 public start;
    uint256 public finish;
    uint256 public goal;
    uint256 public minProfit;

    uint256 public minAmount;
    uint256 public maxAmount;

    uint256 public tokensRaised;
    uint256 finalBalance;

    bool refunding;

    mapping (address => uint256) public invested;
    mapping (address => bool) refunded;

    event Invested(address indexed addr, uint256 tokens);
    event Finalized();
    event Refunding();
    event Refunded(address indexed addr, uint256 tokens);
    event FeePayed(uint256 amount);
    event AdminRefund(uint256 amount);

    constructor() public {
        EM = EventMaster(msg.sender);
        token = ProjectToken(EM.token());
        admin = tx.origin;
    }

    function init(address MP_Addr, uint256 startUNIX, uint256 finishUNIX, uint256 minValue, uint256 maxValue, uint256 costPrice, uint256 surcharge) public {
        require(msg.sender == address(EM));
        if (!EM.admin(tx.origin)) {
            require(address(MP) == address(0));
        }

        MP = MarketPlace(MP_Addr);

        start = startUNIX;
        finish = finishUNIX;
        minAmount = minValue;
        maxAmount = maxValue;

        goal = (costPrice * ((surcharge).add(10000)) / 10000);
        minProfit = goal.sub(costPrice);
    }

    function invest(uint256 tokens) public {
        /* require(block.timestamp >= start && block.timestamp <= finish); */

        require(tokens >= minAmount && tokens <= maxAmount && tokensRaised < goal);

        if (tokensRaised.add(tokens) >= goal) {
            tokens = goal.sub(tokensRaised);
            emit Finalized();
        }

        token.verifiedTransfer(address(this), tokens);

        invested[msg.sender] += tokens;
        tokensRaised += tokens;

        EM.increaseRating(msg.sender, tokens);

        emit Invested(msg.sender, tokens);
    }

    function MP_withdraw(uint256 amount) external {
        require(msg.sender == address(MP));
        token.transfer(address(MP), amount);
    }

    function finalize() public {
        /* require(block.timestamp >= finish); */
        EM.increaseRating(admin, tokensRaised);

        if (tokensRaised == goal) {
            require(msg.sender == address(MP));
            if (MP.profit() < minProfit) {
                finalBalance = token.balanceOf(address(this));
                uint256 comission = (tokensRaised * EM.comission() / 10000);
                if (comission != 0) {
                    if (token.balanceOf(address(this)) > comission.add(minProfit.sub(MP.profit()))) {
                        token.transfer(EM.wallet(), comission);
                    } else {
                        comission = token.balanceOf(address(this)).sub(minProfit.sub(MP.profit()));
                        token.transfer(EM.wallet(), comission);
                    }
                    emit FeePayed(comission);
                }

                token.transfer(admin, minProfit.sub(MP.profit()));
                emit AdminRefund(minProfit.sub(MP.profit()));
            }
        } else {
            emit Finalized();
        }

        refunding = true;

        emit Refunding();
    }

    function refund(address addr) external {
        require(invested[addr] > MP.purchased(addr) && !refunded[addr] && refunding);

        if (tokensRaised == goal && MP.profit() < minProfit) {
            uint256 share = (finalBalance.sub(minProfit.sub(MP.profit())).sub(tokensRaised * EM.comission() / 10000)) * ((invested[addr].sub(MP.purchased(addr))) * 1e18 / finalBalance) / 1e18;
        } else {
            share = invested[addr].sub(MP.purchased(addr));
        }

        refunded[addr] = true;

        token.transfer(addr, share);

        emit Refunded(addr, share);
    }

}

contract MarketPlace {
    using SafeMath for uint256;

    ProjectToken token;
    EventMaster EM;
    FundRaising public FR;

    uint256 public start;
    uint256 public finish;

    uint256 standardSurcharge;
    uint256 investorsSurcharge;
    uint256 fiatSurcharge;

    mapping (address => uint256) public purchased;
    mapping (address => bool) refunded;

    uint256 public tokensRaised;
    uint256 public profit;

    bool finalized;

    event Purchased(address indexed addr, uint256 tokens, string indexed _type);
    event Finalized(uint256 tokens);
    event Withdrawn(address indexed addr, uint256 tokens);
    event FeePayed(uint256 amount);

    constructor() public {
        EM = EventMaster(msg.sender);
        token = ProjectToken(EM.token());
    }

    function init(address FR_Addr, uint256 startUNIX, uint256 finishUNIX, uint256 _standardSurcharge, uint256 _investorsSurcharge, uint256 _fiatSurcharge) public {
        require(msg.sender == address(EM));
        if (!EM.admin(tx.origin)) {
            require(address(FR) == address(0));
        }

        FR = FundRaising(FR_Addr);

        start = startUNIX;
        finish = finishUNIX;
        standardSurcharge = _standardSurcharge;
        investorsSurcharge = _investorsSurcharge;
        fiatSurcharge = _fiatSurcharge;
    }

    function purchase(uint256 tokens) public {
        /* require(block.timestamp >= start && block.timestamp <= finish); */

        uint256 invested = FR.invested(msg.sender);
        if (invested != 0) {

            tokens = tokens * (10000 + investorsSurcharge) / (10000 + standardSurcharge);
            profit += tokens * (investorsSurcharge) / (10000 + investorsSurcharge);

            if (invested > purchased[msg.sender]) {

                if (invested.sub(purchased[msg.sender]) > tokens) {

                    FR.MP_withdraw(tokens);

                    uint256 tokensToWithdraw = 0;

                } else {

                    FR.MP_withdraw(invested.sub(purchased[msg.sender]));

                    tokensToWithdraw = tokens.sub(invested.sub(purchased[msg.sender]));
                }
            }

            emit Purchased(msg.sender, tokens, "investor");
        } else {

            tokensToWithdraw = tokens;
            profit += tokens * (standardSurcharge) / (10000 + standardSurcharge);

            emit Purchased(msg.sender, tokens, "usual");
        }

        purchased[msg.sender] += tokens;
        tokensRaised += tokens;

        EM.increaseRating(msg.sender, tokens);

        if (tokensToWithdraw != 0) {
            token.verifiedTransfer(address(this), tokensToWithdraw);
        }
    }

    function fiatEntrance(uint256 tokens) public {
        /* require(block.timestamp >= start && block.timestamp <= finish); */

        profit += tokens * (fiatSurcharge) / (10000 + fiatSurcharge);
        tokensRaised += tokens;
        token.verifiedTransfer(address(this), tokens);

        emit Purchased(msg.sender, tokens, "fiat");
    }

    function finalize() external {
        /* require(block.timestamp >= finish); */
        EM.increaseRating(admin(), tokensRaised);

        uint256 adminShare = tokensRaised.sub(profit);

        if (profit < FR.minProfit()) {
            adminShare = adminShare.add(profit);
        } else {
            adminShare = adminShare.add(FR.minProfit());
            uint256 comission = (profit.sub(FR.minProfit())) * EM.comission() / 10000;
            if (comission != 0) {
                token.transfer(EM.wallet(), comission);
                emit FeePayed(comission);
            }
        }

        token.transfer(admin(), adminShare);

        FR.finalize();

        finalized = true;
        emit Finalized(tokensRaised);
    }

    function takeProfit(address addr) external {
        require(FR.invested(addr) > 0 && !refunded[addr] && finalized);

        uint256 tokens = (profit.sub(FR.minProfit()) * (10000 - EM.comission()) / 10000) * FR.invested(addr) / FR.tokensRaised();

        refunded[addr] = true;

        EM.increaseRating(addr, tokens);

        token.transfer(addr, tokens);

        emit Withdrawn(addr, tokens);
    }

    function admin() public view returns(address) {
        return FR.admin();
    }
}

contract RatingSystem is Ownable {
    using SafeMath for uint256;

    mapping (address => uint256) public rating;
    EventMaster public EM;

    event RatingIncreased(address indexed addr, uint256 value);
    event RatingDecreased(address indexed addr, uint256 value);

    modifier allowed {
        require(EM.verified(msg.sender) || EM.admin(msg.sender) || msg.sender == address(EM));
        _;
    }

    function setEventMaster(address EM_Addr) public onlyOwner {
        EM = EventMaster(EM_Addr);
    }

    function increaseRating(address addr, uint256 value) public allowed {
        rating[addr] = rating[addr].add(value);
        emit RatingIncreased(addr, value);
    }

    function decreaseRating(address addr, uint256 value) public allowed {
        rating[addr] = rating[addr].sub(value);
        emit RatingDecreased(addr, value);
    }

    function deleteRating(address addr) public allowed {
        emit RatingDecreased(addr, rating[addr]);
        rating[addr] = 0;
    }
}

contract EventMaster is Adminable {

    ProjectToken public token;
    RatingSystem public RS;
    uint256 public comission;
    address public wallet;

    mapping (address => bool) public verified;

    EventSample[] public events;

    struct EventSample {
        address admin;
        FundRaising FR;
        MarketPlace MP;
    }

    event NewEvent(uint256 index, address indexed admin, address indexed FRAddress, address indexed MPAddress);
    event FRInitialized(uint256 index, address indexed FRAddress, uint256 startUNIX, uint256 finishUNIX, uint256 minValue, uint256 maxValue, uint256 costPrice, uint256 surcharge);
    event MPInitialized(uint256 index, address indexed MPAddress, uint256 startUNIX, uint256 finishUNIX, uint256 _standardSurcharge, uint256 _investorsSurcharge, uint256 _fiatSurcharge);

    function createEvent() public returns(uint256) {
        address newFR = new FundRaising();
        verified[newFR] = true;
        address newMP = new MarketPlace();
        verified[newMP] = true;
        events.push(
          EventSample(msg.sender, FundRaising(newFR), MarketPlace(newMP))
        );
        emit NewEvent(events.length - 1, msg.sender, newFR, newMP);
        return(events.length - 1);
    }

    function initFundRaising(uint256 index, uint256 startUNIX, uint256 finishUNIX, uint256 minValue, uint256 maxValue, uint256 costPrice, uint256 surcharge) public {
        require(msg.sender == events[index].admin);
        events[index].FR.init(events[index].MP, startUNIX, finishUNIX, minValue, maxValue, costPrice, surcharge);
        emit FRInitialized(index, address(events[index].FR), startUNIX, finishUNIX, minValue, maxValue, costPrice, surcharge);
    }

    function initMarketPlace(uint256 index, uint256 startUNIX, uint256 finishUNIX, uint256 _investorsSurcharge, uint256 _standardSurcharge, uint256 _fiatSurcharge) public {
        require(msg.sender == events[index].admin);
        events[index].MP.init(events[index].FR, startUNIX, finishUNIX, _standardSurcharge, _investorsSurcharge, _fiatSurcharge);
        emit MPInitialized(index, address(events[index].MP), startUNIX, finishUNIX, _standardSurcharge, _investorsSurcharge, _fiatSurcharge);
    }

    function setToken(address tokenAddr) public restricted {
        token = ProjectToken(tokenAddr);
    }

    function setRS(address RS_Addr) public restricted {
        RS = RatingSystem(RS_Addr);
    }

    function setComission(uint256 newComission) public restricted {
        comission = newComission;
    }

    function setWallet(address newWallet) public restricted {
        wallet = newWallet;
    }

    function increaseRating(address to, uint256 value) public {
        require(admin[msg.sender] || verified[msg.sender]);
        RS.increaseRating(to, value);
    }
}
