# KAM Protocol Deployment Makefile
# Usage: make deploy-mainnet, make deploy-sepolia, make deploy-localhost
-include .env
export

.PHONY: help deploy-mainnet deploy-sepolia deploy-localhost deploy-all deploy-mock-assets verify clean clean-all

# Default target
help:
	@echo "KAM Protocol Deployment Commands"
	@echo "================================="
	@echo "make deploy-mainnet     - Deploy to mainnet"
	@echo "make deploy-sepolia     - Deploy to Sepolia testnet"  
	@echo "make deploy-localhost   - Deploy to localhost"
	@echo "make deploy-all         - Deploy complete protocol (current network)"
	@echo "make verify             - Verify deployment configuration"
	@echo "make clean              - Clean localhost deployment files"
	@echo "make clean-all          - Clean ALL deployment files (DANGER)"
	@echo ""
	@echo "Individual deployment steps:"
	@echo "make deploy-mock-assets - Deploy mock assets for testnets (00)"
	@echo "make deploy-core        - Deploy core contracts (01-03)"
	@echo "make setup-singletons   - Register singletons (04)"
	@echo "make deploy-tokens      - Deploy kTokens (05)"
	@echo "make deploy-modules     - Deploy vault modules (06)"
	@echo "make deploy-vaults      - Deploy vaults (07)"
	@echo "make setup-modules      - Register modules (08)"
	@echo "make deploy-adapters    - Deploy adapters (09)"
	@echo "make configure          - Configure protocol (10)"

# Network-specific deployments
deploy-mainnet:
	@echo "🔴 Deploying to MAINNET..."
	@$(MAKE) deploy-all FORGE_ARGS="--rpc-url ${RPC_MAINNET} --broadcast --account maxDeployer --sender ${DEPLOYER_ADDRESS} --verify --etherscan-api-key ${ETHERSCAN_MAINNET_KEY}"

deploy-sepolia:
	@echo "🟡 Deploying to SEPOLIA..."
	@$(MAKE) deploy-mock-assets FORGE_ARGS="--rpc-url ${RPC_SEPOLIA} --broadcast --account maxDeployer --sender ${DEPLOYER_ADDRESS}"
	@$(MAKE) deploy-all FORGE_ARGS="--rpc-url ${RPC_SEPOLIA} --broadcast --account maxDeployer --sender ${DEPLOYER_ADDRESS}"

deploy-localhost:
	@echo "🟢 Deploying to LOCALHOST..."
	@$(MAKE) deploy-mock-assets FORGE_ARGS="--rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
	@$(MAKE) deploy-all FORGE_ARGS="--rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

# Complete deployment sequence
deploy-all: deploy-core setup-singletons deploy-tokens deploy-modules deploy-vaults setup-modules deploy-adapters configure
	@echo "✅ Complete protocol deployment finished!"

# Mock assets (00) - Only for testnets
deploy-mock-assets:
	@echo "🪙 Deploying mock assets for testnet..."
	forge script script/deployment/00_DeployMockAssets.s.sol $(FORGE_ARGS)

# Core contracts (01-03)
deploy-core:
	@echo "📦 Deploying core contracts..."
	forge script script/deployment/01_DeployRegistry.s.sol $(FORGE_ARGS)
	forge script script/deployment/02_DeployMinter.s.sol $(FORGE_ARGS)
	forge script script/deployment/03_DeployAssetRouter.s.sol $(FORGE_ARGS)

# Registry setup (04)
setup-singletons:
	@echo "⚙️  Registry singleton setup..."
	forge script script/deployment/04_RegisterSingletons.s.sol $(FORGE_ARGS)
	@echo "⚠️  Execute the displayed admin calls via admin account"

# Token deployment (05)
deploy-tokens:
	@echo "🪙 Token deployment setup..."
	forge script script/deployment/05_DeployTokens.s.sol $(FORGE_ARGS)
	@echo "⚠️  Execute the displayed admin calls via admin account"

# Vault modules (06)
deploy-modules:
	@echo "🧩 Deploying vault modules..."
	forge script script/deployment/06_DeployVaultModules.s.sol $(FORGE_ARGS)

# Vaults (07)
deploy-vaults:
	@echo "🏛️  Deploying vaults..."
	forge script script/deployment/07_DeployVaults.s.sol $(FORGE_ARGS)

# Module registration (08)
setup-modules:
	@echo "🔗 Module registration setup..."
	forge script script/deployment/08_RegisterModules.s.sol $(FORGE_ARGS)
	@echo "⚠️  Execute the displayed admin calls via admin account"

# Adapters (09)
deploy-adapters:
	@echo "🔌 Deploying adapters..."
	forge script script/deployment/09_DeployAdapters.s.sol $(FORGE_ARGS)

# Final configuration (10)
configure:
	@echo "⚙️  Protocol configuration setup..."
	forge script script/deployment/10_ConfigureProtocol.s.sol $(FORGE_ARGS)
	@echo "⚠️  Execute the displayed admin calls via admin account"

# Verification
verify:
	@echo "🔍 Verifying deployment..."
	@if [ ! -f "deployments/output/localhost/addresses.json" ] && [ ! -f "deployments/output/mainnet/addresses.json" ] && [ ! -f "deployments/output/sepolia/addresses.json" ]; then \
		echo "❌ No deployment files found"; \
		exit 1; \
	fi
	@echo "✅ Deployment files exist"
	@echo "📄 Check deployments/output/ for contract addresses"

# Development helpers
test:
	forge test

coverage:
	forge coverage

build:
	forge build

clean:
	forge clean
	rm -rf deployments/output/localhost/addresses.json

clean-all:
	forge clean
	rm -rf deployments/output/*/addresses.json

# Documentation
docs:
	forge doc --serve --port 4000

# Color output
RED    = \033[0;31m
GREEN  = \033[0;32m  
YELLOW = \033[0;33m
BLUE   = \033[0;34m
NC     = \033[0m # No Color