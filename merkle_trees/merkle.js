import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";

const values = [
  ["0x1111111111111111111111111111111111111111", "5000000000000000000"],
  ["0x2222222222222222222222222222222222222222", "2500000000000000000"],
];

const tree = StandardMerkleTree.of(values, ["address", "uint256"]);

console.log("Merkle Root:", tree.root);

fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));

// (1)
// const tree = StandardMerkleTree.load(JSON.parse(fs.readFileSync("tree.json", "utf8")));

// (2)
// for (const [i, v] of tree.entries()) {
//   if (v[0] === "0x1111111111111111111111111111111111111111") {
//     // (3)
//     const proof = tree.getProof(i);
//     console.log("Value:", v);
//     console.log("Proof:", proof);
//   }
// }
