# Dual Wallet System Testing Guide

## Overview

This guide explains how to test the dual wallet system implementation using the provided SQL test scripts. The dual wallet system ensures proper money transfer between client personal wallets and company electronic wallets when electronic payments are approved.

## Test Scripts Available

### 1. `VERIFY_DUAL_WALLET_SYSTEM.sql` ⚡ (Quick Check)
**Purpose**: Quick verification that all required components are installed
**Use When**: 
- After running the migration script
- To check system status
- Before running comprehensive tests

**What it checks**:
- ✅ Required functions exist
- ✅ Database triggers are active
- ✅ All tables are present
- ✅ Wallet synchronization status
- ✅ Current system data summary

### 2. `TEST_DUAL_WALLET_ROBUST.sql` 🛡️ (Recommended)
**Purpose**: Comprehensive testing with robust error handling
**Use When**: 
- Primary testing of the dual wallet system
- Can be run multiple times safely
- Production-ready testing

**Features**:
- ✅ Handles all edge cases
- ✅ Proper conflict resolution
- ✅ Detailed test results
- ✅ Automatic cleanup
- ✅ Can run repeatedly without issues

### 3. `TEST_DUAL_WALLET_ISOLATED.sql` 🔬 (Detailed)
**Purpose**: Isolated testing with detailed step-by-step validation
**Use When**: 
- Debugging specific issues
- Need detailed transaction analysis
- Development testing

### 4. `TEST_DUAL_WALLET_SIMPLE.sql` 🎯 (Basic)
**Purpose**: Simple test using existing data
**Use When**: 
- Quick functional test
- Working with existing user data
- Minimal setup required

## Testing Workflow

### Step 1: Install the Dual Wallet System
```sql
-- Run the migration script first
\i FIX_ELECTRONIC_PAYMENT_APPROVAL_WORKFLOW.sql
```

### Step 2: Verify Installation
```sql
-- Quick verification
\i VERIFY_DUAL_WALLET_SYSTEM.sql
```

**Expected Output**:
```
=== DUAL WALLET SYSTEM VERIFICATION ===
✅ process_dual_wallet_transaction function exists
✅ update_client_wallet_balance function exists
✅ update_electronic_wallet_balance function exists
✅ handle_electronic_payment_approval_v3 function exists
✅ Electronic payment approval trigger exists
✅ All required tables exist
```

### Step 3: Run Comprehensive Tests
```sql
-- Recommended comprehensive test
\i TEST_DUAL_WALLET_ROBUST.sql
```

**Expected Output**:
```
=== ROBUST DUAL WALLET SYSTEM TEST ===
✅ Test data setup completed
✅ Required function exists
✅ Direct function call succeeded
✅ Insufficient balance correctly rejected
✅ Trigger approval succeeded
✅ All balances correct
✅ Money conservation verified

🎉 ALL TESTS PASSED - DUAL WALLET SYSTEM WORKING CORRECTLY
```

## Test Scenarios Covered

### 1. **Function Existence Tests**
- Verifies all required database functions are installed
- Checks trigger configuration

### 2. **Balance Validation Tests**
- ✅ **Sufficient Balance**: Client has enough money for payment
- ❌ **Insufficient Balance**: Client doesn't have enough money (should be rejected)

### 3. **Atomic Transaction Tests**
- **Client Wallet Debit**: Money deducted from client personal wallet
- **Electronic Wallet Credit**: Money added to company electronic wallet
- **Transaction Linking**: Both transactions reference the same payment ID

### 4. **Money Conservation Tests**
- **Before Transaction**: Total system money = Client Balance + Electronic Balance
- **After Transaction**: Total system money remains exactly the same
- **No Money Creation**: Ensures money is transferred, not created

### 5. **Trigger Integration Tests**
- **Payment Approval**: Tests the automatic trigger when payment status changes to 'approved'
- **Error Handling**: Verifies proper error messages in Arabic

### 6. **Data Integrity Tests**
- **Transaction Records**: Both wallet transaction tables have proper records
- **Reference Linking**: Transactions are properly linked via payment ID
- **Audit Trail**: Complete transaction history is maintained

## Understanding Test Results

### ✅ **PASS Results**
```
✅ Direct function call succeeded
✅ All balances correct
✅ Money conservation verified
```
**Meaning**: The dual wallet system is working correctly

### ❌ **FAIL Results**
```
❌ Client balance incorrect - Expected: 850.00, Got: 1000.00
❌ Money conservation failed - money was created or destroyed
```
**Meaning**: There's an issue with the implementation that needs fixing

### 🎉 **All Tests Passed**
```
🎉 ALL TESTS PASSED - DUAL WALLET SYSTEM WORKING CORRECTLY
Tests Passed: 6, Tests Failed: 0, Success Rate: 100%
```
**Meaning**: The system is ready for production use

## Troubleshooting Common Issues

### Issue 1: Functions Missing
**Error**: `❌ process_dual_wallet_transaction function MISSING`
**Solution**: Run the migration script `FIX_ELECTRONIC_PAYMENT_APPROVAL_WORKFLOW.sql`

### Issue 2: Primary Key Violations
**Error**: `duplicate key value violates unique constraint`
**Solution**: Use `TEST_DUAL_WALLET_ROBUST.sql` which handles conflicts properly

### Issue 3: Balance Not Updated
**Error**: `❌ Client balance incorrect`
**Possible Causes**:
- Trigger not working
- Function has errors
- Transaction rollback occurred

**Debug Steps**:
1. Check trigger exists: `VERIFY_DUAL_WALLET_SYSTEM.sql`
2. Check function logs in PostgreSQL
3. Run isolated test for detailed analysis

### Issue 4: Money Conservation Failed
**Error**: `❌ Money conservation failed`
**Meaning**: Money was created or destroyed instead of transferred
**Solution**: Check the dual wallet transaction function implementation

## Production Testing Checklist

Before deploying to production, ensure:

- [ ] ✅ All verification checks pass
- [ ] ✅ Comprehensive tests pass with 100% success rate
- [ ] ✅ Money conservation is verified
- [ ] ✅ Arabic error messages work correctly
- [ ] ✅ UI balance validation works
- [ ] ✅ Transaction history shows linked records
- [ ] ✅ System can handle insufficient balance scenarios
- [ ] ✅ Approval workflow updates both wallets atomically

## Manual UI Testing

After SQL tests pass, test the UI workflow:

1. **Create Electronic Wallet** (Accountant Dashboard)
2. **Create Client Payment** (Client Interface)
3. **Verify Balance Display** (Approval Dialog)
4. **Approve Payment** (Accountant)
5. **Check Balance Updates** (Both Wallets)
6. **Verify Transaction History** (Both Transaction Lists)

## Performance Considerations

- Tests create and clean up temporary data
- Robust test can be run multiple times safely
- Each test run uses unique identifiers
- Cleanup is automatic and thorough

## Support

If tests fail or you encounter issues:

1. **Check Prerequisites**: Ensure migration script was run successfully
2. **Review Error Messages**: Look for specific error details in test output
3. **Run Verification**: Use `VERIFY_DUAL_WALLET_SYSTEM.sql` to check system status
4. **Check Logs**: Review PostgreSQL logs for detailed error information
5. **Incremental Testing**: Start with simple tests and progress to comprehensive ones

The dual wallet system is designed to be robust, secure, and maintainable. These tests ensure it works correctly before production deployment.
