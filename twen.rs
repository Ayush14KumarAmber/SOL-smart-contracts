use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct ERC20Token {
    name: String,
    symbol: String,
    decimals: u8,
    total_supply: u128,
    balances: HashMap<String, u128>,
    allowances: HashMap<String, HashMap<String, u128>>,
}

#[derive(Debug)]
pub enum TokenError {
    InsufficientBalance,
    InsufficientAllowance,
    InvalidAddress,
}

impl ERC20Token {
    /// Create a new ERC20 token
    pub fn new(name: String, symbol: String, decimals: u8, initial_supply: u128, owner: String) -> Self {
        let mut balances = HashMap::new();
        balances.insert(owner.clone(), initial_supply);
        
        ERC20Token {
            name,
            symbol,
            decimals,
            total_supply: initial_supply,
            balances,
            allowances: HashMap::new(),
        }
    }
    
    /// Get token name
    pub fn name(&self) -> &str {
        &self.name
    }
    
    /// Get token symbol
    pub fn symbol(&self) -> &str {
        &self.symbol
    }
    
    /// Get decimals
    pub fn decimals(&self) -> u8 {
        self.decimals
    }
    
    /// Get total supply
    pub fn total_supply(&self) -> u128 {
        self.total_supply
    }
    
    /// Get balance of an address
    pub fn balance_of(&self, address: &str) -> u128 {
        *self.balances.get(address).unwrap_or(&0)
    }
    
    /// Transfer tokens from sender to recipient
    pub fn transfer(&mut self, from: &str, to: &str, amount: u128) -> Result<(), TokenError> {
        if from.is_empty() || to.is_empty() {
            return Err(TokenError::InvalidAddress);
        }
        
        let from_balance = self.balance_of(from);
        if from_balance < amount {
            return Err(TokenError::InsufficientBalance);
        }
        
        // Deduct from sender
        self.balances.insert(from.to_string(), from_balance - amount);
        
        // Add to recipient
        let to_balance = self.balance_of(to);
        self.balances.insert(to.to_string(), to_balance + amount);
        
        println!("Transfer: {} tokens from {} to {}", amount, from, to);
        Ok(())
    }
    
    /// Approve spender to spend tokens on behalf of owner
    pub fn approve(&mut self, owner: &str, spender: &str, amount: u128) -> Result<(), TokenError> {
        if owner.is_empty() || spender.is_empty() {
            return Err(TokenError::InvalidAddress);
        }
        
        self.allowances
            .entry(owner.to_string())
            .or_insert_with(HashMap::new)
            .insert(spender.to_string(), amount);
        
        println!("Approval: {} approved {} to spend {} tokens", owner, spender, amount);
        Ok(())
    }
    
    /// Get allowance amount
    pub fn allowance(&self, owner: &str, spender: &str) -> u128 {
        self.allowances
            .get(owner)
            .and_then(|allowances| allowances.get(spender))
            .copied()
            .unwrap_or(0)
    }
    
    /// Transfer tokens from one address to another using allowance
    pub fn transfer_from(&mut self, spender: &str, from: &str, to: &str, amount: u128) -> Result<(), TokenError> {
        if spender.is_empty() || from.is_empty() || to.is_empty() {
            return Err(TokenError::InvalidAddress);
        }
        
        let current_allowance = self.allowance(from, spender);
        if current_allowance < amount {
            return Err(TokenError::InsufficientAllowance);
        }
        
        let from_balance = self.balance_of(from);
        if from_balance < amount {
            return Err(TokenError::InsufficientBalance);
        }
        
        // Update allowance
        self.allowances
            .get_mut(from)
            .unwrap()
            .insert(spender.to_string(), current_allowance - amount);
        
        // Deduct from sender
        self.balances.insert(from.to_string(), from_balance - amount);
        
        // Add to recipient
        let to_balance = self.balance_of(to);
        self.balances.insert(to.to_string(), to_balance + amount);
        
        println!("TransferFrom: {} transferred {} tokens from {} to {}", spender, amount, from, to);
        Ok(())
    }
}

// Example usage
fn main() {
    let mut token = ERC20Token::new(
        "MyToken".to_string(),
        "MTK".to_string(),
        18,
        1_000_000_000_000_000_000_000_000, // 1 million tokens with 18 decimals
        "alice".to_string(),
    );
    
    println!("Token Name: {}", token.name());
    println!("Token Symbol: {}", token.symbol());
    println!("Total Supply: {}", token.total_supply());
    println!("Alice Balance: {}\n", token.balance_of("alice"));
    
    // Transfer tokens
    match token.transfer("alice", "bob", 100_000) {
        Ok(_) => println!("Transfer successful!"),
        Err(e) => println!("Transfer failed: {:?}", e),
    }
    
    println!("Alice Balance: {}", token.balance_of("alice"));
    println!("Bob Balance: {}\n", token.balance_of("bob"));
    
    // Approve and transfer from
    token.approve("alice", "charlie", 50_000).unwrap();
    println!("Allowance (alice -> charlie): {}\n", token.allowance("alice", "charlie"));
    
    match token.transfer_from("charlie", "alice", "dave", 30_000) {
        Ok(_) => println!("TransferFrom successful!"),
        Err(e) => println!("TransferFrom failed: {:?}", e),
    }
    
    println!("\nFinal Balances:");
    println!("Alice: {}", token.balance_of("alice"));
    println!("Bob: {}", token.balance_of("bob"));
    println!("Dave: {}", token.balance_of("dave"));
    println!("Remaining Allowance (alice -> charlie): {}", token.allowance("alice", "charlie"));
}
