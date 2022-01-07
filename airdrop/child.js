const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const fs = require('fs');
const { exit } = require('process');

process.on('message', (msg) => {
    let users = [];
    let csv = fs.readFileSync("airdrop.csv").toString().split("\n");
    csv = csv.map((x) =>
      x.split(",")
    )
    let i = 0
    for (const r of csv.slice(1)) {
      try{
        users.push({address: r[1], amount: ethers.BigNumber.from(r[7])});
      } catch {
        console.log(i, r);
      }
      i++
    }
    
    const elements = users.map((x) =>
      ethers.utils.solidityKeccak256(["address", "uint256"], [x.address, x.amount])
    );
    
    const merkleTree = new MerkleTree(elements, keccak256, { sort: true });
    const root = merkleTree.getHexRoot();

    console.log("Got merkle root", root)

    content = ""
    for (let i = 0; i < msg.rows.length; i++) {
      console.log(msg.id, i, "/", msg.rows.length)
      let row = msg.rows[i];
      let proof = merkleTree.getHexProof(msg.leaves[i]);
      proof = proof.join(" ")
      content += row.join(",") + "," + proof + "\n"
    }
    fs.writeFileSync("airdrop_processed_" + msg.id.toString() + ".csv", content);
});
