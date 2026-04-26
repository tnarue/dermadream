//
//  ProductLookupService.swift
//  dermadream
//
//  Thin wrapper around the Barcode Lookup API
//  (https://www.barcodelookup.com/api).
//
//  Endpoint used:
//      GET https://api.barcodelookup.com/v3/products
//          ?barcode=<BARCODE>&formatted=y&key=<BARCODELOOKUP_API_KEY>
//
//  The key is read from `Config.xcconfig` through `Info.plist` via
//  `APIConfig` — never hardcoded.
//
//  The barcode *UI* (scan + manual code) for Routine / Suspect lives at the
//  bottom of this file so all Barcode Lookup usage shares one
//  `ProductLookupDataScanner` with Product Check (`ProductsView`).
//

import AVFoundation
import Foundation
import SwiftUI
import UIKit
import VisionKit

// MARK: - Public result

/// Minimal product shape consumed by the UI layer + Gemini integration.
struct ProductLookupResult: Equatable {
    let barcode: String
    let brand: String
    let title: String

    /// The string handed to `TargetProductAnalysisService`.
    ///
    /// We send `products[0].title` verbatim — the same way the Manual
    /// Input sheet sends whatever the user typed into "Product name".
    /// `brand` is kept on the struct for display only; we don't
    /// concatenate it here because most Barcode Lookup titles already
    /// embed the brand (e.g. "The Ordinary Glycolic Acid 7% Toning
    /// Solution") and doubling it up confuses Gemini.
    var targetProductName: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty {
            return collapseWhitespace(t)
        }
        // Fallback when the API returned a brand-only record with no title.
        return collapseWhitespace(brand.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func collapseWhitespace(_ input: String) -> String {
        input.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
    }
}

// MARK: - Errors

enum ProductLookupError: LocalizedError {
    case invalidBarcode
    case invalidURL
    case missingAPIKey(String)
    case notFound
    case http(status: Int, body: String)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidBarcode:
            return "The scanned barcode was empty or malformed."
        case .invalidURL:
            return "Could not build a valid Barcode Lookup URL."
        case .missingAPIKey(let detail):
            return "Barcode Lookup API key is not configured. \(detail)"
        case .notFound:
            return "Product not found. Please try Manual Input."
        case .http(let status, let body):
            return "Barcode Lookup HTTP error \(status). \(body)"
        case .decoding(let detail):
            return "Failed to decode Barcode Lookup response: \(detail)"
        case .transport(let detail):
            return "Network error: \(detail)"
        }
    }
}

// MARK: - Service

final class ProductLookupService {
    private let session: URLSession
    private let baseURL: String

    init(
        session: URLSession = .shared,
        baseURL: String = APIConfig.barcodeLookupBaseURL
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    /// GET /v3/products?barcode=...&formatted=y&key=...
    /// Returns the first product's brand + title. Empty `products`
    /// array -> `ProductLookupError.notFound`.
    func lookupProduct(barcode: String) async throws -> ProductLookupResult {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProductLookupError.invalidBarcode
        }

        let url = try buildURL(for: trimmed)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ProductLookupError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ProductLookupError.transport("Response was not an HTTP response.")
        }

        // The API returns 404 when the barcode isn't in its database.
        if http.statusCode == 404 {
            throw ProductLookupError.notFound
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            throw ProductLookupError.http(status: http.statusCode, body: body)
        }

        let decoded: BarcodeLookupResponse
        do {
            decoded = try JSONDecoder().decode(BarcodeLookupResponse.self, from: data)
        } catch {
            throw ProductLookupError.decoding(error.localizedDescription)
        }

        guard let first = decoded.products.first else {
            throw ProductLookupError.notFound
        }

        let brand = (first.brand ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (first.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        // Even if the API succeeds but returns no usable name at all,
        // treat it as not found so the UI falls back to Manual Input.
        guard !(brand.isEmpty && title.isEmpty) else {
            throw ProductLookupError.notFound
        }

        return ProductLookupResult(
            barcode: trimmed,
            brand: brand,
            title: title
        )
    }

    // MARK: - URL construction

    private func buildURL(for barcode: String) throws -> URL {
        let apiKey: String
        do {
            apiKey = try APIConfig.barcodeLookupAPIKeyThrowing()
        } catch {
            throw ProductLookupError.missingAPIKey(error.localizedDescription)
        }

        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "barcode", value: barcode),
            URLQueryItem(name: "formatted", value: "y"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        guard let url = components?.url else {
            throw ProductLookupError.invalidURL
        }
        return url
    }
}

// MARK: - Wire models

/// Partial decoding of the Barcode Lookup response. We only read the
/// fields the app actually needs.
private struct BarcodeLookupResponse: Decodable {
    let products: [BarcodeLookupProduct]
}

private struct BarcodeLookupProduct: Decodable {
    let title: String?
    let brand: String?
    let manufacturer: String?

    enum CodingKeys: String, CodingKey {
        case title
        case brand
        case manufacturer
    }
}

// MARK: - Barcode form sheet (API via `DermadreamEngine.lookupProductByBarcode` → `ProductLookupService`)

/// Scan or type a barcode, then return `ProductLookupResult` from
/// `ProductLookupService` (through the engine). Used by Suspect and Routine.
@available(iOS 16.0, *)
struct ProductLookupBarcodeSheet: View {
    @EnvironmentObject private var engine: DermadreamEngine
    @Binding var isPresented: Bool
    var onResult: (ProductLookupResult) -> Void

    @State private var manualBarcode = ""
    @State private var cameraAuthorized: Bool?
    @State private var phase: LookupPhase = .idle
    @State private var activeAlert: ProductLookupFormAlert?
    @State private var scannerResetToken = UUID()

    private enum LookupPhase: Equatable {
        case idle
        case lookingUp(String)
    }

    private enum ProductLookupFormAlert: Identifiable {
        case notFound
        case error(String)

        var id: String {
            switch self {
            case .notFound: return "not_found"
            case .error(let s): return "e:\(s)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    formScannerBlock
                    manualBarcodeRow
                }
                if case let .lookingUp(code) = phase {
                    formLookupOverlay(code: code)
                }
            }
            .navigationTitle("Scan barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                        .foregroundStyle(DermadreamTheme.deepUmber)
                        .disabled(phase != .idle)
                }
            }
            .task { await checkCameraAccess() }
            .alert(item: $activeAlert) { alert in
                switch alert {
                case .notFound:
                    Alert(
                        title: Text("Product not found"),
                        message: Text("We couldn’t find this barcode. Try a different product or type the name manually."),
                        dismissButton: .default(Text("OK")) { resume() }
                    )
                case .error(let message):
                    Alert(
                        title: Text("Lookup failed"),
                        message: Text(message),
                        dismissButton: .default(Text("OK")) { resume() }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var formScannerBlock: some View {
        if ProductLookupDataScanner.isSupported {
            switch cameraAuthorized {
            case .some(true):
                ProductLookupDataScanner(
                    resetToken: scannerResetToken,
                    isPaused: phase != .idle
                ) { runLookup($0) }
                .ignoresSafeArea(edges: .bottom)
            case .some(false):
                formCameraDenied
            case .none:
                ProgressView("Requesting camera access...")
                    .tint(DermadreamTheme.deepUmber)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            formScannerUnsupported
        }
    }

    private var formCameraDenied: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Enable camera access in Settings to scan, or enter the code below.")
                .font(DermadreamTheme.displaySemibold(14))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
        }
    }

    private var formScannerUnsupported: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Live scanning isn’t available on this device. Enter the barcode below.")
                .font(DermadreamTheme.displaySemibold(14))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
        }
    }

    private var manualBarcodeRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TextField(
                    "Enter barcode (EAN/UPC)…",
                    text: $manualBarcode
                )
                .font(DermadreamTheme.displaySemibold(15))
                .keyboardType(.numberPad)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )
                .foregroundStyle(.white)
                .disabled(phase != .idle)

                Button {
                    runLookup(manualBarcode)
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(DermadreamTheme.deepUmber)
                }
                .disabled(phase != .idle || manualBarcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private func formLookupOverlay(code: String) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .tint(.white)
                Text("Looking up product…")
                    .font(DermadreamTheme.displaySemibold(15))
                    .foregroundStyle(.white)
                Text("Barcode \(code)")
                    .font(DermadreamTheme.displaySemibold(12))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(20)
        }
    }

    private func runLookup(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, phase == .idle else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        phase = .lookingUp(trimmed)
        Task { @MainActor in
            do {
                let result = try await engine.lookupProductByBarcode(trimmed)
                phase = .idle
                isPresented = false
                onResult(result)
            } catch let e as ProductLookupError {
                phase = .idle
                switch e {
                case .notFound: activeAlert = .notFound
                default: activeAlert = .error(e.localizedDescription)
                }
            } catch {
                phase = .idle
                activeAlert = .error(error.localizedDescription)
            }
        }
    }

    private func resume() {
        manualBarcode = ""
        scannerResetToken = UUID()
    }

    private func checkCameraAccess() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            await MainActor.run { cameraAuthorized = true }
        case .notDetermined:
            let ok = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run { cameraAuthorized = ok }
        default:
            await MainActor.run { cameraAuthorized = false }
        }
    }
}

// MARK: - VisionKit (shared: Product Check + sheet above)

@available(iOS 16.0, *)
struct ProductLookupDataScanner: UIViewControllerRepresentable {
    let resetToken: UUID
    let isPaused: Bool
    var onCodeScanned: (String) -> Void

    static var isSupported: Bool {
        DataScannerViewController.isSupported
    }

    func makeCoordinator() -> ProductLookupScanCoordinator {
        ProductLookupScanCoordinator(onCodeScanned: onCodeScanned)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [.ean13, .upce, .ean8, .code128])
            ],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        context.coordinator.scanner = scanner
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onCodeScanned = onCodeScanned
        context.coordinator.apply(
            resetToken: resetToken,
            isPaused: isPaused,
            on: scanner
        )
    }

    static func dismantleUIViewController(
        _ scanner: DataScannerViewController,
        coordinator: ProductLookupScanCoordinator
    ) {
        scanner.stopScanning()
    }

    final class ProductLookupScanCoordinator: NSObject, DataScannerViewControllerDelegate {
        var onCodeScanned: (String) -> Void
        weak var scanner: DataScannerViewController?
        private var hasScanned = false
        private var lastResetToken: UUID?

        init(onCodeScanned: @escaping (String) -> Void) {
            self.onCodeScanned = onCodeScanned
        }

        func apply(
            resetToken: UUID,
            isPaused: Bool,
            on scanner: DataScannerViewController
        ) {
            if lastResetToken != resetToken {
                lastResetToken = resetToken
                hasScanned = false
            }
            if isPaused {
                scanner.stopScanning()
                return
            }
            guard !scanner.isScanning else { return }
            do {
                try scanner.startScanning()
            } catch { }
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !hasScanned else { return }
            for item in addedItems {
                if case let .barcode(code) = item,
                   let payload = code.payloadStringValue,
                   !payload.isEmpty {
                    hasScanned = true
                    dataScanner.stopScanning()
                    onCodeScanned(payload)
                    return
                }
            }
        }
    }
}
