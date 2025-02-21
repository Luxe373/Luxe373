//+------------------------------------------------------------------+
//|                                          EnhancedSignalGenerator.mq5 |
//|                                  Copyright 2025, Your Company Name    |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company Name"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   8

// Indicator Buffers
double BuySignalBuffer[];
double SellSignalBuffer[];
double FastEMABuffer[];
double SlowEMABuffer[];
double RSIBuffer[];
double ADXBuffer[];
double ATRBuffer[];
double SRLevelsBuffer[];

// Input Parameters
input group "Display Settings"
input bool   ShowLabels = true;          // Show Text Labels
input bool   ShowDebugLogs = true;       // Show Debug Logs
input color  BullishColor = clrLime;     // Bullish Signal Color
input color  BearishColor = clrRed;      // Bearish Signal Color
input color  NeutralColor = clrGray;     // Neutral Color

input group "Technical Indicators"
input int    FastEMAPeriod = 50;         // Fast EMA Period
input int    SlowEMAPeriod = 200;        // Slow EMA Period
input int    RSIPeriod = 14;             // RSI Period
input double RSIOverbought = 70;         // RSI Overbought Level
input double RSIOversold = 30;           // RSI Oversold Level
input int    ADXPeriod = 14;             // ADX Period
input double ADXThreshold = 20;          // ADX Minimum Threshold

input group "Price Action Settings"
input bool   UseEngulfing = true;        // Use Engulfing Patterns
input bool   UsePinBars = true;          // Use Pin Bars
input bool   UseInsideBars = true;       // Use Inside Bars
input bool   UseDoubleTops = true;       // Use Double Tops/Bottoms

input group "Risk Management"
input double ATRMultiplier = 1.5;        // ATR Multiplier for SL/TP
input double RiskRewardRatio = 1.5;      // Risk-Reward Ratio
input bool   UseHigherTimeframe = true;   // Use Higher Timeframe Confirmation

// Indicator Handles
int FastEMAHandle;
int SlowEMAHandle;
int RSIHandle;
int ADXHandle;
int ATRHandle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                           |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize Buffers
    SetIndexBuffer(0, BuySignalBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, SellSignalBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, FastEMABuffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(3, SlowEMABuffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(4, RSIBuffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(5, ADXBuffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(6, ATRBuffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(7, SRLevelsBuffer, INDICATOR_CALCULATIONS);
    
    // Set plot properties
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
    
    // Create indicator handles
    FastEMAHandle = iMA(_Symbol, PERIOD_CURRENT, FastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    SlowEMAHandle = iMA(_Symbol, PERIOD_CURRENT, SlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    RSIHandle = iRSI(_Symbol, PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE);
    ADXHandle = iADX(_Symbol, PERIOD_CURRENT, ADXPeriod);
    ATRHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
    
    return(INIT_SUCCEEDED);
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
    if(rates_total < FastEMAPeriod || rates_total < SlowEMAPeriod)
        return(0);
        
    int limit = prev_calculated == 0 ? rates_total - FastEMAPeriod - 1 : rates_total - prev_calculated;
    
    // Copy indicator values
    ArraySetAsSeries(FastEMABuffer, true);
    ArraySetAsSeries(SlowEMABuffer, true);
    ArraySetAsSeries(RSIBuffer, true);
    ArraySetAsSeries(ADXBuffer, true);
    ArraySetAsSeries(ATRBuffer, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    CopyBuffer(FastEMAHandle, 0, 0, rates_total, FastEMABuffer);
    CopyBuffer(SlowEMAHandle, 0, 0, rates_total, SlowEMABuffer);
    CopyBuffer(RSIHandle, 0, 0, rates_total, RSIBuffer);
    CopyBuffer(ADXHandle, 0, 0, rates_total, ADXBuffer);
    CopyBuffer(ATRHandle, 0, 0, rates_total, ATRBuffer);
    
    // Main calculation loop
    for(int i = limit; i >= 0; i--)
    {
        BuySignalBuffer[i] = 0;
        SellSignalBuffer[i] = 0;
        
        // Check trend conditions
        bool isBullishTrend = FastEMABuffer[i] > SlowEMABuffer[i];
        bool isBearishTrend = FastEMABuffer[i] < SlowEMABuffer[i];
        
        // Check RSI conditions
        bool isRSIBullish = RSIBuffer[i] > 50 && RSIBuffer[i] < RSIOverbought;
        bool isRSIBearish = RSIBuffer[i] < 50 && RSIBuffer[i] > RSIOversold;
        
        // Check ADX strength
        bool isStrongTrend = ADXBuffer[i] >= ADXThreshold;
        
        // Generate signals
        if(isStrongTrend)
        {
            if(isBullishTrend && isRSIBullish && CheckPriceAction(i, true, close, high, low))
            {
                BuySignalBuffer[i] = low[i] - ATRBuffer[i];
                if(ShowDebugLogs)
                    Print("Buy Signal at ", TimeToString(time[i]));
            }
            else if(isBearishTrend && isRSIBearish && CheckPriceAction(i, false, close, high, low))
            {
                SellSignalBuffer[i] = high[i] + ATRBuffer[i];
                if(ShowDebugLogs)
                    Print("Sell Signal at ", TimeToString(time[i]));
            }
        }
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Check Price Action Patterns                                        |
//+------------------------------------------------------------------+
bool CheckPriceAction(const int index,
                     const bool isBullish,
                     const double &close[],
                     const double &high[],
                     const double &low[])
{
    if(!UseEngulfing && !UsePinBars && !UseInsideBars)
        return true;
        
    bool patternFound = false;
    
    // Check Engulfing Pattern
    if(UseEngulfing)
    {
        if(isBullish)
            patternFound |= (close[index] > open[index+1] && open[index] < close[index+1]);
        else
            patternFound |= (close[index] < open[index+1] && open[index] > close[index+1]);
    }
    
    // Check Pin Bars
    if(UsePinBars)
    {
        double bodySize = MathAbs(close[index] - open[index]);
        double upperWick = high[index] - MathMax(open[index], close[index]);
        double lowerWick = MathMin(open[index], close[index]) - low[index];
        
        if(isBullish)
            patternFound |= (lowerWick > bodySize * 2 && upperWick < bodySize);
        else
            patternFound |= (upperWick > bodySize * 2 && lowerWick < bodySize);
    }
    
    // Check Inside Bars
    if(UseInsideBars)
    {
        patternFound |= (high[index] < high[index+1] && low[index] > low[index+1]);
    }
    
    return patternFound;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up
}
