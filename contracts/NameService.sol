// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Web3ChatENS
 * @dev Simple ENS-like registry for web3chat domain names
 */
contract Web3ChatENS is Ownable, ReentrancyGuard {

     constructor() Ownable(msg.sender) {
        // contract constructor
    }

    // Domain suffix for all chat users
    string public constant DOMAIN_SUFFIX = ".web3chat";
    
    // Mapping from domain hash to owner address
    mapping(bytes32 => address) public domains;
    
    // Mapping from address to domain name
    mapping(address => string) public addressToDomain;
    
    // Mapping to check if domain exists
    mapping(string => bool) public domainExists;
    
    // Events
    event DomainRegistered(address indexed owner, string domain, bytes32 indexed domainHash);
    event DomainTransferred(address indexed from, address indexed to, string domain);
    
    /**
     * @dev Register a new domain for the caller using full name (extracts first name)
     * @param _fullName The full name (will extract first name)
     */
    function registerDomain(string memory _fullName) external nonReentrant {
        string memory firstName = _extractFirstName(_fullName);
        require(bytes(firstName).length > 0, "Name cannot be empty");
        require(bytes(firstName).length <= 32, "Name too long");
        require(!domainExists[firstName], "Domain already exists");
        require(bytes(addressToDomain[msg.sender]).length == 0, "Address already has domain");
        
        // Create full domain name
        string memory fullDomain = string(abi.encodePacked(firstName, DOMAIN_SUFFIX));
        bytes32 domainHash = keccak256(abi.encodePacked(fullDomain));
        
        // Register the domain
        domains[domainHash] = msg.sender;
        addressToDomain[msg.sender] = fullDomain;
        domainExists[firstName] = true;
        
        emit DomainRegistered(msg.sender, fullDomain, domainHash);
    }
    
    /**
     * @dev Extract first name from full name string
     * @param _fullName The full name string
     */
    function _extractFirstName(string memory _fullName) internal pure returns (string memory) {
        bytes memory nameBytes = bytes(_fullName);
        if (nameBytes.length == 0) {
            return "";
        }
        
        uint256 spaceIndex = 0;
        bool foundSpace = false;
        
        // Find the first space character
        for (uint256 i = 0; i < nameBytes.length; i++) {
            if (nameBytes[i] == 0x20) { // 0x20 is ASCII space
                spaceIndex = i;
                foundSpace = true;
                break;
            }
        }
        
        // If no space found, return the entire string (assuming it's already first name)
        if (!foundSpace) {
            return _fullName;
        }
        
        // Create a new bytes array for the first name
        bytes memory firstNameBytes = new bytes(spaceIndex);
        for (uint256 i = 0; i < spaceIndex; i++) {
            firstNameBytes[i] = nameBytes[i];
        }
        
        return string(firstNameBytes);
    }
    
    /**
     * @dev Get the owner of a domain
     * @param _name The domain name (without .web3chat suffix)
     */
    function getDomainOwner(string memory _name) external view returns (address) {
        string memory fullDomain = string(abi.encodePacked(_name, DOMAIN_SUFFIX));
        bytes32 domainHash = keccak256(abi.encodePacked(fullDomain));
        return domains[domainHash];
    }
    
    /**
     * @dev Get the domain name for an address
     * @param _owner The owner address
     */
    function getAddressDomain(address _owner) external view returns (string memory) {
        return addressToDomain[_owner];
    }
    
    /**
     * @dev Check if a first name is available for registration
     * @param _firstName The first name to check
     */
    function isFirstNameAvailable(string memory _firstName) external view returns (bool) {
        require(bytes(_firstName).length > 0, "Name cannot be empty");
        require(bytes(_firstName).length <= 32, "Name too long");
        return !domainExists[_firstName];
    }
    
    /**
     * @dev Extract first name from full name (public function)
     * @param _fullName The full name string
     */
    function extractFirstName(string memory _fullName) external pure returns (string memory) {
        return _extractFirstName(_fullName);
    }
}
