#property copyright "Copyright 2024"
#property link      ""
#property version   "1.00"
#property script_show_inputs

void OnStart()
{
    string symbol = Symbol();  // Current chart symbol
    
    // Symbol properties
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    // Price data
    MqlTick lastTick;
    SymbolInfoTick(symbol, lastTick);
    
    // Indicator values
    int atrHandle = iATR(symbol, PERIOD_CURRENT, 14);
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);
    CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
    
    int rsiHandle = iRSI(symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
    double rsiBuffer[];
    ArraySetAsSeries(rsiBuffer, true);
    CopyBuffer(rsiHandle, 0, 0, 1, rsiBuffer);
    
    // Get MA values
    int fastMA = iMA(symbol, PERIOD_CURRENT, 21, 0, MODE_EMA, PRICE_CLOSE);
    int slowMA = iMA(symbol, PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE);
    double fastBuffer[], slowBuffer[];
    ArraySetAsSeries(fastBuffer, true);
    ArraySetAsSeries(slowBuffer, true);
    CopyBuffer(fastMA, 0, 0, 1, fastBuffer);
    CopyBuffer(slowMA, 0, 0, 1, slowBuffer);
    
    // Format output
    string data = "=== Symbol Data ===\n";
    data += "Symbol: " + symbol + "\n";
    data += "Digits: " + IntegerToString(digits) + "\n";
    data += "Point: " + DoubleToString(point, 8) + "\n";
    data += "Current Bid: " + DoubleToString(lastTick.bid, digits) + "\n";
    data += "Current Ask: " + DoubleToString(lastTick.ask, digits) + "\n";
    data += "ATR: " + DoubleToString(atrBuffer[0], digits) + "\n";
    data += "RSI: " + DoubleToString(rsiBuffer[0], 2) + "\n";
    data += "Fast EMA: " + DoubleToString(fastBuffer[0], digits) + "\n";
    data += "Slow EMA: " + DoubleToString(slowBuffer[0], digits) + "\n";
    data += "MA Difference: " + DoubleToString(MathAbs(fastBuffer[0] - slowBuffer[0]), digits);
    
    Alert(data);
    
    // Clean up
    IndicatorRelease(atrHandle);
    IndicatorRelease(rsiHandle);
    IndicatorRelease(fastMA);
    IndicatorRelease(slowMA);
}
