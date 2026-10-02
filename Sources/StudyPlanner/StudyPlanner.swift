import Foundation

public enum StudyCategory: String, Codable, CaseIterable {
    case reading, practice, project
}

public enum StudyPlanError: Error, Equatable {
    case blankTitle
    case nonPositiveEstimatedMinutes
    case duplicateID(String)
    case unknownID(String)
}

public struct StudyItem: Codable, Equatable {
    public let id: String
    public let title: String
    public let estimatedMinutes: Int
    public let category: StudyCategory
    public private(set) var isCompleted: Bool

    public init(
        id: String,
        title: String,
        estimatedMinutes: Int,
        category: StudyCategory,
        isCompleted: Bool = false
    ) throws {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw StudyPlanError.blankTitle
        }
        if estimatedMinutes <= 0 {
            throw StudyPlanError.nonPositiveEstimatedMinutes
        }
        self.id = id
        self.title = title
        self.estimatedMinutes = estimatedMinutes
        self.category = category
        self.isCompleted = isCompleted
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, estimatedMinutes, category, isCompleted
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let title = try container.decode(String.self, forKey: .title)
        let estimatedMinutes = try container.decode(Int.self, forKey: .estimatedMinutes)
        let category = try container.decode(StudyCategory.self, forKey: .category)
        let isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false

        try self.init(
            id: id,
            title: title,
            estimatedMinutes: estimatedMinutes,
            category: category,
            isCompleted: isCompleted
        )
    }
}

public struct StudyPlan: Codable, Equatable {
    public private(set) var items: [StudyItem]

    public init(items: [StudyItem]) throws {
        var seenIDs = Set<String>()
        for item in items {
            if seenIDs.contains(item.id) {
                throw StudyPlanError.duplicateID(item.id)
            }
            seenIDs.insert(item.id)
        }

        self.items = items.sorted { lhs, rhs in
            if lhs.title != rhs.title {
                return lhs.title < rhs.title
            }
            return lhs.id < rhs.id
        }
    }

    private enum CodingKeys: String, CodingKey {
        case items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawItems = try container.decode([StudyItem].self, forKey: .items)
        try self.init(items: rawItems)
    }

    public static func decode(from data: Data) throws -> StudyPlan {
        let decoder = JSONDecoder()
        if let jsonObject = try? JSONSerialization.jsonObject(with: data), jsonObject is [Any] {
            let items = try decoder.decode([StudyItem].self, from: data)
            return try StudyPlan(items: items)
        }
        return try decoder.decode(StudyPlan.self, from: data)
    }

    public func items(in category: StudyCategory) -> [StudyItem] {
        return items.filter { $0.category == category }
    }

    public func incompleteMinutes() -> Int {
        return items.lazy.filter { !$0.isCompleted }.reduce(0) { $0 + $1.estimatedMinutes }
    }

    public mutating func markCompleted(id: String) throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw StudyPlanError.unknownID(id)
        }
        items[index] = try StudyItem(
            id: items[index].id,
            title: items[index].title,
            estimatedMinutes: items[index].estimatedMinutes,
            category: items[index].category,
            isCompleted: true
        )
    }

    public mutating func importMerging(_ importedItems: [StudyItem]) throws {
        var importedIDs = Set<String>()
        for item in importedItems {
            if importedIDs.contains(item.id) {
                throw StudyPlanError.duplicateID(item.id)
            }
            importedIDs.insert(item.id)
        }

        var existingIDToIndex = [String: Int]()
        for (index, item) in items.enumerated() {
            existingIDToIndex[item.id] = index
        }

        var updatedItems = items
        var newItems = [StudyItem]()

        for item in importedItems {
            if let existingIndex = existingIDToIndex[item.id] {
                updatedItems[existingIndex] = item
            } else {
                newItems.append(item)
            }
        }

        newItems.sort { $0.id < $1.id }
        updatedItems.append(contentsOf: newItems)
        self.items = updatedItems
    }
}
