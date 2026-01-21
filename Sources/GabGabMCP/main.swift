import Foundation
import GabGab

@main
struct GabGabMCPMain {
    @MainActor
    static func main() async {
        let handler = MCPProtocolHandler.create()
        await handler.run()
    }
}
