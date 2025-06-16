//+------------------------------------------------------------------+
//|                 MomentumSignalsPro2.mq5                        |
//|  Fully Fixed & Optimized Indicator for Trend-Based Trade Signals |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "2.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 13
#property indicator_plots   13

// Plot index settings for Moving Averages
#property indicator_label1  "Fast MA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "Slow MA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrCrimson
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

// Plot index settings for Buy/Sell signals
#property indicator_label3  "Buy Signal"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrLime
#property indicator_width3  2

#property indicator_label4  "Sell Signal"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed
#property indicator_width4  2

// Plot index settings for RSI
#property indicator_label5  "RSI"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrGold
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

// Plot index settings for ATR
#property indicator_label6  "ATR"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrMagenta
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

// Plot index settings for ADX
#property indicator_label7  "ADX"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrOrange
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1

// Plot index settings for Support/Resistance
#property indicator_label8  "Support"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrLime
#property indicator_style8  STYLE_DOT
#property indicator_width8  1

#property indicator_label9  "Resistance"
#property indicator_type9   DRAW_LINE
#property indicator_color9  clrRed
#property indicator_style9  STYLE_DOT
#property indicator_width9  1

// Plot index settings for TP/SL levels
#property indicator_label10  "Buy TP"
#property indicator_type10   DRAW_LINE
#property indicator_color10  clrLime
#property indicator_style10  STYLE_DASHDOT
#property indicator_width10  2

#property indicator_label11  "Buy SL"
#property indicator_type11   DRAW_LINE
#property indicator_color11  clrRed
#property indicator_style11  STYLE_DASHDOT
#property indicator_width11  2

#property indicator_label12  "Sell TP"
#property indicator_type12   DRAW_LINE
#property indicator_color12  clrLime
#property indicator_style12  STYLE_DASHDOT
#property indicator_width12  2

#property indicator_label13  "Sell SL"
#property indicator_type13   DRAW_LINE
#property indicator_color13  clrRed
#property indicator_style13  STYLE_DASHDOT
#property indicator_width13  2

// ✅ Default User Inputs - Optimized for Long-Term Trends
input int RSI_Period = 14;
input int ATR_Period = 14;
input int ADX_Period = 14;
input double RiskRewardRatio = 1.5;  // Standard risk-reward ratio

// ✅ Support/Resistance Settings
input group "Support/Resistance"
input int SR_Period = 50;            // Period for S/R calculation
input int SR_Sensitivity = 2;        // Number of touches to confirm S/R
input double SR_Level_Distance = 0.3; // Minimum distance between S/R levels (%)
input double ATR_Zone_Multiplier = 1.5; // ATR multiplier for S/R zones
input double Min_Range_Multiplier = 1.0;  // Minimum range multiplier for ATR
input int ADX_Threshold = 25;        // ADX threshold for trend strength

// ✅ RSI Settings
input group "RSI Settings"
input int RSI_Overbought = 70;    // RSI overbought level
input int RSI_Oversold = 30;      // RSI oversold level
input int RSI_Warning = 60;       // RSI warning level for trend exhaustion

// ✅ Additional Filters
input bool Show_Debug_Info = true;
// input bool Use_SupportResistance_Filter = true; // Removed as PrintSignalAnalysis is removed

// ✅ Price Action Parameters

// ✅ Visualization
input group "Visualization"
input color Support_Color = clrGreen;         // Support line color
input color Resistance_Color = clrRed;        // Resistance line color
input color Zone_Color = clrYellow;           // Zone color (with transparency)
input int Line_Width = 2;                     // Line width
input ENUM_LINE_STYLE Line_Style = STYLE_SOLID; // Line style

// ✅ Dual MA System
input group "Dual MA System"
input int FastMA_Period = 21;       // Fast Moving Average Period
input int SlowMA_Period = 50;       // Slow Moving Average Period
input ENUM_MA_METHOD MA_Method = MODE_EMA;  // Moving Average Method

// ✅ Indicator Buffers
double BuyBuffer[];
double SellBuffer[];
double RSIBuffer[];
double ATRBuffer[];
double ADXBuffer[];
double SupportBuffer[];
double ResistanceBuffer[];
double BuyTP[];
double BuySL[];
double SellTP[];
double SellSL[];
double FastMABuffer[];
double SlowMABuffer[];

// ✅ Indicator Handles
int FastMA_Handle;
int SlowMA_Handle;
int RSI_Handle;
int ATR_Handle;
int ADX_Handle;

// Global Variables
int digits;  // Symbol digits
double point;  // Symbol point

//+------------------------------------------------------------------+
//| Get symbol-specific data                                           |
//+------------------------------------------------------------------+
bool GetSymbolData()
{
    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    if(digits == 0 || point == 0)
    {
        Print("❌ Error getting symbol data - digits: ", digits, " point: ", point);
        return false;
    }
    
    Print("✅ Symbol data loaded - digits: ", digits, " point: ", point);
    return true;
}

//+------------------------------------------------------------------+
//| Get MA periods based on timeframe                                  |
//+------------------------------------------------------------------+
int GetFastMAPeriod()
{
    switch(Period())
    {
        case PERIOD_M1:  return 21;
        case PERIOD_M5:  return 21;
        case PERIOD_M15: return 21;
        case PERIOD_H1:  return 21;
        case PERIOD_H4:  return 34;
        case PERIOD_D1:  return 50;
        case PERIOD_W1:  return 21;  // Optimized for weekly
        default:         return FastMA_Period;
    }
}

int GetSlowMAPeriod()
{
    switch(Period())
    {
        case PERIOD_M1:  return 50;
        case PERIOD_M5:  return 50;
        case PERIOD_M15: return 50;
        case PERIOD_H1:  return 50;
        case PERIOD_H4:  return 89;
        case PERIOD_D1:  return 200;
        case PERIOD_W1:  return 50;  // Optimized for weekly
        default:         return SlowMA_Period;
    }
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                           |
//+------------------------------------------------------------------+
int OnInit()
{
    // Get symbol data first
    if(!GetSymbolData())
    {
        Print("❌ Failed to get symbol data!");
        return INIT_FAILED;
    }
    
    // Get timeframe-specific MA periods
    int fastPeriod = GetFastMAPeriod();
    int slowPeriod = GetSlowMAPeriod();
    
    // Assign buffers
    ArraySetAsSeries(BuyBuffer, true);
    ArraySetAsSeries(SellBuffer, true);
    ArraySetAsSeries(BuyTP, true);
    ArraySetAsSeries(BuySL, true);
    ArraySetAsSeries(SellTP, true);
    ArraySetAsSeries(SellSL, true);
    ArraySetAsSeries(FastMABuffer, true);
    ArraySetAsSeries(SlowMABuffer, true);
    ArraySetAsSeries(RSIBuffer, true);
    ArraySetAsSeries(ATRBuffer, true);
    ArraySetAsSeries(ADXBuffer, true);
    
    SetIndexBuffer(0, FastMABuffer, INDICATOR_DATA);
    SetIndexBuffer(1, SlowMABuffer, INDICATOR_DATA);
    SetIndexBuffer(2, BuyBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, SellBuffer, INDICATOR_DATA);
    SetIndexBuffer(4, RSIBuffer, INDICATOR_DATA);
    SetIndexBuffer(5, ATRBuffer, INDICATOR_DATA);
    SetIndexBuffer(6, ADXBuffer, INDICATOR_DATA);
    SetIndexBuffer(7, SupportBuffer, INDICATOR_DATA);
    SetIndexBuffer(8, ResistanceBuffer, INDICATOR_DATA);
    SetIndexBuffer(9, BuyTP, INDICATOR_DATA);
    SetIndexBuffer(10, BuySL, INDICATOR_DATA);
    SetIndexBuffer(11, SellTP, INDICATOR_DATA);
    SetIndexBuffer(12, SellSL, INDICATOR_DATA);
    
    // Set arrow codes for buy/sell signals
    PlotIndexSetInteger(2, PLOT_ARROW, 233);  // Up arrow for buy
    PlotIndexSetInteger(3, PLOT_ARROW, 234);  // Down arrow for sell
    
    // Initialize buffers with EMPTY_VALUE
    ArrayInitialize(BuyBuffer, EMPTY_VALUE);
    ArrayInitialize(SellBuffer, EMPTY_VALUE);
    ArrayInitialize(BuyTP, EMPTY_VALUE);
    ArrayInitialize(BuySL, EMPTY_VALUE);
    ArrayInitialize(SellTP, EMPTY_VALUE);
    ArrayInitialize(SellSL, EMPTY_VALUE);
    ArrayInitialize(FastMABuffer, EMPTY_VALUE);
    ArrayInitialize(SlowMABuffer, EMPTY_VALUE);
    ArrayInitialize(RSIBuffer, EMPTY_VALUE);
    ArrayInitialize(ATRBuffer, EMPTY_VALUE);
    ArrayInitialize(ADXBuffer, EMPTY_VALUE);
    
    // Create indicator handles with timeframe-specific periods
    FastMA_Handle = iMA(_Symbol, PERIOD_CURRENT, fastPeriod, 0, MA_Method, PRICE_CLOSE);
    SlowMA_Handle = iMA(_Symbol, PERIOD_CURRENT, slowPeriod, 0, MA_Method, PRICE_CLOSE);
    RSI_Handle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
    ATR_Handle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
    ADX_Handle = iADX(_Symbol, PERIOD_CURRENT, ADX_Period);
    
    // Validate handles
    if(FastMA_Handle == INVALID_HANDLE || SlowMA_Handle == INVALID_HANDLE ||
       RSI_Handle == INVALID_HANDLE || ATR_Handle == INVALID_HANDLE || 
       ADX_Handle == INVALID_HANDLE)
    {
        Print("❌ Error creating indicator handles!");
        return INIT_FAILED;
    }
    
    // Log the initialization
    Print("✅ Indicator initialized for ", _Symbol, " ", EnumToString(Period()),
          " - Fast MA: ", fastPeriod,
          " Slow MA: ", slowPeriod);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(FastMA_Handle);
    IndicatorRelease(SlowMA_Handle);
    IndicatorRelease(RSI_Handle);
    IndicatorRelease(ATR_Handle);
    IndicatorRelease(ADX_Handle);
    
    // Clean up objects
    ObjectDelete(0, "BuyTP");
    ObjectDelete(0, "BuySL");
    ObjectDelete(0, "SellTP");
    ObjectDelete(0, "SellSL");
    ObjectDelete(0, "Support_Line");
    ObjectDelete(0, "Resistance_Line");
    ObjectDelete(0, "Support_Zone");
    ObjectDelete(0, "Resistance_Zone");
    
    Comment(""); // Clear debug info from chart
}

//+------------------------------------------------------------------+
//| Modified support/resistance calculation                          |
//+------------------------------------------------------------------+
void CalculateSupportResistance(const int index, const double &high[], const double &low[], const double &close[])
{
    // Ensure ATRBuffer is valid before use for srZone calculation
    if(ATRBuffer[index] == EMPTY_VALUE || ATRBuffer[index] == 0)
    {
        // Not enough data or invalid ATR, cannot calculate S/R reliably
        SupportBuffer[index] = EMPTY_VALUE;
        ResistanceBuffer[index] = EMPTY_VALUE;
        return;
    }

    double currentPrice = close[index];
    double minDistance = currentPrice * SR_Level_Distance / 100.0;
    double srZone = ATRBuffer[index] * ATR_Zone_Multiplier;
    
    double potentialSupport = low[index];
    double potentialResistance = high[index];
    int touchCountSupport = 0;
    int touchCountResistance = 0;
    
    // Look back for better levels
    for(int i = 1; i < SR_Period && (index - i) >= 0; i++)
    {
        int back = index - i;
        
        // Support level logic with minimum distance check
        if(MathAbs(low[back] - potentialSupport) > minDistance)
        {
            if(low[back] < potentialSupport && touchCountSupport < SR_Sensitivity)
            {
                potentialSupport = low[back];
                touchCountSupport++;
            }
        }
        
        // Resistance level logic with minimum distance check
        if(MathAbs(high[back] - potentialResistance) > minDistance)
        {
            if(high[back] > potentialResistance && touchCountResistance < SR_Sensitivity)
            {
                potentialResistance = high[back];
                touchCountResistance++;
            }
        }
    }
    
    // Only update buffers if we have enough touches and valid range
    if(touchCountSupport >= SR_Sensitivity && touchCountResistance >= SR_Sensitivity)
    {
        SupportBuffer[index] = potentialSupport;
        ResistanceBuffer[index] = potentialResistance;
    }
}

//+------------------------------------------------------------------+
//| Draw support and resistance lines with zones                      |
//+------------------------------------------------------------------+
void DrawSupportResistanceLines(const int index, const datetime &time[])
{
    if(index == 0) // Only draw for the current bar
    {
        string supportName = "Support_Line";
        string resistanceName = "Resistance_Line";
        string supportZoneName = "Support_Zone";
        string resistanceZoneName = "Resistance_Zone";
        
        // Calculate zone boundaries
        double srZone = ATRBuffer[index] * ATR_Zone_Multiplier;
        double supportZoneUpper = SupportBuffer[index] + srZone;
        double supportZoneLower = SupportBuffer[index] - srZone;
        double resistanceZoneUpper = ResistanceBuffer[index] + srZone;
        double resistanceZoneLower = ResistanceBuffer[index] - srZone;
        
        // Delete previous objects
        ObjectDelete(0, supportName);
        ObjectDelete(0, resistanceName);
        ObjectDelete(0, supportZoneName);
        ObjectDelete(0, resistanceZoneName);
        
        // Create semi-transparent color for zones
        color zoneColorWithAlpha = (color)(Zone_Color & 0x3FFFFFFF); // 75% transparency
        
        // Draw support line
        if(SupportBuffer[index] != EMPTY_VALUE && SupportBuffer[index] != 0)
        {
            ObjectCreate(0, supportName, OBJ_TREND, 0, time[index], SupportBuffer[index], 
                        time[index] + PeriodSeconds()*20, SupportBuffer[index]);
            ObjectSetInteger(0, supportName, OBJPROP_COLOR, Support_Color);
            ObjectSetInteger(0, supportName, OBJPROP_WIDTH, Line_Width);
            ObjectSetInteger(0, supportName, OBJPROP_STYLE, Line_Style);
            ObjectSetInteger(0, supportName, OBJPROP_RAY_RIGHT, true);
            
            // Draw support zone
            ObjectCreate(0, supportZoneName, OBJ_RECTANGLE, 0, 
                        time[index], supportZoneUpper,
                        time[index] + PeriodSeconds()*20, supportZoneLower);
            ObjectSetInteger(0, supportZoneName, OBJPROP_COLOR, Zone_Color);
            ObjectSetInteger(0, supportZoneName, OBJPROP_BACK, true);
            ObjectSetInteger(0, supportZoneName, OBJPROP_FILL, true);
            ObjectSetInteger(0, supportZoneName, OBJPROP_BGCOLOR, zoneColorWithAlpha);
        }
        
        // Draw resistance line
        if(ResistanceBuffer[index] != EMPTY_VALUE && ResistanceBuffer[index] != 0)
        {
            ObjectCreate(0, resistanceName, OBJ_TREND, 0, time[index], ResistanceBuffer[index],
                        time[index] + PeriodSeconds()*20, ResistanceBuffer[index]);
            ObjectSetInteger(0, resistanceName, OBJPROP_COLOR, Resistance_Color);
            ObjectSetInteger(0, resistanceName, OBJPROP_WIDTH, Line_Width);
            ObjectSetInteger(0, resistanceName, OBJPROP_STYLE, Line_Style);
            ObjectSetInteger(0, resistanceName, OBJPROP_RAY_RIGHT, true);
            
            // Draw resistance zone
            ObjectCreate(0, resistanceZoneName, OBJ_RECTANGLE, 0,
                        time[index], resistanceZoneUpper,
                        time[index] + PeriodSeconds()*20, resistanceZoneLower);
            ObjectSetInteger(0, resistanceZoneName, OBJPROP_COLOR, Zone_Color);
            ObjectSetInteger(0, resistanceZoneName, OBJPROP_BACK, true);
            ObjectSetInteger(0, resistanceZoneName, OBJPROP_FILL, true);
            ObjectSetInteger(0, resistanceZoneName, OBJPROP_BGCOLOR, zoneColorWithAlpha);
        }
    }
}

//+------------------------------------------------------------------+
//| Enhanced Market Commentary                                         |
//+------------------------------------------------------------------+
string GetMarketAnalysis(const int index,
                        const double &high[],
                        const double &low[])
{
    if(index < 0 || index >= ArraySize(FastMABuffer) ||
       index >= ArraySize(high) || index >= ArraySize(low))
    {
        Print("Invalid index or arrays in GetMarketAnalysis");
        return "";
    }
    
    string analysis = "=== Market Analysis ===\n";
    
    // Signal Status
    if(BuyBuffer[index] != EMPTY_VALUE)
    {
        analysis += "\n⚡ BUY SIGNAL ACTIVE\n";
        analysis += "Entry Price: " + DoubleToString(BuyBuffer[index], digits) + "\n";
        analysis += "Take Profit: " + DoubleToString(BuyTP[index], digits) + "\n";
        analysis += "Stop Loss: " + DoubleToString(BuySL[index], digits) + "\n";
    }
    else if(SellBuffer[index] != EMPTY_VALUE)
    {
        analysis += "\n⚡ SELL SIGNAL ACTIVE\n";
        analysis += "Entry Price: " + DoubleToString(SellBuffer[index], digits) + "\n";
        analysis += "Take Profit: " + DoubleToString(SellTP[index], digits) + "\n";
        analysis += "Stop Loss: " + DoubleToString(SellSL[index], digits) + "\n";
    }
    
    // Trend Status
    analysis += "\n⚡ TREND STATUS:\n";
    if(FastMABuffer[index] > SlowMABuffer[index])
    {
        double trendStrength = NormalizeDouble(MathAbs(FastMABuffer[index] - SlowMABuffer[index]), digits);
        analysis += "↗ Uptrend - Fast EMA above Slow EMA\n";
        analysis += "Strength: " + DoubleToString(trendStrength, digits) + " points\n";
    }
    else if(FastMABuffer[index] < SlowMABuffer[index])
    {
        double trendStrength = NormalizeDouble(MathAbs(SlowMABuffer[index] - FastMABuffer[index]), digits);
        analysis += "↘ Downtrend - Fast EMA below Slow EMA\n";
        analysis += "Strength: " + DoubleToString(trendStrength, digits) + " points\n";
    }
    
    // RSI Analysis
    analysis += "\n⚡ RSI ANALYSIS:\n";
    if(RSIBuffer[index] > RSI_Overbought)
        analysis += "⚠ Approaching overbought - Exercise caution\n";
    else if(RSIBuffer[index] < RSI_Oversold)
        analysis += "⚠ Approaching oversold - Exercise caution\n";
    
    // Trend Strength
    analysis += "\n⚡ TREND STRENGTH:\n";
    if(ADXBuffer[index] >= ADX_Threshold)
    {
        analysis += "✅ Strong trend - Consider trending strategies\n";
    }
    else
    {
        analysis += "⚠ Weak trend - Consider ranging market strategies\n";
    }
    
    // Range Analysis
    analysis += "\n⚡ RANGE ANALYSIS:\n";
    double currentRange = NormalizeDouble(MathAbs(high[index] - low[index]), digits);
    double minRange = NormalizeDouble(ATRBuffer[index] * Min_Range_Multiplier, digits);
    analysis += "Current Range: " + DoubleToString(currentRange, digits) + "\n";
    analysis += "Minimum Required: " + DoubleToString(minRange, digits);
    
    return analysis;
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                                |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    // Validate data
    if(rates_total < 2)
    {
        Print("❌ Not enough data to calculate for ", _Symbol);
        return 0;
    }
    
    // Set arrays as series
    ArraySetAsSeries(time, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(FastMABuffer, true);
    ArraySetAsSeries(SlowMABuffer, true);
    ArraySetAsSeries(RSIBuffer, true);
    ArraySetAsSeries(ATRBuffer, true);
    ArraySetAsSeries(ADXBuffer, true);
    
    // Calculate start position
    int start = prev_calculated == 0 ? rates_total - 1 : prev_calculated - 1;
    
    // Copy indicator data with retry
    for(int attempts = 0; attempts < 3; attempts++)
    {
        if(CopyBuffer(FastMA_Handle, 0, 0, rates_total, FastMABuffer) <= 0 ||
           CopyBuffer(SlowMA_Handle, 0, 0, rates_total, SlowMABuffer) <= 0 ||
           CopyBuffer(RSI_Handle, 0, 0, rates_total, RSIBuffer) <= 0 ||
           CopyBuffer(ATR_Handle, 0, 0, rates_total, ATRBuffer) <= 0 ||
           CopyBuffer(ADX_Handle, 0, 0, rates_total, ADXBuffer) <= 0)
        {
            if(attempts == 2)
            {
                Print("❌ Failed to copy indicator data for ", _Symbol, " after ", attempts + 1, " attempts");
                return 0;
            }
            Sleep(100); // Wait before retry
            continue;
        }
        break;
    }
    
    // Get current market data
    MqlTick last_tick;
    if(!SymbolInfoTick(_Symbol, last_tick))
    {
        Print("Error getting last tick: ", GetLastError());
        return 0;
    }
    
    // Main calculation loop
    for(int i = start; i >= 0 && !IsStopped(); i--)
    {
        // Reset signal buffers
        BuyBuffer[i] = EMPTY_VALUE;
        SellBuffer[i] = EMPTY_VALUE;
        BuyTP[i] = EMPTY_VALUE;
        BuySL[i] = EMPTY_VALUE;
        SellTP[i] = EMPTY_VALUE;
        SellSL[i] = EMPTY_VALUE;
        
        // Calculate Support and Resistance
        CalculateSupportResistance(i, high, low, close);

        // Calculate signals
        if(IsBuySignal(i, high, low, close))
        {
            double atr = ATRBuffer[i];
            if(atr > 0)  // Validate ATR
            {
                double currentPrice = (i == 0) ? last_tick.ask : close[i];
                BuyBuffer[i] = NormalizeDouble(currentPrice, digits);
                BuyTP[i] = NormalizeDouble(currentPrice + (atr * RiskRewardRatio), digits);
                BuySL[i] = NormalizeDouble(currentPrice - atr, digits);
                
                // Draw labels for current bar
                if(i == 0)
                {
                    ObjectDelete(0, "BuyTP"); // Add delete before create
                    ObjectCreate(0, "BuyTP", OBJ_TEXT, 0, time[i], BuyTP[i]);
                    ObjectSetString(0, "BuyTP", OBJPROP_TEXT, "TP " + DoubleToString(BuyTP[i], digits));
                    ObjectSetInteger(0, "BuyTP", OBJPROP_COLOR, clrLime);
                    
                    ObjectDelete(0, "BuySL"); // Add delete before create
                    ObjectCreate(0, "BuySL", OBJ_TEXT, 0, time[i], BuySL[i]);
                    ObjectSetString(0, "BuySL", OBJPROP_TEXT, "SL " + DoubleToString(BuySL[i], digits));
                    ObjectSetInteger(0, "BuySL", OBJPROP_COLOR, clrRed);
                }
            }
        }
        else if(IsSellSignal(i, high, low, close))
        {
            double atr = ATRBuffer[i];
            if(atr > 0)  // Validate ATR
            {
                double currentPrice = (i == 0) ? last_tick.bid : close[i];
                SellBuffer[i] = NormalizeDouble(currentPrice, digits);
                SellTP[i] = NormalizeDouble(currentPrice - (atr * RiskRewardRatio), digits);
                SellSL[i] = NormalizeDouble(currentPrice + atr, digits);
                
                // Draw labels for current bar
                if(i == 0)
                {
                    ObjectDelete(0, "SellTP"); // Add delete before create
                    ObjectCreate(0, "SellTP", OBJ_TEXT, 0, time[i], SellTP[i]);
                    ObjectSetString(0, "SellTP", OBJPROP_TEXT, "TP " + DoubleToString(SellTP[i], digits));
                    ObjectSetInteger(0, "SellTP", OBJPROP_COLOR, clrLime);
                    
                    ObjectDelete(0, "SellSL"); // Add delete before create
                    ObjectCreate(0, "SellSL", OBJ_TEXT, 0, time[i], SellSL[i]);
                    ObjectSetString(0, "SellSL", OBJPROP_TEXT, "SL " + DoubleToString(SellSL[i], digits));
                    ObjectSetInteger(0, "SellSL", OBJPROP_COLOR, clrRed);
                }
            }
        }
        
        // Draw Support/Resistance lines for the current bar
        if(i == 0)
        {
            DrawSupportResistanceLines(i, time);
        }

        // Update market analysis for current bar
        if(i == 0)
        {
        string analysis = GetMarketAnalysis(i, high, low); // GetMarketAnalysis is kept for chart comments
            if(analysis != "")
            {
                Comment(analysis);
            }
        }
    }
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Get ATR multiplier based on timeframe                             |
//+------------------------------------------------------------------+
double GetTimeframeATRMultiplier()
{
    ENUM_TIMEFRAMES tf = Period();
    
    switch(tf)
    {
        case PERIOD_M1:  return 1.5;   // More aggressive for scalping
        case PERIOD_M5:  return 1.8;
        case PERIOD_M15: return 2.0;
        case PERIOD_H1:  return 2.2;
        case PERIOD_H4:  return 2.5;
        case PERIOD_D1:  return 3.0;    // More conservative for higher timeframes
        case PERIOD_W1:  return 3.5;
        default:         return 2.0;    // Default multiplier
    }
}

//+------------------------------------------------------------------+
//| Get RSI thresholds based on timeframe                             |
//+------------------------------------------------------------------+
void GetRSIThresholds(double &buyThreshold, double &sellThreshold)
{
    switch(Period())
    {
        case PERIOD_W1:  // Weekly
            buyThreshold = 40;
            sellThreshold = 70;
            break;
        case PERIOD_D1:  // Daily
            buyThreshold = 45;
            sellThreshold = 65;
            break;
        default:        // All other timeframes
            buyThreshold = 48;
            sellThreshold = 52;
            break;
    }
}

//+------------------------------------------------------------------+
//| Calculate Signals                                                 |
//+------------------------------------------------------------------+
bool IsBuySignal(const int index,
                 const double &high[],
                 const double &low[],
                 const double &close[])
{
    if(index < 1) return false;

    // Ensure ATRBuffer is valid before use
    if(ATRBuffer[index] == EMPTY_VALUE || ATRBuffer[index] == 0) return false;
    
    // Get timeframe-specific ATR multiplier
    double atrMultiplier = GetTimeframeATRMultiplier();
    
    // Trend validation
    bool strongTrend = ADXBuffer[index] >= ADX_Threshold;
    bool maSignal = FastMABuffer[index] > SlowMABuffer[index] && 
                    FastMABuffer[index-1] <= SlowMABuffer[index-1];
    
    // RSI conditions
    bool rsiValid = RSIBuffer[index] < RSI_Warning;
    
    // Minimum price movement validation
    double minMove = ATRBuffer[index] * Min_Range_Multiplier;
    bool validRange = MathAbs(high[index] - low[index]) >= minMove;
    
    // Price action validation
    bool priceAboveMA = close[index] > FastMABuffer[index];
    
    return strongTrend && maSignal && rsiValid && validRange && priceAboveMA;
}

//+------------------------------------------------------------------+
//| Calculate sell signals based on timeframe                          |
//+------------------------------------------------------------------+
bool IsSellSignal(const int index,
                  const double &high[],
                  const double &low[],
                  const double &close[])
{
    if(index < 1) return false;
    
    // Get timeframe-specific ATR multiplier
    double atrMultiplier = GetTimeframeATRMultiplier();
    
    // Trend validation
    bool strongTrend = ADXBuffer[index] >= ADX_Threshold;
    bool maSignal = FastMABuffer[index] < SlowMABuffer[index] && 
                    FastMABuffer[index-1] >= SlowMABuffer[index-1];
    
    // RSI conditions
    bool rsiValid = RSIBuffer[index] > (100 - RSI_Warning);
    
    // Minimum price movement validation
    double minMove = ATRBuffer[index] * Min_Range_Multiplier;
    bool validRange = MathAbs(high[index] - low[index]) >= minMove;
    
    // Price action validation
    bool priceBelowMA = close[index] < FastMABuffer[index];
    
    return strongTrend && maSignal && rsiValid && validRange && priceBelowMA;
}
