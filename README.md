# Dermadream

Dermadream is an iOS app for tracking skincare routine usage and supporting irritation-focused decision making.
It combines routine logging, product checking, and symptom-driven investigation into one guided flow.

## Features

- **Acute Irritation Flow**
  - Symptom mapping with visual and non-visual options
  - Multi-ticket irritation capture (for separate areas/symptom sets)
  - Guided suspect-product logging before report generation
  - Structured irritation report with routine heatmap and risk-focused insights

- **Product Check (Shelf Diagnostics)**
  - Manual product input
  - Barcode-based product lookup flow
  - Risk-oriented analysis result view
  - Recent checks history and shelf diagnostics

- **Routine Management**
  - Add products with day slot and usage frequency
  - Grouped view of current routine by time-of-day
  - Archive/stop workflow for past products
  - Product history browsing

- **App Experience**
  - Welcome onboarding paths for core concerns
  - Dashboard summary cards
  - Quick menu shortcuts to major flows
  - Consistent design system and theme tokens

## Main App Flow

1. **Welcome**
   - User selects a pathway: Acute Irritation, Product Check, or Skincare Routine.
2. **Feature Workflows**
   - Acute Irritation: map symptoms -> log suspect products -> view report.
   - Product Check: manual/barcode input -> analysis result.
   - Routine: add/update products -> maintain current and past routine.
3. **Cross-feature Context**
   - Routine and symptom context inform later analysis screens and reporting.

## Project Structure

`dermadream/dermadream/` contains the main app target source files.

Key files:

- `ContentView.swift` – App shell, tab host, quick menu.
- `WelcomeView.swift` – Entry routing into primary journeys.
- `RoutineView.swift` – Routine logging and history.
- `ProductsView.swift` – Product Check and result navigation.
- `AnatomySelectionView.swift` – Symptom map for acute irritation.
- `SuspectProductFlowView.swift` – Suspect product step before report.
- `IrritationReportView.swift` – Final irritation report UI.
- `DermadreamEngine.swift` – Orchestration and app-level feature state.
- `TargetProductAnalysisService.swift` – Target product analysis service integration.
- `AcuteIrritationService.swift` – Acute irritation analysis service integration.
- `ProductLookupService.swift` – Barcode/product lookup integration.
- `Models.swift` – Shared domain models and app data structures.

## Requirements

- macOS with Xcode installed
- iOS deployment target configured by the project (see Xcode target settings)

## Getting Started

1. Open the project in Xcode:
   - `dermadream/dermadream.xcodeproj`
2. Select the `dermadream` scheme.
3. Build and run on Simulator or a device.

## Configuration

Environment-specific values are supplied via `Config.xcconfig` and referenced in `Info.plist`.

Make sure your local configuration file is present and correctly mapped in target build configurations before running.

## Notes

- Keep local/environment configuration files out of version control when they contain sensitive values.
- For production deployments, use backend-managed data services and environment-specific configuration management.