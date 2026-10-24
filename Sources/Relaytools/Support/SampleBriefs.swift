import Foundation

struct SampleBrief: Identifiable {
    let id: String
    let title: String
    let summary: String
    let symbol: String
    let text: String
}

enum SampleBriefs {
    static let all: [SampleBrief] = [
        .init(id: "shared-inbox", title: "Team inbox", summary: "Sell software to a busy business", symbol: "tray.2", text: DemoData.exampleBrief),
        .init(id: "coffee", title: "Coffee subscription", summary: "Turn a first order into a regular habit", symbol: "cup.and.saucer", text: """
        Ember & Oak is a fictional coffee subscription delivering freshly roasted whole beans to home customers. Customers choose a flavour profile and can pause or cancel before the next dispatch.

        A 500g delivery costs £18, including delivery. Delivery can be every two or four weeks. There is no minimum subscription term. We offer a one-off 250g tasting pack for £10 including delivery, but there are no free samples.

        The customer enjoys coffee but is unsure whether a subscription is worth more than supermarket beans. Ask about their brewing method, how much coffee they use, flavour preferences, and budget.

        The goal is to agree on a tasting pack or a suitable first subscription delivery if there is a genuine fit. Do not claim health benefits, invent discounts, or pressure someone who prefers a one-off order.
        """),
        .init(id: "scheduling", title: "Shift scheduling", summary: "Help a manager simplify the rota", symbol: "calendar", text: """
        Shiftwise is a fictional scheduling tool for independent cafés and small shops. Managers can create weekly rotas, share updates with staff, and review shift-swap requests in one place.

        It costs £49 per location per month for up to 20 employees. There is a 14-day free trial, no setup fee, and monthly cancellation. It does not include payroll processing or automatic legal-compliance checks.

        The customer manages a small team using spreadsheets and a group chat. They may worry about price, staff learning another app, and the time it takes to switch.

        The goal is to understand the manager's current scheduling problems and agree on a short demo or a trial for the next rota. Be clear about the limits and ask what a successful trial would look like.
        """),
        .init(id: "bicycle", title: "City bicycle", summary: "Find the right fit for a new commuter", symbol: "bicycle", text: """
        The Cityline 7 is a fictional commuter bicycle sold in a local bike shop. It has seven gears, mudguards, a rear rack, and integrated lights. It costs £549 and includes a basic fitting and a six-week adjustment service.

        A helmet and lock are sold separately. We offer a free 20-minute test ride with a booking, but no finance plans or guaranteed discounts. Stock and frame-size availability must be checked before promising collection.

        The customer is considering cycling to work and may be comparing this bike with a cheaper model or keeping their current transport. Ask about their route, distance, storage, budget, and riding experience.

        The goal is to identify whether the bike suits their needs and agree on a test ride or purchase if appropriate. Do not make safety guarantees or sell a bike that is the wrong size or unsuitable for the route.
        """)
    ]
}
