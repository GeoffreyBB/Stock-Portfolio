# Stock Portfolio Tracker

A Flutter mobile app for tracking stock investments, monitoring portfolio performance, and viewing real-time stock price updates.

## Screenshots

<div align="center">

<table>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/59ee82b3-167a-4169-a813-e42c2b1a3432" width="250"/></td>
    <td><img src="https://github.com/user-attachments/assets/4c559743-62d9-4f14-95ba-a4660658e425" width="250"/></td>
    <td><img src="https://github.com/user-attachments/assets/5dda93f6-9561-4797-bfcf-d189d336731e" width="250"/></td>
  </tr>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/2cb8ea84-0c68-4a0c-8cc6-8724e916b72e" width="250"/></td>
    <td><img src="https://github.com/user-attachments/assets/665a0941-65e1-4b70-835a-86862285a927" width="250"/></td>
    <td><img src="https://github.com/user-attachments/assets/55d986cf-56c4-4833-9390-1e902ff4193f" width="250"/></td>
  </tr>
</table>

</div>

## Features

- Add and track stock positions
- View total portfolio value
- Track gains, losses, cost basis, dividends, and realized gains
- Real-time stock price updates
- Portfolio allocation chart
- Individual stock detail pages
- Buy and sell stock tracking
- Watchlist for monitoring stocks
- Price alerts with local notifications
- Currency display options
- Light and dark mode support
- Local data storage using SharedPreferences

## Tech Stack

- Flutter
- Dart
- Provider for state management
- Finnhub API for stock quotes and metrics
- Yahoo Finance chart data for dividends and historical price data
- fl_chart for charts and visualizations
- shared_preferences for local storage
- flutter_local_notifications for price alerts

## Project Structure

```text
lib/
├── models/
├── providers/
├── screens/
├── services/
├── widgets/
└── main.dart
