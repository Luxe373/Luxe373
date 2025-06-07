//+------------------------------------------------------------------+
//|                                                  SnapTrade_EA.mq5 |
//|                                      Copyright 2025, xAI          |
//|                                             https://snaptrade.io |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xAI"
#property link      "https://snaptrade.io"
#property version   "1.09" // Updated version
#property description "SnapTrade MT5 Expert Advisor"

#property ex5_strict
#property script_show_inputs

// Standard library includes
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Arrays\ArraySort.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Math\Stat\Math.mqh>
#include <MovingAverages.mqh>

// SnapTrade specific configuration (replace with your actual credentials)
#define SNAPTRADE_USER_ID       "your_user_id"
#define SNAPTRADE_USER_SECRET   "your_user_secret"

// Trading parameters - these should be inputs for flexibility
input group "Trading Parameters"
input double InpLots          = 0.01;    // Lot size
input int    InpStopLoss      = 500;     // Stop Loss in points
input int    InpTakeProfit    = 1000;    // Take Profit in points
input int    InpMagicNumber   = 12345;   // EA Magic Number

input group "Moving Average Parameters"
input int    InpFastMAPeriod  = 10;      // Fast MA Period
input int    InpSlowMAPeriod  = 20;      // Slow MA Period
input ENUM_MA_METHOD InpMAMethod = MODE_EMA; // MA Method (Exponential)
input ENUM_APPLIED_PRICE InpMAPrice = PRICE_CLOSE; // Applied Price

input group "Volume Filter Parameters"
input bool   UseVolumeFilter  = true;    // Enable Volume Filter
input int    volEMAPeriod     = 14;      // Volume EMA Period
input double volFactor        = 1.5;     // Volume Factor (e.g., 1.5 = 50% above EMA)

// Global objects
CTrade trade;
CSymbolInfo symbol;
CPositionInfo position;
COrderInfo order;
CHistoryOrderInfo historyOrder;
CArrayDouble priceArray; // For MA calculations
CArrayDouble volArray;   // For Volume EMA calculations

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("SnapTrade EA Initializing...");
   Print("Version: ", __FILE__, " ", __DATE__, " ", __TIME__);

   // Initialize trading objects
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10); // Allowable slippage
   trade.SetTypeFillingBySymbol(Symbol());

   if(!symbol.Name(Symbol())) return(INIT_FAILED);
   symbol.RefreshRates();

   // Validate inputs (basic checks)
   if(InpLots <= 0 || InpStopLoss <= 0 || InpTakeProfit <= 0)
     {
      Print("Error: Invalid trading parameters (Lots, SL, TP must be > 0).");
      return(INIT_FAILED);
     }
   if(InpFastMAPeriod <= 0 || InpSlowMAPeriod <= 0 || InpFastMAPeriod >= InpSlowMAPeriod)
     {
      Print("Error: Invalid MA parameters (Periods > 0, Fast < Slow).");
      return(INIT_FAILED);
     }
   if(UseVolumeFilter && (volEMAPeriod <= 0 || volFactor <= 0))
     {
      Print("Error: Invalid Volume Filter parameters (Period and Factor must be > 0).");
      return(INIT_FAILED);
     }

   // SnapTrade Authentication (Conceptual - replace with actual API calls if available)
   if(SNAPTRADE_USER_ID == "your_user_id" || SNAPTRADE_USER_SECRET == "your_user_secret")
     {
      Print("Warning: Using default SnapTrade credentials. Please update.");
      // Potentially, you might want to prevent trading if not properly authenticated
      // return(INIT_FAILED);
     }
   // SendLogToSnapTrade("EA Initialized: " + symbol.Name());

   Print("SnapTrade EA Initialized Successfully.");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("SnapTrade EA Deinitializing... Reason: ", reason);
   // Perform cleanup if necessary (e.g., close open trades managed by this EA)
   // SendLogToSnapTrade("EA Deinitialized: " + symbol.Name() + ", Reason: " + IntegerToString(reason));
   Print("SnapTrade EA Deinitialized.");
  }
//+------------------------------------------------------------------+
//| Expert tick function (main trading logic)                        |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Check if trading is allowed for the symbol and account
   if(!trade.IsTradingAllowed())
     {
      // Print("Trading is not allowed currently.");
      return;
     }
   if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_NOT_TRADABLE)
     {
      // PrintFormat("%s is not tradable at the moment.", _Symbol);
      return;
     }

   // Refresh symbol rates
   if(!symbol.RefreshRates())
     {
      Print("Error: Could not refresh symbol rates.");
      return;
     }

   // Get latest prices
   double askPrice = symbol.Ask();
   double bidPrice = symbol.Bid();
   if(askPrice == 0 || bidPrice == 0)
     {
      Print("Error: Invalid Ask/Bid prices.");
      return;
     }

   // MA Calculation
   MqlRates rates[];
   if(CopyRates(Symbol(), Period(), 0, InpSlowMAPeriod + 5, rates) < InpSlowMAPeriod) // +5 for buffer
     {
      Print("Error: Not enough bars for MA calculation.");
      return;
     }
   ArraySetAsSeries(rates, true); // Oldest data at the end

   double fastMA_current = iMAOnArray(GetPriceArray(rates, InpSlowMAPeriod, InpMAPrice), 0, InpFastMAPeriod, 0, InpMAMethod, 0);
   double fastMA_previous = iMAOnArray(GetPriceArray(rates, InpSlowMAPeriod, InpMAPrice), 0, InpFastMAPeriod, 0, InpMAMethod, 1);
   double slowMA_current = iMAOnArray(GetPriceArray(rates, InpSlowMAPeriod, InpMAPrice), 0, InpSlowMAPeriod, 0, InpMAMethod, 0);
   double slowMA_previous = iMAOnArray(GetPriceArray(rates, InpSlowMAPeriod, InpMAPrice), 0, InpSlowMAPeriod, 0, InpMAMethod, 1);

   if(fastMA_current == 0 || fastMA_previous == 0 || slowMA_current == 0 || slowMA_previous == 0)
     {
      Print("Error: MA calculation resulted in zero values.");
      return;
     }

   // Volume Filter (if enabled)
   bool volumeConditionMet = !UseVolumeFilter; // True if filter is disabled
   if(UseVolumeFilter)
     {
      if(CopyRates(Symbol(), Period(), 0, volEMAPeriod + 5, rates) < volEMAPeriod +2) // Ensure enough data for volArray
        {
         Print("Error: Not enough bars for Volume EMA calculation.");
         return;
        }
      // ArraySetAsSeries(rates, true); // Already set

      // Populate volArray, ensuring we don't go out of bounds for rates
      // rates[0] is current forming bar, rates[1] is last completed, rates[2] is the one before etc.
      // We need volEMAPeriod worth of *closed* bar volumes.
      // If volEMAPeriod = 14, we need rates[1] through rates[14]
      // The loop for volArray will be from k=0 to volEMAPeriod-1
      // volArray[k] should correspond to rates[k+1].tick_volume if we want most recent first
      // Or rates[volEMAPeriod-1-k+1] if we want oldest first for iMAOnArray
      // Let's prepare it for iMAOnArray (oldest first)

      if(!volArray.Resize(volEMAPeriod))
        {
         Print("Error: Could not resize volArray.");
         return;
        }

      for(int k=0; k < volEMAPeriod; k++) {
          // rates are series, rates[0] is current bar. We need previous bars.
          // rates[1] is the last completed bar, rates[2] the one before, etc.
          // For EMA, data should be oldest first. So volArray[0] = oldest volume.
          // rates[volEMAPeriod] is the oldest, rates[1] is the newest *closed* bar.
          volArray[k] = (double)rates[k+2].tick_volume; // Corrected indexing
      }

      double currentVolume = rates[1].tick_volume; // Volume of the last completed bar
      double volumeEMA = iMAOnArray(volArray, 0, volEMAPeriod, 0, MODE_EMA, 0); // EMA of previous volumes

      if(volumeEMA > 0 && currentVolume > volumeEMA * volFactor)
        {
         volumeConditionMet = true;
        }
      else if (volumeEMA == 0 && currentVolume > 0) // Handle case where EMA might be zero initially
        {
         volumeConditionMet = true;
        }
      else
        {
         // PrintFormat("Volume condition not met. Current: %f, EMA: %f", currentVolume, volumeEMA);
        }
     }

   // Trading Logic: MA Crossover
   bool buySignal = fastMA_current > slowMA_current && fastMA_previous <= slowMA_previous;
   bool sellSignal = fastMA_current < slowMA_current && fastMA_previous >= slowMA_previous;

   // Check for open positions for this symbol and magic number
   int totalPositions = PositionsTotal();
   int symbolPositions = 0;
   for(int i = totalPositions - 1; i >= 0; i--)
     {
      if(position.SelectByIndex(i))
        {
         if(position.Symbol() == Symbol() && position.Magic() == InpMagicNumber)
           {
            symbolPositions++;
           }
        }
     }

   // Execute trades if signals and conditions are met
   if(symbolPositions == 0) // Only trade if no existing position for this symbol/magic
     {
      if(buySignal && volumeConditionMet)
        {
         double sl = bidPrice - InpStopLoss * symbol.Point();
         double tp = bidPrice + InpTakeProfit * symbol.Point();
         if(trade.Buy(InpLots, Symbol(), bidPrice, sl, tp, "SnapTrade Buy (MA Crossover)"))
           {
            // SendLogToSnapTrade("BUY order placed: " + Symbol() + " at " + DoubleToString(bidPrice,Digits()));
            Print("BUY order placed for ", Symbol(), " at ", bidPrice);
           }
         else
           {
            Print("Error placing BUY order: ", GetLastError());
            // SendLogToSnapTrade("BUY order failed: " + Symbol() + ", Error: " + IntegerToString(GetLastError()));
           }
        }
      else if(sellSignal && volumeConditionMet)
        {
         double sl = askPrice + InpStopLoss * symbol.Point();
         double tp = askPrice - InpTakeProfit * symbol.Point();
         if(trade.Sell(InpLots, Symbol(), askPrice, sl, tp, "SnapTrade Sell (MA Crossover)"))
           {
            // SendLogToSnapTrade("SELL order placed: " + Symbol() + " at " + DoubleToString(askPrice,Digits()));
            Print("SELL order placed for ", Symbol(), " at ", askPrice);
           }
         else
           {
            Print("Error placing SELL order: ", GetLastError());
            // SendLogToSnapTrade("SELL order failed: " + Symbol() + ", Error: " + IntegerToString(GetLastError()));
           }
        }
     }
   // else { Print("Position already exists for ", Symbol()); }
  }
//+------------------------------------------------------------------+
//| Helper function to get price array for MA calculation            |
//+------------------------------------------------------------------+
double[] GetPriceArray(const MqlRates &rates[], int count, ENUM_APPLIED_PRICE priceType)
  {
   if(priceArray.Resize(count) != count)
     {
      Print("Error: Could not resize priceArray.");
      return NULL;
     }

   for(int i = 0; i < count; i++)
     {
      switch(priceType)
        {
         case PRICE_CLOSE:     priceArray[i] = rates[i].close; break;
         case PRICE_OPEN:      priceArray[i] = rates[i].open; break;
         case PRICE_HIGH:      priceArray[i] = rates[i].high; break;
         case PRICE_LOW:       priceArray[i] = rates[i].low; break;
         case PRICE_MEDIAN:    priceArray[i] = (rates[i].high + rates[i].low) / 2.0; break;
         case PRICE_TYPICAL:   priceArray[i] = (rates[i].high + rates[i].low + rates[i].close) / 3.0; break;
         case PRICE_WEIGHTED:  priceArray[i] = (rates[i].high + rates[i].low + rates[i].close + rates[i].close) / 4.0; break;
         default:              priceArray[i] = rates[i].close; break;
        }
     }
   return priceArray.Buffer();
  }
//+------------------------------------------------------------------+
//| Function to send logs/status to SnapTrade (Conceptual)           |
//+------------------------------------------------------------------+
/*
void SendLogToSnapTrade(string message)
  {
   // This is a conceptual function. In a real EA, you would use WebRequest
   // to send data to your SnapTrade backend.
   // Example:
   // string url = "https://api.snaptrade.io/log";
   // string headers = "Content-Type: application/json\r\n"
   //                  "X-User-ID: " + SNAPTRADE_USER_ID + "\r\n"
   //                  "X-User-Secret: " + SNAPTRADE_USER_SECRET; // Or a session token
   // string jsonData = StringFormat("{\"symbol\": \"%s\", \"message\": \"%s\"}", Symbol(), message);
   // char post[], result[];
   // StringToCharArray(jsonData, post);
   // int res = WebRequest("POST", url, headers, 5000, post, result);
   // if(res == -1) Print("Error in WebRequest: ", GetLastError());
   // else Print("Log sent to SnapTrade: ", CharArrayToString(result));

   Print("SnapTrade Log (local): " + message); // For local testing
  }
*/
//+------------------------------------------------------------------+
//| OnTester function (for Strategy Tester optimization)             |
//+------------------------------------------------------------------+
double OnTester()
  {
   double ret = 0.0;
   // Custom criteria for optimization can be calculated here
   // For example, based on Profit, Sharpe Ratio, etc.
   // ret = TesterStatistics(STAT_PROFIT);
   return(ret);
  }
//+------------------------------------------------------------------+
//| OnTrade function (called when a trade event occurs)              |
//+------------------------------------------------------------------+
void OnTrade()
  {
   // Example: Log trade events
   // CTradeResult trade_result;
   // if(trade.Result(trade_result))
   //   {
   //    SendLogToSnapTrade(StringFormat("Trade Event: Order #%d, Action: %s, Price: %.5f, Volume: %.2f, Result: %s",
   //       trade_result.order, EnumToString(trade_result.action), trade_result.price, trade_result.volume, EnumToString(trade_result.retcode)));
   //   }
  }
//+------------------------------------------------------------------+
//| OnTimer function (if using EventSetTimer)                        |
//+------------------------------------------------------------------+
/*
void OnTimer()
  {
   // Handle timed events if any timers are set
  }
*/
//+------------------------------------------------------------------+
//| OnChartEvent function (for chart interactions)                   |
//+------------------------------------------------------------------+
/*
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   // Handle chart events like button clicks, object modifications etc.
  }
*/
//+------------------------------------------------------------------+
