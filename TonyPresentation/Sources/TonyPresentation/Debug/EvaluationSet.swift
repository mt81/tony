import Foundation
import TonyCore

extension EvaluationCase {
    /// 26 cases per language: 10 plans to word, 12 sentences to read as tasks, 4 descriptions of a week.
    public static let all: [EvaluationCase] = ["en", "fr"].flatMap { language in
        plans(language) + sentences(language) + routines(language)
    }

    private typealias Plan = (day: String, items: [BriefingRequest.Item], busy: [(start: String, end: String)], others: [String])

    private static func plans(_ language: String) -> [EvaluationCase] {
        let locale = Locale(identifier: language)
        let plans: [Plan] = language == "fr" ? frenchPlans : englishPlans
        return plans.enumerated().map { index, plan in
            var footer = plan.busy.map { localized("Busy from \($0.start) to \($0.end)", locale) }
            if plan.items.isEmpty {
                footer.append(localized("Nothing is planned today.", locale))
            }
            let times = plan.items.map(\.time) + plan.busy.flatMap { [$0.start, $0.end] }
            let names = plan.items.map(\.title).formatted(.list(type: .and).locale(locale))
            let request = BriefingRequest(
                instructions: ModelInstructions.briefing(locale),
                header: [plan.day],
                items: plan.items,
                footer: footer,
                allowedMinutes: BriefingValidator.minutesOfDay(in: times.joined(separator: " ")),
                otherTaskNames: plan.others,
                fallback: plan.items.isEmpty
                    ? localized("Nothing needs you today. Enjoy it.", locale)
                    : localized("\(plan.items.count) things would be nice today: \(names).", locale)
            )
            return EvaluationCase(id: "B\(index + 1) \(language)", languageCode: language, kind: .briefing(request))
        }
    }

    private static func sentences(_ language: String) -> [EvaluationCase] {
        let sentences = language == "fr" ? frenchSentences : englishSentences
        return sentences.enumerated().map { index, sentence in
            EvaluationCase(
                id: "T\(index + 1) \(language)",
                languageCode: language,
                kind: .task(sentence: sentence.0, nameKeyword: sentence.1, cadence: sentence.2)
            )
        }
    }

    private static func routines(_ language: String) -> [EvaluationCase] {
        let routines = language == "fr" ? frenchRoutines : englishRoutines
        return routines.enumerated().map { index, routine in
            EvaluationCase(id: "R\(index + 1) \(language)", languageCode: language, kind: .routine(description: routine.0, expected: routine.1))
        }
    }

    private static let englishPlans: [Plan] = [
        (
            day: "Tuesday 10 November",
            items: [
                .init(time: "08:00", title: "Water the plants", reason: "The first moment that fits."),
                .init(time: "12:30", title: "Laundry · Start the wash", reason: "Before your 14:00 meetings. It runs on its own."),
                .init(time: "18:00", title: "Gym", reason: "Kept for the evening."),
            ],
            busy: [("14:00", "15:30")],
            others: ["Vacuum", "Meal prep"]
        ),
        (
            day: "Saturday 14 November",
            items: [
                .init(time: "10:00", title: "Vacuum", reason: "9 days since last time"),
            ],
            busy: [],
            others: ["Laundry", "Gym"]
        ),
        (
            day: "Wednesday 11 November",
            items: [],
            busy: [("09:00", "12:00")],
            others: ["Water the plants", "Gym"]
        ),
        (
            day: "Monday 9 November",
            items: [
                .init(time: "07:30", title: "Supplements", reason: "The first moment that fits."),
                .init(time: "19:00", title: "Meal prep", reason: "Kept for the evening."),
            ],
            busy: [("10:00", "11:00"), ("13:00", "14:30")],
            others: ["Run"]
        ),
        (
            day: "Thursday 12 November",
            items: [
                .init(time: "08:00", title: "Take out the trash", reason: "The first moment that fits."),
                .init(time: "08:15", title: "Water the plants", reason: "The first moment that fits."),
                .init(time: "12:00", title: "Laundry · Start the wash", reason: "The first moment that fits. It runs on its own."),
                .init(time: "20:00", title: "Laundry · Fold", reason: "Kept for the evening."),
            ],
            busy: [],
            others: ["Gym", "Vacuum"]
        ),
        (
            day: "Friday 13 November",
            items: [
                .init(time: "17:30", title: "Run", reason: "Right after your meetings."),
            ],
            busy: [("15:00", "17:30")],
            others: ["Gym", "Meal prep"]
        ),
        (
            day: "Sunday 15 November",
            items: [
                .init(time: "09:00", title: "Change bed sheets", reason: "16 days since last time"),
                .init(time: "11:00", title: "Meal prep", reason: "The first moment that fits."),
            ],
            busy: [],
            others: ["Vacuum"]
        ),
        (
            day: "Tuesday 17 November",
            items: [
                .init(time: "18:30", title: "Renew the passport", reason: "The first moment that fits."),
            ],
            busy: [("09:00", "18:00")],
            others: ["Gym", "Laundry"]
        ),
        (
            day: "Wednesday 18 November",
            items: [
                .init(time: "08:00", title: "Gym", reason: "The first moment that fits."),
                .init(time: "13:00", title: "Laundry · Dry", reason: "The first moment that fits. It runs on its own."),
                .init(time: "21:00", title: "Laundry · Fold", reason: "Kept for the evening."),
            ],
            busy: [],
            others: ["Run", "Supplements"]
        ),
        (
            day: "Monday 16 November",
            items: [
                .init(time: "12:15", title: "Call the dentist", reason: "Before your 13:00 meetings."),
            ],
            busy: [("13:00", "14:00")],
            others: ["Gym", "Run", "Vacuum"]
        ),
    ]

    private static let frenchPlans: [Plan] = [
        (
            day: "mardi 10 novembre",
            items: [
                .init(time: "08:00", title: "Arroser les plantes", reason: "Le premier moment qui convient."),
                .init(time: "12:30", title: "Lessive · Lancer la machine", reason: "Avant tes réunions de 14:00. Ça tourne tout seul."),
                .init(time: "18:00", title: "Sport", reason: "Gardé pour ce soir."),
            ],
            busy: [("14:00", "15:30")],
            others: ["Aspirateur", "Préparer les repas"]
        ),
        (
            day: "samedi 14 novembre",
            items: [
                .init(time: "10:00", title: "Aspirateur", reason: "9 jours depuis la dernière fois"),
            ],
            busy: [],
            others: ["Lessive", "Sport"]
        ),
        (
            day: "mercredi 11 novembre",
            items: [],
            busy: [("09:00", "12:00")],
            others: ["Arroser les plantes", "Sport"]
        ),
        (
            day: "lundi 9 novembre",
            items: [
                .init(time: "07:30", title: "Compléments", reason: "Le premier moment qui convient."),
                .init(time: "19:00", title: "Préparer les repas", reason: "Gardé pour ce soir."),
            ],
            busy: [("10:00", "11:00"), ("13:00", "14:30")],
            others: ["Courir"]
        ),
        (
            day: "jeudi 12 novembre",
            items: [
                .init(time: "08:00", title: "Sortir les poubelles", reason: "Le premier moment qui convient."),
                .init(time: "08:15", title: "Arroser les plantes", reason: "Le premier moment qui convient."),
                .init(time: "12:00", title: "Lessive · Lancer la machine", reason: "Le premier moment qui convient. Ça tourne tout seul."),
                .init(time: "20:00", title: "Lessive · Plier", reason: "Gardé pour ce soir."),
            ],
            busy: [],
            others: ["Sport", "Aspirateur"]
        ),
        (
            day: "vendredi 13 novembre",
            items: [
                .init(time: "17:30", title: "Courir", reason: "Juste après tes réunions."),
            ],
            busy: [("15:00", "17:30")],
            others: ["Sport", "Préparer les repas"]
        ),
        (
            day: "dimanche 15 novembre",
            items: [
                .init(time: "09:00", title: "Changer les draps", reason: "16 jours depuis la dernière fois"),
                .init(time: "11:00", title: "Préparer les repas", reason: "Le premier moment qui convient."),
            ],
            busy: [],
            others: ["Aspirateur"]
        ),
        (
            day: "mardi 17 novembre",
            items: [
                .init(time: "18:30", title: "Renouveler le passeport", reason: "Le premier moment qui convient."),
            ],
            busy: [("09:00", "18:00")],
            others: ["Sport", "Lessive"]
        ),
        (
            day: "mercredi 18 novembre",
            items: [
                .init(time: "08:00", title: "Sport", reason: "Le premier moment qui convient."),
                .init(time: "13:00", title: "Lessive · Sécher", reason: "Le premier moment qui convient. Ça tourne tout seul."),
                .init(time: "21:00", title: "Lessive · Plier", reason: "Gardé pour ce soir."),
            ],
            busy: [],
            others: ["Courir", "Compléments"]
        ),
        (
            day: "lundi 16 novembre",
            items: [
                .init(time: "12:15", title: "Appeler le dentiste", reason: "Avant tes réunions de 13:00."),
            ],
            busy: [("13:00", "14:00")],
            others: ["Sport", "Courir", "Aspirateur"]
        ),
    ]

    private static let englishSentences: [(String, String, Cadence?)] = [
        ("Water the plants every 5 days", "plants", .afterCompletion(days: 5)),
        ("Take out the trash every Tuesday", "trash", .weekdays([.tuesday])),
        ("Go to the gym 3 times a week", "gym", .timesPerWeek(3)),
        ("Renew my passport", "passport", nil),
        ("Change the bed sheets every two weeks", "sheets", .afterCompletion(days: 14)),
        ("Meal prep on Sundays and Wednesdays", "meal", .weekdays([.sunday, .wednesday])),
        ("Take my supplements every morning", "supplements", .afterCompletion(days: 1)),
        ("Run twice a week", "run", .timesPerWeek(2)),
        ("Call the dentist", "dentist", nil),
        ("Clean the bathroom once every ten days", "bathroom", .afterCompletion(days: 10)),
        ("Water the garden every other day", "garden", .afterCompletion(days: 2)),
        ("Yoga on Mondays, Wednesdays and Fridays", "yoga", .weekdays([.monday, .wednesday, .friday])),
    ]

    private static let frenchSentences: [(String, String, Cadence?)] = [
        ("Arroser les plantes tous les 5 jours", "plantes", .afterCompletion(days: 5)),
        ("Sortir les poubelles chaque mardi", "poubelles", .weekdays([.tuesday])),
        ("Aller à la salle de sport 3 fois par semaine", "sport", .timesPerWeek(3)),
        ("Renouveler mon passeport", "passeport", nil),
        ("Changer les draps toutes les deux semaines", "draps", .afterCompletion(days: 14)),
        ("Préparer les repas le dimanche et le mercredi", "repas", .weekdays([.sunday, .wednesday])),
        ("Prendre mes compléments chaque matin", "compléments", .afterCompletion(days: 1)),
        ("Courir deux fois par semaine", "courir", .timesPerWeek(2)),
        ("Appeler le dentiste", "dentiste", nil),
        ("Nettoyer la salle de bain une fois tous les dix jours", "salle de bain", .afterCompletion(days: 10)),
        ("Arroser le jardin un jour sur deux", "jardin", .afterCompletion(days: 2)),
        ("Yoga le lundi, le mercredi et le vendredi", "yoga", .weekdays([.monday, .wednesday, .friday])),
    ]

    private static let englishRoutines: [(String, RoutineExpectation)] = [
        ("I work at the office on Tuesdays and Thursdays, at home the other weekdays", RoutineExpectation(homeDays: [.monday, .wednesday, .friday], officeDays: [.tuesday, .thursday])),
        ("I work from 8:30 to 5 pm", RoutineExpectation(workStart: DateComponents(hour: 8, minute: 30), workEnd: DateComponents(hour: 17, minute: 0))),
        ("I get up at 6:30 and go to bed around 10:30 pm", RoutineExpectation(wakeTime: DateComponents(hour: 6, minute: 30), bedtime: DateComponents(hour: 22, minute: 30))),
        ("I do not work on Fridays", RoutineExpectation(homeDays: [.monday, .tuesday, .wednesday, .thursday], officeDays: [])),
    ]

    private static let frenchRoutines: [(String, RoutineExpectation)] = [
        ("Je travaille au bureau le mardi et le jeudi, à la maison les autres jours de la semaine", RoutineExpectation(homeDays: [.monday, .wednesday, .friday], officeDays: [.tuesday, .thursday])),
        ("Je travaille de 8 h 30 à 17 h", RoutineExpectation(workStart: DateComponents(hour: 8, minute: 30), workEnd: DateComponents(hour: 17, minute: 0))),
        ("Je me lève à 6 h 30 et je me couche vers 22 h 30", RoutineExpectation(wakeTime: DateComponents(hour: 6, minute: 30), bedtime: DateComponents(hour: 22, minute: 30))),
        ("Je ne travaille pas le vendredi", RoutineExpectation(homeDays: [.monday, .tuesday, .wednesday, .thursday], officeDays: [])),
    ]
}
