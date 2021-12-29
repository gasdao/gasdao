// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./GasDaoTokenLock.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @dev An ERC20 token for GasDao.
 *      Besides the addition of voting capabilities, we make a couple of customisations:
 *       - Airdrop claim functionality via `claimTokens`. At creation time the tokens that
 *         should be available for the airdrop are transferred to the token contract address;
 *         airdrop claims are made from this balance.
 *       - Support for the owner (the DAO) to mint new tokens, at up to 2% PA.
 */
contract GasDaoToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    bytes32 public merkleRoot;

    mapping(address=>bool) private claimed;

    event MerkleRootChanged(bytes32 merkleRoot);
    event Claim(address indexed claimant, uint256 amount);

    // total supply 1 trillion, 55% airdrop, 15% devs vested, remainder to timelock
    uint256 constant airdropSupply = 550000000000000085770152383000;
    uint256 constant devSupply = 150_000_000_000e18;
    uint256 constant timelockSupply = 1_000_000_000_000e18 - airdropSupply - devSupply;

    bool public vestStarted = false;

    uint256 public constant claimPeriodEnds = 1651363200; // may 1, 2022

    /**
     * @dev Constructor.
     * @param timelockAddress The address of the timelock.
     */
    constructor(
        address timelockAddress
    )
        ERC20("Gas DAO", "GAS")
        ERC20Permit("Gas DAO")
    {
        _mint(address(this), airdropSupply);
        _mint(address(this), devSupply);
        _mint(timelockAddress, timelockSupply);
    }

    function startVest(address tokenLockAddress) public onlyOwner {
        require(!vestStarted, "GasDao: Vest has already started.");
        vestStarted = true;
        _approve(address(this), tokenLockAddress, devSupply);
        GasDaoTokenLock(tokenLockAddress).lock(0x73ea708dC6e7A629AE3c89322320F1107537e200, 25_000_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0xd96bfADF43F106C5882c30B96E8a0769dbD5486B, 25_000_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0x7a1B5439c870a062c5701C78F52eE83FAFBb9274, 25_000_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0xF0591DA70765fE40B99E8B0e2bD0bF1F6A1AE797, 10_000_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0x379C326e6443c34Fa6a6E21e4D48A2F6CDd8cE23, 10_000_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0xD75fB66E71bfFbB1C9d09F7Ae2C3270d9F71ecfb, 10_000_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0x87892947e4AE5a208f647b0128180032145837cC,  6_000_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0xf28E9401310E13Cfd3ae0A9AF083af9101069453,  5_000_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0x5F2c4aa7d6943f1B5F8dFc6cc58f3A52F889B8e8,  3_000_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0x85A83A4810213Eb84dde3053C923f0Ee565Fb14f,  3_000_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0x3d2B46E9c730975415ef283f0D5254662358887D,  2_500_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0x9E51bB806f126EFDCa437dD8a939C7f1c840Eb1f,  2_500_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0x9FF216d036872222CB18683F0A72CAd6ee1E736F,  2_500_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0x15f3E2B44F6c8F832EFB60f588252AB001653320,  2_500_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0xa0eE3c95AB7099e91c5E1009c28b093d4c1faA50,  2_500_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0x9949a8335948491F1b126f3c3Ba247F63d34970A,  2_500_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0xFCb1365fD8d2033Fc5b5258EA3fe80D2D6CE2DA1,  2_500_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0x6dF5cb181c362EF37977F99adefCCd51FA45dC27,  2_000_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0x5407a5eF608d01544dbCc57EBaaEa235eFa9055A,  2_000_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0x96273F34b18F096903f8a683FB01BA9ed35cce98,  2_000_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0x8E37DEC70b948077BCeeb2dCA3BB2aF1CC183A32,  1_000_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0xb3968575aB0A5892eC3965E9fb9C74f6d2651f17,  1_000_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0x0cE90F4cB5D5fEbb3189E0F376F976E8e8Ea2020,  1_000_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0x36b3843d782b48481f277c3f047cc2e143C49dA5,  1_000_000_000e18);
        GasDaoTokenLock(tokenLockAddress).lock(0x060de4538bDf72C4785840e79034ad722722b7eB,    500_000_000e18);
    }

    /**
     * @dev Claims airdropped tokens.
     * @param amount The amount of the claim being made.
     * @param merkleProof A merkle proof proving the claim is valid.
     */
    function claimTokens(uint256 amount, bytes32[] calldata merkleProof) public {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        bool valid = MerkleProof.verify(merkleProof, merkleRoot, leaf);
        require(valid, "GasDao: Valid proof required.");
        require(!claimed[msg.sender], "GasDao: Tokens already claimed.");
        claimed[msg.sender] = true;
    
        emit Claim(msg.sender, amount);

        _transfer(address(this), msg.sender, amount);
    }

    /**
     * @dev Allows the owner to sweep unclaimed tokens after the claim period ends.
     * @param dest The address to sweep the tokens to.
     */
    function sweep(address dest) public onlyOwner {
        require(block.timestamp > claimPeriodEnds, "GasDao: Claim period not yet ended");
        _transfer(address(this), dest, balanceOf(address(this)));
    }

    /**
     * @dev Returns true if the claim at the given index in the merkle tree has already been made.
     * @param account The address to check if claimed.
     */
    function hasClaimed(address account) public view returns (bool) {
        return claimed[account];
    }

    /**
     * @dev Sets the merkle root. Only callable if the root is not yet set.
     * @param _merkleRoot The merkle root to set.
     */
    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        require(merkleRoot == bytes32(0), "GasDao: Merkle root already set");
        merkleRoot = _merkleRoot;
        emit MerkleRootChanged(_merkleRoot);
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}
