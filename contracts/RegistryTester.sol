// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Register.sol";
import "./NameService.sol";

/**
 * @title RegistryTester
 * @dev Simple contract to test Registry functions step by step
 */
contract RegistryTester {
    Web3ChatRegistry public registry;
    Web3ChatENS public ens;
    
    constructor(address _registryAddress, address _ensAddress) {
        registry = Web3ChatRegistry(_registryAddress);
        ens = Web3ChatENS(_ensAddress);
    }
    
    // Test function 1: Basic name extraction
    function testExtractFirstName(string memory _fullName) external view returns (string memory) {
        return ens.extractFirstName(_fullName);
    }
    
    // Test function 2: Check if name is available in registry only
    function testRegistryNameAvailability(string memory _firstName) external view returns (bool) {
        return registry.isNameTaken(_firstName);
    }
    
    // Test function 3: Check if domain exists in ENS only
    function testENSDomainExists(string memory _firstName) external view returns (bool) {
        return ens.domainExists(_firstName);
    }
    
    // Test function 4: Check combined availability
    function testFullAvailability(string memory _fullName) external view returns (bool) {
        return registry.isFullNameAvailable(_fullName);
    }
    
    // Test function 5: Try to register step by step
    function testRegisterUser(string memory _fullName, string memory _imageIPFS) external returns (bool success, string memory error) {
        try registry.registerUser(_fullName, _imageIPFS) {
            return (true, "Registration successful");
        } catch Error(string memory reason) {
            return (false, reason);
        } catch (bytes memory) {
            return (false, "Unknown error occurred");
        }
    }
    
    // Test function 6: Get detailed user info
    function testGetUserProfile(address _user) external view returns (
        string memory name,
        string memory imageIPFS,
        string memory ensDomain,
        bool isRegistered,
        uint256 registrationTime
    ) {
        Web3ChatRegistry.UserProfile memory profile = registry.getUserProfile(_user);
        return (profile.name, profile.imageIPFS, profile.ensDomain, profile.isRegistered, profile.registrationTime);
    }
    
    // Test function 7: Check all conditions for registration
    function testRegistrationConditions(string memory _fullName, string memory _imageIPFS, address _user) external view returns (
        bool userNotRegistered,
        bool nameNotEmpty,
        bool nameLengthOk,
        bool imageNotEmpty,
        string memory extractedFirstName,
        bool firstNameNotEmpty,
        bool firstNameLengthOk,
        bool nameNotTaken,
        bool ensNotExists
    ) {
        Web3ChatRegistry.UserProfile memory profile = registry.getUserProfile(_user);
        userNotRegistered = !profile.isRegistered;
        nameNotEmpty = bytes(_fullName).length > 0;
        nameLengthOk = bytes(_fullName).length <= 100;
        imageNotEmpty = bytes(_imageIPFS).length > 0;
        
        extractedFirstName = ens.extractFirstName(_fullName);
        firstNameNotEmpty = bytes(extractedFirstName).length > 0;
        firstNameLengthOk = bytes(extractedFirstName).length <= 32;
        nameNotTaken = !registry.isNameTaken(extractedFirstName);
        ensNotExists = !ens.domainExists(extractedFirstName);
    }
}
