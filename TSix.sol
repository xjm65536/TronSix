pragma solidity ^0.4.0;


library Bytes {

    // Copy 'len' bytes from memory address 'src', to address 'dest'.
    // This function does not check the or destination, it only copies
    // the bytes.
    function copy(uint src, uint dest, uint len) internal pure {
        // Copy word-length chunks while possible
        for (; len >= /*BYTES_HEADER_SIZE*/32; len -= /*BYTES_HEADER_SIZE*/32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += /*BYTES_HEADER_SIZE*/32;
            src += /*BYTES_HEADER_SIZE*/32;
        }

        // Copy remaining bytes
        uint mask = 256 ** (/*BYTES_HEADER_SIZE*/32 - len) - 1;
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }

    // This function does the same as 'dataPtr(bytes memory)', but will also return the
    // length of the provided bytes array.
    function fromBytes(bytes memory bts) internal pure returns (uint addr, uint len) {
        len = bts.length;
        assembly {
            addr := add(bts, /*BYTES_HEADER_SIZE*/32)
        }
    }

    // Combines 'self' and 'other' into a single array.
    // Returns the concatenated arrays:
    //  [self[0], self[1], ... , self[self.length - 1], other[0], other[1], ... , other[other.length - 1]]
    // The length of the new array is 'self.length + other.length'
    function concat(bytes memory self, bytes memory other) internal pure returns (bytes memory) {
        bytes memory ret = new bytes(self.length + other.length);
        (uint src, uint srcLen) = fromBytes(self);
        (uint src2, uint src2Len) = fromBytes(other);
        (uint dest,) = fromBytes(ret);
        uint dest2 = dest + src2Len;
        copy(src, dest, srcLen);
        copy(src2, dest2, src2Len);
        return ret;
    }
}

library SafeMath {

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }


    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0); // Solidity only automatically asserts when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
    * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        if(b > a) {
            return 0;
        } else {
            uint256 c = a - b;
            return c;
        }

    }

    /**
    * @dev Adds two numbers, reverts on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
    * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
    * reverts when dividing by zero.
    */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

contract Ownership {
    address public owner;
    bool public paused = false;
    mapping(address => uint256)  internal  admins;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Ownerkilled(address, uint256);
    event SetAdmin(address, uint256);
    event GamePaused(address);
    event GameUnPaused(address);

    constructor() public {
        owner = msg.sender;
        admins[owner] = 1;
    }

    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    /*
     * only human is allowed to call this contract
     */
    modifier isHuman() {
        require((bytes32(msg.sender) & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) == (bytes32(tx.origin) & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF));
        _;
    }

    modifier  onlyAdmin() {
        bool isInArray = false;
        if (admins[msg.sender] > 0) {
            isInArray = true;
        }
        require(isInArray);
        _;
    }

    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    modifier whenPaused {
        require(paused);
        _;
    }

    function isPaused() view public onlyOwner returns(bool) {
        return paused;
    }

    function pause() public onlyOwner {
        paused = true;
        emit GamePaused(msg.sender);
    }

    function unPause() public onlyOwner {
        paused = false;
        emit GameUnPaused(msg.sender);
    }

    function setAdmin(address owner_address) public onlyOwner {
        admins[owner_address] = 1;
        emit  SetAdmin(owner_address, admins[owner_address]);
    }

    //过户
    function transferOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function ownerkill() public onlyOwner {
        emit Ownerkilled(msg.sender, address(this).balance);
        selfdestruct(owner);
    }

    function getBlockHash(uint256 blockNum) view public returns(bytes32) {
        return blockhash(blockNum);
    }
}

contract DividendFund {
    // YESToken private myToken;

    function playerFrom(bytes32 inviterCode, address sender) external returns (bool);
    function showInvitationCodeOf(bytes32 _code) external view returns (address);
    function showInviter(address _addr) external view returns(address);

    function mintToken(address _player, uint256 _betAmount) external;
    function fundTrx() external payable;

    function setTokenAddr(address _newAddress) public;
    function getTokenAddr() view public returns(address);
}

contract YESToken {
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
}

contract Oracle {
    using Bytes for *;
    address private countAddr;
    address private owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    function setCounter(address addr) public onlyOwner {
        countAddr = addr;
    }

    function getCounter() view public onlyOwner returns(address){
        return countAddr;
    }

    function randomNum(bytes32 _sysRandom, /*bytes32 _betRandom, */uint256 _blockNum) view external returns (uint8)
    {
        require(msg.sender == countAddr);
        bytes32 _blockhash = blockhash(_blockNum);
        bytes memory res = abi.encodePacked(_sysRandom).concat(abi.encodePacked(_blockhash));//.concat(abi.encodePacked(block.number));
        bytes32 _sha3 = keccak256(res);
        return uint8(uint256(_sha3) % 6);
    }
}

contract TSix is Ownership{

    struct Reward{
        uint256 amount;
        address addr;
    }

    Counter private countAddr; // Counter Contract
    mapping(bytes32 => Reward) private rewards;

    event Human(bytes32 indexed sender, bytes32 indexed origin);

    // constructor () public payable{}
    function () public payable {log2(0x00001, bytes32(msg.sender), bytes32(msg.value));}

    function setCounter(address addr) public onlyOwner {
        countAddr = Counter(addr);
    }

    function getCounter() view public onlyOwner returns(address){
        return countAddr;
    }

    function doBet(bytes32 _betId, /*bytes32 _random, */uint8 _betNum) public payable whenNotPaused isHuman returns (uint256) {
        _betNum = _betNum & 0x3f;
        require(_betNum < 63 && _betNum > 0);
        require(_betId.length == 32 && _betId > bytes32(0));
        // must bet more than 20 trx
        require(msg.value >= 20000000 && msg.value <= 2000000000);
        countAddr.doBet.value(msg.value)(msg.sender, _betId, /*_random, */_betNum);
        return block.number;
    }

    function getReward(bytes32 betId) view public returns(uint256){
        Reward storage r = rewards[betId];
        // only creator or Bet can query the detail reward;
        require(owner == msg.sender || r.addr == msg.sender);
        return r.amount;
    }

    function doReward(address _addr, bytes32 _betId) public payable {
        require(msg.sender == address(countAddr));
        require(_addr > 0);
        require(msg.value >= 0);
        require(rewards[_betId].amount == 0);
        rewards[_betId] = Reward(msg.value, _addr);

        if (msg.value > 0){
            _addr.transfer(msg.value);
        }
    }

    function close() public onlyOwner {
        log1(0x00002, bytes32(address(this).balance));
        selfdestruct(owner);
    }
}

// 记账的合约
contract Counter is Ownership{

    // /*
    //  * checks only owner address is calling
    //  */
    // modifier onlyOwner {
    //     require(msg.sender == creator);
    //     _;
    // }

    // modifier onlySuperAdmin {
    //     require(admins[msg.sender] >= 10000);
    //     _;
    // }

    // modifier onlyAdmin {
    //     require(admins[msg.sender] >= 1000);
    //     _;
    // }

    // modifier onlyOperator {
    //     require(admins[msg.sender] >= 10);
    //     _;
    // }

    Oracle private oracle;
    DividendFund private myFund;
    TSix private betAddr;

    event ShortCoin(address indexed sender, address indexed beter, bytes32 indexed betId, uint256 nowAmnt, uint256 needAmnt);

    struct Bet{
        uint8 state; // 0: invalid, 1: valid, 2: reward
        uint8 lot;  // 0: invalid, 1: 1st prize, 2: 2rd prize, 3: 3th prize

        uint8 num;
        /*bytes32 random;*/

        uint256 amount;
        uint256 blockNum;
        address addr;
    }

    bytes32 private sysSalt; // system salt
    event betEvent(address user, bytes32 betId, /*bytes32 random, */uint256 betValue, uint256 betNum);

    event betRetEvent(address user, /*bytes32 random, */uint256 num, uint256 amount, uint8 lot, uint8 state);
    event fundEvent(address founder, uint256 fondAmount, uint256 remainAmount);

    // betId => Bet
    mapping(bytes32 => Bet) private bets;

    uint256  public fundIn;
    uint256  public fundOut;

    /**
     * the sysSalt can only be set once.
     */
    function initSysSolt(bytes32 salt) public onlyOwner {
        require(sysSalt == 0x0);
        sysSalt = salt;
    }

    function () public payable {log2(0x00001, bytes32(msg.sender), bytes32(msg.value));}

    function getBet(bytes32 bid) public {
        Bet storage bet = bets[bid];
        require(admins[msg.sender] >= 1 || bet.addr == msg.sender);
        emit betRetEvent(bet.addr, bet.num, bet.amount, bet.lot, bet.state);
    }

    function doBet(address _user, bytes32 _betId, /*bytes32 _betRandom, */uint8 _betNum) public payable {
        require(msg.sender == address(betAddr));
        require(msg.value > 0);
        /* require(_betRandom > bytes32(0));*/

        // game mint
        if ( address(myFund) > 0x0){
            myFund.mintToken(_user, msg.value);
        }
        fundIn = SafeMath.add(fundIn, msg.value);

        bets[_betId] = Bet(1, 0, _betNum, /*_betRandom, */msg.value, block.number, _user);
        // unopenBets[betId] = block.number;
        emit betEvent(_user, _betId, /*_betRandom, */msg.value, _betNum);
    }

    function doReveal(address _user, bytes32 _betId, uint8 _num, uint256 _amount) public onlyAdmin returns(uint256){
        require(_betId > 0);
        _num = _num & 0x3f;
        Bet storage bet = bets[_betId];
        require(bet.state == 1);
        require(bet.blockNum < block.number);
        require(bet.amount == _amount && bet.num == _num && bet.addr == _user);

        uint8 rNum = oracle.randomNum(sysSalt, /*bet.random, */block.number);

        if (_num & (1 << rNum) > 0){
            uint8 lotto = 0;
            for (; _num > 0; ++lotto){_num &= (_num - 1);}

            uint256 rewardAmount = SafeMath.mul(58800, _amount);
            rewardAmount = SafeMath.div(rewardAmount, lotto * 10000);//  (6 * 9800 * bet.amount) / ( lotto * 10000);
            fundOut = SafeMath.add(fundOut, rewardAmount);

            if ((address(this)).balance < rewardAmount){
                bet.state = 1;
                emit ShortCoin(msg.sender, _user, _betId, (address(this)).balance, rewardAmount);
            }else{
                bet.lot = lotto;
                bet.state = 2;
                betAddr.doReward.value(rewardAmount)(_user, _betId);
                return rewardAmount;
            }
        }else{
            bet.state = 2;
        }
        return 0;
    }

    /**
     * if it's is reached 10000 TRX, then try to fund
     */
    function doFound() public onlyAdmin returns(uint256){
        uint256 foundAmount = SafeMath.sub(fundIn, fundOut);
        if (address(myFund) > 0x0){
            fundIn = 0;
            fundOut = 0;
            myFund.fundTrx.value(foundAmount)();
            emit fundEvent(msg.sender, foundAmount, address(this).balance);
            return foundAmount;
        }
        return 0;
    }

    function getFundAmount() public view returns(uint256){
        if (fundIn <= fundOut){
            return 0;
        }
        return SafeMath.sub(fundIn, fundOut);
    }

    function setOracleAddr(address _newAddress) public onlyOwner {
        oracle = Oracle(_newAddress);
    }

    function getOracleAddr() view public onlyAdmin returns(address) {
        return oracle;
    }

    function setFundAddr(address _newAddress) public onlyOwner {
        myFund = DividendFund(_newAddress);
    }

    function getFundAddr() view public returns(address) {
        return myFund;
    }

    function setBetAddr(address addr) public onlyOwner {
        betAddr = TSix(addr);
    }

    function getBetAddr() view public onlyAdmin returns(address) {
        return betAddr;
    }

}