import Foundation
import Combine

final class AppData: ObservableObject {
    @Published var problems: [PracticeProblem] = []
    @Published var tutorials: [AlgorithmTutorial] = []
    @Published var savedProblemIDs: [String] = []
    @Published var practicedProblemIDs: [String] = []

    init() {
        loadProblems()
        loadTutorials()
    }

    var savedProblems: [PracticeProblem] {
        savedProblemIDs.compactMap { problemID in
            problems.first(where: { $0.id == problemID })
        }
    }

    func loadProblems() {
        problems = Bundle.main.decode("problems.json")
    }

    func loadTutorials() {
        tutorials = Bundle.main.decode("tutorials.json")
    }

    func saveProblem(_ problem: PracticeProblem) {
        guard !savedProblemIDs.contains(problem.id) else { return }
        savedProblemIDs.append(problem.id)
    }

    func isSaved(_ problem: PracticeProblem) -> Bool {
        savedProblemIDs.contains(problem.id)
    }

    func markAsPracticed(problem: PracticeProblem) {
        guard !practicedProblemIDs.contains(problem.id) else { return }
        practicedProblemIDs.append(problem.id)
    }

    func isPracticed(_ problem: PracticeProblem) -> Bool {
        practicedProblemIDs.contains(problem.id)
    }
}

extension Bundle {
    func decode<T: Decodable>(_ fileName: String) -> T {
        let directURL = url(forResource: fileName, withExtension: nil)
        let resourcesURL = url(forResource: fileName, withExtension: nil, subdirectory: "Resources")

        guard let url = directURL ?? resourcesURL else {
            fatalError("Could not find \(fileName) in app bundle.")
        }

        guard let data = try? Data(contentsOf: url) else {
            fatalError("Could not load \(fileName) from app bundle.")
        }

        let decoder = JSONDecoder()

        guard let loadedData = try? decoder.decode(T.self, from: data) else {
            fatalError("Could not decode \(fileName) from app bundle.")
        }

        return loadedData
    }
}
