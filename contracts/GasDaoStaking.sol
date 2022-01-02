// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 Staking contract that awards GAS holders that delegate based on how much Ethereum gas they spend while delegated.
 The Merkle root, token allocation, and claim end date are settable by the owner, the DAO Timelock/Treasury.

First Governance Proposal to seed the staking contract:
targets = [0x6Bba316c48b49BD1eAc44573c5c871ff02958469]
values = [0],
calldata = [transfer(GasDaoTokenStakingReward_Address, 50B gas)]

Second Governance Proposal to start the airdrop:
targets = [GasDaoTokenStakingReward_Address, GasDaoTokenStakingReward_Address]
values = [0, 0],
calldata = [setMerkleRoot(XXX), setClaimPeriodEnds(XXX)]
*/
contract GasDaoTokenStakingReward is Ownable {
    address private constant GAS_TOKEN_ADDRESS = 0x6Bba316c48b49BD1eAc44573c5c871ff02958469;
    bytes32 public merkleRoot;
    mapping(address=>bool) private claimed;

    event MerkleRootChanged(bytes32 merkleRoot);
    event ClaimPeriodEndsChanged(uint256 claimPeriodEnds);
    event Claim(address indexed claimant, uint256 amount);

    uint256 public claimPeriodEnds;

    constructor(address owner) {
        _transferOwnership(owner);
    }

    /**
     * @dev Sets the merkle root.
     * @param _merkleRoot The merkle root to set.
     */
    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
        emit MerkleRootChanged(_merkleRoot);
    }

    /**
     * @dev Sets the claim period end.
     * @param _claimPeriodEnds The new claim period end timestamp.
     */
    function setClaimPeriodEnds(uint256 _claimPeriodEnds) public onlyOwner {
        claimPeriodEnds = _claimPeriodEnds;
        emit ClaimPeriodEndsChanged(_claimPeriodEnds);
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

        ERC20(GAS_TOKEN_ADDRESS).transfer(msg.sender, amount);
    }

    /**
     * @dev Returns true if the claim at for the address has already been made.
     * @param account The address to check if claimed.
     */
    function hasClaimed(address account) public view returns (bool) {
        return claimed[account];
    }

    /**
     * @dev Allows the owner to sweep unclaimed tokens after the claim period ends.
     * @param dest The address to sweep the tokens to.
     */
    function sweep(address dest) public onlyOwner {
        require(block.timestamp > claimPeriodEnds, "GasDao: Claim period not yet ended");
        ERC20(GAS_TOKEN_ADDRESS).transfer(dest, ERC20(GAS_TOKEN_ADDRESS).balanceOf(address(this)));
    }
}
