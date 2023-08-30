#[starknet::contract]
mod ERC20 {

    use zeroable::Zeroable;
    use starknet::get_caller_address;
    use integer::BoundedInt;
    use starknet::contract_address_const;
    use starknet::get_contract_address;
    use starknet::ContractAddress;
    use starknet::contract_address::ContractAddressZeroable;

    use napa::interfaces::IERC20::IERC20;

    use debug::PrintTrait;

    ////////////////////////////////
    // STORAGE
    ////////////////////////////////

    #[storage]
    struct Storage {
        name: felt252,
        symbol: felt252,
        decimals: u8,
        total_supply: u256,
        balances: LegacyMap::<ContractAddress, u256>,
        allowances: LegacyMap::<(ContractAddress, ContractAddress), u256>,
    }

    ////////////////////////////////
    // EVENTS
    ////////////////////////////////

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer { from: ContractAddress, to: ContractAddress, value: u256 }

    #[derive(Drop, starknet::Event)]
    struct Approval { owner: ContractAddress, spender: ContractAddress, value: u256 }

    ////////////////////////////////
    // CONSTRUCTOR
    ////////////////////////////////

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name_: felt252,
        symbol_: felt252,
        decimals_: u8,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        initializer(ref self, name_, symbol_, decimals_);
        _mint(ref self, recipient, initial_supply);

    }

    #[external(v0)]
    impl ERC20Impl of IERC20<ContractState> {

        ////////////////////////////////
        // VIEW FUNCTIONS
        ////////////////////////////////

        fn name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        fn symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.allowances.read((owner, spender))
        }

        ////////////////////////////////
        // EXTERNAL FUNCTIONS
        ////////////////////////////////

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let sender = get_caller_address();
            _transfer(ref self, sender, recipient, amount);
            true
        }

        fn transfer_from(
            ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
        ) -> bool {
            let caller = get_caller_address();
            _spend_allowance(ref self, sender, caller, amount);
            _transfer(ref self, sender, recipient, amount);
            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            _approve(ref self, caller, spender, amount);
            true
        }

        fn increase_allowance(ref self: ContractState, spender: ContractAddress, added_value: u256) -> bool {
            _increase_allowance(ref self, spender, added_value)
        }

        fn decrease_allowance(ref self: ContractState, spender: ContractAddress, subtracted_value: u256) -> bool {
            _decrease_allowance(ref self, spender, subtracted_value)
        }
    }

    ////////////////////////////////
    // INTERNAL FUNCTIONS
    ////////////////////////////////

    fn initializer(
        ref self: ContractState, name_: felt252, symbol_: felt252, decimals_: u8,
    ) {
        self.name.write(name_);
        self.symbol.write(symbol_);
        self.decimals.write(decimals_);
    }

    fn _increase_allowance(ref self: ContractState, spender: ContractAddress, added_value: u256) -> bool {
        let caller = get_caller_address();
        _approve(ref self, caller, spender, self.allowances.read((caller, spender)) + added_value);
        true
    }

    fn _decrease_allowance(ref self: ContractState, spender: ContractAddress, subtracted_value: u256) -> bool {
        let caller = get_caller_address();
        _approve(ref self, caller, spender, self.allowances.read((caller, spender)) - subtracted_value);
        true
    }

    fn _mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
        assert(!recipient.is_zero(), 'ERC20: mint to 0');
        self.total_supply.write(self.total_supply.read() + amount);
        self.balances.write(recipient, self.balances.read(recipient) + amount);
        self.emit(Event::Transfer(Transfer { from: Zeroable::zero(), to: recipient, value: amount }));
    }

    fn _burn(ref self: ContractState, account: ContractAddress, amount: u256) {
        assert(!account.is_zero(), 'ERC20: burn from 0');
        self.total_supply.write(self.total_supply.read() - amount);
        self.balances.write(account, self.balances.read(account) - amount);
        self.emit(Event::Transfer(Transfer { from: account, to: Zeroable::zero(), value: amount }));
    }

    fn _approve(ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256) {
        assert(!owner.is_zero(), 'ERC20: approve from 0');
        assert(!spender.is_zero(), 'ERC20: approve to 0');
        self.allowances.write((owner, spender), amount);
        self.emit(Event::Approval(Approval { owner, spender, value: amount }));
    }

    fn _transfer(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) {
        assert(!sender.is_zero(), 'ERC20: transfer from 0');
        assert(!recipient.is_zero(), 'ERC20: transfer to 0');
        self.balances.write(sender, self.balances.read(sender) - amount);
        self.balances.write(recipient, self.balances.read(recipient) + amount);
        self.emit(Event::Transfer(Transfer { from: sender, to: recipient, value: amount }));
    }

    fn _spend_allowance(ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256) {
        let current_allowance = self.allowances.read((owner, spender));
        if current_allowance != BoundedInt::max() {
            _approve(ref self, owner, spender, current_allowance - amount);
        }
    }
}
