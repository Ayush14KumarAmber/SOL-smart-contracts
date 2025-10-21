// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Message {
    struct MessageInfo {
        address sender;
        string message;
        uint256 amount;
        uint256 timestamp;
    }

    MessageInfo[] public messages;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    //  Function to send a message along with ETH
    function sendMessage(string memory _message) public payable {
        require(msg.value > 0, "Must send some ETH");
        require(bytes(_message).length > 0, "Message cannot be empty");

        messages.push(MessageInfo({
            sender: msg.sender,
            message: _message,
            amount: msg.value,
            timestamp: block.timestamp
        }));
    }

    //  View all messages
    function getAllMessages() public view returns (MessageInfo[] memory) {
        return messages;
    }

    //  View total balance stored in contract
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    //  Allow only owner to withdraw ETH
    function withdraw() public {
        require(msg.sender == owner, "Only owner can withdraw");
        payable(owner).transfer(address(this).balance);
    }
}
