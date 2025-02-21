# Enhanced Signal Generator

A professional-grade MQL5 trading indicator that generates high-probability buy and sell signals by integrating multiple technical indicators and price action patterns.

## Features

- Multi-timeframe analysis
- Dynamic ATR-based stop-loss and take-profit levels
- Integration of multiple technical indicators:
  - RSI (Relative Strength Index)
  - ADX (Average Directional Index)
- Price Action Pattern Recognition:
  - Engulfing patterns
  - Pin bars (hammer/shooting star)
  - Inside bars
  - Double tops & bottoms
- Support/Resistance level validation
- Customizable display settings
- Comprehensive debug logging

## Installation

1. Copy the `EnhancedSignalGenerator.mq5` file to your MetaTrader 5 indicators folder:
   - Windows: `%APPDATA%\MetaQuotes\Terminal\<TERMINAL_ID>\MQL5\Indicators`
2. Restart MetaTrader 5 or refresh the Navigator window
3. Drag the indicator onto any chart

## Input Parameters

### Display Settings
- ShowLabels: Enable/disable text labels
- ShowDebugLogs: Enable/disable debug logging
- Color customization for bullish/bearish signals

### Technical Indicators
- RSIPeriod: Period for RSI calculation (default: 14)
- ADXPeriod: Period for ADX calculation (default: 14)

### Risk Management
- ATRMultiplier: Multiplier for stop-loss/take-profit calculation
- RiskRewardRatio: Default risk-reward ratio
- UseHigherTimeframe: Enable/disable higher timeframe confirmation

## Usage

1. Apply the indicator to your desired chart timeframe
2. Configure input parameters according to your trading strategy
3. Monitor for buy/sell signals indicated by arrows on the chart
4. Use the displayed stop-loss and take-profit levels for trade management

## Signal Generation Logic

The indicator generates signals based on the following conditions:

### Buy Signals
- RSI > 50 (Bullish momentum)
- ADX ≥ 20 (Strong trend)
- Price action confirmation (if enabled)
- Not near strong resistance level

### Sell Signals
- RSI < 50 (Bearish momentum)
- ADX ≥ 20 (Strong trend)
- Price action confirmation (if enabled)
- Not near strong support level

## License

Copyright 2025. All rights reserved.
