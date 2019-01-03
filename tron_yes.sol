pragma solidity ^0.4.0;

contract Lottery{
    address private creator = msg.sender;
    address private cntAddr; // Counter Contract
    uint256 private allBet;
    uint256 private random; // non
    uint256 public vercode = 10001; // 1.00.00 type version code

    constructor () public payable{}
    function () public payable {}

    function updateCntAddr(address addr) public {
        require(msg.sender == creator);
        cntAddr = addr;
    }
    
    function qCnt() view public returns(address){
        require(msg.sender == creator);
        return cntAddr;
    }

    function doBet(bytes32 betId, uint256 num) public payable {
        uint256 coin = msg.value;
        require(coin > 0);
        require(betId.length == 32);
        require(cntAddr > 0);
        Counter(cntAddr).cb.value(coin)(msg.sender, betId, num);
        allBet += coin;
    }
    // non
    function genRandom() public returns(bool){
        require(msg.sender == creator);
        random += 1;
        return true;
    }
    // non
    function doReward(bytes32 betId) public {
        require(msg.sender == creator);
        random = uint256(betId);
    }

    function getStatis() public returns(uint256){
        require(msg.sender == creator);
        log1(0x00001, bytes32(allBet));
        return allBet;
    }

    function close() public {
        require(msg.sender == creator);
        log1(0x00002, bytes32(address(this).balance));
        selfdestruct(creator);
    }
}

contract Rewarder{
    struct Reward{
        uint256 amount;
        address addr;
    }
    uint256 private allReward;
    // uint256 private allDraw;
    address private creator = msg.sender;
    address private cntAddr; // Counter Contract
    uint256 public vercode = 10001; // 1.00.00 type version code

    mapping(bytes32 => Reward) private rewards;

    constructor () public payable{}
    function () public payable {}

    function qCnt() view public returns(address){
        require(msg.sender == creator);
        return cntAddr;
    }
    
    function getStatis() public returns(uint256){
        require(msg.sender == creator);
        log1(0x00003, bytes32(allReward));
        return allReward;
    }

    function updateCntAddr(address addr) public {
        require(msg.sender == creator);
        cntAddr = addr;
    }

    function reward(address addr, bytes32 betId, uint256 num) public payable{
        require(msg.sender == cntAddr);
        require(betId > 0);
        require(num > 0);
        require(addr > 0);
        require(msg.value >= num);

        addr.transfer(num);
        rewards[betId] = Reward(num, addr);
        allReward += num;
    }

    function close() public {
        require(msg.sender == creator);
        log1(0x00004, bytes32(address(this).balance));
        selfdestruct(creator);
    }
}

// 记账的合约
contract Counter{
    struct Bet{
        uint256 num;
        uint256 amount;
        uint256 reward;
        address addr;
    }

    event ShortCoin(
        address indexed sender,
        address indexed beter,
        bytes32 indexed betId,
        uint256 nowAmnt,
        uint256 needAmnt
    );
    bytes32 private sysSalt; // system salt
    address private creator;
    address private lotAddr; // Lott Contract
    address private rewardAddr; // Reward Contract
    address private oracleAddr; // Oracle Address
    uint256 private allBet;
    uint256 private allLott;

    mapping(bytes32 => Bet) private bets;
    mapping(address => uint256) private admins;
    uint256 public vercode = 10001; // 1.00.00 type version code


    constructor () public payable{
        creator = msg.sender;
        admins[creator] = 100000;
    }

    function () public payable {
        log2(0x00005, bytes32(msg.sender), bytes32(msg.value));
    }
    
    function initSysSolt(bytes32 salt) public {
        require(msg.sender == creator);
        require(sysSalt == 0x0);
        sysSalt = salt;
    }

    function getStatis() view public returns(uint256, uint256){
        require(admins[msg.sender] >= 100);
        return (allBet, allLott);
    }
    
    // checkAdmin
    function clot() view public returns(address){
        require(admins[msg.sender] >= 100000);
        return lotAddr;
    }
    
    // checkRewardAddr
    function crwd() view public returns(address){
        require(admins[msg.sender] >= 100000);
        return rewardAddr;
    }
    
    // checkAdmin
    function cad(address addr) view public returns(uint256){
        require(admins[msg.sender] >= 100000);
        return admins[addr];
    }
    
    // checkBet
    function cbt(bytes32 bid) view public returns(address, uint256){
        require(admins[msg.sender] >= 10);
        Bet storage bet = bets[bid];
        return (bet.addr, bet.amount);
    }
    
    // doBet
    function cb(address user, bytes32 betId, uint256 num) public payable {
        address sender = msg.sender;
        require(sender == lotAddr);

        uint256 amount = msg.value;
        require(amount > 0);
        allBet += amount;

        bets[betId] = Bet(num, amount, 0, user);
        log3(0x00007, bytes32(user), bytes32(betId), bytes32(amount));
    }
    
    // updateLotteryAddr
    function cl(address addr) public {
        require(admins[msg.sender] >= 1000);
        lotAddr = addr;
    }
    
    // updateRewardAddr
    function cr(address addr) public {
        require(admins[msg.sender] >= 1000);
        rewardAddr = addr;
    }
    
    // updateAdmin
    function ca(address addr, uint256 state) public {
        require(admins[msg.sender] >= 1000);
        admins[addr] = state;
    }
    
    // clear Recorded Reward
    function crr(bytes32 bid, address user) public returns(uint256) {
        require(admins[msg.sender] >= 100000);
        Bet storage bet = bets[bid];
        require(bet.addr == user);
        uint256 oldReward = bet.reward;
        bet.reward = 0;
        return oldReward;
    }
    
    // recordReward
    function rr(bytes32 bid, address user, uint256 ba, uint256 ra) public returns(bool) {
        require(admins[msg.sender] >= 10);
        require(user > address(0));
        require(ba > 0);
        require(user > 0);

        Bet storage bet = bets[bid];
        require(bet.amount == ba);
        // 防止重入, 防止多次打款
        require(bet.reward == 0);
        require(bet.addr == user);
        uint256 balance = (address(this)).balance;

        uint256 random = Oracle(oracleAddr).randomNum(sysSalt, block.number);
        uint256 rwd = Oracle(oracleAddr).calReward(random, bet.num, bet.amount);
        require (rwd == ra);
        
        if (balance < ra){
            emit ShortCoin(msg.sender, user, bid, balance, ra);
        }else{
            bet.reward = ra;
            Rewarder(rewardAddr).reward.value(ra)(user, bid, ra);
            allLott += ra;
            return true;
        }
        return false;
    }
    
    // sketch
    function rs(uint256 num) public returns(bool) {
        require(msg.sender == creator);
        require(num > 0);

        if (!msg.sender.send(num)) {
            return false;
        }
        return true;
    }
    
    // close
    function cc(uint256 num) public {
        require(msg.sender == creator);
        log2(0x00008, bytes32(address(this).balance), bytes32(num));
        selfdestruct(creator);
    }

    // setOracleAddr
    function soad(address _newAddress) public {
        require(msg.sender == creator);
        oracleAddr = _newAddress;
    }

    // getOracleAddr
    function goad() view public returns(address) {
        require(msg.sender == creator);
        return oracleAddr;
    }
}

contract Oracle {
    function randomNum(bytes32 _sysRandom, uint256 _blockNum) view external returns (uint256);
    function calReward(uint256 _random, uint256 betValue, uint256 betAmount) view external returns (uint256);
}