// TS translation of below rust implementation
// https://github.com/starknetfndn/defispring/blob/main/backend/src/api/merkle_tree.rs
// Turns out, the implementation uses a mix of pedersen and poseidon hashes.
// The poseidon hash is used for the leaf nodes (to create leaves), while the pedersen hash is used
// for the internal nodes (to create the tree).

import * as starknet from "@scure/starknet";

type FieldElement = bigint; // hex string, e.g. "0x123..."
type Address = bigint; // hex string

export interface CumulativeAllocation {
  address: Address;
  cumulative_amount: bigint;
}

export interface CairoCalldata {
  amount: string;
  proof: string[];
}

export class Node {
  left_child?: Node;
  right_child?: Node;
  accessible_addresses: Set<FieldElement>;
  value: FieldElement;

  constructor(
    value: FieldElement,
    accessible_addresses: Set<FieldElement>,
    left_child?: Node,
    right_child?: Node
  ) {
    this.value = value;
    this.accessible_addresses = accessible_addresses;
    this.left_child = left_child;
    this.right_child = right_child;
  }

  static new(a: Node, b: Node): Node {
    // Order nodes by value
    let left_child: Node, right_child: Node;
    if (BigInt(a.value) < BigInt(b.value)) {
      left_child = a;
      right_child = b;
    } else {
      left_child = b;
      right_child = a;
    }
    const value = hash(left_child.value, right_child.value);
    const accessible_addresses = new Set([
      ...left_child.accessible_addresses,
      ...right_child.accessible_addresses,
    ]);
    return new Node(value, accessible_addresses, left_child, right_child);
  }

  static new_leaf(allocation: CumulativeAllocation): Node {
    const address = allocation.address;
    const cumulated_amount = allocation.cumulative_amount;
    // keep order address, amount
    const value = poseidon_hash(address, cumulated_amount);
    return new Node(value, new Set([address]));
  }
}

export class MerkleTree {
  root: Node;
  allocations: CumulativeAllocation[];

  constructor(allocations: CumulativeAllocation[]) {
    if (allocations.length === 0) {
      throw new Error("No data for merkle tree");
    }
    let leaves = allocations.map((a) => Node.new_leaf(a));

    // if odd length add a copy of last elem
    if (leaves.length % 2 === 1) {
      leaves.push(leaves[leaves.length - 1]);
    }

    this.root = build_tree(leaves);
    this.allocations = allocations;
  }

  address_calldata(address: Address): CairoCalldata {
    const felt_address = address;

    if (!this.root.accessible_addresses.has(felt_address)) {
      throw new Error("Address not found in tree");
    }
    let hashes: FieldElement[] = [];
    let current_node = this.root;
    // if either child is_some, then both is_some
    while (true) {
      const left = current_node.left_child;
      const right = current_node.right_child;
      if (!left || !right) {
        throw new Error("Invalid tree structure");
      }
      if (left.accessible_addresses.has(felt_address)) {
        hashes.push(right.value);
        current_node = left;
      } else {
        hashes.push(left.value);
        current_node = right;
      }

      if (!current_node.left_child) {
        break;
      }
    }
    // reverse to leaf first root last
    hashes = hashes.reverse();

    const allocation = this.allocations.find((a) => a.address === felt_address);
    if (!allocation) throw new Error("Allocation not found");

    const amount = allocation.cumulative_amount.toString();

    return {
      amount: felt_to_b16(amount),
      proof: hashes.map(felt_to_b16),
    };
  }
}

function build_tree(leaves: Node[]): Node {
  function build_tree_recursively(nodes: Node[]): Node {
    let next_nodes: Node[] = [];
    let i = 0;
    while (i < nodes.length) {
      const a = nodes[i];
      const b = nodes[i + 1];
      next_nodes.push(Node.new(a, b));
      i += 2;
    }
    if (next_nodes.length === 1) {
      return next_nodes[0];
    }
    if (next_nodes.length % 2 === 1) {
      next_nodes.push(next_nodes[next_nodes.length - 1]);
    }
    return build_tree_recursively(next_nodes);
  }
  return build_tree_recursively(leaves);
}

function felt_to_b16(felt: string | bigint): string {
  if (typeof felt === "bigint") {
    return "0x" + felt.toString(16);
  }
  if (felt.startsWith("0x")) return felt;
  return "0x" + BigInt(felt).toString(16);
}

function hash(a: FieldElement, b: FieldElement): FieldElement {
  if (BigInt(a) < BigInt(b)) {
    return BigInt(starknet.pedersen(a, b).toString());
  }
  return BigInt(starknet.pedersen(b, a).toString());
}

function poseidon_hash(a: FieldElement, b: FieldElement): FieldElement {
  return BigInt(starknet.poseidonHash(a, b).toString());
}
