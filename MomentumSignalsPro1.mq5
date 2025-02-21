//+------------------------------------------------------------------+
//|                                              MomentumSignalsPro1.mq5 |
//|                                  Copyright 2025, MetaQuotes Software |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// Input Parameters
input int    MomentumPeriod = 14;        // Momentum Period
input int    MAPeriod       = 20;        // Moving Average Period
input double UpperThreshold = 100.5;      // Upper Momentum Threshold
input double LowerThreshold = 99.5;       // Lower Momentum Threshold
input double TakeProfit     = 100;        // Take Profit in points
input double StopLoss       = 50;         // Stop Loss in points
input double LotSize        = 0.1;        // Trading Lot Size

// Global Variables
int momentumHandle;
int maHandle;
int barTotal;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize Momentum indicator
    momentumHandle = iMomentum(_Symbol, PERIOD_CURRENT, MomentumPeriod, PRICE_CLOSE);
    if(momentumHandle == INVALID_HANDLE)
    {
        Print("Error creating Momentum indicator");
        return(INIT_FAILED);
    }
    
    // Initialize Moving Average indicator
    maHandle = iMA(_Symbol, PERIOD_CURRENT, MAPeriod, 0, MODE_SMA, PRICE_CLOSE);
    if(maHandle == INVALID_HANDLE)
    {
        Print("Error creating Moving Average indicator");
        return(INIT_FAILED);
    }
    
    barTotal = iBars(_Symbol, PERIOD_CURRENT);
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(momentumHandle != INVALID_HANDLE)
        IndicatorRelease(momentumHandle);
    if(maHandle != INVALID_HANDLE)
        IndicatorRelease(maHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check for new bar
    int bars = iBars(_Symbol, PERIOD_CURRENT);
    if(bars == barTotal) return;
    barTotal = bars;
    
    // Arrays for indicator values
    double momentumBuffer[];
    double maBuffer[];
    ArraySetAsSeries(momentumBuffer, true);
    ArraySetAsSeries(maBuffer, true);
    
    // Copy indicator data
    if(CopyBuffer(momentumHandle, 0, 0, 3, momentumBuffer) < 3) return;
    if(CopyBuffer(maHandle, 0, 0, 3, maBuffer) < 3) return;
    
    // Check if we have any open positions
    if(PositionsTotal() == 0)
    {
        // Generate trading signals
        if(momentumBuffer[1] > UpperThreshold && Close[1] > maBuffer[1])
        {
            OpenBuyPosition();
        }
        else if(momentumBuffer[1] < LowerThreshold && Close[1] < maBuffer[1])
        {
            OpenSellPosition();
        }
    }
}

//+------------------------------------------------------------------+
//| Open Buy Position                                                  |
//+------------------------------------------------------------------+
void OpenBuyPosition()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl = ask - StopLoss * _Point;
    double tp = ask + TakeProfit * _Point;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = LotSize;
    request.type = ORDER_TYPE_BUY;
    request.price = ask;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 10;
    request.magic = 123456;
    request.comment = "MomentumSignalsPro1 Buy";
    request.type_filling = ORDER_FILLING_FOK;
    
    if(!OrderSend(request, result))
        PrintFormat("OrderSend error %d", GetLastError());
}

//+------------------------------------------------------------------+
//| Open Sell Position                                                 |
//+------------------------------------------------------------------+
void OpenSellPosition()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = bid + StopLoss * _Point;
    double tp = bid - TakeProfit * _Point;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = LotSize;
    request.type = ORDER_TYPE_SELL;
    request.price = bid;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 10;
    request.magic = 123456;
    request.comment = "MomentumSignalsPro1 Sell";
    request.type_filling = ORDER_FILLING_FOK;
    
    if(!OrderSend(request, result))
        PrintFormat("OrderSend error %d", GetLastError());
}
