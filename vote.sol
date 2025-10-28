// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Voting {
    struct Candidate {
        string name;
        uint256 voteCount;
    }
    
    struct Election {
        string title;
        string description;
        address creator;
        uint256 endTime;
        bool active;
        Candidate[] candidates;
        mapping(address => bool) hasVoted;
    }
    
    Election[] public elections;
    
    event ElectionCreated(uint256 electionId, string title, address creator);
    event VoteCast(uint256 electionId, address voter, uint256 candidateIndex);
    
    function createElection(
        string memory _title,
        string memory _description,
        string[] memory _candidates,
        uint256 _duration
    ) public {
        require(_candidates.length >= 2, "At least 2 candidates required");
        require(_duration > 0, "Duration must be positive");
        
        uint256 electionId = elections.length;
        elections.push();
        Election storage newElection = elections[electionId];
        
        newElection.title = _title;
        newElection.description = _description;
        newElection.creator = msg.sender;
        newElection.endTime = block.timestamp + _duration;
        newElection.active = true;
        
        for (uint256 i = 0; i < _candidates.length; i++) {
            newElection.candidates.push(Candidate({
                name: _candidates[i],
                voteCount: 0
            }));
        }
        
        emit ElectionCreated(electionId, _title, msg.sender);
    }
    
    function vote(uint256 _electionId, uint256 _candidateIndex) public {
        require(_electionId < elections.length, "Invalid election ID");
        Election storage election = elections[_electionId];
        
        require(election.active, "Election is not active");
        require(block.timestamp < election.endTime, "Election has ended");
        require(!election.hasVoted[msg.sender], "You have already voted");
        require(_candidateIndex < election.candidates.length, "Invalid candidate");
        
        election.hasVoted[msg.sender] = true;
        election.candidates[_candidateIndex].voteCount++;
        
        emit VoteCast(_electionId, msg.sender, _candidateIndex);
    }
    
    function getElectionCount() public view returns (uint256) {
        return elections.length;
    }
    
    function getElectionDetails(uint256 _electionId) public view returns (
        string memory title,
        string memory description,
        address creator,
        uint256 endTime,
        bool active,
        string[] memory candidates,
        uint256[] memory voteCounts
    ) {
        require(_electionId < elections.length, "Invalid election ID");
        Election storage election = elections[_electionId];
        
        uint256 candidateCount = election.candidates.length;
        candidates = new string[](candidateCount);
        voteCounts = new uint256[](candidateCount);
        
        for (uint256 i = 0; i < candidateCount; i++) {
            candidates[i] = election.candidates[i].name;
            voteCounts[i] = election.candidates[i].voteCount;
        }
        
        return (
            election.title,
            election.description,
            election.creator,
            election.endTime,
            election.active && block.timestamp < election.endTime,
            candidates,
            voteCounts
        );
    }
}
