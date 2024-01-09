# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# Remove modules
remove:
	rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

# Install the Modules
install:
	forge install foundry-rs/forge-std --no-commit
	forge install OpenZeppelin/openzeppelin-contracts@v5.0.1 --no-commit
	forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v5.0.1 --no-commit

# Update the modules
update: remove install

# Builds
clean:
	forge fmt && forge clean

build:
	forge build --evm-version paris

clean_build: clean bulid

# Tests
quick_test:
	forge test --fuzz-runs 256

std_test:
	forge test

gas_test:
	forge test --gas-report

fuzz_test:
	forge test --fuzz-runs 10000

# Deployments
deploy_sepolia: build
	forge script script/Deploy.s.sol:Deploy --evm-version paris --rpc-url sepolia --ledger --sender ${SENDER} --broadcast
	sleep 5
	$(eval deployed_contract=$(shell cat out.txt))
	forge verify-contract $(deployed_contract) src/TLUniversalDeployer.sol:TLUniversalDeployer --chain sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}

deploy_arb_sepolia: build
	forge script script/Deploy.s.sol:Deploy --evm-version paris --rpc-url arb_sepolia --ledger --sender ${SENDER} --broadcast
	sleep 5
	$(eval deployed_contract=$(shell cat out.txt))
	forge verify-contract $(deployed_contract) src/TLUniversalDeployer.sol:TLUniversalDeployer --chain arbitrum-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}

deploy_base_sepolia: build
	forge script script/Deploy.s.sol:Deploy --evm-version paris --rpc-url base_sepolia --ledger --sender ${SENDER} --broadcast
	sleep 5
	$(eval deployed_contract=$(shell cat out.txt))
	forge verify-contract $(deployed_contract) src/TLUniversalDeployer.sol:TLUniversalDeployer --chain base-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}

