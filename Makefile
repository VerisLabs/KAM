# KAM Protocol Deployment Makefile
# Usage: make deploy-mainnet, make deploy-sepolia, make deploy-localhost
-include .env
export

.PHONY: help deploy-mainnet deploy-sepolia deploy-localhost deploy-all deploy-mock-assets verify clean clean-all configure-adapters register-modules format-output

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
	@echo "make deploy-adapters    - Deploy adapters (08)"
	@echo "make configure          - Configure protocol (09)"
	@echo "make configure-adapters - Configure adapter permissions (10)"
	@echo "make register-modules   - Register vault modules (11) [OPTIONAL]"

# Network-specific deployments
deploy-mainnet:
	@echo "🔴 Deploying to MAINNET..."
	@$(MAKE) deploy-all FORGE_ARGS="--rpc-url ${RPC_MAINNET} --broadcast --account keyDeployer --sender ${DEPLOYER_ADDRESS} --slow --verify --etherscan-api-key ${ETHERSCAN_MAINNET_KEY}"

deploy-sepolia:
	@echo "🟡 Deploying to SEPOLIA..."
	@$(MAKE) deploy-mock-assets FORGE_ARGS="--rpc-url ${RPC_SEPOLIA} --broadcast --account keyDeployer --sender ${DEPLOYER_ADDRESS}	--slow"
	@$(MAKE) deploy-all FORGE_ARGS="--rpc-url ${RPC_SEPOLIA} --broadcast --account keyDeployer --sender ${DEPLOYER_ADDRESS}	--slow"

deploy-localhost:
	@echo "🟢 Deploying to LOCALHOST..."
	@$(MAKE) deploy-mock-assets FORGE_ARGS="--rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --slow"
	@$(MAKE) deploy-all FORGE_ARGS="--rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --slow"

# Complete deployment sequence
deploy-all: deploy-core setup-singletons deploy-tokens deploy-modules deploy-vaults deploy-adapters configure configure-adapters format-output
	@echo "✅ Complete protocol deployment finished!"

# Format JSON output files
format-output:
	@echo "📝 Formatting JSON output files..."
	@for file in deployments/output/*/*.json; do \
		if [ -f "$$file" ]; then \
			echo "Formatting $$file"; \
			jq . "$$file" > "$$file.tmp" && mv "$$file.tmp" "$$file"; \
		fi; \
	done
	@echo "✅ JSON files formatted!"

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

# Adapters (08)
deploy-adapters:
	@echo "🔌 Deploying adapters..."
	forge script script/deployment/08_DeployAdapters.s.sol $(FORGE_ARGS)

# Final configuration (09)
configure:
	@echo "⚙️  Executing protocol configuration..."
	forge script script/deployment/09_ConfigureProtocol.s.sol $(FORGE_ARGS)

# Adapter permissions configuration (10)
configure-adapters:
	@echo "🔐 Configuring adapter permissions..."
	forge script script/deployment/10_ConfigureAdapterPermissions.s.sol $(FORGE_ARGS)

# Register vault modules (11) - Optional step for adding ReaderModule to vaults
register-modules:
	@echo "📦 Registering vault modules..."
	forge script script/deployment/11_RegisterVaultModules.s.sol $(FORGE_ARGS)
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

compile:
	@$(MAKE) check-selectors
	@$(MAKE) check-interface-completeness
	forge fmt --check
	forge build --sizes --skip test

build:
	@$(MAKE) build-selectors
	@$(MAKE) build-interfaces
	forge fmt
	forge build --use $$(which solx)

clean:
	forge clean
	rm -rf deployments/output/localhost/addresses.json

clean-all:
	forge clean
	rm -rf deployments/output/*/addresses.json

# Documentation
docs:
	forge doc --serve --port 4000

# Verify that IModule contracts have complete selectors() functions
check-selectors:
	@echo "🔍 Checking IModule contracts for complete selectors()..."
	@bash -c '\
	found_issues=0; \
	for file in $$(find src -name "*.sol" -type f); do \
		if grep -q "IModule" "$$file" && grep -q "function selectors()" "$$file"; then \
			echo "Checking $$file..."; \
			contract_name=$$(basename "$$file" .sol); \
			selectors=$$(grep -E "function [a-zA-Z0-9_]+\(" "$$file" | \
				grep -E "(external|public)" | \
				grep -v "function selectors()" | \
				grep -v "constructor" | \
				grep -v "^[[:space:]]*///" | \
				grep -v "^[[:space:]]*\*" | \
				sed "s/.*function \([a-zA-Z0-9_]*\).*/\1/"); \
			selectors_array=$$(grep -A 100 "function selectors()" "$$file" | \
				grep "this\." | \
				sed "s/.*this\.\([a-zA-Z0-9_]*\).*/\1/"); \
			for selector in $$selectors; do \
				if ! echo "$$selectors_array" | grep -q "$$selector"; then \
					echo "  ❌ Missing selector: $$selector in $$contract_name"; \
					found_issues=$$((found_issues + 1)); \
				fi; \
			done; \
			if [ $$found_issues -eq 0 ]; then \
				echo "  ✅ All selectors present in $$contract_name"; \
			fi; \
		fi; \
	done; \
	if [ $$found_issues -gt 0 ]; then \
		echo ""; \
		echo "❌ Found $$found_issues missing selector(s)"; \
		exit 1; \
	else \
		echo ""; \
		echo "✅ All IModule contracts have complete selectors() functions"; \
	fi'

# Automatically fix IModule contracts by rebuilding selectors() function
build-selectors:
	@echo "🔧 Fixing IModule contracts selectors()..."
	@bash -c '\
	fixed_count=0; \
	for file in $$(find src -name "*.sol" -type f); do \
		filename=$$(basename "$$file"); \
		if [ "$$filename" = "IModule.sol" ]; then \
			echo "⏭️  Skipping $$file (interface file)"; \
			continue; \
		fi; \
		\
		if grep -q "IModule" "$$file" && grep -q "function selectors()" "$$file"; then \
			echo "Checking $$file..."; \
			contract_name=$$(basename "$$file" .sol); \
			\
			selectors=(); \
			in_function=0; \
			is_public_external=0; \
			func_name=""; \
			\
			while IFS= read -r line; do \
				clean_line=$$(echo "$$line" | sed "s://.*$$::"); \
				\
				if echo "$$clean_line" | grep -q "function selectors()"; then \
					in_function=0; \
					continue; \
				fi; \
				\
				if echo "$$clean_line" | grep -q "constructor"; then \
					in_function=0; \
					continue; \
				fi; \
				\
				if echo "$$clean_line" | grep -qE "function[[:space:]]+[a-zA-Z0-9_]+[[:space:]]*\("; then \
					func_name=$$(echo "$$clean_line" | sed -n "s/.*function[[:space:]]*\([a-zA-Z0-9_]*\)[[:space:]]*(.*/\1/p"); \
					in_function=1; \
					is_public_external=0; \
					\
					if echo "$$clean_line" | grep -qE "(public|external)"; then \
						is_public_external=1; \
					fi; \
				fi; \
				\
				if [ $$in_function -eq 1 ] && [ $$is_public_external -eq 0 ]; then \
					if echo "$$clean_line" | grep -qE "(public|external)"; then \
						is_public_external=1; \
					fi; \
				fi; \
				\
				if [ $$in_function -eq 1 ] && echo "$$clean_line" | grep -qE "\{|;"; then \
					if [ $$is_public_external -eq 1 ] && [ -n "$$func_name" ]; then \
						selectors+=("$$func_name"); \
					fi; \
					in_function=0; \
					func_name=""; \
				fi; \
			done < "$$file"; \
			\
			num_selectors=$${#selectors[@]}; \
			echo "  📋 Found $$num_selectors function(s): $${selectors[*]}"; \
			\
			temp_file=$$(mktemp); \
			in_selectors_func=0; \
			skip_until_closing=0; \
			indent=""; \
			\
			while IFS= read -r line; do \
				if echo "$$line" | grep -q "function selectors()"; then \
					in_selectors_func=1; \
					skip_until_closing=1; \
					indent=$$(echo "$$line" | sed "s/\(^[[:space:]]*\).*/\1/"); \
					echo "$$line" >> "$$temp_file"; \
					echo "$${indent}    bytes4[] memory moduleSelectors = new bytes4[]($$num_selectors);" >> "$$temp_file"; \
					\
					idx=0; \
					for selector in "$${selectors[@]}"; do \
						echo "$${indent}    moduleSelectors[$$idx] = this.$$selector.selector;" >> "$$temp_file"; \
						idx=$$((idx + 1)); \
					done; \
					\
					echo "$${indent}    return moduleSelectors;" >> "$$temp_file"; \
					continue; \
				fi; \
				\
				if [ $$skip_until_closing -eq 1 ]; then \
					if echo "$$line" | grep -qE "^$${indent}}"; then \
						skip_until_closing=0; \
						in_selectors_func=0; \
						echo "$$line" >> "$$temp_file"; \
					fi; \
					continue; \
				fi; \
				\
				echo "$$line" >> "$$temp_file"; \
			done < "$$file"; \
			\
			mv "$$temp_file" "$$file"; \
			echo "  ✅ Rebuilt selectors() for $$contract_name with $$num_selectors selector(s)"; \
			fixed_count=$$((fixed_count + 1)); \
		fi; \
	done; \
	if [ $$fixed_count -gt 0 ]; then \
		echo ""; \
		echo "✅ Rebuilt selectors() in $$fixed_count contract(s)"; \
		echo "⚠️  Please review the changes and run tests"; \
	else \
		echo ""; \
		echo "ℹ️  No IModule contracts found to fix"; \
	fi'
	
check-interface-completeness:
	@echo " Checking contracts for interface completeness..."
	@bash -c '\
	found_issues=0; \
	get_interface_funcs() { \
		local interface_file=$$1; \
		local funcs=""; \
		local inherited_interfaces=$$(grep -E "interface[[:space:]]+[A-Za-z0-9_]+[[:space:]]+is[[:space:]]+" "$$interface_file" | sed -E "s/.*is[[:space:]]+(.+)[[:space:]]*\{.*/\1/" | tr "," "\n" | sed "s/^[[:space:]]*//;s/[[:space:]]*$$//"); \
		funcs=$$(grep -E "function[[:space:]]+[A-Za-z0-9_]+\(" "$$interface_file" | sed -E "s/.*function[[:space:]]+([A-Za-z0-9_]+)\(.*/\1/"); \
		for inherited in $$inherited_interfaces; do \
			inherited_file=$$(find src/interfaces -type f -name "$$inherited.sol" | head -n 1); \
			if [ -f "$$inherited_file" ]; then \
				inherited_funcs=$$(get_interface_funcs "$$inherited_file"); \
				funcs=$$(printf "%s\n%s" "$$funcs" "$$inherited_funcs"); \
			fi; \
		done; \
		echo "$$funcs" | grep -v "^$$" | sort -u; \
	}; \
	for file in $$(find src -name "*.sol" -type f ! -path "src/vendor/*" ! -path "src/interfaces/*" ! -path "src/adapters/parameters/*"); do \
		if grep -qE "contract[[:space:]]+[A-Za-z0-9_]+[[:space:]]+is[[:space:]]+I" "$$file"; then \
			contract_name=$$(basename "$$file" .sol); \
			interface_name=$$(grep -oE "is[[:space:]]+I[A-Za-z0-9_]+" "$$file" | head -n 1 | sed -E "s/is[[:space:]]+//"); \
			if [ -z "$$interface_name" ]; then \
				continue; \
			fi; \
			echo "Checking $$contract_name against $$interface_name..."; \
			interface_file=$$(find src/interfaces -type f -name "$$interface_name.sol" | head -n 1); \
			if [ ! -f "$$interface_file" ]; then \
				echo "  ⚠️  Interface file not found: $$interface_name.sol"; \
				found_issues=$$((found_issues + 1)); \
				continue; \
			fi; \
			contract_funcs=$$(grep -E "function[[:space:]]+[A-Za-z0-9_]+\(" "$$file" | grep -E "(public|external)" | sed -E "s/.*function[[:space:]]+([A-Za-z0-9_]+)\(.*/\1/" | grep -vE "^(initialize|selectors)$$"); \
			interface_funcs=$$(get_interface_funcs "$$interface_file"); \
			for func in $$contract_funcs; do \
				if ! echo "$$interface_funcs" | grep -q "^$$func$$"; then \
					echo "  ❌ Missing in $$interface_name: $$func"; \
					found_issues=$$((found_issues + 1)); \
				fi; \
			done; \
		fi; \
	done; \
	if [ $$found_issues -gt 0 ]; then \
		echo ""; \
		echo "  Found $$found_issues missing interface function(s)"; \
		exit 1; \
	else \
		echo ""; \
		echo "  ✅ All contracts match their interfaces"; \
	fi'

build-interfaces:
	@echo " Building and updating interfaces..."
	@bash -c '\
	get_interface_funcs() { \
		local interface_file=$$1; \
		local funcs=""; \
		local inherited_interfaces=$$(grep -E "interface[[:space:]]+[A-Za-z0-9_]+[[:space:]]+is[[:space:]]+" "$$interface_file" | sed -E "s/.*is[[:space:]]+(.+)[[:space:]]*\{.*/\1/" | tr "," "\n" | sed "s/^[[:space:]]*//;s/[[:space:]]*$$//"); \
		funcs=$$(grep -E "function[[:space:]]+[A-Za-z0-9_]+\(" "$$interface_file" | sed -E "s/.*function[[:space:]]+([A-Za-z0-9_]+)\(.*/\1/"); \
		for inherited in $$inherited_interfaces; do \
			inherited_file=$$(find src/interfaces -type f -name "$$inherited.sol" | head -n 1); \
			if [ -f "$$inherited_file" ]; then \
				inherited_funcs=$$(get_interface_funcs "$$inherited_file"); \
				funcs=$$(printf "%s\n%s" "$$funcs" "$$inherited_funcs"); \
			fi; \
		done; \
		echo "$$funcs" | grep -v "^$$" | sort -u; \
	}; \
	for file in $$(find src -name "*.sol" -type f ! -path "src/vendor/*" ! -path "src/interfaces/*" ! -path "src/adapters/parameters/*"); do \
		if grep -qE "contract[[:space:]]+[A-Za-z0-9_]+[[:space:]]+is[[:space:]]+I" "$$file"; then \
			contract_name=$$(basename "$$file" .sol); \
			interface_name=$$(grep -oE "is[[:space:]]+I[A-Za-z0-9_]+" "$$file" | head -n 1 | sed -E "s/is[[:space:]]+//"); \
			if [ -z "$$interface_name" ]; then \
				continue; \
			fi; \
			interface_file=$$(find src/interfaces -type f -name "$$interface_name.sol" | head -n 1); \
			if [ ! -f "$$interface_file" ]; then \
				echo "  ⚠️  Interface file not found: $$interface_name.sol - skipping"; \
				continue; \
			fi; \
			contract_funcs=$$(grep -E "function[[:space:]]+[A-Za-z0-9_]+\(" "$$file" | grep -E "(public|external)" | sed -E "s/.*function[[:space:]]+([A-Za-z0-9_]+)\(.*/\1/" | grep -vE "^(initialize|selectors)$$"); \
			interface_funcs=$$(get_interface_funcs "$$interface_file"); \
			missing_funcs=""; \
			for func in $$contract_funcs; do \
				if ! echo "$$interface_funcs" | grep -q "^$$func$$"; then \
					missing_funcs="$$missing_funcs $$func"; \
				fi; \
			done; \
			if [ -n "$$missing_funcs" ]; then \
				echo "Updating $$interface_name with missing functions from $$contract_name..."; \
				temp_file=$$(mktemp); \
				cp "$$interface_file" "$$temp_file"; \
				for func in $$missing_funcs; do \
					func_signature=$$(grep -E "function[[:space:]]+$$func\(" "$$file" | grep -E "(public|external)" | head -n 1 | sed -E "s/[[:space:]]*(public|external|internal|private)[[:space:]]*/ external /g; s/\{.*//; s/[[:space:]]+$$//" | sed "s/$$/;/"); \
					if [ -n "$$func_signature" ]; then \
						echo "  ➕ Adding: $$func"; \
						awk -v sig="    $$func_signature" "/^}[[:space:]]*$$/ {print sig; print; next} {print}" "$$temp_file" > "$$temp_file.new" && mv "$$temp_file.new" "$$temp_file"; \
					fi; \
				done; \
				mv "$$temp_file" "$$interface_file"; \
				echo "  ✅ Updated $$interface_name"; \
			fi; \
		fi; \
	done; \
	echo ""; \
	echo "  ✅ Interface building complete"'

# Color output
RED    = \033[0;31m
GREEN  = \033[0;32m  
YELLOW = \033[0;33m
BLUE   = \033[0;34m
NC     = \033[0m # No Color