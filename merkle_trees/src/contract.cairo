use starknet::ContractAddress;

// 0x232a79c2b164fd81c8da6b52c536d5004d6428e1fbbee44f43f784ca0ea64ff // deployed address of this contract

#[starknet::interface]
pub trait IDistributor<TContractState> {
    fn claim(ref self: TContractState, amount: u128, proof: Span<felt252>);

    fn add_root(ref self: TContractState, new_root: felt252);

    fn get_root_for(
        self: @TContractState, claimee: ContractAddress, amount: u128, proof: Span<felt252>,
    ) -> felt252;

    fn amount_already_claimed(self: @TContractState, claimee: ContractAddress) -> u128;

    fn roots(self: @TContractState) -> Span<felt252>;
    
    fn deposit_from_sender(
        ref self: TContractState, sender: ContractAddress, amount: u256
    );
}

#[starknet::contract]
pub mod Distributor {
    // imports for Merkle tree and Ownable component
    use alexandria_merkle_tree::merkle_tree::pedersen::PedersenHasherImpl;
    use alexandria_merkle_tree::merkle_tree::{Hasher, MerkleTree, MerkleTreeTrait};
    use core::array::{ArrayTrait, SpanTrait};
    use core::poseidon::hades_permutation;
    use core::traits::TryInto;
    use openzeppelin::access::ownable::ownable::OwnableComponent;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::*;
    use starknet::{ContractAddress, get_caller_address};

    const STRK_ADDRESS: felt252 =
        0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d;

    #[storage]
    pub struct Storage {
        allocation_claimed: Map<ContractAddress, u128>,
        merkle_roots: Vec<felt252>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[derive(Drop, starknet::Event)]
    #[event]
    enum Event {
        Claimed: Claimed,
        Deposited: Deposited,
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Claimed {
        claimee: ContractAddress,
        amount: u128,
    }

     #[derive(Drop, starknet::Event)]
    pub struct Deposited {
        sender: ContractAddress,
        amount: u256,
    }


    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    pub impl Distributor of super::IDistributor<ContractState> {
        fn claim(ref self: ContractState, amount: u128, proof: Span<felt252>) {
            let claimee = get_caller_address();
            let root = self.get_root_for(claimee, amount, proof);

            let roots = self.roots();
            let mut i = 0;
            let mut found_root = false;

            // iterate through the roots span to find the root
            loop {
                if (i >= roots.len()) {
                    break;
                }
                if (*roots.at(i) == root) {
                    found_root = true;
                    break;
                }
                i += 1;
            }
            assert(found_root, 'INVALID PROOF');

            let token = IERC20Dispatcher { contract_address: STRK_ADDRESS.try_into().unwrap() };
            let amount_claimed_by_claimee = self.allocation_claimed.read(claimee);
            let left_to_claim = amount - amount_claimed_by_claimee;

            if left_to_claim > 0 {
                assert(
                    token.transfer(claimee, u256 { high: 0, low: left_to_claim }),
                    'TRANSFER FAILED',
                );
                self.allocation_claimed.write(claimee, amount);
                self.emit(Event::Claimed(Claimed { claimee, amount }));
            } else {
                assert(left_to_claim == 0, 'AMOUNT ALREADY CLAIMED');
            }
        }

        fn get_root_for(
            self: @ContractState, claimee: ContractAddress, amount: u128, proof: Span<felt252>,
        ) -> felt252 {
            let mut merkle_tree: MerkleTree<Hasher> = MerkleTreeTrait::new();

            let (leaf, _, _) = hades_permutation(claimee.into(), amount.into(), 2);
            // compute_root would expect felt252 based on context
            merkle_tree.compute_root(leaf, proof)
        }

        fn add_root(ref self: ContractState, new_root: felt252) {
            self.ownable.assert_only_owner();
            self.merkle_roots.append().write(new_root);
        }

        fn amount_already_claimed(self: @ContractState, claimee: ContractAddress) -> u128 {
            self.allocation_claimed.read(claimee)
        }

        fn roots(self: @ContractState) -> Span<felt252> {
            let mut res: Array<felt252> = array![];
            let len = self.merkle_roots.len();
            let mut i: u64 = 0;
            loop {
                if (i >= len) {
                    break;
                }
                res.append(self.merkle_roots.at(i).read());
                i += 1;
            }
            res.span()
        }

        fn deposit_from_sender(
            ref self: ContractState, sender: ContractAddress, amount: u256
        ) {
            let token = IERC20Dispatcher { contract_address: STRK_ADDRESS.try_into().unwrap() };
            let current_contract_address = starknet::get_contract_address();

            let success = token.transfer_from(sender, current_contract_address, amount);
            assert(success, 'TRANSFER_FROM_FAILED');

            self.emit(Event::Deposited(Deposited { sender, amount }));
        }
    }
}