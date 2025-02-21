---
title: 'Optimize Signal Calculation Performance'
labels: enhancement, performance, good first issue
---

# Performance Optimization Needed

## Current Situation
The indicator currently recalculates all signals on each tick, which can be resource-intensive on lower timeframes or when multiple instances are running.

## Objectives
1. Reduce CPU usage by optimizing calculation methods
2. Implement smart caching for previously calculated values
3. Minimize memory footprint

## Suggested Approaches
1. Cache calculated values between ticks
2. Implement partial updates (only recalculate what's needed)
3. Optimize array operations
4. Consider using static buffers where appropriate

## Success Criteria
- 30% or more reduction in CPU usage
- No loss in signal accuracy
- Stable memory usage across long periods

## Skills Needed
- MQL5 programming
- Performance optimization experience
- Understanding of trading indicators

This is a great opportunity for someone interested in optimization techniques in trading systems!
