// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Voting
 * @notice Robust on-chain voting with delegation, quadratic voting, and timeboxed phases.
 * - Supports multiple proposals per poll
 * - Delegation with cycle prevention
 * - Quadratic voting (optional per poll)
 * - Voter whitelisting and tokenless weight (1 per voter) by default
 * - Snapshots at start time to prevent late joiners if whitelist is frozen
 */
contract Voting is Ownable, ReentrancyGuard {
	struct Proposal {
		string description;
		uint256 votes; // sum of voting weight (after quadratic transform if enabled)
	}

	enum Phase {
		Created,
		Registration,
		VotingPhase,
		Ended
	}

	event VoterRegistered(address indexed voter);
	event Delegated(address indexed from, address indexed to);
	event Voted(address indexed voter, uint256 indexed proposalId, uint256 weightUsed);
	event Undelegated(address indexed from);
	event PhaseChanged(Phase indexed newPhase);
	event ProposalAdded(uint256 indexed proposalId, string description);

	// Governance
	Phase public phase;
	bool public quadratic;
	uint256 public startTime;
	uint256 public endTime;

	// Proposals
	Proposal[] public proposals;

	// Voters and weights
	mapping(address => bool) public isRegistered;
	mapping(address => uint256) public votingPower; // default 1 when registered
	uint256 public registeredCount;

	// Delegation
	mapping(address => address) public delegateOf; // voter => delegate target
	mapping(address => uint256) public receivedDelegations; // effective added weight from others

	modifier inPhase(Phase expected) {
		require(phase == expected, "Bad phase");
		_;
	}

	modifier onlyDuring(uint256 start, uint256 end) {
		require(block.timestamp >= start && block.timestamp <= end, "Out of window");
		_;
	}

	constructor(
		string[] memory _descriptions,
		bool _quadratic,
		uint256 _startTime,
		uint256 _endTime,
		address _owner
	) Ownable(_owner) {
		require(_descriptions.length >= 2, "At least 2 proposals");
		require(_endTime > _startTime && _endTime > block.timestamp, "Bad times");
		quadratic = _quadratic;
		startTime = _startTime;
		endTime = _endTime;
		phase = Phase.Created;
		for (uint256 i = 0; i < _descriptions.length; i++) {
			proposals.push(Proposal({description: _descriptions[i], votes: 0}));
			emit ProposalAdded(i, _descriptions[i]);
		}
	}

	// ============ Admin controls ============
	function startRegistration() external onlyOwner inPhase(Phase.Created) {
		phase = Phase.Registration;
		emit PhaseChanged(phase);
	}

	function startVoting() external onlyOwner inPhase(Phase.Registration) {
		require(block.timestamp >= startTime, "Too early");
		require(registeredCount >= 1, "No voters");
		phase = Phase.VotingPhase;
		emit PhaseChanged(phase);
	}

	function endPoll() external onlyOwner inPhase(Phase.VotingPhase) {
		require(block.timestamp >= endTime, "Too early");
		phase = Phase.Ended;
		emit PhaseChanged(phase);
	}

	// ============ Registration ============
	function registerVoters(address[] calldata voters) external onlyOwner inPhase(Phase.Registration) {
		for (uint256 i = 0; i < voters.length; i++) {
			address voter = voters[i];
			if (!isRegistered[voter]) {
				isRegistered[voter] = true;
				votingPower[voter] = 1; // base weight
				registeredCount++;
				emit VoterRegistered(voter);
			}
		}
	}

	// ============ Delegation ============
	function delegate(address to) external inPhase(Phase.VotingPhase) onlyDuring(startTime, endTime) {
		require(isRegistered[msg.sender], "Not registered");
		require(isRegistered[to], "Delegate not registered");
		require(to != msg.sender, "Self");
		// prevent cycles
		address cur = to;
		while (cur != address(0)) {
			require(cur != msg.sender, "Cycle");
			cur = delegateOf[cur];
		}

		// remove previous delegation, if any
		address prev = delegateOf[msg.sender];
		if (prev != address(0)) {
			receivedDelegations[prev] -= effectiveWeight(msg.sender);
		}

		delegateOf[msg.sender] = to;
		receivedDelegations[to] += effectiveWeight(msg.sender);
		emit Delegated(msg.sender, to);
	}

	function undelegate() external inPhase(Phase.VotingPhase) onlyDuring(startTime, endTime) {
		address prev = delegateOf[msg.sender];
		require(prev != address(0), "No delegation");
		receivedDelegations[prev] -= effectiveWeight(msg.sender);
		delegateOf[msg.sender] = address(0);
		emit Undelegated(msg.sender);
	}

	// ============ Voting ============
	mapping(address => bool) public hasVoted;

	function vote(uint256 proposalId) external nonReentrant inPhase(Phase.VotingPhase) onlyDuring(startTime, endTime) {
		require(isRegistered[msg.sender], "Not registered");
		require(!hasVoted[msg.sender], "Voted");
		require(proposalId < proposals.length, "Bad id");

		uint256 weight = totalWeight(msg.sender);
		require(weight > 0, "No weight");

		hasVoted[msg.sender] = true;
		uint256 applied = quadratic ? sqrt(weight) : weight;
		proposals[proposalId].votes += applied;
		emit Voted(msg.sender, proposalId, applied);
	}

	// ============ Views ============
	function proposalCount() external view returns (uint256) {
		return proposals.length;
	}

	function getProposal(uint256 id) external view returns (string memory description, uint256 votes_) {
		require(id < proposals.length, "Bad id");
		Proposal storage p = proposals[id];
		return (p.description, p.votes);
	}

	function leadingProposal() external view returns (uint256 id, string memory description, uint256 votes_) {
		require(phase == Phase.Ended, "Not ended");
		uint256 maxVotes = 0;
		uint256 winner = 0;
		for (uint256 i = 0; i < proposals.length; i++) {
			if (proposals[i].votes > maxVotes) {
				maxVotes = proposals[i].votes;
				winner = i;
			}
		}
		Proposal storage p = proposals[winner];
		return (winner, p.description, p.votes);
	}

	function totalWeight(address voter) public view returns (uint256) {
		return effectiveWeight(voter) + receivedDelegations[voter];
	}

	function effectiveWeight(address voter) internal view returns (uint256) {
		return votingPower[voter];
	}

	function sqrt(uint256 x) internal pure returns (uint256 y) {
		if (x == 0) return 0;
		uint256 z = (x + 1) / 2;
		y = x;
		while (z < y) {
			y = z;
			z = (x / z + z) / 2;
		}
	}
}
