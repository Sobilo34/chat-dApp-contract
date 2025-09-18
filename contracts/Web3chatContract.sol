// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Web3ChatDApp {

    string public constant DOMAIN_SUFFIX = ".web3chat";

    struct UserProfile {
        string name;
        string imageIPFS;
        string ensDomain;
        bool isRegistered;
        uint256 registrationTime;
    }
    
    struct Message {
        address sender;
        string content;
        uint256 timestamp;
    }
    
    struct GroupChat {
        string name;
        address admin;
        address[] members;
        uint256 messageCount;
        bool isActive;
        uint256 createdAt;
    }
    
    mapping(bytes32 => address) public domains;
    mapping(address => string) public addressToDomain;
    
    mapping(address => UserProfile) public userProfiles;
    address[] public registeredUsers;
    mapping(string => bool) public firstNameTaken;
    
    mapping(bytes32 => Message[]) public privateChats;
    mapping(uint256 => GroupChat) public groupChats;
    mapping(uint256 => Message[]) public groupMessages;
    mapping(address => uint256[]) public userGroups;
    
    uint256 public nextGroupId = 1;
    
    event UserRegistered(address indexed user, string name, string ensDomain, string imageIPFS);
    event ProfileUpdated(address indexed user, string imageIPFS);
    event PrivateMessageSent(address indexed from, address indexed to, uint256 timestamp);
    event GroupMessageSent(uint256 indexed groupId, address indexed sender, uint256 timestamp);
    event GroupCreated(uint256 indexed groupId, string name, address indexed admin);
    event MemberAddedToGroup(uint256 indexed groupId, address indexed member);
    
    // constructor() {}
    
    modifier onlyRegistered() {
        require(userProfiles[msg.sender].isRegistered, "User not registered");
        _;
    }
    
    function registerUser(string memory _fullName, string memory _imageIPFS) 
        external  
    {
        require(!userProfiles[msg.sender].isRegistered, "Already registered");
        require(bytes(_fullName).length > 0, "Name cannot be empty");
        require(bytes(_fullName).length <= 50, "Name too long");
        require(bytes(_imageIPFS).length > 0, "Image required");
        
        string memory firstName = _extractFirstName(_fullName);
        require(bytes(firstName).length > 0, "Invalid name");
        require(bytes(firstName).length <= 20, "First name too long");
        require(!firstNameTaken[firstName], "First name taken");
        
        string memory ensDomain = string(abi.encodePacked(firstName, DOMAIN_SUFFIX));
        bytes32 domainHash = keccak256(abi.encodePacked(ensDomain));
        
        domains[domainHash] = msg.sender;
        addressToDomain[msg.sender] = ensDomain;
        firstNameTaken[firstName] = true;
        
        userProfiles[msg.sender] = UserProfile({
            name: _fullName,
            imageIPFS: _imageIPFS,
            ensDomain: ensDomain,
            isRegistered: true,
            registrationTime: block.timestamp
        });
        
        registeredUsers.push(msg.sender);
        
        emit UserRegistered(msg.sender, _fullName, ensDomain, _imageIPFS);
    }
    
    function updateProfileImage(string memory _imageIPFS) external onlyRegistered {
        require(bytes(_imageIPFS).length > 0, "Image required");
        
        userProfiles[msg.sender].imageIPFS = _imageIPFS;
        emit ProfileUpdated(msg.sender, _imageIPFS);
    }
    
    function sendPrivateMessage(address _to, string memory _content) 
        external 
        onlyRegistered  
    {
        require(userProfiles[_to].isRegistered, "Recipient not registered");
        require(bytes(_content).length > 0, "Empty message");
        require(bytes(_content).length <= 2000, "Message too long");
        require(_to != msg.sender, "Cannot message yourself");
        
        bytes32 chatId = _getChatId(msg.sender, _to);
        
        privateChats[chatId].push(Message({
            sender: msg.sender,
            content: _content,
            timestamp: block.timestamp
        }));
        
        emit PrivateMessageSent(msg.sender, _to, block.timestamp);
    }
    
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
    
    function createGroupChat(string memory _name, address[] memory _members)
        external
        onlyRegistered
    {
        require(bytes(_name).length > 0, "Group name required");
        require(bytes(_name).length <= 32, "Group name too long");
        require(_members.length <= 100, "Too many members");
        
        uint256 groupId = nextGroupId++;
        
        address[] memory allMembers = new address[](_members.length + 1);
        allMembers[0] = msg.sender;
        
        for (uint256 i = 0; i < _members.length; i++) {
            require(userProfiles[_members[i]].isRegistered, "Member not registered");
            require(_members[i] != msg.sender, "Cannot add yourself");
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
    }
    
    function sendGroupMessage(uint256 _groupId, string memory _content)
        external
        onlyRegistered
    {
        require(groupChats[_groupId].isActive, "Group inactive");
        require(bytes(_content).length > 0, "Empty message");
        require(bytes(_content).length <= 2000, "Message too long");
        require(_isMemberOfGroup(_groupId, msg.sender), "Not a member");
        
        groupMessages[_groupId].push(Message({
            sender: msg.sender,
            content: _content,
            timestamp: block.timestamp
        }));
        
        groupChats[_groupId].messageCount++;
        
        emit GroupMessageSent(_groupId, msg.sender, block.timestamp);
    }
    
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
    
    function addGroupMember(uint256 _groupId, address _member) 
        external 
        onlyRegistered 
    {
        require(groupChats[_groupId].admin == msg.sender, "Only admin");
        require(userProfiles[_member].isRegistered, "Member not registered");
        require(!_isMemberOfGroup(_groupId, _member), "Already member");
        require(groupChats[_groupId].members.length < 100, "Group full");
        
        groupChats[_groupId].members.push(_member);
        userGroups[_member].push(_groupId);
        
        emit MemberAddedToGroup(_groupId, _member);
    }
    
    function getUserProfile(address _user) external view returns (UserProfile memory) {
        return userProfiles[_user];
    }
    
    function isUserRegistered(address _user) external view returns (bool) {
        return userProfiles[_user].isRegistered;
    }
    
    function getTotalUsers() external view returns (uint256) {
        return registeredUsers.length;
    }
    
    function getRegisteredUsers(uint256 _start, uint256 _limit)
        external
        view
        returns (address[] memory users, UserProfile[] memory profiles)
    {
        require(_start < registeredUsers.length, "Invalid start");
        require(_limit > 0 && _limit <= 100, "Invalid limit");
        
        uint256 end = _start + _limit;
        if (end > registeredUsers.length) {
            end = registeredUsers.length;
        }
        
        uint256 length = end - _start;
        users = new address[](length);
        profiles = new UserProfile[](length);
        
        for (uint256 i = 0; i < length; i++) {
            address userAddr = registeredUsers[_start + i];
            users[i] = userAddr;
            profiles[i] = userProfiles[userAddr];
        }
    }
    
    function getUserByFirstName(string memory _firstName)
        external
        view
        returns (address userAddress, UserProfile memory profile)
    {
        address domainOwner = getDomainOwner(_firstName);
        require(domainOwner != address(0), "User not found");
        return (domainOwner, userProfiles[domainOwner]);
    }
    
    function isFirstNameAvailable(string memory _firstName) external view returns (bool) {
        require(bytes(_firstName).length > 0, "Empty name");
        require(bytes(_firstName).length <= 20, "Name too long");
        return !firstNameTaken[_firstName];
    }
    
    function getDomainOwner(string memory _name) public view returns (address) {
        string memory fullDomain = string(abi.encodePacked(_name, DOMAIN_SUFFIX));
        bytes32 domainHash = keccak256(abi.encodePacked(fullDomain));
        return domains[domainHash];
    }
    
    function getUserGroups(address _user) external view returns (uint256[] memory) {
        return userGroups[_user];
    }
    
    function getGroupInfo(uint256 _groupId) external view returns (GroupChat memory) {
        return groupChats[_groupId];
    }
    
    function getChatId(address _user1, address _user2) external pure returns (bytes32) {
        return _getChatId(_user1, _user2);
    }
    
    function isMemberOfGroup(uint256 _groupId, address _user) external view returns (bool) {
        return _isMemberOfGroup(_groupId, _user);
    }
    
    function getPrivateMessageCount(address _user1, address _user2) external view returns (uint256) {
        bytes32 chatId = _getChatId(_user1, _user2);
        return privateChats[chatId].length;
    }
    
    function _extractFirstName(string memory _fullName) internal pure returns (string memory) {
        bytes memory nameBytes = bytes(_fullName);
        if (nameBytes.length == 0) return "";
        
        uint256 spaceIndex = 0;
        bool foundSpace = false;
        
        for (uint256 i = 0; i < nameBytes.length; i++) {
            if (nameBytes[i] == 0x20) {
                spaceIndex = i;
                foundSpace = true;
                break;
            }
        }
        
        if (!foundSpace) return _fullName;
        
        bytes memory firstNameBytes = new bytes(spaceIndex);
        for (uint256 i = 0; i < spaceIndex; i++) {
            firstNameBytes[i] = nameBytes[i];
        }
        
        return string(firstNameBytes);
    }
    
    function _getChatId(address _user1, address _user2) internal pure returns (bytes32) {
        return _user1 < _user2 
            ? keccak256(abi.encodePacked(_user1, _user2))
            : keccak256(abi.encodePacked(_user2, _user1));
    }
    
    function _isMemberOfGroup(uint256 _groupId, address _user) internal view returns (bool) {
        address[] memory members = groupChats[_groupId].members;
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i] == _user) return true;
        }
        return false;
    }
}