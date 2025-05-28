//+------------------------------------------------------------------+
//|                                         PREBR22 – EBRE v2.62      |
//|   Buy → Hedge → Recovery Buy with Fixed Points Entries           |
//|   Trades at M1 candle close, closes all on any TP hit            |
//|   Resets cycle after 3 trades or TP closure                      |
//|   © 2025 Greg QA                                               |
//+------------------------------------------------------------------+
#property strict
#property version   "2.62"
#property copyright "Greg QA"

// Fixed points as provided
#include <Trade\Trade.mqh>
CTrade trade;

//--- USER PARAMETERS ---
input bool   AutoTradeEnabled         = true;     // Enable automated trading
input string TradeSymbol              = "NASUSD"; // Symbol to trade
input double InitialLot               = 0.03;     // Lot size for all trades

// Initial BUY parameters
input double BuyTriggerPoints         = 5.0;      // Points above prior M1 low to trigger BUY
input double BuyTPPoints              = 50.0;     // Points above entry for BUY take-profit

// SELL Hedge parameters
input double HedgeTriggerPoints       = 5.0;      // Points below BUY price to trigger SELL hedge
input double HedgeTPPoints            = 50.0;     // Points below entry for SELL take-profit

// Recovery BUY parameters
input double RecoveryTriggerPoints    = 5.0;      // Points above SELL price to trigger recovery BUY
input double RecoveryTPPoints         = 50.0;     // Points above entry for recovery take-profit

// Safety
input double EmergencyEquityThresh    = 800.0;    // Pause if equity below ($)
input double EmergencyMarginLevel     = 400.0;    // Pause if margin level < (%)
input double ResumeEquityThreshold    = 900.0;    // Resume if equity above ($)
input double ResumeMarginThreshold    = 500.0;    // Resume if margin level > (%)
input ulong  MagicNumber              = 20230501; // Unique magic number

//--- INTERNAL STATES ---
enum CycleStage { NONE, INITIAL_BUY, HEDGE_SELL, RECOVERY_BUY };
CycleStage stage       = NONE;
bool       paused      = false;
int        cycleTradeCount=0; // Track trades in current cycle
ulong      tBuy=0, tHedge=0, tRec=0;
double     buyPrice=0.0, buyTP=0.0, hedgePrice=0.0, hedgeTP=0.0, recPrice=0.0, recTP=0.0;
double     lastBid=0.0, lastAsk=0.0; // Store the latest bid/ask prices
static datetime lastBar;
long       stopLevel=0;

//+------------------------------------------------------------------+
//| Helper: margin level                                            |
//+------------------------------------------------------------------+
double MarginLevel()
{
  double m=AccountInfoDouble(ACCOUNT_MARGIN),
         e=AccountInfoDouble(ACCOUNT_EQUITY);
  double lvl = (m<=0 ? 9999.0 : (e/m)*100.0);
  return lvl;
}

//+------------------------------------------------------------------+
//| Helper: prior M1 low                                             |
//+------------------------------------------------------------------+
double PriorLow()
{
  return iLow(_Symbol, PERIOD_M1, 1);
}

//+------------------------------------------------------------------+
//| Close all EA positions                                           |
//+------------------------------------------------------------------+
void CloseAll()
{
  Print("CloseAll -> closing all positions");
  for(int i=PositionsTotal()-1; i>=0; i--)
  {
    ulong tk=PositionGetTicket(i);
    if(PositionSelectByTicket(tk) && PositionGetInteger(POSITION_MAGIC)==MagicNumber)
      trade.PositionClose(tk);
  }
  stage = NONE;
  // Note: 'paused' is reset here. If CloseAll() was called due to a TP hit 
  // while safety conditions (low equity/margin) were active, 
  // the Safety() function in OnTick (on the next new bar) will re-evaluate 
  // and re-apply the paused state if those conditions persist.
  paused = false; 
  tBuy=0; tHedge=0; tRec=0;
  buyPrice=0.0; buyTP=0.0; hedgePrice=0.0; hedgeTP=0.0; recPrice=0.0; recTP=0.0;
  cycleTradeCount=0;
}

//+------------------------------------------------------------------+
//| Open initial BUY                                                 |
//+------------------------------------------------------------------+
bool OpenBuy(double bid, double ask)
{
  if(cycleTradeCount >= 3) return false;
  double priorLow = PriorLow();
  double triggerPrice = priorLow + BuyTriggerPoints * _Point;
  PrintFormat("OpenBuy Check -> priorLow=%.5f  ask=%.5f  triggerPrice=%.5f", priorLow, ask, triggerPrice);
  if(ask >= triggerPrice)
  {
    double tp = ask + BuyTPPoints * _Point;
    if((tp-ask)/_Point < stopLevel) 
      tp = ask + stopLevel*_Point;
    bool ok = trade.Buy(InitialLot, _Symbol, ask, 0, tp, "InitBuy");
    if(ok)
    {
      tBuy = trade.ResultOrder();
      buyPrice = ask;
      buyTP = tp;
      cycleTradeCount++;
      PrintFormat("OpenBuy -> price=%.5f  TP=%.5f  ticket=%d  cycleTrades=%d", ask, tp, tBuy, cycleTradeCount);
    }
    else
    {
      PrintFormat("OpenBuy -> price=%.5f  failed: %s", ask, trade.ResultComment());
    }
    return ok;
  }
  return false;
}

//+------------------------------------------------------------------+
//| Open single SELL hedge                                           |
//+------------------------------------------------------------------+
bool OpenHedge(double bid)
{
  if(cycleTradeCount >= 3) return false;
  double triggerPrice = buyPrice - HedgeTriggerPoints * _Point;
  PrintFormat("OpenHedge Check -> buyPrice=%.5f  bid=%.5f  triggerPrice=%.5f", buyPrice, bid, triggerPrice);
  if(bid <= triggerPrice)
  {
    double tp = bid - HedgeTPPoints * _Point;
    if((bid-tp)/_Point < stopLevel)
      tp = bid - stopLevel*_Point;
    bool ok = trade.Sell(InitialLot, _Symbol, bid, 0, tp, "HedgeSell");
    if(ok)
    {
      tHedge = trade.ResultOrder();
      hedgePrice = bid;
      hedgeTP = tp;
      cycleTradeCount++;
      PrintFormat("OpenHedge -> price=%.5f  TP=%.5f  ticket=%d  cycleTrades=%d", bid, tp, tHedge, cycleTradeCount);
    }
    else
    {
      PrintFormat("OpenHedge -> price=%.5f  failed: %s", bid, trade.ResultComment());
    }
    return ok;
  }
  return false;
}

//+------------------------------------------------------------------+
//| Open recovery BUY                                                |
//+------------------------------------------------------------------+
bool OpenRecovery(double bid, double ask)
{
  if(cycleTradeCount >= 3) return false;
  double triggerPrice = hedgePrice + RecoveryTriggerPoints * _Point;
  PrintFormat("OpenRecovery Check -> hedgePrice=%.5f  ask=%.5f  triggerPrice=%.5f", hedgePrice, ask, triggerPrice);
  if(ask >= triggerPrice)
  {
    double tp = ask + RecoveryTPPoints * _Point;
    if((tp-ask)/_Point < stopLevel)
      tp = ask + stopLevel*_Point;
    bool ok = trade.Buy(InitialLot, _Symbol, ask, 0, tp, "RecBuy");
    if(ok)
    {
      tRec = trade.ResultOrder();
      recPrice = ask;
      recTP = tp;
      cycleTradeCount++;
      PrintFormat("OpenRecovery -> price=%.5f  TP=%.5f  ticket=%d  cycleTrades=%d", ask, tp, tRec, cycleTradeCount);
    }
    else
    {
      PrintFormat("OpenRecovery -> price=%.5f  failed: %s", ask, trade.ResultComment());
    }
    return ok;
  }
  return false;
}

//+------------------------------------------------------------------+
//| Safety & pause logic                                             |
//+------------------------------------------------------------------+
void Safety()
{
  double e=AccountInfoDouble(ACCOUNT_EQUITY),
         ml=MarginLevel();
  if(e<EmergencyEquityThresh || ml<EmergencyMarginLevel)
  {
    paused=true;
    Print("Safety -> tradingPaused = true");
  }
  else if(e>ResumeEquityThreshold && ml>ResumeMarginThreshold)
  {
    paused=false;
    Print("Safety -> tradingPaused = false");
  }
}

//+------------------------------------------------------------------+
//| Main cycle                                                       |
//+------------------------------------------------------------------+
void ManageCycle(double bid, double ask)
{
  PrintFormat("ManageCycle -> stage=%d  positions=%d  cycleTrades=%d", stage, PositionsTotal(), cycleTradeCount);

  // Enforce 3-trade limit: reset cycle at next candle close if limit reached and no positions
  if(cycleTradeCount >= 3 && PositionsTotal() == 0)
  {
    Print("ManageCycle -> Cycle trade limit reached (3 trades), resetting cycle");
    stage = NONE;
    tBuy=0; tHedge=0; tRec=0;
    buyPrice=0.0; buyTP=0.0; hedgePrice=0.0; hedgeTP=0.0; recPrice=0.0; recTP=0.0;
    cycleTradeCount=0;
    return;
  }
  else if(cycleTradeCount >= 3)
  {
    Print("ManageCycle -> Cycle trade limit reached (3 trades), waiting for positions to close");
    return;
  }

  // Stage machine
  switch(stage)
  {
    case NONE:
      if(!paused && OpenBuy(bid, ask))
      {
        stage = INITIAL_BUY;
        Print("→ Stage = INITIAL_BUY (fixed points trigger)");
      }
      break;
    case INITIAL_BUY:
      // Check if the initial BUY position is still valid.
      // If tBuy is 0 (trade never properly opened/recorded) or PositionSelectByTicket fails 
      // (e.g., position closed manually, by broker, or by another part of EA),
      // the expected state is lost, so reset the cycle.
      if(tBuy == 0 || !PositionSelectByTicket(tBuy))
      {
        Print("Initial BUY ticket invalid, resetting cycle");
        CloseAll();
        break;
      }
      if(OpenHedge(bid))
      {
        stage = HEDGE_SELL;
        Print("→ Stage = HEDGE_SELL (fixed points trigger)");
      }
      break;
    case HEDGE_SELL:
      // Check if the HEDGE SELL position is still valid.
      // If tHedge is 0 (trade never properly opened/recorded) or PositionSelectByTicket fails
      // (e.g., position closed manually, by broker, or by another part of EA),
      // the expected state for recovery logic is lost, so reset the cycle.
      if(tHedge == 0 || !PositionSelectByTicket(tHedge))
      {
        Print("Hedge SELL ticket invalid, resetting cycle");
        CloseAll();
        break;
      }
      if(OpenRecovery(bid, ask))
      {
        stage = RECOVERY_BUY;
        Print("→ Stage = RECOVERY_BUY (fixed points trigger)");
      }
      break;
    case RECOVERY_BUY:
      // Check if the RECOVERY BUY position is still valid.
      // If tRec is 0 (trade never properly opened/recorded) or PositionSelectByTicket fails
      // (e.g., position closed manually, by broker, or by another part of EA),
      // the EA considers its state uncertain and resets the cycle.
      if(tRec == 0 || !PositionSelectByTicket(tRec))
      {
        Print("Recovery BUY ticket invalid, resetting cycle");
        CloseAll();
        break;
      }
      break;
  }
}

//+------------------------------------------------------------------+
//| OnTick handler                                                   |
//+------------------------------------------------------------------+
void OnTick()
{
  if(!AutoTradeEnabled || _Symbol != TradeSymbol || Period() != PERIOD_M1) return;

  // Store the latest bid and ask prices on each tick
  lastBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
  lastAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

  // Check if any TP is hit and close all positions
  if(PositionsTotal() > 0)
  {
    // --- Initial BUY position TP check ---
    if(tBuy > 0)
    {
      if(PositionSelectByTicket(tBuy)) // Select the position AND check if selection is successful
      {
        long posType = PositionGetInteger(POSITION_TYPE);
        // Specific check for BUY position TP
        if(posType == POSITION_TYPE_BUY && lastBid >= buyTP)
        {
          PrintFormat("TP Hit -> Closing all positions (Initial BUY TP reached at %.5f >= %.5f, Ticket: %d)", lastBid, buyTP, tBuy);
          CloseAll();
          return;
        }
      }
      else 
      {
        // If PositionSelectByTicket fails, print a message
        PrintFormat("TP Check: Position with ticket %d (tBuy) could not be selected, skipping.", tBuy);
      }
    }

    // --- SELL Hedge position TP check ---
    if(tHedge > 0)
    {
      if(PositionSelectByTicket(tHedge)) // Select the position AND check if selection is successful
      {
        long posType = PositionGetInteger(POSITION_TYPE);
        // Specific check for SELL position TP
        if(posType == POSITION_TYPE_SELL && lastAsk <= hedgeTP)
        {
          PrintFormat("TP Hit -> Closing all positions (SELL Hedge TP reached at %.5f <= %.5f, Ticket: %d)", lastAsk, hedgeTP, tHedge);
          CloseAll();
          return;
        }
      }
      else 
      {
        // If PositionSelectByTicket fails, print a message
        PrintFormat("TP Check: Position with ticket %d (tHedge) could not be selected, skipping.", tHedge);
      }
    }

    // --- Recovery BUY position TP check ---
    if(tRec > 0)
    {
      if(PositionSelectByTicket(tRec)) // Select the position AND check if selection is successful
      {
        long posType = PositionGetInteger(POSITION_TYPE);
        // Specific check for BUY position TP
        if(posType == POSITION_TYPE_BUY && lastBid >= recTP)
        {
          PrintFormat("TP Hit -> Closing all positions (Recovery BUY TP reached at %.5f >= %.5f, Ticket: %d)", lastBid, recTP, tRec);
          CloseAll();
          return;
        }
      }
      else 
      {
        // If PositionSelectByTicket fails, print a message
        PrintFormat("TP Check: Position with ticket %d (tRec) could not be selected, skipping.", tRec);
      }
    }
  }

  datetime bar = iTime(_Symbol, PERIOD_M1, 0);
  if(bar != lastBar)
  {
    // Use the last recorded bid/ask as the "closing prices" of the previous candle
    PrintFormat("Candle Close -> bid=%.5f  ask=%.5f", lastBid, lastAsk);

    // Update lastBar and run safety checks
    lastBar = bar;
    Print("▶ New M1 bar: processing cycle");

    Safety();
    if(paused)
    {
      Print("OnTick -> trading paused at candle close");
      return;
    }

    // Execute trade logic using the closing prices
    ManageCycle(lastBid, lastAsk);
  }
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
  PrintFormat("PREBR22 v2.62 OnInit -> %s %s", TradeSymbol, EnumToString(PERIOD_M1));
  if(Period() != PERIOD_M1)
  {
    Print("ERROR: This EA runs only on M1 timeframe");
    return INIT_PARAMETERS_INCORRECT;
  }
  if(!SymbolInfoDouble(TradeSymbol, SYMBOL_BID))
  {
    Print("ERROR: Invalid TradeSymbol: ", TradeSymbol);
    return INIT_PARAMETERS_INCORRECT;
  }
  if(InitialLot <= 0 || MagicNumber == 0)
  {
    Print("ERROR: Invalid InitialLot or MagicNumber");
    return INIT_PARAMETERS_INCORRECT;
  }
  stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
  PrintFormat("Broker StopLevel: %d points", stopLevel);
  trade.SetExpertMagicNumber(MagicNumber);
  Print("MagicNumber set to ", MagicNumber);
  return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  string reasonText;
  switch(reason)
  {
    case REASON_PROGRAM:        reasonText = "EA stopped by user"; break;
    case REASON_CHARTCHANGE:    reasonText = "Chart symbol or timeframe changed"; break;
    case REASON_PARAMETERS:     reasonText = "Input parameters changed"; break;
    case REASON_ACCOUNT:        reasonText = "Account changed"; break;
    case REASON_INITFAILED:     reasonText = "Initialization failed"; break;
    case REASON_REMOVE:         reasonText = "EA removed from chart"; break;
    case REASON_RECOMPILE:      reasonText = "EA recompiled"; break;
    case REASON_CHARTCLOSE:     reasonText = "Chart closed"; break;
    case REASON_TEMPLATE:       reasonText = "Template changed"; break;
    default:                    reasonText = "Unknown reason: " + IntegerToString(reason); break;
  }
  PrintFormat("PREBR22 v2.62 OnDeinit -> reason=%d (%s)", reason, reasonText);
}
//+------------------------------------------------------------------+
