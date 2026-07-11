import Foundation

protocol MatchServicing {
    /// Live stream of the user's matches, newest activity first.
    func observeMatches(userId: String) -> AsyncStream<[Match]>
    func fetchMatch(matchId: String) async throws -> Match?
}
