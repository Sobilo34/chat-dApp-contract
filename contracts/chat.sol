// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Web3ChatRegistry } from "./Register.sol";

contract Web3ChatMessaging is Ownable, ReentrancyGuard {
    struct Message {
        address sender;
        string content;
        uint256 timestamp;
        bool isDeleted;
    }
    
    struct GroupChat {
        string name;
        address admin;
        address[] members;
        uint256 messageCount;
        bool isActive;
        uint256 createdAt;
    }
    
    // Reference to registry contract
    Web3ChatRegistry public registryContract;
    
    // Private chat: hash of two addresses => messages
    mapping(bytes32 => Message[]) public privateChats;
    
    // Group chats
    mapping(uint256 => GroupChat) public groupChats;
    mapping(uint256 => Message[]) public groupMessages;
    
    // Group ID counter
    uint256 public nextGroupId = 1;
    
    // User's group memberships
    mapping(address => uint256[]) public userGroups;
    
    // Events
    event PrivateMessageSent(address indexed from, address indexed to, string content, uint256 timestamp);
    event GroupMessageSent(uint256 indexed groupId, address indexed sender, string content, uint256 timestamp);
    event GroupCreated(uint256 indexed groupId, string name, address indexed admin);
    event MemberAddedToGroup(uint256 indexed groupId, address indexed member);
    event MemberRemovedFromGroup(uint256 indexed groupId, address indexed member);
    
    constructor(address _registryContract) Ownable(msg.sender) {
        registryContract = Web3ChatRegistry(_registryContract);
    }
    
    modifier onlyRegistered() {
        require(registryContract.isUserRegistered(msg.sender), "User not registered");
        _;
    }
    
    /**
     * @dev Send a private message to another user
     * @param _to Recipient's address
     * @param _content Message content
     */
    function sendPrivateMessage(address _to, string memory _content) external onlyRegistered nonReentrant {
        require(registryContract.isUserRegistered(_to), "Recipient not registered");
        require(bytes(_content).length > 0, "Message cannot be empty");
        require(bytes(_content).length <= 1000, "Message too long");
        require(_to != msg.sender, "Cannot send message to yourself");
        
        // Create a unique chat ID by hashing the two addresses
        bytes32 chatId = _getChatId(msg.sender, _to);
        
        // Add message to private chat
        privateChats[chatId].push(Message({
            sender: msg.sender,
            content: _content,
            timestamp: block.timestamp,
            isDeleted: false
        }));
        
        emit PrivateMessageSent(msg.sender, _to, _content, block.timestamp);
    }
    
    /**
     * @dev Create a new group chat
     * @param _name Group name
     * @param _members Initial members (excluding admin)
     */
    function createGroupChat(string memory _name, address[] memory _members) external onlyRegistered nonReentrant {
        require(bytes(_name).length > 0, "Group name cannot be empty");
        require(bytes(_name).length <= 50, "Group name too long");
        require(_members.length <= 50, "Too many initial members");
        
        uint256 groupId = nextGroupId++;
        
        // Create group with admin as first member
        address[] memory allMembers = new address[](_members.length + 1);
        allMembers[0] = msg.sender;
        
        // Add other members and verify they're registered
        for (uint256 i = 0; i < _members.length; i++) {
            require(registryContract.isUserRegistered(_members[i]), "Member not registered");
            require(_members[i] != msg.sender, "Cannot add yourself as member");
            allMembers[i + 1] = _members[i];
            userGroups[_members[i]].push(groupId);
        }
        
        groupChats[groupId] = GroupChat({
            name: _name,
            admin: msg.sender,
            members: allMembers,
            messageCount: 0,
            isActive: true,
            createdAt: block.timestamp
        });
        
        userGroups[msg.sender].push(groupId);
        
        emit GroupCreated(groupId, _name, msg.sender);
        
        // Emit events for added members
        for (uint256 i = 1; i < allMembers.length; i++) {
            emit MemberAddedToGroup(groupId, allMembers[i]);
        }
    }
    
    /**
     * @dev Send a message to a group chat
     * @param _groupId Group ID
     * @param _content Message content
     */
    function sendGroupMessage(uint256 _groupId, string memory _content) external onlyRegistered nonReentrant {
        require(groupChats[_groupId].isActive, "Group not active");
        require(bytes(_content).length > 0, "Message cannot be empty");
        require(bytes(_content).length <= 1000, "Message too long");
        require(_isMemberOfGroup(_groupId, msg.sender), "Not a member of this group");
        
        // Add message to group
        groupMessages[_groupId].push(Message({
            sender: msg.sender,
            content: _content,
            timestamp: block.timestamp,
            isDeleted: false
        }));
        
        groupChats[_groupId].messageCount++;
        
        emit GroupMessageSent(_groupId, msg.sender, _content, block.timestamp);
    }
    
    /**
     * @dev Get private chat messages between two users
     * @param _user1 First user's address
     * @param _user2 Second user's address
     * @param _start Start index for pagination
     * @param _limit Number of messages to return
     */
    function getPrivateMessages(address _user1, address _user2, uint256 _start, uint256 _limit) 
        external 
        view 
        returns (Message[] memory messages) 
    {
        bytes32 chatId = _getChatId(_user1, _user2);
        Message[] storage chatMessages = privateChats[chatId];
        
        if (_start >= chatMessages.length) {
            return new Message[](0);
        }
        
        uint256 end = _start + _limit;
        if (end > chatMessages.length) {
            end = chatMessages.length;
        }
        
        uint256 length = end - _start;
        messages = new Message[](length);
        
        for (uint256 i = 0; i < length; i++) {
            messages[i] = chatMessages[_start + i];
        }
    }
    
    /**
     * @dev Get group chat messages
     * @param _groupId Group ID
     * @param _start Start index for pagination
     * @param _limit Number of messages to return
     */
    function getGroupMessages(uint256 _groupId, uint256 _start, uint256 _limit) 
        external 
        view 
        returns (Message[] memory messages) 
    {
        Message[] storage chatMessages = groupMessages[_groupId];
        
        if (_start >= chatMessages.length) {
            return new Message[](0);
        }
        
        uint256 end = _start + _limit;
        if (end > chatMessages.length) {
            end = chatMessages.length;
        }
        
        uint256 length = end - _start;
        messages = new Message[](length);
        
        for (uint256 i = 0; i < length; i++) {
            messages[i] = chatMessages[_start + i];
        }
    }
    
    /**
     * @dev Get user's group memberships
     * @param _user User's address
     */
    function getUserGroups(address _user) external view returns (uint256[] memory) {
        return userGroups[_user];
    }
    
    /**
     * @dev Get group information
     * @param _groupId Group ID
     */
    function getGroupInfo(uint256 _groupId) external view returns (GroupChat memory) {
        return groupChats[_groupId];
    }
    
    /**
     * @dev Add member to group (admin only)
     * @param _groupId Group ID
     * @param _member Member to add
     */
    function addGroupMember(uint256 _groupId, address _member) external onlyRegistered {
        require(groupChats[_groupId].admin == msg.sender, "Only admin can add members");
        require(registryContract.isUserRegistered(_member), "Member not registered");
        require(!_isMemberOfGroup(_groupId, _member), "Already a member");
        require(groupChats[_groupId].members.length < 100, "Group is full");
        
        groupChats[_groupId].members.push(_member);
        userGroups[_member].push(_groupId);
        
        emit MemberAddedToGroup(_groupId, _member);
    }
    
    /**
     * @dev Get chat ID for two users (deterministic) - public function for frontend
     * @param _user1 First user's address
     * @param _user2 Second user's address
     */
    function getChatId(address _user1, address _user2) external pure returns (bytes32) {
        return _getChatId(_user1, _user2);
    }
    
    /**
     * @dev Check if user is member of group - public function
     * @param _groupId Group ID
     * @param _user User's address
     */
    function isMemberOfGroup(uint256 _groupId, address _user) external view returns (bool) {
        return _isMemberOfGroup(_groupId, _user);
    }
    
    /**
     * @dev Get private chat message count
     * @param _user1 First user's address
     * @param _user2 Second user's address
     */
    function getPrivateMessageCount(address _user1, address _user2) external view returns (uint256) {
        bytes32 chatId = _getChatId(_user1, _user2);
        return privateChats[chatId].length;
    }
    
    /**
     * @dev Get chat ID for two users (deterministic) - internal function
     */
    function _getChatId(address _user1, address _user2) internal pure returns (bytes32) {
        if (_user1 < _user2) {
            return keccak256(abi.encodePacked(_user1, _user2));
        } else {
            return keccak256(abi.encodePacked(_user2, _user1));
        }
    }
    
    /**
     * @dev Check if user is member of group - internal function
     */
    function _isMemberOfGroup(uint256 _groupId, address _user) internal view returns (bool) {
        address[] memory members = groupChats[_groupId].members;
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i] == _user) {
                return true;
            }
        }
        return false;
    }
}

/**
 * @title Web3ChatMulticall
 * @dev Batch multiple calls in a single transaction
 */
contract Web3ChatMulticall {
    struct Call {
        address target;
        bytes callData;
    }
    
    struct Result {
        bool success;
        bytes returnData;
    }
    
    /**
     * @dev Execute multiple calls in a single transaction
     * @param calls Array of calls to execute
     */
    function multicall(Call[] calldata calls) external view returns (Result[] memory results) {
        results = new Result[](calls.length);
        
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory returnData) = calls[i].target.staticcall(calls[i].callData);
            results[i] = Result(success, returnData);
        }
    }
    
    /**
     * @dev Get multiple user profiles in one call
     * @param registry The registry contract address
     * @param users Array of user addresses
     */
    function getUserProfiles(address registry, address[] calldata users) 
        external 
        view 
        returns (Web3ChatRegistry.UserProfile[] memory profiles) 
    {
        profiles = new Web3ChatRegistry.UserProfile[](users.length);
        Web3ChatRegistry registryContract = Web3ChatRegistry(registry);
        
        for (uint256 i = 0; i < users.length; i++) {
            profiles[i] = registryContract.getUserProfile(users[i]);
        }
    }
}