//
//  MockUserRecordsDB.swift
//  dermadream
//
//  In-memory stand-in for a MongoDB connection.
//  Database: "dermadream", Collection: "user_records".
//
//  Wrapped in an actor so it is safe to access from any async context.
//  Swap the internal storage for a real MongoDB driver (or a networked
//  backend) without changing the call sites in TargetProductAnalysisService.
//

import Foundation

// MARK: - Schema

/// Matches a single document in the `user_records` collection.
struct UserRecord: Codable, Equatable, Identifiable {
    var id: String { userId }
    let userId: String
    let skinBaseline: String
    let knownAllergens: [String]
    var history: [ProductReactionRecord]
    /// Unified routine source (current + stopped). Analysis should prefer this.
    var routineLog: [RoutineEntry]

    enum CodingKeys: String, CodingKey {
        case userId
        case skinBaseline
        case knownAllergens
        case history
        case routineLog
    }

    init(
        userId: String,
        skinBaseline: String,
        knownAllergens: [String],
        history: [ProductReactionRecord],
        routineLog: [RoutineEntry] = []
    ) {
        self.userId = userId
        self.skinBaseline = skinBaseline
        self.knownAllergens = knownAllergens
        self.history = history
        self.routineLog = routineLog
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decode(String.self, forKey: .userId)
        skinBaseline = try c.decode(String.self, forKey: .skinBaseline)
        knownAllergens = try c.decode([String].self, forKey: .knownAllergens)
        history = try c.decodeIfPresent([ProductReactionRecord].self, forKey: .history) ?? []
        routineLog = try c.decodeIfPresent([RoutineEntry].self, forKey: .routineLog) ?? []
    }
}

/// One row of the user's product history array.
struct ProductReactionRecord: Codable, Equatable, Hashable {
    let productBrand: String
    let productName: String
    /// e.g. "burning", "redness", "itching", "flaking", "none".
    let reactionType: String
    let details: String

    enum CodingKeys: String, CodingKey {
        case productBrand = "product_brand"
        case productName = "product_name"
        case reactionType = "reaction_type"
        case details
    }
}

// MARK: - Database errors

enum UserRecordsDBError: LocalizedError {
    case userNotFound(String)

    var errorDescription: String? {
        switch self {
        case .userNotFound(let id):
            return "No user record found for userId \"\(id)\" in dermadream.user_records."
        }
    }
}

// MARK: - Provider protocol

/// Abstraction over "fetch a user record by id".
/// `MockUserRecordsDB` (in-memory) and `RemoteUserRecordsService`
/// (HTTP → MongoDB bridge) both conform, so the rest of the app can
/// stay oblivious to where the data actually lives.
protocol UserRecordsProviding: Sendable {
    func findUserRecord(userId: String) async throws -> UserRecord
}

extension MockUserRecordsDB: UserRecordsProviding {}

// MARK: - Mock DB

/// Actor-based in-memory store that mimics a MongoDB collection.
/// Thread-safe by construction; all reads/writes go through the actor.
actor MockUserRecordsDB {
    static let shared = MockUserRecordsDB()

    private var collection: [String: UserRecord]

    init(seed: [UserRecord] = MockUserRecordsDB.defaultSeed) {
        var dict: [String: UserRecord] = [:]
        for record in seed {
            dict[record.userId] = record
        }
        self.collection = dict
    }

    /// `db.dermadream.user_records.findOne({ userId })`
    func findUserRecord(userId: String) async throws -> UserRecord {
        guard let record = collection[userId] else {
            throw UserRecordsDBError.userNotFound(userId)
        }
        return record
    }

    /// Upsert — `updateOne({ userId }, { $set: record }, { upsert: true })`.
    func upsert(_ record: UserRecord) {
        collection[record.userId] = record
    }

    /// Append a new reaction to a user's history array.
    /// `updateOne({ userId }, { $push: { history: reaction } })`
    func appendReaction(_ reaction: ProductReactionRecord, for userId: String) throws {
        guard let existing = collection[userId] else {
            throw UserRecordsDBError.userNotFound(userId)
        }
        let mergedRoutine = Self.upsertRoutineEntry(from: reaction, into: existing.routineLog)
        let updated = UserRecord(
            userId: existing.userId,
            skinBaseline: existing.skinBaseline,
            knownAllergens: existing.knownAllergens,
            history: existing.history + [reaction],
            routineLog: mergedRoutine
        )
        collection[userId] = updated
    }

    private static func upsertRoutineEntry(
        from reaction: ProductReactionRecord,
        into log: [RoutineEntry]
    ) -> [RoutineEntry] {
        let key = normalizedProductKey(brand: reaction.productBrand, name: reaction.productName)
        let hasEntry = log.contains {
            normalizedProductKey(brand: $0.brand, name: $0.productName) == key
        }
        guard !hasEntry else { return log }

        let status: RoutineStatus = reaction.reactionType.caseInsensitiveCompare("Routine Log") == .orderedSame
            ? .current
            : .stopped
        let added = RoutineEntry(
            productName: reaction.productName,
            brand: reaction.productBrand,
            status: status,
            startDate: nil,
            endDate: status == .stopped ? .now : nil,
            slot: .other
        )
        return [added] + log
    }

    private static func normalizedProductKey(brand: String, name: String) -> String {
        let b = brand.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let n = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if b.isEmpty { return n }
        if n.isEmpty { return b }
        return "\(b) \(n)"
    }

    // MARK: - Seed data

    /// Mirror of `dermadream/mock-db.json`.
    ///
    /// The JSON uses a single `product_full_name` field per history entry,
    /// so we map that verbatim into `productName` and leave `productBrand`
    /// blank; `TargetProductAnalysisService.combinedProductLabel` handles
    /// the empty brand and sends just the full name to Gemini — the same
    /// string shape the barcode flow sends via `products[0].title`.
    ///
    /// `severity` is folded into `details` so it survives the trip to
    /// Gemini through `user_history[].details`.
    static let defaultSeed: [UserRecord] = [
        UserRecord(
            userId: "1",
            skinBaseline: "Sensitive-Combination",
            knownAllergens: [],
            history: [
                ProductReactionRecord(
                    productBrand: "",
                    productName: "The Ordinary Glycolic Acid 7% Toning Solution",
                    reactionType: "Chemical Irritation",
                    details: "Severity: High. Intense burning on the cheeks and immediate flare-up of redness."
                ),
                ProductReactionRecord(
                    productBrand: "",
                    productName: "CeraVe Facial Moisturizing Lotion PM",
                    reactionType: "None",
                    details: "Severity: None. Standard daily moisturizer. No negative reaction, skin feels calm."
                ),
                ProductReactionRecord(
                    productBrand: "",
                    productName: "SkinCeuticals Retinol 0.3",
                    reactionType: "Retinization",
                    details: "Severity: Low. Dryness and mild peeling for the first 2 weeks, but no pain or burning."
                )
            ],
            routineLog: [
                RoutineEntry(
                    productName: "COSRX Low pH Good Morning Gel Cleanser",
                    brand: "CosRX",
                    status: .current,
                    startDate: Calendar.current.date(byAdding: .day, value: -20, to: .now),
                    slot: .morning
                ),
                RoutineEntry(
                    productName: "CeraVe Skin Renewing Vitamin C Serum",
                    brand: "CeraVe",
                    status: .current,
                    startDate: Calendar.current.date(byAdding: .day, value: -62, to: .now),
                    slot: .morning
                ),
                RoutineEntry(
                    productName: "Olay Night Repair Super Serum",
                    brand: "Olay",
                    status: .current,
                    startDate: Calendar.current.date(byAdding: .day, value: -20, to: .now),
                    slot: .night
                ),
                RoutineEntry(
                    productName: "Yves Saint Laurent Pure Shots Night Reboot Serum",
                    brand: "YSL",
                    status: .stopped,
                    startDate: Calendar.current.date(byAdding: .day, value: -110, to: .now),
                    endDate: Calendar.current.date(byAdding: .day, value: -8, to: .now),
                    slot: .night
                ),
                // Bring legacy reaction-only rows into stopped routine so
                // history is not disconnected from product lists.
                RoutineEntry(
                    productName: "The Ordinary Glycolic Acid 7% Toning Solution",
                    brand: "",
                    status: .stopped,
                    startDate: nil,
                    endDate: Calendar.current.date(byAdding: .day, value: -30, to: .now),
                    slot: .other
                ),
                RoutineEntry(
                    productName: "SkinCeuticals Retinol 0.3",
                    brand: "",
                    status: .stopped,
                    startDate: nil,
                    endDate: Calendar.current.date(byAdding: .day, value: -45, to: .now),
                    slot: .other
                )
            ]
        )
    ]
}
