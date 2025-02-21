//+------------------------------------------------------------------+
//|                 MomentumSignalsPro1.mq5                        |
//|  Fully Fixed & Optimized Indicator for Trend-Based Trade Signals |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "2.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 15
#property indicator_plots   15

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

#property indicator_label14  "Fast MA Buffer"
#property indicator_type14   DRAW_LINE
#property indicator_color14  clrDodgerBlue
#property indicator_style14  STYLE_SOLID
#property indicator_width14  1

#property indicator_label15  "Slow MA Buffer"
#property indicator_type15   DRAW_LINE
#property indicator_color15  clrCrimson
#property indicator_style15  STYLE_SOLID
#property indicator_width15  1

// ✅ Default User Inputs - Optimized for Long-Term Trends
input int EMA_Fast_Period = 50;      // Fast EMA period
input int EMA_Slow_Period = 200;     // Slow EMA period
input int RSI_Period = 14;
input int ATR_Period = 14;
input int ADX_Period = 14;
input double RiskRewardRatio = 1.5;  // Standard risk-reward ratio

// ✅ Risk Management Settings
input group "Risk Management"
input double M1_ATR_Multiplier = 1.0;   // M1 ATR multiplier for SL
input double M5_ATR_Multiplier = 1.2;   // M5 ATR multiplier for SL
input double M15_ATR_Multiplier = 1.5;  // M15 ATR multiplier for SL
input double H1_ATR_Multiplier = 1.8;   // H1 ATR multiplier for SL
input double H4_ATR_Multiplier = 2.0;   // H4 ATR multiplier for SL
input double D1_ATR_Multiplier = 2.0;   // D1 ATR multiplier for SL
input double W1_ATR_Multiplier = 3.0;   // W1 ATR multiplier for SL

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
input bool Use_Engulfing_Filter = true;
input bool Use_EMA_Distance_Filter = true;
input bool Use_SupportResistance_Filter = true;
input bool Use_ATR_Filter = true;
input bool Show_Debug_Info = true;

// ✅ Price Action Parameters
input bool Use_Engulfing_Pattern = true;
input bool Use_PinBar_Pattern = true;
input bool Use_InsideBar_Pattern = true;
input double PinBar_Factor = 2.0;      // Pin bar nose length vs body

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
double EmaFastBuffer[];
double EmaSlowBuffer[];
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
double pipValue;  // Value of one pip

//+------------------------------------------------------------------+
//| Get symbol-specific data                                           |
//+------------------------------------------------------------------+
bool GetSymbolData()
{
    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    pipValue = point * 10;
    
    if(digits == 0 || point == 0)
    {
        Print("❌ Error getting symbol data - digits: ", digits, " point: ", point);
        return false;
    }
    
    Print("✅ Symbol data loaded - digits: ", digits, " point: ", point, " pipValue: ", pipValue);
    return true;
}

//+------------------------------------------------------------------+
//| Check if current bar is finished                                   |
//+------------------------------------------------------------------+
bool IsBarFinished()
{
    datetime time_current = TimeCurrent();
    datetime time_prev = iTime(_Symbol, PERIOD_CURRENT, 0);
    return time_current >= time_prev + PeriodSeconds(PERIOD_CURRENT);
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
    FastMA_Handle = iMA(_Symbol, PERIOD_CURRENT, fastPeriod, 0, MODE_EMA, PRICE_CLOSE);
    SlowMA_Handle = iMA(_Symbol, PERIOD_CURRENT, slowPeriod, 0, MODE_EMA, PRICE_CLOSE);
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
//| Display Signal Information Using Comment()                      |
//+------------------------------------------------------------------+
void DisplaySignalInfo(string text)
{
    Comment(text);
}

//+------------------------------------------------------------------+
//| Function to check if price is in valid trading range             |
//+------------------------------------------------------------------+
bool IsValidTradingRange(const int index)
{
    double range = MathAbs(ResistanceBuffer[index] - SupportBuffer[index]);
    double minRequiredRange = ATRBuffer[index] * Min_Range_Multiplier;
    
    return (range >= minRequiredRange);
}

//+------------------------------------------------------------------+
//| Function to check if we have a strong trend                      |
//+------------------------------------------------------------------+
bool IsStrongTrend(const int index)
{
    return (ADXBuffer[index] > ADX_Threshold);
}

//+------------------------------------------------------------------+
//| Function to validate breakout                                    |
//+------------------------------------------------------------------+
bool ValidateBreakout(const int index, const bool isBuy, const double &close[])
{
    double srZone = ATRBuffer[index] * ATR_Zone_Multiplier;
    
    if(isBuy)
    {
        // Buy signal: price closes above resistance zone
        return (close[index] > ResistanceBuffer[index] + srZone);
    }
    else
    {
        // Sell signal: price closes below support zone
        return (close[index] < SupportBuffer[index] - srZone);
    }
}

//+------------------------------------------------------------------+
//| Modified support/resistance calculation                          |
//+------------------------------------------------------------------+
void CalculateSupportResistance(const int index, const double &high[], const double &low[], const double &close[])
{
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
//| Enhanced market condition analysis                                 |
//+------------------------------------------------------------------+
string AnalyzeMarketConditions(const int index)
{
    string analysis = "\n=== Market Analysis ===\n";
    
    // Trend Analysis
    analysis += "🔄 TREND STATUS:\n";
    bool isUptrend = EmaFastBuffer[index] > EmaSlowBuffer[index];
    double emaDiff = (EmaFastBuffer[index] - EmaSlowBuffer[index]) / Point();
    
    analysis += "🔄 TREND STATUS:\n";
    if(isUptrend)
    {
        analysis += "📈 Uptrend - Fast EMA above Slow EMA\n";
        analysis += "   Strength: " + DoubleToString(emaDiff * Point(), _Digits) + " points\n";
    }
    else
    {
        analysis += "📉 Downtrend - Fast EMA below Slow EMA\n";
        analysis += "   Strength: " + DoubleToString(MathAbs(emaDiff) * Point(), _Digits) + " points\n";
    }
    
    // RSI Analysis
    analysis += "\n📊 RSI ANALYSIS:\n";
    if(RSIBuffer[index] > RSI_Overbought)
        analysis += "⚠️ OVERBOUGHT - High probability of pullback\n";
    else if(RSIBuffer[index] > RSI_Warning)
        analysis += "⚠️ Approaching overbought - Exercise caution\n";
    else if(RSIBuffer[index] < RSI_Oversold)
        analysis += "⚠️ OVERSOLD - Watch for potential reversal\n";
    else
        analysis += "✅ RSI in neutral zone\n";
    
    // Trend Strength
    analysis += "\n💪 TREND STRENGTH:\n";
    if(ADXBuffer[index] > 25)
        analysis += "✅ Strong trend (ADX > 25)\n";
    else if(ADXBuffer[index] > 20)
        analysis += "⚠️ Moderate trend strength\n";
    else
        analysis += "❌ Weak trend - Consider ranging market strategies\n";
    
    // Range Analysis
    analysis += "\n📐 RANGE ANALYSIS:\n";
    double range = MathAbs(ResistanceBuffer[index] - SupportBuffer[index]);
    double minRange = ATRBuffer[index] * Min_Range_Multiplier;
    
    analysis += "Current Range: " + DoubleToString(range, _Digits) + "\n";
    analysis += "Minimum Required: " + DoubleToString(minRange, _Digits) + "\n";
    
    if(range < minRange)
        analysis += "⚠ Range too tight for reliable signals\n";
    else
        analysis += "✅ Sufficient range for trading\n";
    
    // Market Context Warning
    if(RSIBuffer[index] > RSI_Warning && ADXBuffer[index] < 25)
    {
        analysis += "\n🚨 SPECIAL WARNING:\n";
        analysis += "High RSI with weak trend strength suggests\n";
        analysis += "increased probability of pullback or consolidation.\n";
    }
    
    return analysis;
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
                    ObjectCreate(0, "BuyTP", OBJ_TEXT, 0, time[i], BuyTP[i]);
                    ObjectSetString(0, "BuyTP", OBJPROP_TEXT, "TP " + DoubleToString(BuyTP[i], digits));
                    ObjectSetInteger(0, "BuyTP", OBJPROP_COLOR, clrLime);
                    
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
                    ObjectCreate(0, "SellTP", OBJ_TEXT, 0, time[i], SellTP[i]);
                    ObjectSetString(0, "SellTP", OBJPROP_TEXT, "TP " + DoubleToString(SellTP[i], digits));
                    ObjectSetInteger(0, "SellTP", OBJPROP_COLOR, clrLime);
                    
                    ObjectCreate(0, "SellSL", OBJ_TEXT, 0, time[i], SellSL[i]);
                    ObjectSetString(0, "SellSL", OBJPROP_TEXT, "SL " + DoubleToString(SellSL[i], digits));
                    ObjectSetInteger(0, "SellSL", OBJPROP_COLOR, clrRed);
                }
            }
        }
        
        // Update market analysis for current bar
        if(i == 0)
        {
            string analysis = GetMarketAnalysis(i, high, low);
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
//| Print Signal Analysis to Expert Log                               |
//+------------------------------------------------------------------+
void PrintSignalAnalysis(const double emaFast, const double emaSlow, const double rsi, const double adx, 
                        const bool nearSupport, const bool nearResistance)
{
    string analysis = "\n=== Signal Analysis ===\n";
    
    // Trend Analysis
    analysis += "🔄 TREND ANALYSIS:\n";
    double emaDiff = emaFast - emaSlow;
    if(emaFast > emaSlow) 
        analysis += "✅ UPTREND: Fast EMA " + DoubleToString(emaDiff, 2) + " points above Slow EMA\n";
    else 
        analysis += "❌ DOWNTREND: Fast EMA " + DoubleToString(-emaDiff, 2) + " points below Slow EMA\n";
    
    // Momentum Analysis
    analysis += "\n📊 MOMENTUM ANALYSIS:\n";
    double rsiBuyThresh, rsiSellThresh;
    GetRSIThresholds(rsiBuyThresh, rsiSellThresh);
    
    if(rsi > rsiSellThresh) 
        analysis += "⚠️ RSI (" + DoubleToString(rsi,1) + ") above " + DoubleToString(rsiSellThresh,1) + " - Overbought\n";
    else if(rsi < rsiBuyThresh) 
        analysis += "⚠️ RSI (" + DoubleToString(rsi,1) + ") below " + DoubleToString(rsiBuyThresh,1) + " - Oversold\n";
    else 
        analysis += "✅ RSI (" + DoubleToString(rsi,1) + ") in optimal range (" + 
                   DoubleToString(rsiBuyThresh,1) + " - " + DoubleToString(rsiSellThresh,1) + ")\n";
    
    // Trend Strength
    analysis += "\n💪 TREND STRENGTH:\n";
    if(adx >= 11) 
        analysis += "✅ ADX (" + DoubleToString(adx,1) + ") shows sufficient trend strength\n";
    else 
        analysis += "❌ ADX (" + DoubleToString(adx,1) + ") too weak - waiting for stronger trend\n";
    
    // Support/Resistance
    if(Use_SupportResistance_Filter)
    {
        analysis += "\n🎯 PRICE LEVELS:\n";
        if(nearResistance) 
            analysis += "⚠️ Price near resistance - Caution on buys\n";
        if(nearSupport) 
            analysis += "⚠️ Price near support - Caution on sells\n";
        if(!nearResistance && !nearSupport)
            analysis += "✅ Price in clear zone - No S/R conflicts\n";
    }
    
    Print(analysis);
    
    // Print current ATR multiplier info
    double atrMultiplier = GetTimeframeATRMultiplier();
    Print("📊 Current ATR Multiplier: ", DoubleToString(atrMultiplier,1), "x");
}

//+------------------------------------------------------------------+
//| Get most recent valid price                                        |
//+------------------------------------------------------------------+
double GetValidPrice()
{
    MqlTick last_tick;
    if(!SymbolInfoTick(_Symbol, last_tick))
    {
        Print("Error getting last tick: ", GetLastError());
        return 0;
    }
    return last_tick.last;
}

//+------------------------------------------------------------------+
//| Get current market data                                            |
//+------------------------------------------------------------------+
bool GetCurrentMarketData(double &price, double &bid, double &ask, datetime &tick_time)
{
    MqlTick last_tick;
    if(!SymbolInfoTick(_Symbol, last_tick))
    {
        Print("Error getting market data: ", GetLastError());
        return false;
    }
    
    price = last_tick.last;
    bid = last_tick.bid;
    ask = last_tick.ask;
    tick_time = last_tick.time;
    return true;
}

//+------------------------------------------------------------------+
//| Detect Engulfing Pattern                                           |
//+------------------------------------------------------------------+
bool IsEngulfingPattern(const int index, const double &open[], const double &close[], bool isBullish)
{
    if(index < 1) return false;
    
    double currentBody = MathAbs(close[index] - open[index]);
    double prevBody = MathAbs(close[index+1] - open[index+1]);
    
    if(isBullish)
    {
        return close[index] > open[index] &&           // Current bar is bullish
               close[index+1] < open[index+1] &&       // Previous bar is bearish
               open[index] < close[index+1] &&         // Current open below prev close
               close[index] > open[index+1] &&         // Current close above prev open
               currentBody > prevBody * 1.1;           // Current body larger than prev
    }
    else
    {
        return close[index] < open[index] &&           // Current bar is bearish
               close[index+1] > open[index+1] &&       // Previous bar is bullish
               open[index] > close[index+1] &&         // Current open above prev close
               close[index] < open[index+1] &&         // Current close below prev open
               currentBody > prevBody * 1.1;           // Current body larger than prev
    }
}

//+------------------------------------------------------------------+
//| Detect Pin Bar Pattern                                             |
//+------------------------------------------------------------------+
bool IsPinBar(const int index, const double &open[], const double &high[], const double &low[], const double &close[], bool isBullish)
{
    if(index < 1) return false;
    
    double body = MathAbs(open[index] - close[index]);
    double upperWick = high[index] - MathMax(open[index], close[index]);
    double lowerWick = MathMin(open[index], close[index]) - low[index];
    double totalLength = high[index] - low[index];
    
    if(totalLength == 0) return false;
    
    if(isBullish)  // Hammer
    {
        return lowerWick > body * PinBar_Factor &&     // Long lower wick
               upperWick < body * 0.3 &&               // Short upper wick
               lowerWick > totalLength * 0.6;          // Lower wick is majority of candle
    }
    else  // Shooting Star
    {
        return upperWick > body * PinBar_Factor &&     // Long upper wick
               lowerWick < body * 0.3 &&               // Short lower wick
               upperWick > totalLength * 0.6;          // Upper wick is majority of candle
    }
}

//+------------------------------------------------------------------+
//| Detect Inside Bar Pattern                                          |
//+------------------------------------------------------------------+
bool IsInsideBar(const int index, const double &high[], const double &low[])
{
    if(index < 1) return false;
    
    return high[index] < high[index+1] &&     // Current high below previous high
           low[index] > low[index+1];         // Current low above previous low
}

//+------------------------------------------------------------------+
//| Detect Double Top/Bottom Pattern                                   |
//+------------------------------------------------------------------+
bool IsDoublePattern(const int index, const double &high[], const double &low[], const int lookback, bool isTop)
{
    if(index < lookback) return false;
    
    double tolerance = ATRBuffer[index] * 0.2;  // Use ATR for dynamic tolerance
    double firstLevel = isTop ? high[index + lookback] : low[index + lookback];
    double currentLevel = isTop ? high[index] : low[index];
    
    // Check if current level is within tolerance of first level
    if(MathAbs(currentLevel - firstLevel) > tolerance)
        return false;
        
    // Check for lower low (double top) or higher high (double bottom) between points
    for(int i = index + 1; i < index + lookback; i++)
    {
        if(isTop)
        {
            if(high[i] > firstLevel + tolerance)
                return false;
            if(low[i] < MathMin(low[index], low[index + lookback]) - tolerance)
                return true;
        }
        else
        {
            if(low[i] < firstLevel - tolerance)
                return false;
            if(high[i] > MathMax(high[index], high[index + lookback]) + tolerance)
                return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Add timeframe check and recommendation                           |
//+------------------------------------------------------------------+
string GetTimeframeRecommendation()
{
    string recommendation = "\n=== Timeframe Analysis ===\n";
    ENUM_TIMEFRAMES current_tf = Period();
    
    switch(current_tf)
    {
        case PERIOD_M1:
        case PERIOD_M5:
        case PERIOD_M15:
        case PERIOD_M30:
            recommendation += "⚠️ Current timeframe too short for swing trading.\nRecommended: H4, D1, or W1";
            break;
            
        case PERIOD_H1:
            recommendation += "⚠️ H1 timeframe marginal for swing trading.\nRecommended: H4, D1, or W1";
            break;
            
        case PERIOD_H4:
            recommendation += "✅ H4 timeframe good for shorter swing trades";
            break;
            
        case PERIOD_D1:
            recommendation += "✅ D1 timeframe ideal for swing trading";
            break;
            
        case PERIOD_W1:
        case PERIOD_MN1:
            recommendation += "✅ Excellent for position trading";
            break;
    }
    
    return recommendation;
}

//+------------------------------------------------------------------+
//| Update debug information                                          |
//+------------------------------------------------------------------+
void UpdateDebugInfo(const int index, 
                    const bool nearSupport,
                    const bool nearResistance)
{
    if(!Show_Debug_Info) return;
    
    string signalText = "📊 Market Conditions:\n";
    signalText += "=== Technical Indicators ===\n";
    signalText += "EMA Fast: " + DoubleToString(EmaFastBuffer[index], 2) + "\n";
    signalText += "EMA Slow: " + DoubleToString(EmaSlowBuffer[index], 2) + "\n";
    signalText += "RSI: " + DoubleToString(RSIBuffer[index], 1) + "\n";
    signalText += "ATR: " + DoubleToString(ATRBuffer[index], 2) + "\n";
    signalText += "ADX: " + DoubleToString(ADXBuffer[index], 1) + "\n\n";
    
    signalText += "=== Support/Resistance ===\n";
    if(nearSupport) signalText += "📈 Near Support Level: " + DoubleToString(SupportBuffer[index], 2) + "\n";
    if(nearResistance) signalText += "📉 Near Resistance Level: " + DoubleToString(ResistanceBuffer[index], 2) + "\n\n";
    
    // Add detailed market analysis
    signalText += AnalyzeMarketConditions(index);
    
    // Add timeframe recommendation
    signalText += GetTimeframeRecommendation();
    
    Comment(signalText);
}

//+------------------------------------------------------------------+
//| Enhanced Market Analysis Function                                  |
//+------------------------------------------------------------------+
bool IsValidTradingSetup(const int index, const bool isBuy, 
                        const double &close[], const double &high[], const double &low[])
{
    // First check if we have enough data
    if(index < 0 || index >= ArraySize(FastMABuffer) || 
       index + 5 >= ArraySize(FastMABuffer))  // Need 5 more bars for angle calculation
    {
        return false;
    }

    // Check if we have valid MA values
    if(FastMABuffer[index] == EMPTY_VALUE || SlowMABuffer[index] == EMPTY_VALUE)
    {
        return false;
    }

    // Check if price is in proper position relative to MAs
    bool maAlignment = false;
    if(isBuy)
    {
        maAlignment = close[index] > FastMABuffer[index] && 
                     FastMABuffer[index] > SlowMABuffer[index];
    }
    else
    {
        maAlignment = close[index] < FastMABuffer[index] && 
                     FastMABuffer[index] < SlowMABuffer[index];
    }
    
    // Check for trend strength using MA angle
    // Only calculate if we have enough bars
    bool strongTrend = false;
    if(index + 5 < ArraySize(FastMABuffer))
    {
        double maAngle = MathArctan((FastMABuffer[index] - FastMABuffer[index+5]) / 5) * 180 / M_PI;
        strongTrend = MathAbs(maAngle) >= 15; // Minimum angle for strong trend
    }
    
    // Check RSI conditions
    bool validRSI = true;
    if(RSIBuffer[index] == EMPTY_VALUE)
    {
        return false;
    }
    
    if(isBuy && RSIBuffer[index] > RSI_Overbought)
        validRSI = false;
    if(!isBuy && RSIBuffer[index] < RSI_Oversold)
        validRSI = false;
        
    // Range analysis
    if(ATRBuffer[index] == EMPTY_VALUE)
    {
        return false;
    }
    
    double atr = ATRBuffer[index];
    double rangeSize = MathAbs(high[index] - low[index]);
    bool validRange = rangeSize >= atr * Min_Range_Multiplier;
    
    return maAlignment && strongTrend && validRSI && validRange;
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
