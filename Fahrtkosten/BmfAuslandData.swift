struct BmfAuslandEntry: Identifiable {
    let id: String
    let name: String
    let day: Double      // An-/Abreisetag / > 8 h
    let fullDay: Double  // voller Tag (24 h)
}

// BMF-Schreiben vom 5. Dezember 2025 – europäische Länder ab 1. Januar 2026
// Für nicht gelistete Länder gilt der Luxemburg-Fallback (31 € / 47 €).
enum BmfAuslandData {
    static let year = 2026
    static let fallbackName = "Luxemburg (Fallback)"
    static let fallbackDay: Double = 31
    static let fallbackFullDay: Double = 47

    static let countries: [BmfAuslandEntry] = [
        .init(id: "albanien",         name: "Albanien",                               day: 22, fullDay: 33),
        .init(id: "belgien",          name: "Belgien",                                day: 40, fullDay: 59),
        .init(id: "daenemark",        name: "Dänemark",                               day: 50, fullDay: 75),
        .init(id: "finnland",         name: "Finnland",                               day: 36, fullDay: 54),
        .init(id: "fr_paris",         name: "Frankreich – Paris",                     day: 39, fullDay: 58),
        .init(id: "fr_sonst",         name: "Frankreich – übriges Land",              day: 36, fullDay: 53),
        .init(id: "it_rom",           name: "Italien – Rom",                          day: 32, fullDay: 48),
        .init(id: "it_sonst",         name: "Italien – übriges Land",                 day: 28, fullDay: 42),
        .init(id: "luxemburg",        name: "Luxemburg",                              day: 31, fullDay: 47),
        .init(id: "niederlande",      name: "Niederlande",                            day: 39, fullDay: 58),
        .init(id: "oesterreich",      name: "Österreich",                             day: 33, fullDay: 50),
        .init(id: "ch_bern",          name: "Schweiz – Bern",                         day: 55, fullDay: 82),
        .init(id: "ch_genf",          name: "Schweiz – Genf",                         day: 44, fullDay: 70),
        .init(id: "ch_sonst",         name: "Schweiz – übriges Land",                 day: 47, fullDay: 70),
        .init(id: "es_madrid",        name: "Spanien – Madrid",                       day: 28, fullDay: 42),
        .init(id: "es_sonst",         name: "Spanien – übriges Land",                 day: 23, fullDay: 34),
        .init(id: "uk_london",        name: "Vereinigtes Königreich – London",         day: 44, fullDay: 66),
        .init(id: "uk_sonst",         name: "Vereinigtes Königreich – übriges Land",   day: 35, fullDay: 52),
        .init(id: "weissrussland",    name: "Weißrussland",                           day: 13, fullDay: 20),
        .init(id: "zypern",           name: "Zypern",                                 day: 28, fullDay: 42),
    ]

    static var sorted: [BmfAuslandEntry] { countries.sorted { $0.name < $1.name } }
}
