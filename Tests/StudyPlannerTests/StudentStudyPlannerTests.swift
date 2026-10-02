import XCTest
@testable import StudyPlanner

final class StudentStudyPlannerTests: XCTestCase {

    // - Task 1: Validation Precedence & Error Handling

    func testValidationPrecedenceBlankTitleOverNonPositiveMinutes() {
        // Arrange
        let blankTitle = "   \n\t "
        let invalidMinutes = -10

        // Act & Assert
        XCTAssertThrowsError(
            try StudyItem(id: "val-1", title: blankTitle, estimatedMinutes: invalidMinutes, category: .reading)
        ) { error in
            XCTAssertEqual(error as? StudyPlanError, StudyPlanError.blankTitle)
        }
    }

    func testNonPositiveMinutesIsRejected() {
        // Arrange
        let title = "Valid Title"
        let zeroMinutes = 0

        // Act & Assert
        XCTAssertThrowsError(
            try StudyItem(id: "val-2", title: title, estimatedMinutes: zeroMinutes, category: .practice)
        ) { error in
            XCTAssertEqual(error as? StudyPlanError, StudyPlanError.nonPositiveEstimatedMinutes)
        }
    }

    // - Task 2 & 3: Duplicates, Ordering, and Decoding

    func testStudyPlanDuplicateIDThrowsFirstDuplicate() throws {
        // Arrange
        let item1 = try StudyItem(id: "dup", title: "Alpha", estimatedMinutes: 10, category: .reading)
        let item2 = try StudyItem(id: "dup", title: "Beta", estimatedMinutes: 20, category: .practice)

        // Act & Assert
        XCTAssertThrowsError(
            try StudyPlan(items: [item1, item2])
        ) { error in
            XCTAssertEqual(error as? StudyPlanError, StudyPlanError.duplicateID("dup"))
        }
    }

    func testStudyPlanDeterministicOrderingByTitleThenID() throws {
        // Arrange
        let itemA = try StudyItem(id: "2", title: "Math", estimatedMinutes: 15, category: .practice)
        let itemB = try StudyItem(id: "1", title: "Math", estimatedMinutes: 25, category: .reading)
        let itemC = try StudyItem(id: "3", title: "Algorithms", estimatedMinutes: 30, category: .project)

        // Act
        let plan = try StudyPlan(items: [itemA, itemB, itemC])

        // Assert
        XCTAssertEqual(plan.items.map { $0.id }, ["3", "1", "2"])
    }

    func testDecodingTopLevelArrayAndKeyedJSON() throws {
        // Arrange
        let jsonArrayData = """
        [
            {"id": "item-1", "title": "Read Chapter", "estimatedMinutes": 30, "category": "reading", "isCompleted": false}
        ]
        """.data(using: .utf8)!

        let jsonKeyedData = """
        {
            "items": [
                {"id": "item-1", "title": "Read Chapter", "estimatedMinutes": 30, "category": "reading", "isCompleted": false}
            ]
        }
        """.data(using: .utf8)!

        // Act
        let planFromArray = try StudyPlan.decode(from: jsonArrayData)
        let planFromKeyed = try StudyPlan.decode(from: jsonKeyedData)

        // Assert
        XCTAssertEqual(planFromArray, planFromKeyed)
        XCTAssertEqual(planFromArray.items.count, 1)
        XCTAssertEqual(planFromArray.items.first?.id, "item-1")
    }

    // - Task 4: Queries, Completion, and Idempotency

    func testCategoryQueryAndIncompleteMinutesCalculation() throws {
        // Arrange
        let item1 = try StudyItem(id: "1", title: "Read Book", estimatedMinutes: 40, category: .reading, isCompleted: false)
        let item2 = try StudyItem(id: "2", title: "Solve Quiz", estimatedMinutes: 20, category: .practice, isCompleted: true)
        let item3 = try StudyItem(id: "3", title: "Build App", estimatedMinutes: 60, category: .project, isCompleted: false)
        let plan = try StudyPlan(items: [item1, item2, item3])

        // Act
        let readingItems = plan.items(in: .reading)
        let totalIncomplete = plan.incompleteMinutes()

        // Assert
        XCTAssertEqual(readingItems.count, 1)
        XCTAssertEqual(readingItems.first?.id, "1")
        XCTAssertEqual(totalIncomplete, 100)
    }

    func testMarkCompletedUnknownIDThrowsAndIdempotent() throws {
        // Arrange
        let item = try StudyItem(id: "10", title: "Task", estimatedMinutes: 15, category: .practice)
        var plan = try StudyPlan(items: [item])

        // Act & Assert Unknown ID
        XCTAssertThrowsError(try plan.markCompleted(id: "unknown")) { error in
            XCTAssertEqual(error as? StudyPlanError, StudyPlanError.unknownID("unknown"))
        }

        // Act & Assert Idempotency
        try plan.markCompleted(id: "10")
        XCTAssertTrue(plan.items[0].isCompleted)

        try plan.markCompleted(id: "10")
        XCTAssertTrue(plan.items[0].isCompleted)
    }

    // - Bonus Task: importMerging

    func testImportMergingReplacesExistingAndAppendsNewInAscendingIDOrder() throws {
        // Arrange
        let orig1 = try StudyItem(id: "b", title: "Original B", estimatedMinutes: 10, category: .reading)
        let orig2 = try StudyItem(id: "d", title: "Original D", estimatedMinutes: 20, category: .practice)
        var plan = try StudyPlan(items: [orig1, orig2])

        let replacementB = try StudyItem(id: "b", title: "Original B", estimatedMinutes: 15, category: .reading, isCompleted: true)
        let newZ = try StudyItem(id: "z", title: "New Z", estimatedMinutes: 30, category: .project)
        let newA = try StudyItem(id: "a", title: "New A", estimatedMinutes: 25, category: .reading)

        // Act
        try plan.importMerging([replacementB, newZ, newA])

        // Assert
        XCTAssertEqual(plan.items[0].estimatedMinutes, 15)
        XCTAssertTrue(plan.items[0].isCompleted)
        XCTAssertEqual(plan.items[1].id, "d")
        XCTAssertEqual(plan.items[2].id, "a")
        XCTAssertEqual(plan.items[3].id, "z")
    }

    func testImportMergingDuplicateIncomingIDsThrowsWithoutModifyingPlan() throws {
        // Arrange
        let orig = try StudyItem(id: "1", title: "Original", estimatedMinutes: 10, category: .reading)
        var plan = try StudyPlan(items: [orig])

        let imported1 = try StudyItem(id: "dup", title: "Dup 1", estimatedMinutes: 15, category: .practice)
        let imported2 = try StudyItem(id: "dup", title: "Dup 2", estimatedMinutes: 25, category: .project)

        // Act & Assert
        XCTAssertThrowsError(try plan.importMerging([imported1, imported2])) { error in
            XCTAssertEqual(error as? StudyPlanError, StudyPlanError.duplicateID("dup"))
        }

        // Assert Plan State Remains Unchanged (Atomic)
        XCTAssertEqual(plan.items.count, 1)
        XCTAssertEqual(plan.items.first?.id, "1")
    }
}
