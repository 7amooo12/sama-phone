# Product Movement Profit Calculation Fix

## Problem Description
The "Total Profit" (إجمالي الربح) field in the Product Movement Report was showing zero instead of the correct calculated value.

## Root Cause Analysis
The issue was in the `ProductMovementService.dart` file where the profit calculation logic had the following problems:

1. **Limited Cost Sources**: Only used `product.sellingPrice` and `product.purchasePrice`
2. **No Fallback Logic**: When purchase price was null or zero, profit calculation failed
3. **Ignored Real Sales Data**: Didn't use actual unit prices from sales transactions
4. **Missing Manufacturing Cost**: Didn't consider `manufacturingCost` field

## Solution Implemented

### 1. Enhanced ProductMovementProductModel
Added new cost fields to support multiple cost sources:
```dart
class ProductMovementProductModel {
  final double? purchasePrice;
  final double? sellingPrice;
  final double? manufacturingCost;  // NEW
  final double? costPrice;          // NEW
  // ... other fields
}
```

### 2. Comprehensive Profit Calculation Method
Created `_calculateProfitMetrics()` method with intelligent cost determination:

#### Cost Price Priority Order:
1. Direct cost price from product data
2. Purchase price from product data  
3. Manufacturing cost from product data
4. Estimated cost from selling price (70% rule)
5. Estimated cost from average sale price (70% rule)

#### Selling Price Priority Order:
1. Average price from actual sales data (most accurate)
2. Selling price from product data
3. Estimated selling price from purchase price (130% markup)

### 3. Enhanced Profit Calculation Logic
```dart
// Calculate profit per unit
profitPerUnit = sellingPrice - costPrice;

// Calculate total profit using actual sales data
totalProfit = salesData.fold<double>(0.0, (sum, sale) {
  final saleProfit = (sale.unitPrice - costPrice) * sale.quantity;
  return sum + saleProfit;
});

// Calculate profit margin
profitMargin = (profitPerUnit / sellingPrice) * 100;
```

### 4. Improved Currency Formatting
Updated currency formatting to properly display Egyptian Pounds:
```dart
final NumberFormat _currencyFormat = NumberFormat.currency(
  symbol: 'ج.م ',
  decimalDigits: 2,
  locale: 'ar_EG',
);
```

## Testing Instructions

### Test Case 1: Product with Purchase Price
- Product: "منتج أ"
- Purchase Price: 100 ج.م
- Selling Price: 150 ج.م
- Expected Profit per Unit: 50 ج.م
- Expected Profit Margin: 33.33%

### Test Case 2: Product with Manufacturing Cost
- Product: "منتج ب"
- Manufacturing Cost: 80 ج.م
- Average Sale Price: 120 ج.م
- Expected Profit per Unit: 40 ج.م
- Expected Profit Margin: 33.33%

### Test Case 3: Product with Estimated Cost
- Product: "منتج ج"
- No cost data available
- Average Sale Price: 200 ج.م
- Estimated Cost (70%): 140 ج.م
- Expected Profit per Unit: 60 ج.م
- Expected Profit Margin: 30%

## Expected Results

After implementing these fixes:

1. ✅ **Profit Per Unit**: Shows correct calculated value instead of zero
2. ✅ **Total Profit**: Displays accurate total profit from all sales
3. ✅ **Profit Margin**: Shows correct percentage margin
4. ✅ **Currency Formatting**: Proper Egyptian Pounds display
5. ✅ **Fallback Logic**: Works even when cost data is missing
6. ✅ **Real Sales Data**: Uses actual transaction prices for accuracy

## Debug Logging

The enhanced calculation includes comprehensive logging:
```
🧮 Calculating profit for product: [Product Name]
📊 Available data:
   - Cost Price: [value]
   - Purchase Price: [value]
   - Manufacturing Cost: [value]
   - Selling Price: [value]
   - Average Sale Price: [value]
   - Total Sales: [count]

💰 Determined prices:
   - Cost Price: [final cost]
   - Selling Price: [final selling price]

✅ Profit calculation successful:
   - Profit per unit: [value]
   - Total profit: [value]
   - Profit margin: [percentage]%
```

## Files Modified

1. `lib/services/product_movement_service.dart`
   - Enhanced profit calculation logic
   - Added comprehensive cost determination methods
   - Improved error handling and logging

2. `lib/models/product_movement_model.dart`
   - Added manufacturingCost and costPrice fields
   - Updated fromJson and toJson methods

3. `lib/screens/shared/advanced_product_movement_screen.dart`
   - Enhanced currency formatting for Egyptian Pounds

4. `lib/screens/shared/product_movement_screen.dart`
   - Updated currency formatting

## Verification Steps

1. Navigate to Admin Dashboard → Product Movement Report
2. Search for any product with sales data
3. Verify "Total Profit" field shows calculated value (not zero)
4. Check that currency is displayed as "ج.م" format
5. Verify profit calculation works for different product types
6. Check console logs for detailed calculation breakdown
