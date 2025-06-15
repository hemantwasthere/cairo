#[starknet::contract]
pub mod jod_contract {
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::{ContractAddress, get_caller_address};

    // Define the ERC20 component
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    // the ERC20 mixin trait for external functions
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    // the internal ERC20 trait for internal functions like mint
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    // Define the contract's storage
    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }

    // Define the contract's events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    // Define the contract's constructor
    #[constructor]
    fn constructor(ref self: ContractState, fixed_supply: u256, recipient: ContractAddress) {
        // Initialize the ERC20 token with name and symbol
        let name = "JOD Token";
        let symbol = "JOD";
        self.erc20.initializer(name, symbol);

        // Mint the fixed supply to the specified recipient
        self.erc20.mint(recipient, fixed_supply);
    }
}
