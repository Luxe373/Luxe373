//+------------------------------------------------------------------+
//|                                   Hybrid_MR75_QPB_Elite_v1.mq5   |
//|                      Hybrid Institutional Inflection System       |
//|          Combines MR75 Inflection + QPB Predictive Bands         |
//|                                 Elite Quant Systems 2025         |
//+------------------------------------------------------------------+
#property copyright "2025 Elite Quant Systems"
#property link      ""
#property version   "1.10"
#property description "Hybrid MR75 × QPB Elite - Institutional Confluence System"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2

#include <Hybrid/MR75_Core.mqh>
#include <Hybrid/QPB_Core.mqh>
#include <Hybrid/Hybrid_SignalEngine.mqh>
#include <Hybrid/Hybrid_Display.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "═══════════ Timeframes ═══════════"
input ENUM_TIMEFRAMES InpSignalTF          = PERIOD_H1;      // Signal Timeframe
input ENUM_TIMEFRAMES InpBandsTF           = PERIOD_H4;      // Bands Timeframe (QPB)
input ENUM_TIMEFRAMES InpHTF1              = PERIOD_D1;      // Reserved for alignment logic
input ENUM_TIMEFRAMES InpHTF2              = PERIOD_W1;      // Reserved for alignment logic

input group "═══════════ Quality Filters ═══════════"
input double          InpMinRR             = 1.8;            // Minimum Risk:Reward Ratio
input double          InpMinConfidence     = 80.0;           // Minimum Confidence Score (0-100)
input MR75_Grade      InpMinMR75Grade      = MR75_GRADE_B;   // Minimum MR75 Grade
input int             InpMaxSignalAgeBars  = 1;              // Max Signal Age (bars)

input group "═══════════ Proximity to Bands ═══════════"
input double          InpMaxDistToBandATR  = 0.25;           // Max Distance to Band (× ATR)
input double          InpMinZScoreStretch  = 1.0;            // Min Z-Score Stretch
input double          InpMaxZScoreStretch  = 2.5;            // Max Z-Score Stretch

input group "═══════════ ATR Settings ═══════════"
input int             InpATRPeriod         = 14;             // ATR Period
input ENUM_APPLIED_PRICE InpATRPrice       = PRICE_CLOSE;    // Reserved for ATR source

input group "═══════════ Visual Settings ═══════════"
input color           InpBuyArrowColor     = clrLime;        // Buy Arrow Color
input color           InpSellArrowColor    = clrTomato;      // Sell Arrow Color
input int             InpArrowCode         = 233;            // Arrow Code (Wingdings)
input int             InpArrowSize         = 2;              // Arrow Size
input bool            InpShowDashboard     = true;           // Show Dashboard Panel
input bool            InpShowDebug         = false;          // Show Debug Info
input bool            InpRealtimeDashboard = false;          // Update dashboard via timer
input int             InpTimerSeconds      = 2;              // Timer interval in seconds

input group "═══════════ Alerts ═══════════"
input bool            InpEnableAlerts      = true;           // Enable Alerts
input bool            InpAlertPopup        = true;           // Alert Popup
input bool            InpAlertSound        = false;          // Alert Sound
input bool            InpAlertPush         = false;          // Push Notification

//+------------------------------------------------------------------+
//| Indicator Buffers                                                |
//+------------------------------------------------------------------+
double BuyBuffer[];
double SellBuffer[];
double ConfBuyBuffer[];
double ConfSellBuffer[];

//+------------------------------------------------------------------+
//| Global Objects                                                   |
//+------------------------------------------------------------------+
CMR75                g_mr75;
CQPB                 g_qpb;
CHybridSignalEngine  g_engine;
CHybridDisplay       g_display;

datetime             g_last_bar_time = 0;
HybridSignal         g_last_signal;
datetime             g_last_alert_bar_time = 0;
int                  g_last_alert_type = HYBRID_NONE;

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
   if(InpMinRR <= 0.0)
   {
      Print("ERROR: InpMinRR must be > 0");
      return(false);
   }

   if(InpMinConfidence < 0.0 || InpMinConfidence > 100.0)
   {
      Print("ERROR: InpMinConfidence must be within [0, 100]");
      return(false);
   }

   if(InpMaxSignalAgeBars < 1)
   {
      Print("ERROR: InpMaxSignalAgeBars must be >= 1");
      return(false);
   }

   if(InpATRPeriod < 2)
   {
      Print("ERROR: InpATRPeriod must be >= 2");
      return(false);
   }

   if(InpMaxDistToBandATR < 0.0)
   {
      Print("ERROR: InpMaxDistToBandATR must be >= 0");
      return(false);
   }

   if(InpMinZScoreStretch < 0.0 || InpMaxZScoreStretch <= InpMinZScoreStretch)
   {
      Print("ERROR: Z-Score bounds are invalid. Require max > min >= 0");
      return(false);
   }

   if(InpTimerSeconds < 1)
   {
      Print("ERROR: InpTimerSeconds must be >= 1");
      return(false);
   }

   return(true);
}

void SetPlotDefaults()
{
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
}

void MaybeFireAlert(const HybridSignal &signal, const datetime bar_time)
{
   if(!InpEnableAlerts)
      return;

   if(signal.type == g_last_alert_type && bar_time == g_last_alert_bar_time)
      return;

   g_display.FireAlert(signal, _Symbol, EnumToString(InpSignalTF));
   g_last_alert_type = signal.type;
   g_last_alert_bar_time = bar_time;
}

void UpdateDashboardAtShift(const int shift)
{
   if(!InpShowDashboard)
      return;

   if(!g_mr75.Refresh(shift) || !g_qpb.Refresh(shift))
      return;

   HybridSignal eval = g_engine.EvaluateSignal(
      g_mr75,
      g_qpb,
      _Symbol,
      InpSignalTF,
      shift
   );

   if(!eval.valid && g_last_signal.valid)
      eval = g_last_signal;

   g_display.UpdateDashboard(eval, g_mr75, g_qpb);
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!ValidateInputs())
      return(INIT_PARAMETERS_INCORRECT);

   SetIndexBuffer(0, BuyBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(0, PLOT_ARROW, InpArrowCode);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpBuyArrowColor);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpArrowSize);
   PlotIndexSetString(0, PLOT_LABEL, "Hybrid BUY");

   SetIndexBuffer(1, SellBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(1, PLOT_ARROW, InpArrowCode);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpSellArrowColor);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpArrowSize);
   PlotIndexSetString(1, PLOT_LABEL, "Hybrid SELL");

   SetIndexBuffer(2, ConfBuyBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, ConfSellBuffer, INDICATOR_CALCULATIONS);

   ArraySetAsSeries(BuyBuffer, true);
   ArraySetAsSeries(SellBuffer, true);
   ArraySetAsSeries(ConfBuyBuffer, true);
   ArraySetAsSeries(ConfSellBuffer, true);

   ArrayInitialize(BuyBuffer, EMPTY_VALUE);
   ArrayInitialize(SellBuffer, EMPTY_VALUE);
   ArrayInitialize(ConfBuyBuffer, 0);
   ArrayInitialize(ConfSellBuffer, 0);
   SetPlotDefaults();

   if(!g_mr75.Init(_Symbol, InpSignalTF))
   {
      Print("ERROR: Failed to initialize MR75 wrapper");
      return(INIT_FAILED);
   }

   if(!g_qpb.Init(_Symbol, InpSignalTF, InpBandsTF))
   {
      Print("ERROR: Failed to initialize QPB wrapper");
      g_mr75.Deinit();
      return(INIT_FAILED);
   }

   g_engine.Initialize(
      InpMinRR,
      InpMinConfidence,
      InpMinMR75Grade,
      InpMaxSignalAgeBars,
      InpMaxDistToBandATR,
      InpMinZScoreStretch,
      InpMaxZScoreStretch
   );

   g_display.Initialize(
      InpShowDashboard,
      InpShowDebug,
      InpEnableAlerts,
      InpAlertPopup,
      InpAlertSound,
      InpAlertPush
   );

   string short_name = StringFormat("Hybrid MR75×QPB Elite v1.10 [%s]", EnumToString(InpSignalTF));
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   if(InpRealtimeDashboard && InpShowDashboard)
      EventSetTimer(InpTimerSeconds);

   g_last_signal.type = HYBRID_NONE;
   g_last_signal.valid = false;
   g_last_alert_type = HYBRID_NONE;
   g_last_alert_bar_time = 0;

   Print("Hybrid MR75 × QPB Elite v1.10 initialized");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(InpRealtimeDashboard && InpShowDashboard)
      EventKillTimer();

   g_mr75.Deinit();
   g_qpb.Deinit();
   g_display.Cleanup();

   Comment("");
   ObjectsDeleteAll(0, "Hybrid_", 0, -1);
   ObjectsDeleteAll(0, "MR75_", 0, -1);
   ObjectsDeleteAll(0, "QPB_", 0, -1);
   ChartRedraw(0);

   Print("Hybrid MR75 × QPB Elite deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   if(rates_total < InpATRPeriod + 100)
      return(0);

   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   int max_shift = rates_total - 2; // last closed bar is shift 1
   int start_shift = (prev_calculated > 0) ? 1 : MathMin(max_shift, rates_total - (InpATRPeriod + 51));

   for(int shift = start_shift; shift <= max_shift; shift++)
   {
      if(shift < 0 || shift >= rates_total)
         continue;

      BuyBuffer[shift] = EMPTY_VALUE;
      SellBuffer[shift] = EMPTY_VALUE;
      ConfBuyBuffer[shift] = 0;
      ConfSellBuffer[shift] = 0;

      if(!g_mr75.Refresh(shift) || !g_qpb.Refresh(shift))
         continue;

      HybridSignal signal = g_engine.EvaluateSignal(g_mr75, g_qpb, _Symbol, InpSignalTF, shift);

      if(!signal.valid)
      {
         if(InpShowDebug && shift == 1)
         {
            PrintFormat("Signal rejected at %s: %s",
                        TimeToString(time[shift], TIME_DATE | TIME_MINUTES),
                        signal.reject_reason);
         }
         continue;
      }

      double atr = g_qpb.GetATR(shift);
      if(atr <= 0.0)
         continue;

      if(signal.type == HYBRID_BUY)
      {
         BuyBuffer[shift] = low[shift] - (0.3 * atr);
         ConfBuyBuffer[shift] = signal.confidence.total;

         if(shift == 1)
            MaybeFireAlert(signal, time[shift]);
      }
      else if(signal.type == HYBRID_SELL)
      {
         SellBuffer[shift] = high[shift] + (0.3 * atr);
         ConfSellBuffer[shift] = signal.confidence.total;

         if(shift == 1)
            MaybeFireAlert(signal, time[shift]);
      }

      if(shift <= 1)
         g_last_signal = signal;
   }

   if(InpShowDashboard)
      UpdateDashboardAtShift(0);

   if(rates_total > 0)
      g_last_bar_time = time[0];

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Timer function (optional - for real-time dashboard updates)      |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(InpRealtimeDashboard && InpShowDashboard)
      UpdateDashboardAtShift(0);
}

//+------------------------------------------------------------------+
//| ChartEvent function (optional - for interactive features)        |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Reserved for future interaction (e.g., dashboard toggles)
}
