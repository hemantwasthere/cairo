use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use starknet::ContractAddress;

// Define the contract interface
#[starknet::interface]
pub trait IPoints<TContractState> {
    fn deposit_tokens(ref self: TContractState, amount: u256);
    fn get_points(self: @TContractState, user: ContractAddress) -> u256;
}

// Define the contract module
#[starknet::contract]
pub mod points_contract {
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::*;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    // Define storage variables
    #[storage]
    pub struct Storage {
        user_points: Map<ContractAddress, u256>, // Mapping from user address to their points
        jod_token_address: ContractAddress // Address of the deployed JOD ERC20 token contract
    }

    // Define contract events
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokensDeposited: TokensDeposited,
        PointsAwarded: PointsAwarded // Event for points being awarded
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokensDeposited {
        user: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PointsAwarded {
        user: ContractAddress,
        tokens_received: u256,
        total_points: u256,
    }

    // Contract constructor
    #[constructor]
    fn constructor(ref self: ContractState, jod_token_address: ContractAddress) {
        self.jod_token_address.write(jod_token_address);
    }

    // Implement the contract interface
    #[abi(embed_v0)]
    pub impl PointsImpl of super::IPoints<ContractState> {
        // Function to deposit tokens and earn points
        fn deposit_tokens(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();
            let token_address = self.jod_token_address.read();
            let token_contract = IERC20Dispatcher { contract_address: token_address };
            let self_address = get_contract_address();

            // Transfer tokens from the caller to this contract
            // Note: The caller must have previously approved this contract
            // to spend 'amount' of their JOD tokens using the JOD contract's 'approve' function.
            token_contract.transfer_from(caller, self_address, amount);

            // Calculate and update points (1 point per token)
            let current_points = self.user_points.read(caller);
            let new_points = current_points + amount;
            self.user_points.write(caller, new_points);

            // Emit events
            self.emit(Event::TokensDeposited(TokensDeposited { user: caller, amount }));
            self
                .emit(
                    Event::PointsAwarded(
                        PointsAwarded {
                            user: caller, tokens_received: amount, total_points: new_points,
                        },
                    ),
                );
        }

        // View function to retrieve a user's points
        fn get_points(self: @ContractState, user: ContractAddress) -> u256 {
            self.user_points.read(user)
        }
    }
}
