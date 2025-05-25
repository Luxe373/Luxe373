//+------------------------------------------------------------------+
//|                                               PriceActionSRTL.mq5 |
//|                        Copyright 2023, XYZ Company (Developer) |
//|                                             https://www.xyz.com |
//|                                                                  |
//|    Comprehensive S/R, Price Action, and Trendline Indicator    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, XYZ Company (Developer)"
#property link      "https://www.xyz.com"
#property version   "1.07" // Fix static array declaration error by moving to global dynamic

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
input double InpPinBarWickToBodyRatio = 2.5;    // PA: Minimum ratio of wick to body for Pin Bars
input int  InpDojiMaxBodySizePoints  = 5;      // PA: Maximum body size in points for a Doji
input int  InpDojiProximityToSRPoints= 10;     // PA: Proximity in points for a Doji to be "near" S/R

// Trendline Detection Settings
input group "Trendline Detection"
input bool   InpEnableTrendlines       = true;   // TL: Enable/disable Trendline detection
input int    InpMinFractalsForTrendline= 2;      // TL: Minimum fractal points to define a trendline (2 or 3 typical)
input int    InpTrendlineLookbackBars  = 100;    // TL: How many bars back to look for fractal points for trendlines
input int    InpTrendlinePenetrationTolerancePoints = 5; // TL: Tolerance (points) for price penetration of a tentative trendline
input int    InpTrendlineExtensionBars = 20;     // TL: How many bars to extend trendline if not using RAY_RIGHT (visual)
input int    InpMaxUptrendLines        = 1;      // TL: Max number of uptrend lines to display
input int    InpMaxDowntrendLines      = 1;      // TL: Max number of downtrend lines to display

// Alert Configuration
input group "Alerts"
input bool   InpEnableAlerts           = true;   // Alerts: Enable/Disable all alerts for Price Action patterns

//--- Indicator Buffers ---
double DummyBuffer[]; // Dummy buffer for indicator plot requirements

//--- Global Variables & Object Prefixes ---

// S/R Line Prefixes
string resistanceLinePrefix = "ResLevel_"; // Prefix for resistance line objects
string supportLinePrefix    = "SupLevel_"; // Prefix for support line objects

// Price Action Signal Object Prefixes
string bullishEngulfingSignalPrefix = "BullEng_"; // Prefix for bullish engulfing signal objects
string bearishEngulfingSignalPrefix = "BearEng_"; // Prefix for bearish engulfing signal objects
string bullishPinBarSignalPrefix    = "BullPB_";  // Prefix for bullish pin bar signal objects
string bearishPinBarSignalPrefix    = "BearPB_";  // Prefix for bearish pin bar signal objects
string dojiAtSRSignalPrefix         = "DojiSR_";  // Prefix for Doji at S/R signal objects

// Trendline Object Prefixes
string uptrendLinePrefix   = "UTL_"; // Prefix for uptrend line objects
string downtrendLinePrefix = "DTL_"; // Prefix for downtrend line objects

// Global dynamic arrays for storing fractal data
// These are resized and initialized in OnCalculate()
double fractalUp[];   // Stores high price of up-fractals, or EMPTY_VALUE
double fractalDown[]; // Stores low price of down-fractals, or EMPTY_VALUE


//+------------------------------------------------------------------+
//| Data Structure for Storing Fractal Point Information             |
//+------------------------------------------------------------------+
struct FractalPoint
  {
   datetime time;      // Time of the fractal bar
   double   price;     // Price level of the fractal (high for up-fractal, low for down-fractal)
   int      index;     // Bar index of the fractal
   bool     isHigh;    // True if it's a high fractal (potential resistance point), false if low fractal (potential support point)
  };

//+------------------------------------------------------------------+
//| Data Structure for Storing Trendline Information                 |
//+------------------------------------------------------------------+
struct TrendlineInfo
  {
   FractalPoint p1;            // First fractal point defining the trendline
   FractalPoint p2;            // Second fractal point defining the trendline
   double       slope;         // Calculated slope of the trendline (price change per bar)
   double       intercept;     // Calculated intercept (price at bar index 0) - mainly for mathematical definition
   int          numTouches;    // Number of fractal points touching or very near the trendline
   bool         isUptrend;     // True if it's an uptrend line, false if a downtrend line
   datetime     lastTouchTime; // Time of the most recent fractal point (p2.time) defining the line, used for recency
   long         score;         // Score for sorting trendlines (e.g., based on recency or number of touches)
  };

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//| Called once when the indicator is first loaded or inputs change. |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Set the number of decimal places for indicator values displayed on chart (if any were plotted)
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

//--- Initialize the dummy buffer
   SetIndexBuffer(0, DummyBuffer, INDICATOR_CALCULATIONS);
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE); // Make the dummy buffer invisible

//--- Initialization successful
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//| Called once when the indicator is removed from the chart.        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Remove all drawn S/R line objects
   // Iterate a bit beyond max configured lines to catch orphaned objects if inputs changed
   for(int i = 0; i < MathMax(InpNumResistanceLevels, InpNumSupportLevels) + 10; i++)
     {
      ObjectDelete(0, resistanceLinePrefix + IntegerToString(i));
      ObjectDelete(0, supportLinePrefix + IntegerToString(i));
     }
   
//--- Delete all Price Action pattern signal objects by their prefixes
   ObjectsDeleteAll(0, bullishEngulfingSignalPrefix, 0, OBJ_ARROW_BUY); 
   ObjectsDeleteAll(0, bearishEngulfingSignalPrefix, 0, OBJ_ARROW_SELL);
   ObjectsDeleteAll(0, bullishPinBarSignalPrefix, 0, OBJ_ARROW_BUY);
   ObjectsDeleteAll(0, bearishPinBarSignalPrefix, 0, OBJ_ARROW_SELL);
   ObjectsDeleteAll(0, dojiAtSRSignalPrefix, 0, OBJ_ARROW);
   
//--- Delete all Trendline objects by their prefixes
   ObjectsDeleteAll(0, uptrendLinePrefix, 0, OBJ_TREND);
   ObjectsDeleteAll(0, downtrendLinePrefix, 0, OBJ_TREND);
//---
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//| Called on every new tick or new bar for the chart symbol.        |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,    // Size of the price arrays
                const int prev_calculated,// Bars calculated in the previous call
                const datetime &time[],   // Time array
                const double &open[],     // Open price array
                const double &high[],     // High price array
                const double &low[],      // Low price array
                const double &close[],    // Close price array
                const long &tick_volume[],// Tick volume array
                const long &volume[],     // Real volume array
                const int &spread[])      // Spread array
  {
// === Part 1: S/R Level Calculation ===
// Identifies S/R levels based on fractals within InpMaxBarsToScan from the current bar.
// These S/R lines are dynamic and update with new price data.
   
   // Determine lookback period for S/R fractal identification
   int srLookbackBars = MathMin(rates_total, InpMaxBarsToScan);

   // Check if there's enough data for any fractal calculation based on the S/R lookback period
   if (rates_total < InpFractalLookbackPeriod * 2 + 1)
   {
      if(prev_calculated == 0) Print("PriceActionSRTL: Not enough data for any fractal calculation. Bars available: ", rates_total, ", Need at least: ", InpFractalLookbackPeriod * 2 + 1);
      return(prev_calculated); // Not enough bars to form even a single fractal for S/R
   }
   
   // Resize and Initialize global fractal arrays for current calculation pass
   // These arrays store fractal price levels or EMPTY_VALUE if no fractal.
   if(ArraySize(fractalUp) != rates_total) ArrayResize(fractalUp, rates_total);
   ArrayInitialize(fractalUp, EMPTY_VALUE); 
   
   if(ArraySize(fractalDown) != rates_total) ArrayResize(fractalDown, rates_total);
   ArrayInitialize(fractalDown, EMPTY_VALUE);

   // Identify all fractals across the loaded chart history (up to rates_total)
   // A fractal at bar 'i' requires 'InpFractalLookbackPeriod' bars on each side.
   for(int i = InpFractalLookbackPeriod; i < rates_total - InpFractalLookbackPeriod; i++)
     {
      // Check for Up Fractal (potential resistance)
      bool isUpFractal = true;
      for(int j = 1; j <= InpFractalLookbackPeriod; j++)
        {
         if(high[i] <= high[i-j] || high[i] <= high[i+j]) { isUpFractal = false; break; }
        }
      if(isUpFractal) fractalUp[i] = high[i];

      // Check for Down Fractal (potential support)
      bool isDownFractal = true;
      for(int j = 1; j <= InpFractalLookbackPeriod; j++)
        {
         if(low[i] >= low[i-j] || low[i] >= low[i+j]) { isDownFractal = false; break; }
        }
      if(isDownFractal) fractalDown[i] = low[i];
     }

   // Collect fractal prices for S/R from the relevant lookback window (srLookbackBars)
   double resistancePrices[]; // Dynamic array for resistance prices
   double supportPrices[];    // Dynamic array for support prices
   int resistanceCount = 0;
   int supportCount = 0;

   // Define the starting bar for collecting S/R fractals
   int srFractalScanStartBar = MathMax(InpFractalLookbackPeriod, rates_total - srLookbackBars); 
   
   for(int i = srFractalScanStartBar; i < rates_total - InpFractalLookbackPeriod; i++)
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
     
   // Sort prices: Resistance descending (highest first), Support ascending (lowest first)
   ArraySort(resistancePrices); // Sorts ascending by default
   ArrayReverse(resistancePrices); // Reverse to get descending order
   ArraySort(supportPrices);    // Sorts ascending by default, which is correct for support

   // Manage and Draw Resistance Lines
   for(int i = 0; i < InpNumResistanceLevels; i++)
     {
      string objName = resistanceLinePrefix + IntegerToString(i);
      if(i < resistanceCount) // If a valid resistance price exists for this level
        {
         if(ObjectFind(0, objName) == -1) // If object doesn't exist, create it
           {
            ObjectCreate(0, objName, OBJ_HLINE, 0, 0, resistancePrices[i]);
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
            ObjectSetString(0, objName, OBJPROP_TEXT, "R" + IntegerToString(i+1));
            ObjectSetInteger(0, objName, OBJPROP_RAY, false); // Full line across chart
           }
         else // Object exists, just move its price level
           {
            ObjectSetDouble(0, objName, OBJPROP_PRICE, resistancePrices[i]);
           }
        }
      else // Not enough resistance fractals found, delete this line object if it exists
        {
         ObjectDelete(0, objName);
        }
     }
   // Cleanup extra S/R lines if InpNumResistanceLevels was reduced by user
   for(int i = MathMax(resistanceCount, InpNumResistanceLevels); i < 100; i++) // Check beyond current needs up to a practical limit
     { string objName = resistanceLinePrefix + IntegerToString(i); if(ObjectFind(0, objName)!=-1) ObjectDelete(0, objName); else break;}

   // Manage and Draw Support Lines (similar logic to resistance)
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


// === Part 2: Price Action Pattern Detection & Drawing ===
// Detects specified PA patterns and draws non-repainting signals. Alerts if enabled.
   if (rates_total >= InpFractalLookbackPeriod * 2 + 1) // Ensure basic data availability
   {
       int pattern_start_bar; // Determine starting bar for PA pattern scan
       if(prev_calculated == 0) pattern_start_bar = 0; // Full scan on first run
       else pattern_start_bar = prev_calculated - 1; // Check last bar again and new bars
       
       // Loop through bars for pattern detection. Start at least from bar 1 for patterns needing i-1.
       for(int bar_idx = MathMax(1, pattern_start_bar); bar_idx < rates_total; bar_idx++)
         {
          if(bar_idx >= rates_total) continue; // Boundary check, though loop condition should handle

          string signalObjName; // Name for the signal object

          // 1. Engulfing Patterns
          if(InpEnableEngulfing)
            {
             signalObjName = bullishEngulfingSignalPrefix + IntegerToString(bar_idx);
             if(ObjectFind(0, signalObjName) == -1) // Check if signal already drawn
               {
                if(IsBullishEngulfing(bar_idx, open, close, rates_total))
                  {
                   ObjectCreate(0, signalObjName, OBJ_ARROW_BUY, 0, time[bar_idx], low[bar_idx] - _Point * 10);
                   ObjectSetInteger(0, signalObjName, OBJPROP_COLOR, clrGreen);
                   ObjectSetInteger(0, signalObjName, OBJPROP_WIDTH, 1);
                   ObjectSetInteger(0, signalObjName, OBJPROP_ARROWCODE, 233); // Arrow shape
                   // Alert for new signal on the latest bar
                   if(InpEnableAlerts && bar_idx == rates_total - 1) Alert("PriceActionSRTL: Bullish Engulfing on ", _Symbol, " ", EnumToString(_Period));
                  }
               }
             
             signalObjName = bearishEngulfingSignalPrefix + IntegerToString(bar_idx);
             if(ObjectFind(0, signalObjName) == -1)
               {
                if(IsBearishEngulfing(bar_idx, open, close, rates_total))
                  {
                   ObjectCreate(0, signalObjName, OBJ_ARROW_SELL, 0, time[bar_idx], high[bar_idx] + _Point * 10);
                   ObjectSetInteger(0, signalObjName, OBJPROP_COLOR, clrRed);
                   ObjectSetInteger(0, signalObjName, OBJPROP_WIDTH, 1);
                   ObjectSetInteger(0, signalObjName, OBJPROP_ARROWCODE, 234); // Arrow shape
                   if(InpEnableAlerts && bar_idx == rates_total - 1) Alert("PriceActionSRTL: Bearish Engulfing on ", _Symbol, " ", EnumToString(_Period));
                  }
               }
            }

          // 2. Pin Bar Patterns
          if(InpEnablePinBars)
            {
             signalObjName = bullishPinBarSignalPrefix + IntegerToString(bar_idx);
             if(ObjectFind(0, signalObjName) == -1)
               {
                if(IsPinBar(bar_idx, true, open, high, low, close, InpPinBarWickToBodyRatio))
                  {
                   ObjectCreate(0, signalObjName, OBJ_ARROW_BUY, 0, time[bar_idx], low[bar_idx] - _Point * 10);
                   ObjectSetInteger(0, signalObjName, OBJPROP_COLOR, clrLimeGreen);
                   ObjectSetInteger(0, signalObjName, OBJPROP_WIDTH, 1);
                   ObjectSetInteger(0, signalObjName, OBJPROP_ARROWCODE, 241); // Triangle shape
                   if(InpEnableAlerts && bar_idx == rates_total - 1) Alert("PriceActionSRTL: Bullish Pin Bar on ", _Symbol, " ", EnumToString(_Period));
                  }
               }

             signalObjName = bearishPinBarSignalPrefix + IntegerToString(bar_idx);
             if(ObjectFind(0, signalObjName) == -1)
               {
                if(IsPinBar(bar_idx, false, open, high, low, close, InpPinBarWickToBodyRatio))
                  {
                   ObjectCreate(0, signalObjName, OBJ_ARROW_SELL, 0, time[bar_idx], high[bar_idx] + _Point * 10);
                   ObjectSetInteger(0, signalObjName, OBJPROP_COLOR, clrTomato);
                   ObjectSetInteger(0, signalObjName, OBJPROP_WIDTH, 1);
                   ObjectSetInteger(0, signalObjName, OBJPROP_ARROWCODE, 242); // Triangle shape
                   if(InpEnableAlerts && bar_idx == rates_total - 1) Alert("PriceActionSRTL: Bearish Pin Bar on ", _Symbol, " ", EnumToString(_Period));
                  }
               }
            }

          // 3. Doji at S/R
          if(InpEnableDojiAtSR)
            {
             signalObjName = dojiAtSRSignalPrefix + IntegerToString(bar_idx);
             if(ObjectFind(0, signalObjName) == -1)
               {
                if(IsDojiNearSR(bar_idx, open, high, low, close, InpDojiMaxBodySizePoints, InpDojiProximityToSRPoints, 
                                 resistanceLinePrefix, supportLinePrefix, InpNumResistanceLevels, InpNumSupportLevels))
                  {
                   ObjectCreate(0, signalObjName, OBJ_ARROW, 0, time[bar_idx], (high[bar_idx] + low[bar_idx]) / 2.0);
                   ObjectSetInteger(0, signalObjName, OBJPROP_COLOR, clrDodgerBlue);
                   ObjectSetInteger(0, signalObjName, OBJPROP_ARROWCODE, 171); // Diamond shape
                   ObjectSetInteger(0, signalObjName, OBJPROP_WIDTH, 1);
                   ObjectSetInteger(0, signalObjName, OBJPROP_ANCHOR, ANCHOR_CENTER);
                   if(InpEnableAlerts && bar_idx == rates_total - 1) Alert("PriceActionSRTL: Doji near S/R on ", _Symbol, " ", EnumToString(_Period));
                  }
               }
            }
         } // End of PA pattern detection loop
   } // End of PA pattern detection block


// === Part 3: Trendline Detection & Drawing ===
// Detects trendlines based on fractals within InpTrendlineLookbackBars.
   if(InpEnableTrendlines && rates_total >= InpTrendlineLookbackBars && rates_total >= (InpFractalLookbackPeriod * 2 + 1) )
     {
      // Clean previously drawn trendlines to reflect the latest analysis
      ObjectsDeleteAll(0, uptrendLinePrefix, 0, OBJ_TREND);
      ObjectsDeleteAll(0, downtrendLinePrefix, 0, OBJ_TREND);

      // 1. Collect Fractal Points for Trendline Analysis
      FractalPoint identifiedTrendlineFractals[]; // Array to store relevant fractals for trendlines
      int tlFractalCount = 0;
      // Define the start bar for collecting trendline fractals
      int trendlineFractalScanStartBar = MathMax(InpFractalLookbackPeriod, rates_total - InpTrendlineLookbackBars);

      // Use fractalUp and fractalDown arrays populated during S/R calculation
      for(int bar_idx = trendlineFractalScanStartBar; bar_idx < rates_total - InpFractalLookbackPeriod; bar_idx++)
        {
         if(fractalUp[bar_idx] != EMPTY_VALUE) // If an up-fractal exists at this bar
           {
            ArrayResize(identifiedTrendlineFractals, tlFractalCount + 1);
            identifiedTrendlineFractals[tlFractalCount].time = time[bar_idx];
            identifiedTrendlineFractals[tlFractalCount].price = fractalUp[bar_idx];
            identifiedTrendlineFractals[tlFractalCount].index = bar_idx;
            identifiedTrendlineFractals[tlFractalCount].isHigh = true;
            tlFractalCount++;
           }
         if(fractalDown[bar_idx] != EMPTY_VALUE) // If a down-fractal exists at this bar
           {
            ArrayResize(identifiedTrendlineFractals, tlFractalCount + 1);
            identifiedTrendlineFractals[tlFractalCount].time = time[bar_idx];
            identifiedTrendlineFractals[tlFractalCount].price = fractalDown[bar_idx];
            identifiedTrendlineFractals[tlFractalCount].index = bar_idx;
            identifiedTrendlineFractals[tlFractalCount].isHigh = false;
            tlFractalCount++;
           }
        }

      // 2. Identify, Validate, and Store Potential Trendlines
      TrendlineInfo validUptrendLines[];   // Array for valid uptrend lines
      int validUptrendCount = 0;
      TrendlineInfo validDowntrendLines[]; // Array for valid downtrend lines
      int validDowntrendCount = 0;
      double penetrationTolerance = InpTrendlinePenetrationTolerancePoints * _Point;
      int minBarSeparation = MathMax(3, InpFractalLookbackPeriod); // Minimum bars between two trendline points

      // Iterate through all pairs of identified fractals
      for(int i = 0; i < tlFractalCount; i++)
        {
         for(int j = i + 1; j < tlFractalCount; j++) // Ensure second fractal is after the first
           {
            FractalPoint fractal1_scan = identifiedTrendlineFractals[i];
            FractalPoint fractal2_scan = identifiedTrendlineFractals[j];
            
            FractalPoint p1, p2; // Ensure p1 is chronologically earlier than p2
            if(fractal1_scan.index < fractal2_scan.index) { p1 = fractal1_scan; p2 = fractal2_scan; }
            else { p1 = fractal2_scan; p2 = fractal1_scan; }

            // Ensure fractals are sufficiently separated
            if(p2.index - p1.index < minBarSeparation) continue;

            // Determine if this pair could form an uptrend or downtrend line
            bool isPotentialUptrend = !p1.isHigh && !p2.isHigh && p2.price >= p1.price; // Low to higher/equal Low
            bool isPotentialDowntrend = p1.isHigh && p2.isHigh && p2.price <= p1.price; // High to lower/equal High

            if(isPotentialUptrend || isPotentialDowntrend)
              {
               if (p2.index - p1.index == 0) continue; // Should not happen due to separation check, but safeguard
               double slope = (p2.price - p1.price) / (p2.index - p1.index); // Price change per bar
               
               bool lineIsValid = true;
               int currentTouches = 0; 

               // Validate: No significant price penetration between p1 and p2
               for(int bar_k = p1.index + 1; bar_k < p2.index; bar_k++)
                 {
                  double priceOnLine = p1.price + slope * (bar_k - p1.index);
                  if(isPotentialUptrend && low[bar_k] < priceOnLine - penetrationTolerance) { lineIsValid = false; break; }
                  if(isPotentialDowntrend && high[bar_k] > priceOnLine + penetrationTolerance) { lineIsValid = false; break; }
                 }
               
               if(lineIsValid) // If no penetration, check for minimum touches
                 {
                  currentTouches = 2; // p1 and p2 are the first two touches
                  if (InpMinFractalsForTrendline > 2) // If more than 2 touches are required
                  {
                      // Check for additional fractal touches between p1 and p2
                      for(int k=0; k < tlFractalCount; k++)
                      {
                          FractalPoint intermediateFractal = identifiedTrendlineFractals[k];
                          // Ensure intermediate fractal is between p1 and p2 and of the correct type
                          if(intermediateFractal.index <= p1.index || intermediateFractal.index >= p2.index) continue; 
                          if( (isPotentialUptrend && intermediateFractal.isHigh) || (isPotentialDowntrend && !intermediateFractal.isHigh) ) continue;

                          double priceOnLine = p1.price + slope * (intermediateFractal.index - p1.index);
                          // Check if intermediate fractal is close enough to the line (wider tolerance for intermediate points)
                          if(MathAbs(intermediateFractal.price - priceOnLine) <= penetrationTolerance * 1.5) 
                          {
                              currentTouches++;
                          }
                      }
                      if(currentTouches < InpMinFractalsForTrendline) lineIsValid = false; // Not enough touches
                  }
                 }

               if(lineIsValid) // If all checks passed, store the trendline
                 {
                  TrendlineInfo currentTrendline;
                  currentTrendline.p1 = p1;
                  currentTrendline.p2 = p2;
                  currentTrendline.slope = slope;
                  currentTrendline.intercept = p1.price - slope * p1.index; // For reference
                  currentTrendline.numTouches = currentTouches;
                  currentTrendline.isUptrend = isPotentialUptrend;
                  currentTrendline.lastTouchTime = p2.time; 
                  currentTrendline.score = (long)p2.time; // Score based on recency of the second point

                  if(isPotentialUptrend)
                    {
                     ArrayResize(validUptrendLines, validUptrendCount + 1);
                     validUptrendLines[validUptrendCount++] = currentTrendline;
                    }
                  else // isPotentialDowntrend
                    {
                     ArrayResize(validDowntrendLines, validDowntrendCount + 1);
                     validDowntrendLines[validDowntrendCount++] = currentTrendline;
                    }
                 }
              } // End if potential up/down trend
           } // End inner loop (j) for fractal pairs
        } // End outer loop (i) for fractal pairs
      
      // 3. Sort Validated Trendlines by Score (recency of p2) - Descending
      // Basic bubble sort (efficient enough for small N of max trendlines)
      for(int i=0; i < validUptrendCount-1; i++) for(int j=0; j < validUptrendCount-i-1; j++)
          if(validUptrendLines[j].score < validUptrendLines[j+1].score) 
              { TrendlineInfo temp = validUptrendLines[j]; validUptrendLines[j] = validUptrendLines[j+1]; validUptrendLines[j+1] = temp;}
      for(int i=0; i < validDowntrendCount-1; i++) for(int j=0; j < validDowntrendCount-i-1; j++)
          if(validDowntrendLines[j].score < validDowntrendLines[j+1].score)
              { TrendlineInfo temp = validDowntrendLines[j]; validDowntrendLines[j] = validDowntrendLines[j+1]; validDowntrendLines[j+1] = temp;}

      // 4. Draw Selected Trendlines
      for(int i = 0; i < MathMin(validUptrendCount, InpMaxUptrendLines); i++)
        {
         TrendlineInfo tl = validUptrendLines[i];
         string objName = uptrendLinePrefix + IntegerToString(i);
         ObjectCreate(0, objName, OBJ_TREND, 0, tl.p1.time, tl.p1.price, tl.p2.time, tl.p2.price);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clrGreen);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, true); // Extend line to the right
         
         // Logic for manual extension if OBJPROP_RAY_RIGHT is false (and InpTrendlineExtensionBars > 0)
         if(InpTrendlineExtensionBars > 0 && !ObjectGetInteger(0, objName, OBJPROP_RAY_RIGHT)) { 
            datetime time2_manual_ext = tl.p2.time + InpTrendlineExtensionBars * PeriodSeconds();
            double price2_manual_ext = tl.p1.price + tl.slope * ( (tl.p2.index - tl.p1.index) + InpTrendlineExtensionBars );
            ObjectSetInteger(0, objName, OBJPROP_TIME, 1, time2_manual_ext); // Set time of the second point
            ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, price2_manual_ext); // Set price of the second point
         }
        }

      for(int i = 0; i < MathMin(validDowntrendCount, InpMaxDowntrendLines); i++)
        {
         TrendlineInfo tl = validDowntrendLines[i];
         string objName = downtrendLinePrefix + IntegerToString(i);
         ObjectCreate(0, objName, OBJ_TREND, 0, tl.p1.time, tl.p1.price, tl.p2.time, tl.p2.price);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDarkOrange); // Distinct color for downtrend lines
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, true); 

         if(InpTrendlineExtensionBars > 0 && !ObjectGetInteger(0, objName, OBJPROP_RAY_RIGHT)) {
            datetime time2_manual_ext = tl.p2.time + InpTrendlineExtensionBars * PeriodSeconds();
            double price2_manual_ext = tl.p1.price + tl.slope * ( (tl.p2.index - tl.p1.index) + InpTrendlineExtensionBars );
            ObjectSetInteger(0, objName, OBJPROP_TIME, 1, time2_manual_ext);
            ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, price2_manual_ext);
         }
        }
     } // End of Trendline logic block

//--- Return value of prev_calculated for next call; crucial for MQL5 to manage calculation state
   return(rates_total);
  }

//+------------------------------------------------------------------+
//|               Price Action Pattern Detection Functions           |
//| These functions check for specific candlestick patterns.         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Checks for Bullish Engulfing Pattern.                            |
//| A bullish engulfing pattern occurs when a smaller bearish candle |
//| is followed by a larger bullish candle that engulfs the previous.|
//| bar_idx: Current bar index.                                      |
//| open[], close[]: Open and Close price arrays.                    |
//| rates_total_for_check: Total bars, for boundary checks.          |
//| Returns: true if pattern is found, false otherwise.              |
//+------------------------------------------------------------------+
bool IsBullishEngulfing(int bar_idx, const double &open[], const double &close[], int rates_total_for_check)
  {
   // Ensure there's a previous bar and we are within array bounds
   if(bar_idx < 1 || bar_idx >= rates_total_for_check) return(false);

   // Current candle must be bullish (close > open)
   bool currentIsBullish = close[bar_idx] > open[bar_idx];
   // Previous candle must be bearish (close < open)
   bool previousIsBearish = close[bar_idx-1] < open[bar_idx-1];

   if(!currentIsBullish || !previousIsBearish) return(false);

   // Bullish engulfing: current bullish body engulfs previous bearish body
   return(close[bar_idx] > open[bar_idx-1] && open[bar_idx] < close[bar_idx-1]);
  }

//+------------------------------------------------------------------+
//| Checks for Bearish Engulfing Pattern.                            |
//| A bearish engulfing pattern occurs when a smaller bullish candle |
//| is followed by a larger bearish candle that engulfs the previous.|
//+------------------------------------------------------------------+
bool IsBearishEngulfing(int bar_idx, const double &open[], const double &close[], int rates_total_for_check)
  {
   if(bar_idx < 1 || bar_idx >= rates_total_for_check) return(false);

   // Current candle must be bearish
   bool currentIsBearish = close[bar_idx] < open[bar_idx];
   // Previous candle must be bullish
   bool previousIsBullish = close[bar_idx-1] > open[bar_idx-1];

   if(!currentIsBearish || !previousIsBullish) return(false);

   // Bearish engulfing: current bearish body engulfs previous bullish body
   return(open[bar_idx] > close[bar_idx-1] && close[bar_idx] < open[bar_idx-1]);
  }

//+------------------------------------------------------------------+
//| Checks for Pin Bar Pattern (Hammer or Shooting Star).            |
//| isBullish: true to check for Bullish Pin Bar (Hammer),           |
//|            false for Bearish Pin Bar (Shooting Star).            |
//| wickToBodyRatio: Minimum ratio of the main wick to the body.     |
//+------------------------------------------------------------------+
bool IsPinBar(int bar_idx, bool isBullish, const double &open[], const double &high[], const double &low[], const double &close[], double wickToBodyRatio)
  {
   if(bar_idx < 0) return(false); // Basic boundary check

   double bodySize = MathAbs(open[bar_idx] - close[bar_idx]);
   if(bodySize < _Point) bodySize = _Point; // Avoid division by zero, treat doji-like body as 1 point for ratio

   double upperWick = high[bar_idx] - MathMax(open[bar_idx], close[bar_idx]);
   double lowerWick = MathMin(open[bar_idx], close[bar_idx]) - low[bar_idx];
   double candleRange = high[bar_idx] - low[bar_idx];

   // Candle must have some range to be significant
   if(candleRange < _Point * 3) return false; 

   if(isBullish) // Bullish Pin Bar (Hammer - long lower wick, small body at top)
     {
      // Body should be in the upper 1/3 of the candle's range
      bool bodyAtTop = (MathMin(open[bar_idx], close[bar_idx])) > (high[bar_idx] - candleRange / 3.0);
      // Lower wick must be long relative to body, and upper wick must be small (e.g., less than 80% of body size)
      return(bodyAtTop && lowerWick >= wickToBodyRatio * bodySize && upperWick < bodySize * 0.8);
     }
   else // Bearish Pin Bar (Shooting Star - long upper wick, small body at bottom)
     {
      // Body should be in the lower 1/3 of the candle's range
      bool bodyAtBottom = (MathMax(open[bar_idx], close[bar_idx])) < (low[bar_idx] + candleRange / 3.0);
      // Upper wick must be long relative to body, and lower wick must be small
      return(bodyAtBottom && upperWick >= wickToBodyRatio * bodySize && lowerWick < bodySize * 0.8);
     }
  }

//+------------------------------------------------------------------+
//| Checks for Doji Pattern.                                         |
//| A Doji is a candle where open and close prices are very close.   |
//| maxBodyPoints: Maximum body size in points to be a Doji.         |
//+------------------------------------------------------------------+
bool IsDoji(int bar_idx, const double &open[], const double &close[], int maxBodyPoints)
  {
   if(bar_idx < 0) return(false);
   // Body size is less than or equal to the specified max points
   return(MathAbs(open[bar_idx] - close[bar_idx]) <= maxBodyPoints * _Point);
  }

//+------------------------------------------------------------------+
//| Checks if a Doji is near an existing S/R level.                  |
//| proximityPoints: How close (in points) to an S/R line.           |
//| resPrefix, supPrefix: Object name prefixes for S/R lines.        |
//| numResLevels, numSupLevels: Number of S/R levels to check.       |
//+------------------------------------------------------------------+
bool IsDojiNearSR(int bar_idx, const double &open[], const double &high[], const double &low[], const double &close[],
                  int maxBodyPoints, int proximityPoints, 
                  const string resPrefix, const string supPrefix, 
                  int numResLevels, int numSupLevels)
  {
   // First, check if the candle is a Doji
   if(!IsDoji(bar_idx, open, close, maxBodyPoints)) return(false);

   double dojiHigh = high[bar_idx];
   double dojiLow = low[bar_idx];
   double proximityRange = proximityPoints * _Point; // Proximity in absolute price units

   // Check against active resistance levels
   for(int k = 0; k < numResLevels; k++)
     {
      string srObjName = resPrefix + IntegerToString(k);
      if(ObjectFind(0, srObjName) != -1) // If S/R line object exists
        {
         double srPrice = ObjectGetDouble(0, srObjName, OBJPROP_PRICE);
         // Check if Doji's range (low to high) is within proximity of the S/R line
         if(dojiHigh >= srPrice - proximityRange && dojiLow <= srPrice + proximityRange) return(true);
        }
     }
   // Check against active support levels
   for(int k = 0; k < numSupLevels; k++)
     {
      string srObjName = supPrefix + IntegerToString(k);
      if(ObjectFind(0, srObjName) != -1)
        {
         double srPrice = ObjectGetDouble(0, srObjName, OBJPROP_PRICE);
         if(dojiHigh >= srPrice - proximityRange && dojiLow <= srPrice + proximityRange) return(true);
        }
     }
   return(false); // Doji found, but not near any active S/R level
  }
//+------------------------------------------------------------------+
// Helper comments on S/R and non-repainting logic from previous versions are kept below for reference.
/*
The "non-repainting" S/R as implemented means S/R lines reflect the analysis of the latest 'InpMaxBarsToScan' window,
so they are dynamic. Price Action signals and Trendlines, once drawn for a specific bar based on historical data
available at that bar's formation, are fixed and do not change for that past bar.
*/
//+------------------------------------------------------------------+
