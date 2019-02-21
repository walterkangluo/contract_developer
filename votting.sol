pragma solidity >=0.4.24 <0.6.0;

/*
* 安全操作函数
*  SafeMath to avoid data overwrite
*/
library SafeMath {
    function mul(uint a, uint b) internal pure returns (uint) {
        uint c = a * b;
        require(a == 0 || c / a == b, "overwrite error");
        return c;
    }
 
    function div(uint a, uint b) internal pure returns (uint) {
        require(b > 0, "overwrite error");
        uint c = a / b;
        require(a == b * c + a % b, "overwrite error");
        return c;
    }
 
    function sub(uint a, uint b) internal pure returns (uint) {
        require(b <= a, "overwrite error");
        return a - b;
    }
 
    function add(uint a, uint b) internal pure returns (uint) {
        uint c = a + b;
        require(c>=a && c>=b, "overwrite error");
        return c;
    }
}

contract JustitiaReputionToken {
    uint256 public totalSupply;
    
    function lockCount(address _account, uint _count) public;
    function unlockCount(address _account, uint _count) public;
    function residePledge(address _owner) public view returns(uint);
    
    function balanceOf(address _owner) public view returns (uint256 balance);
    function transfer(address _to, uint256 _value) public returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
    function approve(address _spender, uint256 _value) public returns (bool success);
    function allowance(address _owner, address _spender) public view returns (uint256 remaining);
}

contract CandidateManage {
    
    using SafeMath for uint;
    uint constant MINIMUM_PLEDGE_TOKEN = 100;
    address public jrAddr = address(0x9f4c14f487b8e4e3986467c2a2aa5bde93052666);
    JustitiaReputionToken public justitia = JustitiaReputionToken(0x9f4c14f487b8e4e3986467c2a2aa5bde93052666);
    
    struct Candidate{
        address account;
        uint pledge;
        uint ranking;   // rank of candidates
        string memo;
        bool isValid;
    }
    address [] public CandidateList;
    mapping(address => Candidate) public candidateLookup;
    
    uint8 constant public Normal = 1;
    uint8 constant public Participate = 2;
    uint8 constant public Candidator = 3;
    
    uint256 public totalPledge;
    // mapping(support, totalPledge)
    mapping(address => uint256) public balanceOfPledge;
    
    // event define
    event ApplyToCandidateEvent(address, bool, string);
    
    // role classify
    // normal: account with PR, which has right to vote
    // participate: normal account which has participate in vote and has peldge currently
    // candidate: account pledge PR to be a candidate
    function getRole(address _account) public view returns(uint8){
        if(isCandidate(_account)){
            return Candidator;
        }
        if (0 != balanceOfPledge[_account]){
            return Participate;
        }
        return Normal;
    }
    
    // criterias to be a candidate 
    function candidateCriteria(address candidate, uint256 pledge) public view returns(bool){
        uint256 balance = justitia.residePledge(candidate);
        if(MINIMUM_PLEDGE_TOKEN <= balance && balance >= pledge){
            return true;
        }
        return false;
    }
    
    // whether the account is candidate
    function isCandidate(address account) public view returns(bool){
        return candidateLookup[account].isValid;
    }
    
    // get pledge balance of address
    function balanceStatistic(address _owner) public returns (uint256 balance, uint256 pledge){
        require(address(0) != _owner);
        
        uint256 total;
        uint256 reside;
        
        total = justitia.balanceOf(_owner);
        reside = justitia.residePledge(_owner);
        
        require(total.sub(reside) == balanceOfPledge[_owner]);
        
        return (total, balanceOfPledge[_owner]);
    }
    
    // get candidate information
    function candidateState(address candidate) public view returns(uint256, uint256, string){
        require(isCandidate(candidate));
        return (candidateLookup[candidate].ranking, candidateLookup[candidate].pledge, candidateLookup[candidate].memo);
    }
    
    // find index to insert the account by specified candidate in CandidateList
    function findIndexOfCandidate(uint pledge) private view returns(uint){
        uint index;
        for(index = 0; index < CandidateList.length; index++){
            if(candidateLookup[CandidateList[index]].pledge <= pledge){
                break;
            }
        }
        return index;
    }
    
    // add applicant to candidate list
    function addToCandidateListDescending(address applicant, uint pledge) private returns(uint){
        uint index;
        index = findIndexOfCandidate(pledge);
        CandidateList.push(applicant);
        for(uint i = CandidateList.length - 1; i > index; i--){
            CandidateList[i] = CandidateList[i - 1];
        }
        CandidateList[index] = applicant;
        return index;
    }
    
    // candidate list adjustment
    function adjustCandidateList(address candidate, uint pledge) public returns(uint){
        if(!isCandidate(candidate)){
            return addToCandidateListDescending(candidate, pledge);
        } 
        
        uint currentIndex;
        uint rightIndex;
        for(currentIndex = 0; currentIndex < CandidateList.length; currentIndex++){
            if(candidateLookup[CandidateList[rightIndex]].pledge > candidateLookup[candidate].pledge){
                rightIndex++;
            }
            if(CandidateList[currentIndex] == candidate){
                break;
            }
        }
        for(uint i = currentIndex; currentIndex > rightIndex; i++){
            CandidateList[i] = CandidateList[i - 1];
        }
        CandidateList[rightIndex] = candidate;
        return rightIndex;
    }
    
    // apply to candidate 
    function ApplyToCandidate(uint pledge, string memo) public returns(bool, string){
        string memory errors;
        Candidate memory candidate;
  
        require(Normal == getRole(msg.sender));
        if(!candidateCriteria(msg.sender, pledge)){
            errors = "errors: some criterias not met.";
            emit ApplyToCandidateEvent(msg.sender, false, errors);
            return (false, errors);
        }
        
        candidate.memo = memo;
        candidate.isValid = true;
        candidate.pledge = pledge;
        candidate.account = msg.sender;
        candidate.ranking = adjustCandidateList(msg.sender, pledge);
        
        justitia.lockCount(msg.sender, pledge);
        totalPledge = totalPledge.add(pledge);
        candidateLookup[msg.sender] = candidate;
        balanceOfPledge[msg.sender] = balanceOfPledge[msg.sender].add(pledge);
        emit ApplyToCandidateEvent(msg.sender, true, errors);
        return (true, errors);
    }
    
    // get candidates
    function Candidates() public view returns(address[]){
        return CandidateList;
    }
}


/* 
*  系统合约调用
*  管理选举情况，包括：选举，取消选举，选举情况统计等
*/
contract ElectionManage is CandidateManage {
    
    using SafeMath for uint;
  
    uint constant ENTRY_HRESHOLD = 100;
    uint constant MAINNET_ONLINE_THRESHOLD = 1000;
    
    event VottingEvent(address, address, uint);
    event VottingCanceledEvent(address, address, uint);
    
    struct Election{
        bool isValid;
        address[] participates;
        mapping(address => uint) election; 
    }
    mapping(address => Election) public candidateElection;

    
    function vote(address candidate, uint pledge) public {
        uint8 role = getRole(msg.sender);
        
        require(isCandidate(candidate));
        require(!isCandidate(candidate));
        require(pledge <= justitia.residePledge(msg.sender));
        
        if(!candidateElection[candidate].isValid){
            candidateElection[candidate].participates.push(msg.sender);
            candidateElection[candidate].isValid = true;
        }
        
        candidateElection[candidate].election[msg.sender] = candidateElection[candidate].election[msg.sender].add(pledge);
        candidateLookup[candidate].pledge = candidateLookup[candidate].pledge.add(pledge);
        adjustCandidateList(candidate, candidateLookup[candidate].pledge);
        totalPledge = totalPledge.add(pledge);
        emit VottingEvent(msg.sender, candidate, pledge);
    }
    
    function cancelVotted(address candidate, uint pledge) public {
        require(isCandidate(candidate));
        require(pledge <= candidateElection[candidate].election[msg.sender]);
        
        candidateLookup[candidate].pledge = candidateLookup[candidate].pledge.sub(pledge);
        candidateElection[candidate].election[msg.sender] = candidateElection[candidate].election[msg.sender].sub(pledge);
        adjustCandidateList(candidate, candidateLookup[candidate].pledge);
        totalPledge = totalPledge.sub(pledge);
        emit VottingCanceledEvent(msg.sender, candidate, pledge);
    }
}


contract CommunityManage is ElectionManage{
    
    bool public mainNetSwitch;
    uint constant MAINNET_ONLINE_THRESHOLD = 1000;
    
     event MainNetOnlineEvent(uint, uint, uint);
    
    // try to online main network
    function tryToOnlineMainNet() private {
        if(!mainNetSwitch){
            if(totalPledge >= MAINNET_ONLINE_THRESHOLD){
                mainNetSwitch = true;
                //emit MainNetOnlineEvent(now, justitia.totalSupply, totalPledge);
            }
        }
    }
    
    function GetOnlineSymbol() public view returns(bool){
        return mainNetSwitch;
    }
    
    function CancelVote(address candidate, uint canceledPledge) public {
        require(isCandidate(candidate));
        cancelVotted(candidate, canceledPledge);
    }
    
    function Votting(address candidate, uint pledge) public{
        require(isCandidate(candidate));
        vote(candidate, pledge);
        tryToOnlineMainNet;
    }
}

