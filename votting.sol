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
    
    function balanceOf(address _owner) public returns (uint256 balance);
    function transfer(address _to, uint256 _value) public returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
    function approve(address _spender, uint256 _value) public returns (bool success);
    function allowance(address _owner, address _spender) public view returns (uint256 remaining);
}

contract CandidateManage {
    
    using SafeMath for uint;
    uint constant MINIMUM_PLEDGE_TOKEN = 100;
    address public jrAddr = address(0xc00430870bd4d4bd891bf2424ae00277bd9a5f09);
    JustitiaReputionToken public justitia = JustitiaReputionToken(0xc00430870bd4d4bd891bf2424ae00277bd9a5f09);
    
     struct Candidate{
        address candidate;
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
        
        uint256 pledges;
        pledges = justitia.balanceOf(_owner).sub(justitia.residePledge(_owner));
        require(balanceOfPledge[_owner] == pledges);
        
        return (justitia.balanceOf(_owner), pledges);
    }
    
    // get candidate information
    function candidateState(address candidate) public view returns(uint256, uint256, string){
        require(isCandidate(candidate));
        return (candidateLookup[candidate].pledge, candidateLookup[candidate].ranking, candidateLookup[candidate].memo);
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
    function ApplyToCandidate(address applicant, uint pledge, string memo) public returns(bool, string){
        string memory errors;
        Candidate memory candidate;
  
        require(Normal == getRole(applicant));
        if(!candidateCriteria(applicant, pledge)){
            errors = "errors: some criterias not met.";
            emit ApplyToCandidateEvent(applicant, false, errors);
            return (false, errors);
        }
        
        candidate.memo = memo;
        candidate.isValid = true;
        candidate.pledge = pledge;
        candidate.candidate = applicant;
        candidate.ranking = adjustCandidateList(applicant, pledge);
        candidateLookup[applicant] = candidate;
        justitia.lockCount(applicant, pledge);
        totalPledge = totalPledge.add(pledge);
    }
    
    // get candidates
    function Candidates() public view returns(address[]){
        return CandidateList;
    }
}

