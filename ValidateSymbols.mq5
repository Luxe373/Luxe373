#property copyright "Copyright 2024"
#property link      ""
#property version   "1.00"
#property script_show_inputs

void OnStart()
{
    string symbols[] = {"NASUSD", "EURUSD", "BTCUSD", "US30"};
    
    Alert("=== Symbol Validation Starting ===");
    
    for(int i = 0; i < ArraySize(symbols); i++)
    {
        if(!SymbolSelect(symbols[i], true))
        {
            Alert("Failed to select symbol: " + symbols[i]);
            continue;
        }
        
        // Get symbol properties
        int digits = (int)SymbolInfoInteger(symbols[i], SYMBOL_DIGITS);
        double point = SymbolInfoDouble(symbols[i], SYMBOL_POINT);
        double tickSize = SymbolInfoDouble(symbols[i], SYMBOL_TRADE_TICK_SIZE);
        double tickValue = SymbolInfoDouble(symbols[i], SYMBOL_TRADE_TICK_VALUE);
        
        // Get current price data
        MqlTick lastTick;
        SymbolInfoTick(symbols[i], lastTick);
        
        // Calculate ATR
        int atrHandle = iATR(symbols[i], PERIOD_CURRENT, 14);
        double atrBuffer[];
        ArraySetAsSeries(atrBuffer, true);
        CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
        
        // Show results in Alert
        string message = "=== Symbol: " + symbols[i] + " ===\n";
        message += "Digits: " + IntegerToString(digits) + "\n";
        message += "Point: " + DoubleToString(point, 8) + "\n";
        message += "Tick Size: " + DoubleToString(tickSize, 8) + "\n";
        message += "Tick Value: " + DoubleToString(tickValue, 8) + "\n";
        message += "Current Bid: " + DoubleToString(lastTick.bid, digits) + "\n";
        message += "Current Ask: " + DoubleToString(lastTick.ask, digits) + "\n";
        message += "Current ATR: " + DoubleToString(atrBuffer[0], digits);
        
        Alert(message);
        
        // Clean up
        IndicatorRelease(atrHandle);
    }
    
    Alert("=== Symbol Validation Complete ===");
}
