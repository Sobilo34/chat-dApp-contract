import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";

describe("Web3ChatDApp", function () {
    it("Should register a new user successfully", async function () {
        const [owner, user1] = await ethers.getSigners();
        const Web3ChatDAppFactory = await ethers.getContractFactory("Web3ChatDApp");
        const web3ChatDApp = await Web3ChatDAppFactory.deploy();
        await web3ChatDApp.waitForDeployment();
        
        const user1Address = await user1.getAddress();
        await web3ChatDApp.connect(user1).registerUser("John Doe", "QmTest123");
        
        const userProfile = await web3ChatDApp.getUserProfile(user1Address);
        expect(userProfile.name).to.equal("John Doe");
        expect(userProfile.isRegistered).to.be.true;
    });

    it("Should prevent duplicate registration", async function () {
        const [owner, user1] = await ethers.getSigners();
        const Web3ChatDAppFactory = await ethers.getContractFactory("Web3ChatDApp");
        const web3ChatDApp = await Web3ChatDAppFactory.deploy();
        await web3ChatDApp.waitForDeployment();
        
        await web3ChatDApp.connect(user1).registerUser("John Doe", "QmTest123");
        await expect(
            web3ChatDApp.connect(user1).registerUser("Jane Smith", "QmTest456")
        ).to.be.revertedWith("Already registered");
    });

    it("Should prevent duplicate first names", async function () {
        const [owner, user1, user2] = await ethers.getSigners();
        const Web3ChatDAppFactory = await ethers.getContractFactory("Web3ChatDApp");
        const web3ChatDApp = await Web3ChatDAppFactory.deploy();
        await web3ChatDApp.waitForDeployment();
        
        await web3ChatDApp.connect(user1).registerUser("John Doe", "QmTest123");
        await expect(
            web3ChatDApp.connect(user2).registerUser("John Smith", "QmTest456")
        ).to.be.revertedWith("First name taken");
    });

    it("Should reject empty names and images", async function () {
        const [owner, user1] = await ethers.getSigners();
        const Web3ChatDAppFactory = await ethers.getContractFactory("Web3ChatDApp");
        const web3ChatDApp = await Web3ChatDAppFactory.deploy();
        await web3ChatDApp.waitForDeployment();
        
        await expect(
            web3ChatDApp.connect(user1).registerUser("", "QmTest123")
        ).to.be.revertedWith("Name cannot be empty");
        
        await expect(
            web3ChatDApp.connect(user1).registerUser("John", "")
        ).to.be.revertedWith("Image required");
    });

    it("Should update profile image", async function () {
        const [owner, user1] = await ethers.getSigners();
        const Web3ChatDAppFactory = await ethers.getContractFactory("Web3ChatDApp");
        const web3ChatDApp = await Web3ChatDAppFactory.deploy();
        await web3ChatDApp.waitForDeployment();
        
        const user1Address = await user1.getAddress();
        await web3ChatDApp.connect(user1).registerUser("John Doe", "QmTest123");
        await web3ChatDApp.connect(user1).updateProfileImage("QmNewImage456");
        
        const userProfile = await web3ChatDApp.getUserProfile(user1Address);
        expect(userProfile.imageIPFS).to.equal("QmNewImage456");
    });

    it("Should check first name availability", async function () {
        const [owner, user1] = await ethers.getSigners();
        const Web3ChatDAppFactory = await ethers.getContractFactory("Web3ChatDApp");
        const web3ChatDApp = await Web3ChatDAppFactory.deploy();
        await web3ChatDApp.waitForDeployment();
        
        await web3ChatDApp.connect(user1).registerUser("Alice Johnson", "QmTest123");
        
        expect(await web3ChatDApp.isFirstNameAvailable("Alice")).to.be.false;
        expect(await web3ChatDApp.isFirstNameAvailable("charlie")).to.be.true;
    });

    it("Should send private message successfully", async function () {
        const [owner, user1, user2] = await ethers.getSigners();
        const Web3ChatDAppFactory = await ethers.getContractFactory("Web3ChatDApp");
        const web3ChatDApp = await Web3ChatDAppFactory.deploy();
        await web3ChatDApp.waitForDeployment();
        
        const user1Address = await user1.getAddress();
        const user2Address = await user2.getAddress();
        
        await web3ChatDApp.connect(user1).registerUser("Alice Johnson", "QmTest123");
        await web3ChatDApp.connect(user2).registerUser("Bob Smith", "QmTest456");
        
        await web3ChatDApp.connect(user1).sendPrivateMessage(user2Address, "Hello Bob!");
        
        const messages = await web3ChatDApp.getPrivateMessages(user1Address, user2Address, 0, 10);
        expect(messages.length).to.equal(1);
        expect(messages[0].content).to.equal("Hello Bob!");
    });

    it("Should prevent messaging non-registered users", async function () {
        const [owner, user1, user2] = await ethers.getSigners();
        const Web3ChatDAppFactory = await ethers.getContractFactory("Web3ChatDApp");
        const web3ChatDApp = await Web3ChatDAppFactory.deploy();
        await web3ChatDApp.waitForDeployment();
        
        const user2Address = await user2.getAddress();
        await web3ChatDApp.connect(user1).registerUser("Alice Johnson", "QmTest123");
        
        await expect(
            web3ChatDApp.connect(user1).sendPrivateMessage(user2Address, "Hello")
        ).to.be.revertedWith("Recipient not registered");
    });

    it("Should prevent self-messaging", async function () {
        const [owner, user1] = await ethers.getSigners();
        const Web3ChatDAppFactory = await ethers.getContractFactory("Web3ChatDApp");
        const web3ChatDApp = await Web3ChatDAppFactory.deploy();
        await web3ChatDApp.waitForDeployment();
        
        const user1Address = await user1.getAddress();
        await web3ChatDApp.connect(user1).registerUser("Alice Johnson", "QmTest123");
        
        await expect(
            web3ChatDApp.connect(user1).sendPrivateMessage(user1Address, "Hello")
        ).to.be.revertedWith("Cannot message yourself");
    });

    it("Should handle message pagination", async function () {
        const [owner, user1, user2] = await ethers.getSigners();
        const Web3ChatDAppFactory = await ethers.getContractFactory("Web3ChatDApp");
        const web3ChatDApp = await Web3ChatDAppFactory.deploy();
        await web3ChatDApp.waitForDeployment();
        
        const user1Address = await user1.getAddress();
        const user2Address = await user2.getAddress();
        
        await web3ChatDApp.connect(user1).registerUser("Alice Johnson", "QmTest123");
        await web3ChatDApp.connect(user2).registerUser("Bob Smith", "QmTest456");
        
        await web3ChatDApp.connect(user1).sendPrivateMessage(user2Address, "Message 1");
        await web3ChatDApp.connect(user1).sendPrivateMessage(user2Address, "Message 2");
        await web3ChatDApp.connect(user1).sendPrivateMessage(user2Address, "Message 3");
        
        const firstBatch = await web3ChatDApp.getPrivateMessages(user1Address, user2Address, 0, 2);
        expect(firstBatch.length).to.equal(2);
        expect(firstBatch[0].content).to.equal("Message 1");
    });

    it("Should create group chat successfully", async function () {
        const [owner, user1, user2, user3] = await ethers.getSigners();
        const Web3ChatDAppFactory = await ethers.getContractFactory("Web3ChatDApp");
        const web3ChatDApp = await Web3ChatDAppFactory.deploy();
        await web3ChatDApp.waitForDeployment();
        
        const user1Address = await user1.getAddress();
        const user2Address = await user2.getAddress();
        const user3Address = await user3.getAddress();
        
        await web3ChatDApp.connect(user1).registerUser("Alice Johnson", "QmTest123");
        await web3ChatDApp.connect(user2).registerUser("Bob Smith", "QmTest456");
        await web3ChatDApp.connect(user3).registerUser("Charlie Brown", "QmTest789");
        
        await web3ChatDApp.connect(user1).createGroupChat("Test Group", [user2Address, user3Address]);
        
        const groupInfo = await web3ChatDApp.getGroupInfo(1);
        expect(groupInfo.name).to.equal("Test Group");
        expect(groupInfo.admin).to.equal(user1Address);
        expect(groupInfo.members.length).to.equal(3);
    });

    it("Should send group messages successfully", async function () {
        const [owner, user1, user2] = await ethers.getSigners();
        const Web3ChatDAppFactory = await ethers.getContractFactory("Web3ChatDApp");
        const web3ChatDApp = await Web3ChatDAppFactory.deploy();
        await web3ChatDApp.waitForDeployment();
        
        const user1Address = await user1.getAddress();
        const user2Address = await user2.getAddress();
        
        await web3ChatDApp.connect(user1).registerUser("Alice Johnson", "QmTest123");
        await web3ChatDApp.connect(user2).registerUser("Bob Smith", "QmTest456");
        
        await web3ChatDApp.connect(user1).createGroupChat("Test Group", [user2Address]);
        await web3ChatDApp.connect(user1).sendGroupMessage(1, "Hello group!");
        
        const messages = await web3ChatDApp.getGroupMessages(1, 0, 10);
        expect(messages.length).to.equal(1);
        expect(messages[0].content).to.equal("Hello group!");
    });

    it("Should prevent non-admin from adding members", async function () {
        const [owner, user1, user2, user3] = await ethers.getSigners();
        const Web3ChatDAppFactory = await ethers.getContractFactory("Web3ChatDApp");
        const web3ChatDApp = await Web3ChatDAppFactory.deploy();
        await web3ChatDApp.waitForDeployment();
        
        const user2Address = await user2.getAddress();
        const user3Address = await user3.getAddress();
        
        await web3ChatDApp.connect(user1).registerUser("Alice Johnson", "QmTest123");
        await web3ChatDApp.connect(user2).registerUser("Bob Smith", "QmTest456");
        await web3ChatDApp.connect(user3).registerUser("Charlie Brown", "QmTest789");
        
        await web3ChatDApp.connect(user1).createGroupChat("Test Group", [user2Address]);
        
        await expect(
            web3ChatDApp.connect(user2).addGroupMember(1, user3Address)
        ).to.be.revertedWith("Only admin");
    });

    it("Should get total user count", async function () {
        const [owner, user1, user2, user3] = await ethers.getSigners();
        const Web3ChatDAppFactory = await ethers.getContractFactory("Web3ChatDApp");
        const web3ChatDApp = await Web3ChatDAppFactory.deploy();
        await web3ChatDApp.waitForDeployment();
        
        await web3ChatDApp.connect(user1).registerUser("Alice Johnson", "QmTest123");
        await web3ChatDApp.connect(user2).registerUser("Bob Smith", "QmTest456");
        await web3ChatDApp.connect(user3).registerUser("Charlie Brown", "QmTest789");
        
        expect(await web3ChatDApp.getTotalUsers()).to.equal(3);
    });

    it("Should check user registration status", async function () {
        const [owner, user1, user2] = await ethers.getSigners();
        const Web3ChatDAppFactory = await ethers.getContractFactory("Web3ChatDApp");
        const web3ChatDApp = await Web3ChatDAppFactory.deploy();
        await web3ChatDApp.waitForDeployment();
        
        const user1Address = await user1.getAddress();
        const user2Address = await user2.getAddress();
        
        await web3ChatDApp.connect(user1).registerUser("Alice Johnson", "QmTest123");
        
        expect(await web3ChatDApp.isUserRegistered(user1Address)).to.be.true;
        expect(await web3ChatDApp.isUserRegistered(user2Address)).to.be.false;
    });

    it("Should reject invalid group creation parameters", async function () {
        const [owner, user1, user2] = await ethers.getSigners();
        const Web3ChatDAppFactory = await ethers.getContractFactory("Web3ChatDApp");
        const web3ChatDApp = await Web3ChatDAppFactory.deploy();
        await web3ChatDApp.waitForDeployment();
        
        const user1Address = await user1.getAddress();
        const user2Address = await user2.getAddress();
        
        await web3ChatDApp.connect(user1).registerUser("Alice Johnson", "QmTest123");
        await web3ChatDApp.connect(user2).registerUser("Bob Smith", "QmTest456");
        
        await expect(
            web3ChatDApp.connect(user1).createGroupChat("", [user2Address])
        ).to.be.revertedWith("Group name required");
        
        await expect(
            web3ChatDApp.connect(user1).createGroupChat("Test", [user1Address])
        ).to.be.revertedWith("Cannot add yourself");
    });
});
