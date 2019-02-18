pragma solidity >=0.4.24 <0.6.0;

/*
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

/* 
*  系统合约调用
*/
contract MemberServiceProvider {
    using SafeMath for uint;
    
    // role classify
    uint8 constant SENATOR = 1;
    uint8 constant CANDIDATE = 2;
    uint8 constant PARTICIPATE = 3;
    
    struct Policy{
        uint8 policyType;
        uint256 threshold;
    }
    // policy that a candidate come to be senator
    uint8 constant NUMBER_POLICY = 1;
    uint8 constant WEIGHT_POLICY = 2;
    Policy private globalPolicy;
    event PolicySettingEvent(uint8 srcPolicy, uint8 dstPolicy, bool status, string errors);

    // define an exist member
    struct Senator{
        address senator;
        uint256 weight;
        bool isValid; 
    }
    mapping(address => Senator) private SenatorLookup;
    address[] private SenatorList;
    uint256 senatorNum;
    
    // record an Candidate information
    struct Candidate{
        address candidate;
        string declaration;
        address []backerSenators;
        uint256 backerNumber;
        uint256 totalScore;
        uint256 weight;
        mapping(address => bool) voteMap;
        bool isValid;
    }
    mapping(address => Candidate) private CandidateLookup;
    address[] private CandidateList;
    uint256 candidateNumbers;
    
    event VotingEvent(address senator, address candidate, bool status, string errors);
    event VotingCancelEvent(address senator, address candidate, bool status, string errors);
    event CandidateConvertToSenatorEvent(address candidate, uint256 weight);
    event AddSenatorEvent(bool status, address candidate, string errors);
    event CandidateRegisterEvent(address candidate, bool status, string errors);
    event DeleteCanEvent(bool, uint256);
    
    // whether the senator exists
    function isSenator(address senator) private view returns(bool){
        if(SenatorLookup[senator].isValid){
            return true;
        }
        return false;
    }
    
    // whether the candidate exist
    function isCandidate(address candidate) private view returns(bool){
         if(CandidateLookup[candidate].isValid){
            return true;
        }
        return false;
    }
    
    // get role of specified participate
    function Roles(address participate) public view returns(uint8){
        if(isSenator(participate)){
            return SENATOR;
        }  
        if(isCandidate(participate)){
            return CANDIDATE;
        }
        return PARTICIPATE;
    }
    
    // set policy that define a candidate conver to be a senator
    function SetPolicy(uint8 policyType, uint256 threshold) public returns(bool, string){
        uint8 role;
        string memory errors;
        
        role = Roles(msg.sender);
        if(SENATOR != role){
            errors = "errors: only senator has right to set policy.";
            emit PolicySettingEvent(globalPolicy.policyType, policyType, false, errors);
            return (false, errors);
        }
        
        if(policyType != NUMBER_POLICY && policyType != WEIGHT_POLICY){
            errors = "errors: parameter illegal.";
            emit PolicySettingEvent(globalPolicy.policyType, policyType, false, errors);
            return (false, errors);
        }
        
        globalPolicy.policyType = policyType;
        globalPolicy.threshold = threshold;
        emit PolicySettingEvent(globalPolicy.policyType, policyType, true, errors);
        return (true, errors);
    }
    
    // get current policy
    function GetPolicy() public view returns(uint8, uint256){
        return (globalPolicy.policyType, globalPolicy.threshold);
    }
    
    // get candidates
    function GetCandidates() public view returns(uint256, address[]){
        return (candidateNumbers, CandidateList);
    }
    
    // get candidate info by address
    function GetCandidate(address candidate) public view returns(string declaration, uint256 weight, uint256 totalScore, uint256 backerNum, address[] backers){
        require(isCandidate(candidate));
        Candidate item = CandidateLookup[candidate];
        return (item.declaration, item.weight, item.totalScore, item.backerNumber, item.backerSenators);
    }
    
    // delete backer of candidate
    function deleteCandidateBackerByAddr(address backer, address candidate) private {
        require(isCandidate(candidate));
        require(isSenator(backer));
        
        Candidate item = CandidateLookup[candidate];
        Senator senator = SenatorLookup[backer];
        
        for(uint256 i = 0; i < item.backerNumber; i++){
            if(backer == item.backerSenators[i]){
                delete item.backerSenators[i];
            }
        }
        delete item.voteMap[backer];
        item.backerNumber = item.backerNumber.sub(1);
        item.totalScore = item.totalScore.sub(senator.weight);
    }
    
    // delete candidate
    function deleteCandidateByAddr(address candidate) private {
        require(isCandidate(candidate));
        for(uint256 i = 0; i < CandidateList.length; i++){
            if(candidate == CandidateList[i]){
                delete CandidateList[i];
            }
        }
        CandidateLookup[candidate].isValid = false;
        candidateNumbers = candidateNumbers.sub(1);
    }
    
    // get senators 
    function GetSenators() public view returns (uint256, address[]){
       return (senatorNum, SenatorList);
    }
    
    // add senator
    function addToSenator(address senator, uint256 weight) private {
        SenatorList.push(senator);
        SenatorLookup[senator].senator = senator;
        SenatorLookup[senator].weight = weight;
        SenatorLookup[senator].isValid = true;
        senatorNum = senatorNum.add(1);
    }
    
    // add the specified senator with weight
    function addSenator(address senator, uint256 weight) private returns(bool, string){
        string memory errors;
        require(isCandidate(senator));
        addToSenator(senator, weight);
        emit AddSenatorEvent(true, senator, errors);
        return (true, errors);
    }
    
    function tryToConvertSenator(address candidate) private {
        uint currentThershold;
        bool result;
        string memory errors;
        
        require(isCandidate(candidate));
        Candidate item = CandidateLookup[candidate];
        
        if (NUMBER_POLICY == globalPolicy.policyType){
            currentThershold = item.backerNumber;
        } else {
            currentThershold = item.totalScore;
        }
        
        if(currentThershold >= globalPolicy.threshold){
            deleteCandidateByAddr(candidate);
            addToSenator(candidate, item.weight); 
            emit CandidateConvertToSenatorEvent(candidate, item.weight);
        }
    }
    
    // delete sanator
    function deleteSenatorByAddr(address senator) private returns(uint256){
        require(isSenator(senator));
        require(isSenator(msg.sender));
        
        for(uint256 index = 0; index < SenatorList.length; index++){
            if(SenatorList[index] == senator){
                delete SenatorList[index];
                delete SenatorLookup[senator];
                senatorNum = senatorNum.sub(1);
                break;
            }
        }
        
        return senatorNum;
    }
    
    // add a Candidate
    function CandidateRegister(address candidate, string memory declaration, uint256 weight) public returns(bool, string){
        uint8 role;
        string memory errors;
        
        role = Roles(candidate);
        if(PARTICIPATE != role){
            errors = "errors: unknown errors.";
            if(SENATOR == role){
                errors = "errors: senator not allown register.";
            }
            if(CANDIDATE == role){
                errors = "errors: candidate not allown register.";
            }
            emit CandidateRegisterEvent(candidate, false, errors);
            return (false, errors);
        }
        
        CandidateLookup[candidate].candidate = candidate;
        CandidateLookup[candidate].declaration = declaration;
        CandidateLookup[candidate].weight = weight;
        CandidateLookup[candidate].isValid = true;
        CandidateList.push(candidate);
        candidateNumbers = candidateNumbers.add(1);  
        emit CandidateRegisterEvent(candidate, true, "success: candidate register success.");
        return (true, errors);
    }
    
    // issue vote for specified candidate
    function Voting(address candidate) public returns(bool, string){
        uint8 role;
        string memory errors;
        
        require(isSenator(msg.sender));
        require(isCandidate(candidate));
        
        // repeat votting
        Candidate item = CandidateLookup[candidate];
        if(item.voteMap[msg.sender]){
            errors = "errors: repeat votting.";
            emit VotingEvent(msg.sender, candidate, false, errors);
            return (false, errors);
        }
    
        item.voteMap[msg.sender] = true;
        item.backerSenators.push(msg.sender);
        item.backerNumber = item.backerNumber.add(1);
        item.totalScore = item.totalScore.add(SenatorLookup[msg.sender].weight);

        // try to convert the candidate to senator if threshold reached
        tryToConvertSenator(candidate);
        
        emit VotingEvent(msg.sender, candidate, true, errors);
        return (true, errors);
    }
    
    function CancelVoting(address candidate) public returns(bool, string){
        uint8 role;
        string memory errors;
        
        require(isSenator(msg.sender));
        require(isCandidate(candidate));
        
        Candidate item = CandidateLookup[candidate];
        require(item.voteMap[msg.sender]);
        
        deleteCandidateBackerByAddr(msg.sender, candidate);
        emit VotingCancelEvent(msg.sender, candidate, true, errors);
        return (true, errors);
    }
    
    function Exit(address member) public {
        if(isSenator(member)){
            deleteSenatorByAddr(member);
        }
        if(isCandidate(member)){
            deleteCandidateByAddr(member);
        }
    }
    
    constructor () public{
        address [3] memory InitorSenator = [
            0x8025c2eeF50a15D29aC839Aed47c3c78F0cAC143, 
            0x368AB89547Aad5604Fce277Cd6dB581851c337d5, 
            0x447ba28444c80Ec90feD276B25985342d77f5ae0];
        for(uint i = 0; i < InitorSenator.length; i++){
            addToSenator(InitorSenator[i], 1);
        }
        globalPolicy.policyType = NUMBER_POLICY;
        globalPolicy.threshold = 2;
    }
}