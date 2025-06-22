import * as starknet from "@scure/starknet";

function pedersenHex(a: string, b: string): string {
  const hash = starknet.pedersen(a, b);
  let hex = BigInt(hash).toString(16);
  hex = hex.padStart(64, "0");
  return "0x" + hex;
}

const values = [
  [
    "0x07a2619df13384228adb42e525a75ee853a0d2aeffcb89dd4257d5112e0a90c2", // my address sepolia
    "5000000000000000000",
  ],
  ["0x2222222222222222222222222222222222222222", "2500000000000000000"],
];

const leaves = values.map((v) => pedersenHex(v[0], v[1]));

function buildMerkleTree(leaves: string[]): string[][] {
  let level = leaves;
  const tree = [level];
  while (level.length > 1) {
    const nextLevel: string[] = [];
    for (let i = 0; i < level.length; i += 2) {
      if (i + 1 < level.length) {
        nextLevel.push(pedersenHex(level[i], level[i + 1]));
      } else {
        // if odd, duplicate last
        nextLevel.push(level[i]);
      }
    }
    tree.push(nextLevel);
    level = nextLevel;
  }
  return tree;
}

const tree = buildMerkleTree(leaves);
const root = tree[tree.length - 1][0];
console.log("Merkle Root:", root);

function getProof(tree: string[][], leafIndex: number): string[] {
  let proof: string[] = [];
  let index = leafIndex;
  for (let level = 0; level < tree.length - 1; level++) {
    const levelNodes = tree[level];
    const isRightNode = index % 2;
    const pairIndex = isRightNode ? index - 1 : index + 1;
    if (pairIndex < levelNodes.length) {
      proof.push(levelNodes[pairIndex]);
    }
    index = Math.floor(index / 2);
  }
  return proof;
}

const leafIndex = 0; // for the first value
const proof = getProof(tree, leafIndex);
console.log("Proof for leaf 0:", proof);

const proof2 = getProof(tree, 1); // for the second value
console.log("Proof for leaf 2:", proof2);
