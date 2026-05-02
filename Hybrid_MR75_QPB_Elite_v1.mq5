//+------------------------------------------------------------------+
//|                                   Hybrid_MR75_QPB_Elite_v1.mq5   |
//|                      Hybrid Institutional Inflection System       |
//|          Combines MR75 Inflection + QPB Predictive Bands         |
//|                                 Elite Quant Systems 2025         |
//+------------------------------------------------------------------+
#property copyright "2025 Elite Quant Systems"
#property link      ""
#property version   "1.11"
#property description "Hybrid MR75 × QPB Elite - Institutional Confluence System (Improved v1.11)"
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
//| Global Objects & State Management                                |
//+------------------------------------------------------------------+
CMR75                g_mr75;
CQPB                 g_qpb;
CHybridSignalEngine  g_engine;
CHybridDisplay       g_display;

datetime             g_last_bar_time = 0;
HybridSignal         g_last_signal;
datetime             g_last_alert_bar_time = 0;
int                  g_last_alert_type = HYBRID_NONE;

// Performance optimization: cache dashboard state
int                  g_last_dashboard_shift = -1;
datetime             g_last_dashboard_update = 0;

// Error tracking
int                  g_init_error_count = 0;
datetime             g_last_error_log_time = 0;

//+------------------------------------------------------------------+
//| Input Validation Helper                                          |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
   bool all_valid = true;

   if(InpMinRR <= 0.0)
   {
      Print("ERROR: InpMinRR must be > 0, got ", InpMinRR);
      all_valid = false;
   }

   if(InpMinConfidence < 0.0 || InpMinConfidence > 100.0)
   {
      Print("ERROR: InpMinConfidence must be within [0, 100], got ", InpMinConfidence);
      all_valid = false;
   }

   if(InpMaxSignalAgeBars < 1)
   {
      Print("ERROR: InpMaxSignalAgeBars must be >= 1, got ", InpMaxSignalAgeBars);
      all_valid = false;
   }

   if(InpATRPeriod < 2)
   {
      Print("ERROR: InpATRPeriod must be >= 2, got ", InpATRPeriod);
      all_valid = false;
   }

   if(InpMaxDistToBandATR < 0.0)
   {
      Print("ERROR: InpMaxDistToBandATR must be >= 0, got ", InpMaxDistToBandATR);
      all_valid = false;
   }

   if(InpMinZScoreStretch < 0.0 || InpMaxZScoreStretch <= InpMinZScoreStretch)
   {
      Print("ERROR: Z-Score bounds invalid. Require max > min >= 0. Got min=", 
            InpMinZScoreStretch, " max=", InpMaxZScoreStretch);
      all_valid = false;
   }

   if(InpTimerSeconds < 1)
   {
      Print("ERROR: InpTimerSeconds must be >= 1, got ", InpTimerSeconds);
      all_valid = false;
   }

   // Validate timeframe consistency
   if(InpSignalTF >= InpBandsTF)
   {
      Print("WARNING: Signal timeframe should typically be lower than bands timeframe. ",
            "Signal TF=", EnumToString(InpSignalTF), " Bands TF=", EnumToString(InpBandsTF));
   }

   return all_valid;
}

//+------------------------------------------------------------------+
//| Plot Initialization Helper                                       |
//+------------------------------------------------------------------+
void SetPlotDefaults()
{
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
}

//+------------------------------------------------------------------+
//| Alert Management Helper                                          |
//+------------------------------------------------------------------+
void MaybeFireAlert(const HybridSignal &signal, const datetime bar_time)
{
   if(!InpEnableAlerts)
      return;

   // Prevent duplicate alerts on the same bar and same signal type
   if(signal.type == g_last_alert_type && bar_time == g_last_alert_bar_time)
      return;

   if(signal.type == HYBRID_NONE)
      return;  // Don't fire alerts for neutral signals

   g_display.FireAlert(signal, _Symbol, EnumToString(InpSignalTF));
   g_last_alert_type = signal.type;
   g_last_alert_bar_time = bar_time;

   if(InpShowDebug)
      PrintFormat("Alert fired: Type=%d at %s (Bar confidence: %.2f%%)",
                  signal.type, TimeToString(bar_time, TIME_DATE|TIME_MINUTES), 
                  signal.confidence.total);
}

//+------------------------------------------------------------------+
//| Dashboard Update with Performance Optimization                   |
//+------------------------------------------------------------------+
void UpdateDashboardAtShift(const int shift)
{
   if(!InpShowDashboard)
      return;

   // Skip redundant updates within the same bar
   if(shift == g_last_dashboard_shift)
   {
      datetime current_time = TimeCurrent();
      if(current_time - g_last_dashboard_update < 1)  // Don't update more than once per second
         return;
   }

   // Attempt to refresh core indicators
   if(!g_mr75.Refresh(shift))
   {
      if(InpShowDebug)
         PrintFormat("WARNING: MR75 refresh failed at shift %d", shift);
      return;
   }

   if(!g_qpb.Refresh(shift))
   {
      if(InpShowDebug)
         PrintFormat("WARNING: QPB refresh failed at shift %d", shift);
      return;
   }

   // Evaluate signal
   HybridSignal eval = g_engine.EvaluateSignal(
      g_mr75,
      g_qpb,
      _Symbol,
      InpSignalTF,
      shift
   );

   // Fallback to last valid signal if current evaluation is invalid
   if(!eval.valid && g_last_signal.valid)
   {
      eval = g_last_signal;
      if(InpShowDebug)
         PrintFormat("Using cached signal from previous bar at shift %d", shift);
   }

   // Update display
   if(eval.valid)
   {
      g_display.UpdateDashboard(eval, g_mr75, g_qpb);
      g_last_dashboard_shift = shift;
      g_last_dashboard_update = TimeCurrent();
   }
   else if(InpShowDebug)
   {
      PrintFormat("Dashboard update skipped: no valid signal at shift %d", shift);
   }
}

//+------------------------------------------------------------------+
//| Confidence Validation Helper                                     |
//+------------------------------------------------------------------+
bool IsConfidenceValid(double confidence)
{
   return confidence >= 0.0 && confidence <= 100.0;
}

//+------------------------------------------------------------------+
//| ATR Validation Helper                                            |
//+------------------------------------------------------------------+
bool IsATRValid(double atr)
{
   return atr > 0.0 && atr < DBL_MAX;  // Check for positive and finite value
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!ValidateInputs())
   {
      Print("FATAL: Input validation failed. Aborting initialization.");
      g_init_error_count++;
      return(INIT_PARAMETERS_INCORRECT);
   }

   // Setup Buy signal buffer
   SetIndexBuffer(0, BuyBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(0, PLOT_ARROW, InpArrowCode);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpBuyArrowColor);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpArrowSize);
   PlotIndexSetString(0, PLOT_LABEL, "Hybrid BUY");

   // Setup Sell signal buffer
   SetIndexBuffer(1, SellBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(1, PLOT_ARROW, InpArrowCode);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpSellArrowColor);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpArrowSize);
   PlotIndexSetString(1, PLOT_LABEL, "Hybrid SELL");

   // Setup calculation buffers (internal use)
   SetIndexBuffer(2, ConfBuyBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, ConfSellBuffer, INDICATOR_CALCULATIONS);

   // Configure all buffers as time-series
   ArraySetAsSeries(BuyBuffer, true);
   ArraySetAsSeries(SellBuffer, true);
   ArraySetAsSeries(ConfBuyBuffer, true);
   ArraySetAsSeries(ConfSellBuffer, true);

   // Initialize buffers with safe default values
   ArrayInitialize(BuyBuffer, EMPTY_VALUE);
   ArrayInitialize(SellBuffer, EMPTY_VALUE);
   ArrayInitialize(ConfBuyBuffer, 0.0);
   ArrayInitialize(ConfSellBuffer, 0.0);
   SetPlotDefaults();

   // Initialize MR75 core
   if(!g_mr75.Init(_Symbol, InpSignalTF))
   {
      Print("FATAL: Failed to initialize MR75 wrapper");
      g_init_error_count++;
      return(INIT_FAILED);
   }

   // Initialize QPB core
   if(!g_qpb.Init(_Symbol, InpSignalTF, InpBandsTF))
   {
      Print("FATAL: Failed to initialize QPB wrapper");
      g_mr75.Deinit();
      g_init_error_count++;
      return(INIT_FAILED);
   }

   // Initialize signal evaluation engine
   g_engine.Initialize(
      InpMinRR,
      InpMinConfidence,
      InpMinMR75Grade,
      InpMaxSignalAgeBars,
      InpMaxDistToBandATR,
      InpMinZScoreStretch,
      InpMaxZScoreStretch
   );

   // Initialize display module
   g_display.Initialize(
      InpShowDashboard,
      InpShowDebug,
      InpEnableAlerts,
      InpAlertPopup,
      InpAlertSound,
      InpAlertPush
   );

   // Set indicator metadata
   string short_name = StringFormat("Hybrid MR75×QPB Elite v1.11 [%s]", EnumToString(InpSignalTF));
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   // Setup real-time updates if enabled
   if(InpRealtimeDashboard && InpShowDashboard)
   {
      EventSetTimer(InpTimerSeconds);
      if(InpShowDebug)
         PrintFormat("Real-time dashboard timer initialized: %d seconds", InpTimerSeconds);
   }

   // Initialize state tracking
   g_last_signal.type = HYBRID_NONE;
   g_last_signal.valid = false;
   g_last_alert_type = HYBRID_NONE;
   g_last_alert_bar_time = 0;
   g_last_dashboard_shift = -1;
   g_last_dashboard_update = 0;

   Print("═══════════════════════════════════════════════════════════");
   Print("Hybrid MR75 × QPB Elite v1.11 INITIALIZED SUCCESSFULLY");
   Print("Signal TF: ", EnumToString(InpSignalTF), " | Bands TF: ", EnumToString(InpBandsTF));
   Print("Min Confidence: ", InpMinConfidence, "% | Min RR: ", InpMinRR);
   Print("═══════════════════════════════════════════════════════════");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up timer if active
   if(InpRealtimeDashboard && InpShowDashboard)
   {
      EventKillTimer();
      if(InpShowDebug)
         Print("Real-time dashboard timer stopped");
   }

   // Deinitialize core modules
   g_mr75.Deinit();
   g_qpb.Deinit();
   g_display.Cleanup();

   // Clear chart objects and comments
   Comment("");
   ObjectsDeleteAll(0, "Hybrid_", 0, -1);
   ObjectsDeleteAll(0, "MR75_", 0, -1);
   ObjectsDeleteAll(0, "QPB_", 0, -1);
   ChartRedraw(0);

   string reason_text = "";
   switch(reason)
   {
      case REASON_ACCOUNT:    reason_text = "Account changed"; break;
      case REASON_CHARTCHANGE: reason_text = "Chart changed"; break;
      case REASON_CHARTCLOSE: reason_text = "Chart closed"; break;
      case REASON_PARAMETERS: reason_text = "Parameters changed"; break;
      case REASON_RECOMPILE:  reason_text = "Recompiled"; break;
      case REASON_REMOVE:     reason_text = "Removed"; break;
      case REASON_TEMPLATE:   reason_text = "Template loaded"; break;
      default:                reason_text = "Unknown"; break;
   }

   Print("═══════════════════════════════════════════════════════════");
   Print("Hybrid MR75 × QPB Elite v1.11 DEINITIALIZED");
   Print("Reason: ", reason_text, " (Code: ", reason, ")");
   Print("═══════════════════════════════════════════════════════════");
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
   // Ensure minimum history
   if(rates_total < InpATRPeriod + 100)
      return(0);

   // Configure arrays as time-series
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   // Calculate processing range
   int max_shift = rates_total - 2;  // Last closed bar is at shift 1
   int start_shift = (prev_calculated > 0) ? 1 : MathMin(max_shift, rates_total - (InpATRPeriod + 51));

   // Main calculation loop
   for(int shift = start_shift; shift <= max_shift; shift++)
   {
      // Reset buffers for this bar
      BuyBuffer[shift] = EMPTY_VALUE;
      SellBuffer[shift] = EMPTY_VALUE;
      ConfBuyBuffer[shift] = 0.0;
      ConfSellBuffer[shift] = 0.0;

      // Refresh core indicators
      if(!g_mr75.Refresh(shift))
      {
         if(InpShowDebug && shift == 1)
            PrintFormat("ERROR: MR75 refresh failed at bar %d (%s)", 
                        shift, TimeToString(time[shift], TIME_DATE|TIME_MINUTES));
         continue;
      }

      if(!g_qpb.Refresh(shift))
      {
         if(InpShowDebug && shift == 1)
            PrintFormat("ERROR: QPB refresh failed at bar %d (%s)", 
                        shift, TimeToString(time[shift], TIME_DATE|TIME_MINUTES));
         continue;
      }

      // Evaluate signal
      HybridSignal signal = g_engine.EvaluateSignal(g_mr75, g_qpb, _Symbol, InpSignalTF, shift);

      if(!signal.valid)
      {
         if(InpShowDebug && shift == 1)
         {
            PrintFormat("Signal REJECTED at %s: %s",
                        TimeToString(time[shift], TIME_DATE|TIME_MINUTES),
                        signal.reject_reason);
         }
         continue;
      }

      // Validate and retrieve ATR
      double atr = g_qpb.GetATR(shift);
      if(!IsATRValid(atr))
      {
         if(InpShowDebug && shift == 1)
            PrintFormat("ERROR: Invalid ATR value (%.6f) at shift %d", atr, shift);
         continue;
      }

      // Validate confidence value
      if(!IsConfidenceValid(signal.confidence.total))
      {
         if(InpShowDebug && shift == 1)
            PrintFormat("ERROR: Invalid confidence value (%.2f) at shift %d. Must be [0-100]", 
                        signal.confidence.total, shift);
         continue;
      }

      // Process BUY signals
      if(signal.type == HYBRID_BUY)
      {
         BuyBuffer[shift] = low[shift] - (0.3 * atr);
         ConfBuyBuffer[shift] = signal.confidence.total;

         if(shift == 1)
         {
            MaybeFireAlert(signal, time[shift]);
            if(InpShowDebug)
               PrintFormat("BUY Signal: Bar=%s, Confidence=%.2f%%, Shift=%d",
                           TimeToString(time[shift], TIME_DATE|TIME_MINUTES),
                           signal.confidence.total, shift);
         }
      }
      // Process SELL signals
      else if(signal.type == HYBRID_SELL)
      {
         SellBuffer[shift] = high[shift] + (0.3 * atr);
         ConfSellBuffer[shift] = signal.confidence.total;

         if(shift == 1)
         {
            MaybeFireAlert(signal, time[shift]);
            if(InpShowDebug)
               PrintFormat("SELL Signal: Bar=%s, Confidence=%.2f%%, Shift=%d",
                           TimeToString(time[shift], TIME_DATE|TIME_MINUTES),
                           signal.confidence.total, shift);
         }
      }

      // Update cached signal state (keep most recent)
      if(shift <= 1)
         g_last_signal = signal;
   }

   // Update dashboard if enabled
   if(InpShowDashboard)
      UpdateDashboardAtShift(0);

   // Track last processed bar time
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
   // Currently not implemented - add handlers as needed
}
