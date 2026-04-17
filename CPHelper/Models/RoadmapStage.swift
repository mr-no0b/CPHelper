import Foundation

struct RoadmapStage: Identifiable, Equatable {
    let id: String
    let title: String
    let ratingRange: ClosedRange<Int>
    let nextRangeLabel: String
    let topicsToLearn: [String]
    let practiceRangeLabel: String
    let focusPoints: [String]

    static let all: [RoadmapStage] = [
        RoadmapStage(
            id: "foundation",
            title: "Foundation Builder",
            ratingRange: 0...999,
            nextRangeLabel: "Reach 1000-1299",
            topicsToLearn: ["Implementation", "Brute force", "Math basics", "Sorting", "Two pointers"],
            practiceRangeLabel: "Practice mostly 800-1000",
            focusPoints: [
                "Solve quickly and cleanly before increasing difficulty.",
                "Write full solutions without relying on hacks or template magic.",
                "Review every wrong answer until you can explain the exact bug."
            ]
        ),
        RoadmapStage(
            id: "pupil",
            title: "Pupil Track",
            ratingRange: 1000...1299,
            nextRangeLabel: "Reach 1300-1499",
            topicsToLearn: ["Greedy", "Prefix sums", "Binary search", "Basic constructive ideas", "Maps and sets"],
            practiceRangeLabel: "Practice mostly 900-1300",
            focusPoints: [
                "Build confidence on standard patterns until they feel automatic.",
                "Upsolve missed contest A/B/C level problems on the same day.",
                "Start tagging problems by pattern after each solve."
            ]
        ),
        RoadmapStage(
            id: "specialist",
            title: "Specialist Ramp",
            ratingRange: 1300...1599,
            nextRangeLabel: "Reach 1600-1799",
            topicsToLearn: ["DFS/BFS", "Shortest paths basics", "DP intro", "Combinatorics basics", "Binary search on answer"],
            practiceRangeLabel: "Practice mostly 1200-1600",
            focusPoints: [
                "Spend more time understanding editorial transitions, not only final code.",
                "Repeat weak tags until your acceptance rate stabilizes.",
                "Practice one or two stretch problems every session."
            ]
        ),
        RoadmapStage(
            id: "expert",
            title: "Expert Push",
            ratingRange: 1600...1899,
            nextRangeLabel: "Reach 1900-2099",
            topicsToLearn: ["Trees", "Advanced greedy", "Data structures", "DP refinement", "Graph modeling"],
            practiceRangeLabel: "Practice mostly 1400-1800",
            focusPoints: [
                "Alternate between contest practice and topic blocks each week.",
                "Track which mistakes come from ideas versus implementation.",
                "Get comfortable solving without immediately opening tutorials."
            ]
        ),
        RoadmapStage(
            id: "candidate-master",
            title: "Candidate Master Track",
            ratingRange: 1900...2199,
            nextRangeLabel: "Reach 2200-2399",
            topicsToLearn: ["Segment tree", "DSU", "Harder DP", "Number theory", "Flows or matching intro"],
            practiceRangeLabel: "Practice mostly 1700-2100",
            focusPoints: [
                "Practice combining two ideas in one problem instead of single-pattern tasks.",
                "Review top-user submissions after editorial study to compare implementations.",
                "Use virtual contests to sharpen time allocation."
            ]
        ),
        RoadmapStage(
            id: "master",
            title: "Master Ladder",
            ratingRange: 2200...3200,
            nextRangeLabel: "Push toward 2400+",
            topicsToLearn: ["Advanced graphs", "Advanced data structures", "String algorithms", "FFT or math heavy tools", "Proof techniques"],
            practiceRangeLabel: "Practice mostly 1900-2400+",
            focusPoints: [
                "Deliberately revisit failed 2000+ problems after a cooldown.",
                "Invest in proof-writing and invariant building, not just coding speed.",
                "Curate a narrow set of elite topics and grind them deeply."
            ]
        )
    ]

    static func stage(for rating: Int) -> RoadmapStage {
        all.first(where: { $0.ratingRange.contains(rating) }) ?? all[all.count - 1]
    }
}
