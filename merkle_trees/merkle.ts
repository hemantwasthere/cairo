import { assert } from "console";
import { Contract, num, RpcProvider } from "starknet";

import { MerkleTree as MerkleTreeSNF } from "./lib";

const values = [
  [
    "0x07a2619df13384228adb42e525a75ee853a0d2aeffcb89dd4257d5112e0a90c2", // my address sepolia
    "5000000000000000000",
  ],
  ["0x2222222222222222222222222222222222222222", "2500000000000000000"],
];

const tree4 = new MerkleTreeSNF(
  values.map((x) => ({
    address: BigInt(num.getDecimalString(x[0].toString())),
    cumulative_amount: BigInt(num.getDecimalString(x[1].toString())),
  }))
);
const root = num.getHexString(tree4.root.value.toString());
console.log("Merkle Tree 4 Root:", root);
const proof = getProof(0); // for the first value
console.log("Merkle Proof for first leaf in Tree 4:", proof);

function getProof(leafIndex: number): string[] {
  return tree4.address_calldata(
    BigInt(num.getDecimalString(values[leafIndex][0].toString()))
  ).proof;
}

async function checkProofValidity(
  user: string,
  amount: string,
  proof: string[],
  myRoot: string
) {
  const addr =
    "0x232a79c2b164fd81c8da6b52c536d5004d6428e1fbbee44f43f784ca0ea64ff";
  const provider = new RpcProvider({
    nodeUrl: "https://starknet-sepolia.public.blastapi.io",
  });
  const cls = await provider.getClassAt(addr);
  const contract = new Contract(cls.abi, addr, provider);

  // returns root as expected by the contract
  const computedRoot: any = await contract.call("get_root_for", [
    user,
    amount,
    proof,
  ]);
  console.log("Computed Root:", num.getHexString(computedRoot));
  assert(
    num.getHexString(computedRoot) === myRoot,
    "Computed root does not match expected root"
  );
  console.log("Proof is valid for user:", user, "with amount:", amount);
}

async function main() {
  await checkProofValidity(values[0][0], values[0][1], proof, root);
}

main();
