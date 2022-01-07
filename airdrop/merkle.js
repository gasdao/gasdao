const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const fs = require('fs');
const { fork } = require('child_process');

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

console.log("Got merkleTree root", root)

let content = csv[0].join(",") + ",proof\n";

const numThreads = 16;
let ct = 0;
for (let i = 0; i < numThreads; i++) {
  let j = i * 1
  let rows = []
  let leaves = []
  for (; j < elements.length; j+= numThreads) {
    rows.push(csv[j+1])
    leaves.push(elements[j])
  }
  const forked = fork('scripts/child.js');
  forked.send({rows: rows, leaves: leaves, id: i});
}
