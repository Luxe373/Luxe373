//+------------------------------------------------------------------+
//|                                               PriceActionSRTL.mq5 |
//|                        Copyright 2023, XYZ Company (Developer) |
//|                                             https://www.xyz.com |
//|                                                                  |
//|    Comprehensive S/R, Price Action, and Trendline Indicator    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, XYZ Company (Developer)"
#property link      "https://www.xyz.com"
#property version   "1.18" // Fix critical compilation errors

#property indicator_chart_window
#property indicator_buffers 1 // For a dummy buffer
#property indicator_plots   0 // No visible plots from buffers

//--- Input Parameters (Organized for Clarity) ---

// General Settings
input int  InpMaxBarsToScan       = 500;  // General: Max historical bars for S/R fractal scan

// Support & Resistance (S/R) Settings
input int  InpFractalLookbackPeriod = 5;    // S/R: Bars left/right for standard fractal definition
input int  InpNumResistanceLevels = 2;    // S/R: Number of resistance levels to display
input int  InpNumSupportLevels    = 2;    // S/R: Number of support levels to display

// Price Action Pattern Settings
input group "Price Action Patterns"
input bool InpEnableEngulfing        = true;   // PA: Enable/disable Engulfing pattern detection
input bool InpEnablePinBars          = true;   // PA: Enable/disable Pin Bar pattern detection
input bool InpEnableDojiAtSR         = true;   // PA: Enable/disable Doji at S/R detection
//input double InpPinBarWickToBodyRatio = 2.5;    // PA: (Old) Minimum ratio of wick to body for Pin Bars - Replaced by ATR
input int  InpDojiMaxBodySizePoints  = 5;      // PA: Maximum body size in points for a Doji (kept points-based for Doji body definition)
//input int  InpDojiProximityToSRPoints= 10;     // PA: (Old) Proximity in points for a Doji to be "near" S/R - Replaced by ATR
input int  InpDojiSignalArrowCode    = 171;    // PA: Arrow code for Doji signal (e.g., 171 for a small circle/dot)

// Trendline Detection Settings
input group "Trendline Detection"
input bool   InpEnableTrendlines       = true;   // TL: Enable/disable Trendline detection
input int    InpMinFractalsForTrendline= 2;      // TL: Minimum fractal points to define a trendline (2 or 3 typical)
input int    InpTrendlineLookbackBars  = 100;    // TL: How many bars back to look for fractal points for trendlines
//input int    InpTrendlinePenetrationTolerancePoints = 5; // TL: (Old) Tolerance (points) for price penetration - Replaced by ATR
input int    InpTrendlineExtensionBars = 20;     // TL: How many bars to extend trendline if not using RAY_RIGHT (visual)
input int    InpMaxUptrendLines        = 1;      // TL: Max number of uptrend lines to display
input int    InpMaxDowntrendLines      = 1;      // TL: Max number of downtrend lines to display

// ATR Dynamic Thresholds
input group "ATR Dynamic Thresholds"
input int    InpATRPeriodForThresholds = 14;     // ATR: Period for dynamic thresholds
input double InpTrendlineToleranceATRMultiplier = 0.2; // ATR: Multiplier for Trendline Penetration
input double InpDojiProximityATRMultiplier    = 0.1; // ATR: Multiplier for Doji Proximity to S/R
input double InpPinBarMinWickATRMultiplier    = 0.5; // ATR: Multiplier for PinBar Minimum Wick Size
input double InpPinBarMaxBodyATRMultiplier    = 0.2; // ATR: Multiplier for PinBar Maximum Body Size

// Confluence Filter Settings
input group "Confluence Filter Settings"
input bool   InpEnableConfluenceFilter = true;    // Enable/disable the confluence filter
input double InpConfluenceMaxDistToSR_ATR_Mult = 0.15; // Max distance to S/R (ATR Multiplier)
input double InpConfluenceMaxDistToTL_ATR_Mult = 0.15; // Max distance to Trendline (ATR Multiplier)

// Alert Configuration
input group "Alerts"
input bool   InpEnableAlerts           = true;   // Alerts: Enable/Disable all alerts for Price Action patterns

// Performance Settings
input group "Performance Settings"
input bool InpEnableBenchmarking     = false;  // Enable/disable performance logging

//--- Indicator Buffers ---
double DummyBuffer[]; // Dummy buffer for indicator plot requirements

//--- Global Variables & Object Prefixes ---
string resistanceLinePrefix = "ResLevel_"; 
string supportLinePrefix    = "SupLevel_"; 
string bullishEngulfingSignalPrefix = "BullEng_"; 
string bearishEngulfingSignalPrefix = "BearEng_"; 
string bullishPinBarSignalPrefix    = "BullPB_";  
string bearishPinBarSignalPrefix    = "BearPB_";  
string dojiAtSRSignalPrefix         = "DojiSR_";  
string uptrendLinePrefix   = "UTL_"; 
string downtrendLinePrefix = "DTL_"; 
double fractalUp[];   
double fractalDown[]; 
int lastAlertBar = -1; 
double g_atr_value = 0.0;


//+------------------------------------------------------------------+
//| Data Structure for Storing Fractal Point Information             |
//+------------------------------------------------------------------+
struct FractalPoint
  {
   datetime time;      
   double   price;     
   int      index;     
   bool     isHigh;    
  };

//+------------------------------------------------------------------+
//| Data Structure for Storing Trendline Information                 |
//+------------------------------------------------------------------+
struct TrendlineInfo
  {
   FractalPoint p1;            
   FractalPoint p2;            
   double       slope;         
   double       intercept;     
   int          numTouches;    
   bool         isUptrend;     
   datetime     lastTouchTime; 
   long         score;         
  };

//--- Function Prototypes for Helper Functions ---
void CalculateFractalsAndDrawSR(int current_rates_total, const datetime &current_time[], const double &current_high[], const double &current_low[]);
void CalculateAndDrawTrendlines(int current_rates_total, const datetime &current_time[], const double &current_high[], const double &current_low[]);
void DetectAndDrawPricePatterns(int current_prev_calculated, int current_rates_total, const datetime &current_time[], const double &current_open[], const double &current_high[], const double &current_low[], const double &current_close[]);
void CleanupAllIndicatorObjects();
void CleanupSRAndTrendlineObjects();
void MaybeAlert(string message, int bar_idx, int current_rates_total); // Kept original signature as no error was reported for it
bool IsPinBar(int bar_idx, bool isBullishSignal, const double &open[], const double &high[], const double &low[], const double &close[], double minWickAbs, double maxBodyAbs);
bool IsDojiNearSR(int bar_idx, const double &open[], const double &high[], const double &low[], const double &close[],
                  int maxBodyPoints, double maxProximityAbsDistance, 
                  const string resPrefix, const string supPrefix, 
                  int numResLevels, int numSupLevels);
double GetNearestSRLevelInfo(int bar_idx, const double &high[], const double &low[], bool &isResistanceHit, int &hitLevelIndex);
double GetDistanceToNearestTrendline(int bar_idx, const datetime &time[], const double &high[], const double &low[], bool checkUptrendLines, int &hitTrendlineIndex);


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   SetIndexBuffer(0, DummyBuffer, INDICATOR_CALCULATIONS);
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   CleanupAllIndicatorObjects(); 
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
   int min_bars_required = MathMax(InpFractalLookbackPeriod * 2 + 1, InpTrendlineLookbackBars);
   min_bars_required = MathMax(min_bars_required, InpATRPeriodForThresholds +1); 
   if (rates_total < min_bars_required)
     {
      if(prev_calculated == 0) Print("PriceActionSRTL: Not enough bars for calculation. Bars: ", rates_total, ", Need: ", min_bars_required);
      return(0); 
     }

   static datetime lastBarTime = 0;
   bool isNewBar = false;
   if(time[0] != lastBarTime)
     {
      lastBarTime = time[0];
      isNewBar = true;
     }

   if(isNewBar)
     {
      double atr_buffer[];
      if(CopyBuffer(iATR(_Symbol, _Period, InpATRPeriodForThresholds), 0, 1, 1, atr_buffer) > 0) 
         g_atr_value = atr_buffer[0];
      else
         g_atr_value = _Point * 10; 
      
      if(g_atr_value <= 0) g_atr_value = _Point * 10; 

      CleanupSRAndTrendlineObjects(); 

      if(InpEnableBenchmarking)
        {
         uint t0_sr = GetTickCount();
         CalculateFractalsAndDrawSR(rates_total, time, high, low);
         PrintFormat("PriceActionSRTL: S/R calculation took %d ms", GetTickCount() - t0_sr);
        }
      else CalculateFractalsAndDrawSR(rates_total, time, high, low);

      if(InpEnableTrendlines)
        {
         if(InpEnableBenchmarking)
           {
            uint t0_tl = GetTickCount();
            CalculateAndDrawTrendlines(rates_total, time, high, low);
            PrintFormat("PriceActionSRTL: Trendline calculation took %d ms", GetTickCount() - t0_tl);
           }
         else CalculateAndDrawTrendlines(rates_total, time, high, low);
        }
        
      if(InpEnableBenchmarking)
        {
         uint t0_pa_newbar = GetTickCount();
         DetectAndDrawPricePatterns(rates_total - 1, rates_total, time, open, high, low, close);
         PrintFormat("PriceActionSRTL: PA detection (on new bar tick benchmark) took %d ms", GetTickCount() - t0_pa_newbar);
        }
     }

   DetectAndDrawPricePatterns(prev_calculated, rates_total, time, open, high, low, close);
   
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Cleanup S/R and Trendline Objects                                |
//+------------------------------------------------------------------+
void CleanupSRAndTrendlineObjects()
  {
   int totalObjects = ObjectsTotal(0, 0, -1); 
   string objName;
   for(int i = totalObjects - 1; i >= 0; i--)
     {
      objName = ObjectName(0, i, 0, -1); 
      if(StringFind(objName, resistanceLinePrefix, 0) == 0 ||
         StringFind(objName, supportLinePrefix, 0) == 0 ||
         StringFind(objName, uptrendLinePrefix, 0) == 0 ||
         StringFind(objName, downtrendLinePrefix, 0) == 0)
        {
         ObjectDelete(0, objName);
        }
     }
  }

//+------------------------------------------------------------------+
//| Cleanup All Indicator-Specific Objects                           |
//+------------------------------------------------------------------+
void CleanupAllIndicatorObjects()
  {
   int totalObjects = ObjectsTotal(0, 0, -1); 
   string objName;
   for(int i = totalObjects - 1; i >= 0; i--)
     {
      objName = ObjectName(0, i, 0, -1); 

      if(StringFind(objName, resistanceLinePrefix, 0) == 0 ||
         StringFind(objName, supportLinePrefix, 0) == 0 ||
         StringFind(objName, bullishEngulfingSignalPrefix, 0) == 0 ||
         StringFind(objName, bearishEngulfingSignalPrefix, 0) == 0 ||
         StringFind(objName, bullishPinBarSignalPrefix, 0) == 0 ||
         StringFind(objName, bearishPinBarSignalPrefix, 0) == 0 ||
         StringFind(objName, dojiAtSRSignalPrefix, 0) == 0 ||
         StringFind(objName, uptrendLinePrefix, 0) == 0 ||
         StringFind(objName, downtrendLinePrefix, 0) == 0)
        {
         ObjectDelete(0, objName);
        }
     }
  }

//+------------------------------------------------------------------+
//| Calculate Fractals and Draw Support/Resistance Levels            |
//+------------------------------------------------------------------+
void CalculateFractalsAndDrawSR(int current_rates_total, const datetime &current_time[], const double &current_high[], const double &current_low[])
  {
   int srLookbackBars = MathMin(current_rates_total, InpMaxBarsToScan);
    
   if(ArraySize(fractalUp) != current_rates_total) ArrayResize(fractalUp, current_rates_total);
   ArrayInitialize(fractalUp, EMPTY_VALUE); 
   
   if(ArraySize(fractalDown) != current_rates_total) ArrayResize(fractalDown, current_rates_total);
   ArrayInitialize(fractalDown, EMPTY_VALUE);

   for(int i = InpFractalLookbackPeriod; i < current_rates_total - InpFractalLookbackPeriod; i++)
     {
      bool isUpFractal = true;
      for(int j = 1; j <= InpFractalLookbackPeriod; j++)
        {
         if(current_high[i] <= current_high[i-j] || current_high[i] <= current_high[i+j]) { isUpFractal = false; break; }
        }
      if(isUpFractal) fractalUp[i] = current_high[i];

      bool isDownFractal = true;
      for(int j = 1; j <= InpFractalLookbackPeriod; j++)
        {
         if(current_low[i] >= current_low[i-j] || current_low[i] >= current_low[i+j]) { isDownFractal = false; break; }
        }
      if(isDownFractal) fractalDown[i] = current_low[i];
     }

   double resistancePrices[]; 
   double supportPrices[];    
   int resistanceCount = 0;
   int supportCount = 0;
   int srFractalScanStartBar = MathMax(InpFractalLookbackPeriod, current_rates_total - srLookbackBars); 
   
   for(int i = srFractalScanStartBar; i < current_rates_total - InpFractalLookbackPeriod; i++)
     {
      if(fractalUp[i] != EMPTY_VALUE)
        {
         ArrayResize(resistancePrices, resistanceCount + 1);
         resistancePrices[resistanceCount++] = fractalUp[i];
        }
      if(fractalDown[i] != EMPTY_VALUE)
        {
         ArrayResize(supportPrices, supportCount + 1);
         supportPrices[supportCount++] = fractalDown[i];
        }
     }
     
   ArraySort(resistancePrices); 
   ArrayReverse(resistancePrices); 
   ArraySort(supportPrices);    

   for(int i = 0; i < InpNumResistanceLevels; i++)
     {
      string objName = resistanceLinePrefix + IntegerToString(i);
      if(i < resistanceCount) 
        {
         if(ObjectFind(0, objName) == -1) 
           {
            ObjectCreate(0, objName, OBJ_HLINE, 0, 0, resistancePrices[i]);
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
            ObjectSetString(0, objName, OBJPROP_TEXT, "R" + IntegerToString(i+1));
            ObjectSetInteger(0, objName, OBJPROP_RAY, false); 
           }
         else ObjectSetDouble(0, objName, OBJPROP_PRICE, resistancePrices[i]);
        }
      else ObjectDelete(0, objName);
     }
   for(int i = MathMax(resistanceCount, InpNumResistanceLevels); i < 100; i++)
     { string objName = resistanceLinePrefix + IntegerToString(i); if(ObjectFind(0, objName)!=-1) ObjectDelete(0, objName); else break;}

   for(int i = 0; i < InpNumSupportLevels; i++)
     {
      string objName = supportLinePrefix + IntegerToString(i);
      if(i < supportCount)
        {
         if(ObjectFind(0, objName) == -1)
           {
            ObjectCreate(0, objName, OBJ_HLINE, 0, 0, supportPrices[i]);
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrBlue);
            ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
            ObjectSetString(0, objName, OBJPROP_TEXT, "S" + IntegerToString(i+1));
            ObjectSetInteger(0, objName, OBJPROP_RAY, false);
           }
         else ObjectSetDouble(0, objName, OBJPROP_PRICE, supportPrices[i]);
        }
      else ObjectDelete(0, objName);
     }
   for(int i = MathMax(supportCount, InpNumSupportLevels); i < 100; i++)
     { string objName = supportLinePrefix + IntegerToString(i); if(ObjectFind(0, objName)!=-1) ObjectDelete(0, objName); else break;}
  }

//+------------------------------------------------------------------+
//| Calculate and Draw Trendlines                                    |
//+------------------------------------------------------------------+
void CalculateAndDrawTrendlines(int current_rates_total, const datetime &current_time[], const double &current_high[], const double &current_low[])
  {
   FractalPoint identifiedTrendlineFractals[];
   int tlFractalCount = 0;
   int trendlineFractalScanStartBar = MathMax(InpFractalLookbackPeriod, current_rates_total - InpTrendlineLookbackBars);

   for(int bar_idx = trendlineFractalScanStartBar; bar_idx < current_rates_total - InpFractalLookbackPeriod; bar_idx++)
     {
      if(fractalUp[bar_idx] != EMPTY_VALUE)
        {
         ArrayResize(identifiedTrendlineFractals, tlFractalCount + 1);
         identifiedTrendlineFractals[tlFractalCount].time = current_time[bar_idx];
         identifiedTrendlineFractals[tlFractalCount].price = fractalUp[bar_idx];
         identifiedTrendlineFractals[tlFractalCount].index = bar_idx;
         identifiedTrendlineFractals[tlFractalCount].isHigh = true;
         tlFractalCount++;
        }
      if(fractalDown[bar_idx] != EMPTY_VALUE)
        {
         ArrayResize(identifiedTrendlineFractals, tlFractalCount + 1);
         identifiedTrendlineFractals[tlFractalCount].time = current_time[bar_idx];
         identifiedTrendlineFractals[tlFractalCount].price = fractalDown[bar_idx];
         identifiedTrendlineFractals[tlFractalCount].index = bar_idx;
         identifiedTrendlineFractals[tlFractalCount].isHigh = false;
         tlFractalCount++;
        }
     }

   TrendlineInfo validUptrendLines[];
   int validUptrendCount = 0;
   TrendlineInfo validDowntrendLines[];
   int validDowntrendCount = 0;
   double dynamicTrendlineTolerance = g_atr_value * InpTrendlineToleranceATRMultiplier; 
   int minBarSeparation = MathMax(3, InpFractalLookbackPeriod); 

   for(int i = 0; i < tlFractalCount; i++)
     {
      for(int j = i + 1; j < tlFractalCount; j++)
        {
         FractalPoint fractal1_scan = identifiedTrendlineFractals[i];
         FractalPoint fractal2_scan = identifiedTrendlineFractals[j];
         FractalPoint p1, p2;
         if(fractal1_scan.index < fractal2_scan.index) { p1 = fractal1_scan; p2 = fractal2_scan; }
         else { p1 = fractal2_scan; p2 = fractal1_scan; }

         if(p2.index - p1.index < minBarSeparation) continue;
         bool isPotentialUptrend = !p1.isHigh && !p2.isHigh && p2.price >= p1.price;
         bool isPotentialDowntrend = p1.isHigh && p2.isHigh && p2.price <= p1.price;

         if(isPotentialUptrend || isPotentialDowntrend)
           {
            if (p2.index - p1.index == 0) continue;
            double slope = (p2.price - p1.price) / (p2.index - p1.index);
            bool lineIsValid = true;
            int currentTouches = 0;

            for(int bar_k = p1.index + 1; bar_k < p2.index; bar_k++)
              {
               double priceOnLine = p1.price + slope * (bar_k - p1.index);
               if(isPotentialUptrend && current_low[bar_k] < priceOnLine - dynamicTrendlineTolerance) { lineIsValid = false; break; }
               if(isPotentialDowntrend && current_high[bar_k] > priceOnLine + dynamicTrendlineTolerance) { lineIsValid = false; break; }
              }
            
            if(lineIsValid)
              {
               currentTouches = 2;
               if (InpMinFractalsForTrendline > 2)
                 {
                  for(int k=0; k < tlFractalCount; k++)
                    {
                     FractalPoint intermediateFractal = identifiedTrendlineFractals[k];
                     if(intermediateFractal.index <= p1.index || intermediateFractal.index >= p2.index) continue;
                     if( (isPotentialUptrend && intermediateFractal.isHigh) || (isPotentialDowntrend && !intermediateFractal.isHigh) ) continue;
                     double priceOnLine = p1.price + slope * (intermediateFractal.index - p1.index);
                     if(MathAbs(intermediateFractal.price - priceOnLine) <= dynamicTrendlineTolerance * 1.5) currentTouches++; 
                    }
                  if(currentTouches < InpMinFractalsForTrendline) lineIsValid = false;
                 }
              }

            if(lineIsValid)
              {
               TrendlineInfo currentTrendline;
               currentTrendline.p1 = p1; currentTrendline.p2 = p2; currentTrendline.slope = slope;
               currentTrendline.intercept = p1.price - slope * p1.index; 
               currentTrendline.numTouches = currentTouches; currentTrendline.isUptrend = isPotentialUptrend;
               currentTrendline.lastTouchTime = p2.time; currentTrendline.score = (long)p2.time;

               if(isPotentialUptrend) { ArrayResize(validUptrendLines, validUptrendCount + 1); validUptrendLines[validUptrendCount++] = currentTrendline; }
               else { ArrayResize(validDowntrendLines, validDowntrendCount + 1); validDowntrendLines[validDowntrendCount++] = currentTrendline; }
              }
           }
        }
     }
   
   for(int i=0; i < validUptrendCount-1; i++) for(int j=0; j < validUptrendCount-i-1; j++)
       if(validUptrendLines[j].score < validUptrendLines[j+1].score) 
           { TrendlineInfo temp = validUptrendLines[j]; validUptrendLines[j] = validUptrendLines[j+1]; validUptrendLines[j+1] = temp;}
   for(int i=0; i < validDowntrendCount-1; i++) for(int j=0; j < validDowntrendCount-i-1; j++)
       if(validDowntrendLines[j].score < validDowntrendLines[j+1].score)
           { TrendlineInfo temp = validDowntrendLines[j]; validDowntrendLines[j] = validDowntrendLines[j+1]; validDowntrendLines[j+1] = temp;}

   for(int i = 0; i < MathMin(validUptrendCount, InpMaxUptrendLines); i++)
     {
      TrendlineInfo tl = validUptrendLines[i]; string objName = uptrendLinePrefix + IntegerToString(i);
      ObjectCreate(0, objName, OBJ_TREND, 0, tl.p1.time, tl.p1.price, tl.p2.time, tl.p2.price);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrGreen); ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1); ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, true);
      if(InpTrendlineExtensionBars > 0 && !ObjectGetInteger(0, objName, OBJPROP_RAY_RIGHT)) { 
         datetime time2_manual_ext = tl.p2.time + InpTrendlineExtensionBars * PeriodSeconds();
         double price2_manual_ext = tl.p1.price + tl.slope * ( (tl.p2.index - tl.p1.index) + InpTrendlineExtensionBars );
         ObjectSetInteger(0, objName, OBJPROP_TIME, 1, time2_manual_ext);
         ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, price2_manual_ext);
      }
     }
   for(int i = 0; i < MathMin(validDowntrendCount, InpMaxDowntrendLines); i++)
     {
      TrendlineInfo tl = validDowntrendLines[i]; string objName = downtrendLinePrefix + IntegerToString(i);
      ObjectCreate(0, objName, OBJ_TREND, 0, tl.p1.time, tl.p1.price, tl.p2.time, tl.p2.price);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDarkOrange); ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1); ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, true); 
      if(InpTrendlineExtensionBars > 0 && !ObjectGetInteger(0, objName, OBJPROP_RAY_RIGHT)) {
         datetime time2_manual_ext = tl.p2.time + InpTrendlineExtensionBars * PeriodSeconds();
         double price2_manual_ext = tl.p1.price + tl.slope * ( (tl.p2.index - tl.p1.index) + InpTrendlineExtensionBars );
         ObjectSetInteger(0, objName, OBJPROP_TIME, 1, time2_manual_ext);
         ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, price2_manual_ext);
      }
     }
  }

//+------------------------------------------------------------------+
//| Detect and Draw Price Action Patterns                            |
//+------------------------------------------------------------------+
void DetectAndDrawPricePatterns(int current_prev_calculated, int current_rates_total, const datetime &current_time[], 
                                const double &current_open[], const double &current_high[], const double &current_low[], const double &current_close[])
  {
    if (current_rates_total < InpFractalLookbackPeriod * 2 + 1) return; 

    int pattern_start_bar;
    if(current_prev_calculated == 0) pattern_start_bar = 0;
    else pattern_start_bar = current_prev_calculated - 1;
    
    for(int bar_idx = MathMax(1, pattern_start_bar); bar_idx < current_rates_total; bar_idx++)
      {
       if(bar_idx >= current_rates_total) continue;
       string signalObjName;
       string alertMsg; 
       bool paPatternFound = false;
       bool isBullishSignal = false; // To guide trendline check direction
       ENUM_OBJECT arrowType = OBJ_ARROW; // Default, will be specified

       if(InpEnableEngulfing)
         {
          if(IsBullishEngulfing(bar_idx, current_open, current_close, current_rates_total))
            {
             paPatternFound = true; isBullishSignal = true;
             signalObjName = bullishEngulfingSignalPrefix + IntegerToString(bar_idx);
             alertMsg = "PriceActionSRTL: Bullish Engulfing on " + _Symbol + " " + EnumToString(_Period);
            }
          else if(IsBearishEngulfing(bar_idx, current_open, current_close, current_rates_total))
            {
             paPatternFound = true; isBullishSignal = false;
             signalObjName = bearishEngulfingSignalPrefix + IntegerToString(bar_idx);
             alertMsg = "PriceActionSRTL: Bearish Engulfing on " + _Symbol + " " + EnumToString(_Period);
            }
         }

       if(!paPatternFound && InpEnablePinBars)
         {
          double dynamicMinWick = g_atr_value * InpPinBarMinWickATRMultiplier;
          double dynamicMaxBody = g_atr_value * InpPinBarMaxBodyATRMultiplier;
          if(IsPinBar(bar_idx, true, current_open, current_high, current_low, current_close, dynamicMinWick, dynamicMaxBody))
            {
             paPatternFound = true; isBullishSignal = true;
             signalObjName = bullishPinBarSignalPrefix + IntegerToString(bar_idx);
             alertMsg = "PriceActionSRTL: Bullish Pin Bar on " + _Symbol + " " + EnumToString(_Period);
            }
          else if(IsPinBar(bar_idx, false, current_open, current_high, current_low, current_close, dynamicMinWick, dynamicMaxBody))
            {
             paPatternFound = true; isBullishSignal = false;
             signalObjName = bearishPinBarSignalPrefix + IntegerToString(bar_idx);
             alertMsg = "PriceActionSRTL: Bearish Pin Bar on " + _Symbol + " " + EnumToString(_Period);
            }
         }

       if(!paPatternFound && InpEnableDojiAtSR)
         {
          double dynamicDojiProx = g_atr_value * InpDojiProximityATRMultiplier;
          if(IsDojiNearSR(bar_idx, current_open, current_high, current_low, current_close, InpDojiMaxBodySizePoints, dynamicDojiProx, 
                           resistanceLinePrefix, supportLinePrefix, InpNumResistanceLevels, InpNumSupportLevels))
            {
             paPatternFound = true; // isBullishSignal for Doji is determined by confluence/breakout later if needed
             signalObjName = dojiAtSRSignalPrefix + IntegerToString(bar_idx);
             alertMsg = "PriceActionSRTL: Doji near S/R on " + _Symbol + " " + EnumToString(_Period);
            }
         }

       if(paPatternFound && ObjectFind(0, signalObjName) == -1)
         {
          bool drawSignal = false;
          if(!InpEnableConfluenceFilter) 
            {
             drawSignal = true; // If filter disabled, always draw
            }
          else
            {
             bool isResistanceHit = false; int srLevelIndex = -1;
             double distToSR_Abs = GetNearestSRLevelInfo(bar_idx, current_high, current_low, isResistanceHit, srLevelIndex);

             bool checkUptrendsForConfluence = !isResistanceHit; // Default: If near support, check uptrend; if near resistance, check downtrend.
             if (StringFind(signalObjName, dojiAtSRSignalPrefix, 0) == 0) // For Doji, determine nearest trendline type
             {
                int tlUpIdx = -1, tlDownIdx = -1;
                double distToUTL = GetDistanceToNearestTrendline(bar_idx, current_time, current_high, current_low, true, tlUpIdx);
                double distToDTL = GetDistanceToNearestTrendline(bar_idx, current_time, current_high, current_low, false, tlDownIdx);
                
                if (distToUTL <= distToDTL) { // If UTL is closer or equidistant
                    checkUptrendsForConfluence = true; 
                } else { // DTL is closer
                    checkUptrendsForConfluence = false; 
                }
             }


             int tlIndex = -1;
             double distToTL_Abs = GetDistanceToNearestTrendline(bar_idx, current_time, current_high, current_low, checkUptrendsForConfluence, tlIndex);

             double maxSrDistAllowed = g_atr_value * InpConfluenceMaxDistToSR_ATR_Mult;
             double maxTlDistAllowed = g_atr_value * InpConfluenceMaxDistToTL_ATR_Mult;

             if(distToSR_Abs <= maxSrDistAllowed && distToTL_Abs <= maxTlDistAllowed && srLevelIndex != -1 && tlIndex != -1)
               {
                drawSignal = true;
               }
            }

          if(drawSignal)
            {
             // Corrected type from ENUM_OBJECT_TYPE to ENUM_OBJECT
             ENUM_OBJECT currentArrowType = OBJ_ARROW_BUY; // Defaulting to BUY, will be specified
             color arrowColor = clrGreen;
             double arrowYPos = current_low[bar_idx] - _Point * 10;
             int arrowCode = 233; // Default Bullish Engulfing

             if(StringFind(signalObjName, bearishEngulfingSignalPrefix, 0) == 0)
               { currentArrowType = OBJ_ARROW_SELL; arrowColor = clrRed; arrowYPos = current_high[bar_idx] + _Point * 10; arrowCode = 234;}
             else if(StringFind(signalObjName, bullishEngulfingSignalPrefix, 0) == 0) // Explicitly Bullish Engulfing
               { currentArrowType = OBJ_ARROW_BUY; arrowColor = clrGreen; arrowYPos = current_low[bar_idx] - _Point * 10; arrowCode = 233;}
             else if(StringFind(signalObjName, bullishPinBarSignalPrefix, 0) == 0)
               { currentArrowType = OBJ_ARROW_BUY; arrowColor = clrLimeGreen; arrowYPos = current_low[bar_idx] - _Point * 10; arrowCode = 241;}
             else if(StringFind(signalObjName, bearishPinBarSignalPrefix, 0) == 0)
               { currentArrowType = OBJ_ARROW_SELL; arrowColor = clrTomato; arrowYPos = current_high[bar_idx] + _Point * 10; arrowCode = 242;}
             else if(StringFind(signalObjName, dojiAtSRSignalPrefix, 0) == 0)
               { currentArrowType = OBJ_ARROW; arrowColor = clrDodgerBlue; arrowYPos = (current_high[bar_idx] + current_low[bar_idx]) / 2.0; arrowCode = InpDojiSignalArrowCode;}


             ObjectCreate(0, signalObjName, currentArrowType, 0, current_time[bar_idx], arrowYPos);
             ObjectSetInteger(0, signalObjName, OBJPROP_COLOR, arrowColor); 
             ObjectSetInteger(0, signalObjName, OBJPROP_WIDTH, 1);
             ObjectSetInteger(0, signalObjName, OBJPROP_ARROWCODE, arrowCode); // OBJPROP_ARROWCODE applies to OBJ_ARROW & OBJ_ARROW_BUY/SELL
             if(currentArrowType == OBJ_ARROW) ObjectSetInteger(0, signalObjName, OBJPROP_ANCHOR, ANCHOR_CENTER);
             
             MaybeAlert(alertMsg, bar_idx, current_rates_total);
            }
         }
      }
  }


//+------------------------------------------------------------------+
//|               Price Action Pattern Detection Functions           |
//+------------------------------------------------------------------+
bool IsBullishEngulfing(int bar_idx, const double &open[], const double &close[], int rates_total_for_check)
  {
   if(bar_idx < 1 || bar_idx >= rates_total_for_check) return(false);
   bool currentIsBullish = close[bar_idx] > open[bar_idx];
   bool previousIsBearish = close[bar_idx-1] < open[bar_idx-1];
   if(!currentIsBullish || !previousIsBearish) return(false);
   return(close[bar_idx] > open[bar_idx-1] && open[bar_idx] < close[bar_idx-1]);
  }

bool IsBearishEngulfing(int bar_idx, const double &open[], const double &close[], int rates_total_for_check)
  {
   if(bar_idx < 1 || bar_idx >= rates_total_for_check) return(false);
   bool currentIsBearish = close[bar_idx] < open[bar_idx];
   bool previousIsBullish = close[bar_idx-1] > open[bar_idx-1];
   if(!currentIsBullish || !previousIsBullish) return(false);
   return(open[bar_idx] > close[bar_idx-1] && close[bar_idx] < open[bar_idx-1]);
  }

bool IsPinBar(int bar_idx, bool isBullishSignal, const double &open[], const double &high[], const double &low[], const double &close[], 
              double minWickAbs, double maxBodyAbs)
  {
   if(bar_idx < 0) return(false);
   double bodySize = MathAbs(open[bar_idx] - close[bar_idx]);
   if(bodySize < _Point) bodySize = _Point; 
   
   double upperWick = high[bar_idx] - MathMax(open[bar_idx], close[bar_idx]);
   double lowerWick = MathMin(open[bar_idx], close[bar_idx]) - low[bar_idx];
   double candleRange = high[bar_idx] - low[bar_idx];

   if(candleRange < _Point * 3) return false; 
   if(maxBodyAbs > 0 && bodySize > maxBodyAbs) return false;

   if(isBullishSignal) 
     {
      bool bodyAtTop = (MathMin(open[bar_idx], close[bar_idx])) > (high[bar_idx] - candleRange / 3.0);
      return(bodyAtTop && lowerWick >= minWickAbs && upperWick < MathMax(bodySize, lowerWick * 0.5));
     }
   else 
     {
      bool bodyAtBottom = (MathMax(open[bar_idx], close[bar_idx])) < (low[bar_idx] + candleRange / 3.0);
      return(bodyAtBottom && upperWick >= minWickAbs && lowerWick < MathMax(bodySize, upperWick * 0.5));
     }
  }

bool IsDoji(int bar_idx, const double &open[], const double &close[], int maxBodyPoints)
  {
   if(bar_idx < 0) return(false);
   return(MathAbs(open[bar_idx] - close[bar_idx]) <= maxBodyPoints * _Point);
  }

bool IsDojiNearSR(int bar_idx, const double &open[], const double &high[], const double &low[], const double &close[],
                  int maxBodyPoints, double maxProximityAbsDistance, 
                  const string resPrefix, const string supPrefix, 
                  int numResLevels, int numSupLevels)
  {
   if(!IsDoji(bar_idx, open, close, maxBodyPoints)) return(false);
   double dojiHigh = high[bar_idx]; double dojiLow = low[bar_idx];
   
   for(int k = 0; k < numResLevels; k++)
     {
      string srObjName = resPrefix + IntegerToString(k);
      if(ObjectFind(0, srObjName) != -1)
        {
         double srPrice = ObjectGetDouble(0, srObjName, OBJPROP_PRICE);
         if(dojiHigh >= srPrice - maxProximityAbsDistance && dojiLow <= srPrice + maxProximityAbsDistance) return(true);
        }
     }
   for(int k = 0; k < numSupLevels; k++)
     {
      string srObjName = supPrefix + IntegerToString(k);
      if(ObjectFind(0, srObjName) != -1)
        {
         double srPrice = ObjectGetDouble(0, srObjName, OBJPROP_PRICE);
         if(dojiHigh >= srPrice - maxProximityAbsDistance && dojiLow <= srPrice + maxProximityAbsDistance) return(true);
        }
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Helper function to manage and throttle alerts.                   |
//+------------------------------------------------------------------+
void MaybeAlert(string message, int bar_idx, int current_rates_total)
  {
   if(InpEnableAlerts && bar_idx == current_rates_total - 1 && bar_idx != lastAlertBar)
     {
      Alert(message);
      lastAlertBar = bar_idx; 
     }
  }

//+------------------------------------------------------------------+
//| Get Nearest S/R Level Information                                |
//| Purpose: Finds the closest S/R level to the middle of a given bar|
//| @param bar_idx           Index of the bar to check.             |
//| @param high[]            High price array.                      |
//| @param low[]             Low price array.                       |
//| @param isResistanceHit   Output: true if nearest is resistance. |
//| @param hitLevelIndex     Output: index of the hit S/R line.     |
//| @return Minimum distance to an S/R level, or DBL_MAX if none.  |
//+------------------------------------------------------------------+
double GetNearestSRLevelInfo(int bar_idx, const double &high[], const double &low[], bool &isResistanceHit, int &hitLevelIndex)
  {
   double currentPrice = (high[bar_idx] + low[bar_idx]) / 2.0;
   double minDistance = DBL_MAX;
   //double nearestLevelPrice = 0; // Not strictly needed for return, but good for debugging
   
   isResistanceHit = false; // Default
   hitLevelIndex = -1;      // Default

   // Check Resistance Levels
   for(int i = 0; i < InpNumResistanceLevels; i++)
     {
      string lineName = resistanceLinePrefix + IntegerToString(i);
      if(ObjectFind(0, lineName) != -1)
        {
         double srPrice = ObjectGetDouble(0, lineName, OBJPROP_PRICE);
         double distance = MathAbs(currentPrice - srPrice);
         if(distance < minDistance)
           {
            minDistance = distance;
            isResistanceHit = true;
            hitLevelIndex = i;
            //nearestLevelPrice = srPrice;
           }
        }
     }

   // Check Support Levels
   for(int i = 0; i < InpNumSupportLevels; i++)
     {
      string lineName = supportLinePrefix + IntegerToString(i);
      if(ObjectFind(0, lineName) != -1)
        {
         double srPrice = ObjectGetDouble(0, lineName, OBJPROP_PRICE);
         double distance = MathAbs(currentPrice - srPrice);
         if(distance < minDistance)
           {
            minDistance = distance;
            isResistanceHit = false; // It's a support level
            hitLevelIndex = i;
            //nearestLevelPrice = srPrice;
           }
        }
     }
   return minDistance;
  }

//+------------------------------------------------------------------+
//| Get Distance to Nearest Trendline                                |
//| Purpose: Calculates the vertical distance from the middle of a   |
//|          given bar to the nearest active trendline of a specific |
//|          type (uptrend or downtrend).                            |
//| @param bar_idx           Index of the bar.                      |
//| @param time[]            Bar time array.                        |
//| @param high[]            High price array.                      |
//| @param low[]             Low price array.                       |
//| @param checkUptrendLines True for uptrend lines, false for down.|
//| @param hitTrendlineIndex Output: index of the hit trendline.    |
//| @return Minimum distance to a trendline, or DBL_MAX if none.   |
//+------------------------------------------------------------------+
double GetDistanceToNearestTrendline(int bar_idx, const datetime &time[], const double &high[], const double &low[], bool checkUptrendLines, int &hitTrendlineIndex)
  {
   datetime currentBarTime = time[bar_idx];
   double currentMidPrice = (high[bar_idx] + low[bar_idx]) / 2.0;
   double minDistance = DBL_MAX;
   hitTrendlineIndex = -1; // Default

   string prefix = checkUptrendLines ? uptrendLinePrefix : downtrendLinePrefix;
   int maxLines = checkUptrendLines ? InpMaxUptrendLines : InpMaxDowntrendLines;

   for(int i = 0; i < maxLines; i++)
     {
      string tlName = prefix + IntegerToString(i);
      if(ObjectFind(0, tlName) == -1) continue;

      datetime time1 = (datetime)ObjectGetInteger(0, tlName, OBJPROP_TIME, 0);
      double price1 = ObjectGetDouble(0, tlName, OBJPROP_PRICE, 0);
      datetime time2 = (datetime)ObjectGetInteger(0, tlName, OBJPROP_TIME, 1);
      //double price2 = ObjectGetDouble(0, tlName, OBJPROP_PRICE, 1); // Not needed for slope with time1, price1

      if(time1 == time2 || PeriodSeconds() == 0) continue; // Avoid division by zero

      // Get slope from object properties if available (more reliable if OBJPROP_RAY_RIGHT is true)
      // However, direct calculation from P1 and P2 is also viable.
      // For simplicity and directness with line equation y = mx + c:
      // price = price1 + slope_per_bar * (bar_index_current - bar_index_p1)
      // Or for time-based slope: price = price1 + slope_per_second * (time_current - time1_p1)
      
      // We need bar index for P1 for slope calculation if using bar indices
      // For now, using the object's stored slope (OBJPROP_SLOPE) which is price units per bar.
      // This is only available if the line was created with OBJ_TRENDBYANGLE.
      // Since we used OBJ_TREND (defined by two points), we must calculate slope.
      // The object properties OBJPROP_PRICE for points 0 and 1, and OBJPROP_TIME for points 0 and 1 are the source.
      
      double price2 = ObjectGetDouble(0, tlName, OBJPROP_PRICE, 1);
      
      // Calculate slope in terms of price per second
      double slope_per_second = 0;
      if (time2 - time1 != 0) // Ensure no division by zero
         slope_per_second = (price2 - price1) / (double)(time2 - time1);
      else continue; // Should not happen for valid trendlines

      double projectedPriceOnTL = price1 + slope_per_second * (double)(currentBarTime - time1);
      double distance = MathAbs(currentMidPrice - projectedPriceOnTL);

      if(distance < minDistance)
        {
         minDistance = distance;
         hitTrendlineIndex = i;
        }
     }
   return minDistance;
  }
//+------------------------------------------------------------------+
/* Helper comments from previous versions retained for reference. */
//+------------------------------------------------------------------+

[end of PriceActionSRTL.mq5]

[end of PriceActionSRTL.mq5]

[end of PriceActionSRTL.mq5]

[end of PriceActionSRTL.mq5]

[end of PriceActionSRTL.mq5]

[end of PriceActionSRTL.mq5]

[end of PriceActionSRTL.mq5]

[end of PriceActionSRTL.mq5]

[end of PriceActionSRTL.mq5]

[end of PriceActionSRTL.mq5]
