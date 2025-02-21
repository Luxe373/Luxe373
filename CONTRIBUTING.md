# Contributing to MomentumSignalsPro

 First off, thanks for taking the time to contribute! We welcome all contributions to improve our MT5 indicators.

## What We Need Help With

### Priority Areas
1. **Performance Optimization**
   - Reducing CPU usage
   - Improving calculation speed
   - Memory optimization

2. **Bug Fixes**
   - Signal accuracy improvements
   - Memory leak fixes
   - Error handling improvements

3. **New Features**
   - Additional technical indicators
   - More customization options
   - Better visualization options

## How to Contribute

### Setting Up Development Environment
1. Install MetaTrader 5
2. Fork this repository
3. Clone your fork locally
4. Set up VS Code with MQL5 extension

### Making Changes
1. Create a new branch for your feature/fix:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. Make your changes
3. Test thoroughly in MT5 Strategy Tester
4. Commit with clear messages:
   ```bash
   git commit -m "Add: brief description of changes"
   ```

### Testing Guidelines
1. Test on multiple timeframes (M1, M5, M15, H1, H4, D1)
2. Test on different currency pairs
3. Run backtests for at least 6 months of data
4. Verify CPU usage remains reasonable

### Pull Request Process
1. Update documentation if needed
2. Add comments explaining complex logic
3. Submit PR with detailed description of changes
4. Link any related issues

## Code Style Guidelines

### Naming Conventions
- Variables: camelCase (e.g., `signalStrength`)
- Constants: UPPER_CASE (e.g., `MAX_PERIOD`)
- Functions: PascalCase (e.g., `CalculateSignal`)

### Code Organization
- Keep functions focused and small
- Add clear comments for complex calculations
- Use consistent indentation
- Group related variables and functions

## Getting Help
- Open an issue for questions
- Join discussions in existing issues
- Check the MT5 documentation
- Review existing code for examples

## Recognition
Contributors will be added to our README.md and credited in release notes.

Thank you for helping improve MomentumSignalsPro! 
