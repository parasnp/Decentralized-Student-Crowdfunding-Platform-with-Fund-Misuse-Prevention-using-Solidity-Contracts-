//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract CrowdfundingWithToken {
    string public name = "VITcoin";
    string public symbol="VITC";
    uint8 public decimals;
    uint256 public totalSupply=100000;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    // keys will be the address of the doners and value will be the amout contributed
    mapping(address => uint256) public contributors;    
    // address of the account that is running the campaign
    address public projectOwner;
    uint public noOfContributors;
    uint public fundingGoal;
    uint public deadline;
    uint public amountRaised;
    uint public minimumContribution=100;
    bool public fundingGoalReached = false;
    bool public crowdsaleClosed = false;
    // Spending Request
    struct Request {
        string description;
        // address of the acount that will receive the contribution
        address payable recipient;
        uint value;
        bool completed;
        uint noOfVoters;
        mapping(address => bool) voters;
    }
    
    // array for storing multiple campaign/spending requests
    // the key is the spending request number (index) - starts from zero
    // the value is a Request struct
    mapping(uint => Request) public requests;

    uint public numRequests;
    event GoalReached(address recipient, uint totalAmountRaised);
    event FundTransfer(address backer, uint amount, bool isContribution);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event CreateRequestEvent(string _description, address _recipient, uint _value);
    constructor(uint fundingGoalInTokens, uint durationInMinutes) 
    {
        balanceOf[msg.sender] = totalSupply;               
        projectOwner = msg.sender;
        fundingGoal = fundingGoalInTokens ;//* (10 ** uint256(decimals));
        deadline = block.timestamp + durationInMinutes * 1 minutes;
    }

    function transfer(address _to, uint256 _value) public returns (bool success) 
    {
        require(balanceOf[msg.sender] >= _value);
        require(balanceOf[_to] + _value >= balanceOf[_to]);
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success)
    {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success)
    {
        require(balanceOf[_from] >= _value);
        require(allowance[_from][msg.sender] >= _value);
        require(balanceOf[_to] + _value >= balanceOf[_to]);
        balanceOf[_from] -= _value;
        allowance[_from][msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);
        return true;
    }
// crowdfunding function
 modifier onlyAdmin() {
        require(msg.sender ==  projectOwner, "Only  Campaign Manager can execute this");
        _;
    }
    
     function createRequest(string calldata _description, address payable _recipient, uint _value) public onlyAdmin {
        //numRequests starts from zero
        Request storage newRequest = requests[numRequests];
        numRequests++;
        
        newRequest.description = _description;
        newRequest.recipient = _recipient;
        newRequest.value = _value;
        newRequest.completed = false;
        newRequest.noOfVoters = 0;
        
        emit CreateRequestEvent(_description, _recipient, _value);
    }
    function voteRequest(uint _requestNo) public {
        require(contributors[msg.sender] > 0, "You must be a contributor to vote!");
        
        Request storage thisRequest = requests[_requestNo];
        require(thisRequest.voters[msg.sender] == false, "You have already voted!");
        
        thisRequest.voters[msg.sender] = true;
        thisRequest.noOfVoters++;
    }
    function makePayment(uint _requestNo) public onlyAdmin {
        Request storage thisRequest = requests[_requestNo];
        require(thisRequest.completed == false, "The request has been already completed!");
        require(thisRequest.noOfVoters > noOfContributors / 2, "The request needs more than 50% of the contributors.");
        
        // setting thisRequest as being completed and transfering the money
        thisRequest.completed = true;
        transfer(thisRequest.recipient, thisRequest.value);      
        emit FundTransfer(thisRequest.recipient, thisRequest.value, true);
    }
    
    function contribute(uint amount) public payable 
    {
        require(!crowdsaleClosed, "required fundhas been raised");
        require(block.timestamp < deadline, "campaign closed.");
        require(amount >= minimumContribution, "The Minimum Contribution not met!");
        require(balanceOf[msg.sender]>amount, "you have insufficient balane!!");
        
        // incrementing the no. of contributors the first time when 
        // someone sends eth to the contract
        if(contributors[msg.sender] == 0) {
            noOfContributors++;
        }
      //  uint amount = msg.value;
        contributors[msg.sender] += amount;
        amountRaised += amount;
        transfer(projectOwner, amount);// / 1 ether * 10 ** uint256(decimals));
        emit FundTransfer(msg.sender, amount, true);
    }
    

    function checkGoalReached() public
    {
        require(block.timestamp >= deadline);
        if (amountRaised >= fundingGoal) {
            fundingGoalReached = true;
            emit GoalReached(projectOwner, amountRaised);
        }
        crowdsaleClosed = true;
    }

    /*function withdrawFunds() public 
    {
        require(fundingGoalReached);
        require(projectOwner == msg.sender);
        uint256 amount = address(this).balance;
        payable(projectOwner).transfer(amount);
        emit FundTransfer(projectOwner, amount, false);
    }*/
    //if the funding goal has not reached then the contributor can get refun by calling the function below
    function refund() public
     {
        require(!fundingGoalReached, "funding goal reached, Sorry no refund will be given");
        require(block.timestamp >= deadline, "Campaign in progress, refund allwed ony if campaign is closed and fundingoal not reached");       uint amount = contributors[msg.sender];
        contributors[msg.sender] = 0;
        if (amount > 0) {
            transfer(projectOwner, amount );// 1 ether * 10 ** uint256(decimals));
            payable(msg.sender).transfer(amount);
            emit FundTransfer(msg.sender, amount, false);
        }
    }
}