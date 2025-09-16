// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Web3ChatENS } from "./NameService.sol";

contract Web3ChatRegistry is Ownable, ReentrancyGuard {

    // Reference to ENS contract
    Web3ChatENS public ensContract;

    constructor(address _ensContract) Ownable(msg.sender) {
        ensContract = Web3ChatENS(_ensContract);
    }

    struct UserProfile {
        string name;
        string imageIPFS;
        string ensDomain;
        bool isRegistered;
        uint256 registrationTime;
    }
    
    // Mapping from address to user profile
    mapping(address => UserProfile) public userProfiles;
    
    // Array of all registered users
    address[] public registeredUsers;
    
    // Mapping to check if name is taken
    mapping(string => bool) public nameTaken;
    
    // Events
    event UserRegistered(address indexed user, string name, string ensDomain, string imageIPFS);
    event ProfileUpdated(address indexed user, string imageIPFS);
    
    
    /**
     * @dev Register a new user with name and image
     * @param _fullName User's full display name (first name will be extracted for ENS)
     * @param _imageIPFS IPFS hash of user's profile image
     */
    function registerUser(string memory _fullName, string memory _imageIPFS) external nonReentrant {
        require(!userProfiles[msg.sender].isRegistered, "User already registered");
        require(bytes(_fullName).length > 0, "Name cannot be empty");
        require(bytes(_fullName).length <= 100, "Full name too long");
        require(bytes(_imageIPFS).length > 0, "Image IPFS cannot be empty");
        
        // Extract first name for ENS
        string memory firstName = ensContract.extractFirstName(_fullName);
        require(bytes(firstName).length > 0, "First name cannot be empty");
        require(bytes(firstName).length <= 32, "First name too long");
        require(!nameTaken[firstName], "First name already taken");
        
        // Register ENS domain with first name
        ensContract.registerDomain(_fullName);
        
        // Create ENS domain name
        string memory ensDomain = string(abi.encodePacked(firstName, ".web3chat"));
        
        // Create user profile
        userProfiles[msg.sender] = UserProfile({
            name: _fullName, // Store full name
            imageIPFS: _imageIPFS,
            ensDomain: ensDomain,
            isRegistered: true,
            registrationTime: block.timestamp
        });
        
        // Mark first name as taken and add to registered users
        nameTaken[firstName] = true;
        registeredUsers.push(msg.sender);
        
        emit UserRegistered(msg.sender, _fullName, ensDomain, _imageIPFS);
    }
    
    /**
     * @dev Update user's profile image
     * @param _imageIPFS New IPFS hash of user's profile image
     */
    function updateProfileImage(string memory _imageIPFS) external {
        require(userProfiles[msg.sender].isRegistered, "User not registered");
        require(bytes(_imageIPFS).length > 0, "Image IPFS cannot be empty");
        
        userProfiles[msg.sender].imageIPFS = _imageIPFS;
        
        emit ProfileUpdated(msg.sender, _imageIPFS);
    }
    
    /**
     * @dev Get user profile by address
     * @param _user User's address
     */
    function getUserProfile(address _user) external view returns (UserProfile memory) {
        return userProfiles[_user];
    }
    
    /**
     * @dev Check if user is registered
     * @param _user User's address
     */
    function isUserRegistered(address _user) external view returns (bool) {
        return userProfiles[_user].isRegistered;
    }
    
    /**
     * @dev Get total number of registered users
     */
    function getTotalUsers() external view returns (uint256) {
        return registeredUsers.length;
    }
    
    /**
     * @dev Get registered users with pagination
     * @param _start Start index
     * @param _limit Number of users to return
     */
    function getRegisteredUsers(uint256 _start, uint256 _limit) 
        external 
        view 
        returns (address[] memory users, UserProfile[] memory profiles) 
    {
        require(_start < registeredUsers.length, "Start index out of bounds");
        
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
    
    /**
     * @dev Search users by first name (extracted from ENS domain)
     * @param _firstName First name to search for
     */
    function getUserByFirstName(string memory _firstName) external view returns (address userAddress, UserProfile memory profile) {
        address domainOwner = ensContract.getDomainOwner(_firstName);
        require(domainOwner != address(0), "User not found");
        require(userProfiles[domainOwner].isRegistered, "User not registered");
        
        return (domainOwner, userProfiles[domainOwner]);
    }
    
    /**
     * @dev Check if a first name is available
     * @param _firstName First name to check
     */
    function isFirstNameAvailable(string memory _firstName) external view returns (bool) {
        return !nameTaken[_firstName];
    }
}
