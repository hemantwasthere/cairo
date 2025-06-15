#[starknet::interface]
pub trait ICounterContract<T> {
    fn get_counter(self: @T) -> u32;
    fn set_counter(ref self: T, value: u32);
    fn increment_counter(ref self: T);
    fn decrement_counter(ref self: T);
}


#[starknet::contract]
pub mod counter_contract {
    use starknet::event::EventEmitter;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::ICounterContract;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CounterUpdate: CounterUpdate,
    }

    #[derive(Drop, starknet::Event)]
    struct CounterUpdate {
        value: u32,
    }

    #[storage]
    struct Storage {
        counter: u32,
    }

    fn constructor(ref self: ContractState, initial_value: u32) {
        self.counter.write(initial_value);
    }

    #[abi(embed_v0)]
    impl CounterImpl of ICounterContract<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }
        fn set_counter(ref self: ContractState, value: u32) {
            self.counter.write(value);
        }
        fn increment_counter(ref self: ContractState) {
            self.counter.write(self.get_counter() + 1);
            self.emit(CounterUpdate { value: self.get_counter() })
        }
        fn decrement_counter(ref self: ContractState) {
            self.counter.write(self.get_counter() - 1);
            self.emit(CounterUpdate { value: self.get_counter() })
        }
    }
}

