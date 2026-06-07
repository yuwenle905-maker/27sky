// Models.swift — SwiftData 数据模型
import SwiftData
import SwiftUI

// MARK: - 消费类目枚举
enum ExpenseCategory: String, CaseIterable, Codable {
    case housing  = "housing"
    case social   = "social"
    case food     = "food"
    case other    = "other"
    case smoking  = "smoking"

    var displayName: String {
        switch self {
        case .housing: return "住房"
        case .social:  return "社交"
        case .food:    return "吃饭"
        case .other:   return "其他"
        case .smoking: return "抽烟"
        }
    }

    var icon: String {
        switch self {
        case .housing: return "🏠"
        case .social:  return "👥"
        case .food:    return "🍔"
        case .other:   return "🛍️"
        case .smoking: return "🚬"
        }
    }

    var tabIcon: String {
        switch self {
        case .housing: return "house.fill"
        case .social:  return "person.2.fill"
        case .food:    return "fork.knife"
        case .other:   return "bag.fill"
        case .smoking: return "smoke.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .housing: return Color(hex: "5B8CFF")
        case .social:  return Color(hex: "FF6B9D")
        case .food:    return Color(hex: "FF9F43")
        case .other:   return Color(hex: "A29BFE")
        case .smoking: return Color(hex: "6C757D")
        }
    }
}

// MARK: - 消费记录
@Model
final class ExpenseRecord {
    var id: UUID
    var amount: Double
    var note: String
    var date: Date
    var categoryRaw: String

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(amount: Double, note: String = "", date: Date = Date(), category: ExpenseCategory) {
        self.id = UUID()
        self.amount = amount
        self.note = note
        self.date = date
        self.categoryRaw = category.rawValue
    }
}

// MARK: - 分类额度配置
@Model
final class CategoryBudget {
    var categoryRaw: String
    var monthlyBudget: Double

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(category: ExpenseCategory, monthlyBudget: Double) {
        self.categoryRaw = category.rawValue
        self.monthlyBudget = monthlyBudget
    }
}

// MARK: - 累计结余记录
@Model
final class SavingsRecord {
    var id: UUID
    var amount: Double       // 本月结余（可为负，但负数不加入累计）
    var year: Int
    var month: Int
    var isCarriedOver: Bool  // 是否已结转到累计金库

    init(amount: Double, year: Int, month: Int) {
        self.id = UUID()
        self.amount = amount
        self.year = year
        self.month = month
        self.isCarriedOver = false
    }
}

// MARK: - Color 扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - 日期工具
extension Date {
    var year: Int  { Calendar.current.component(.year,  from: self) }
    var month: Int { Calendar.current.component(.month, from: self) }
    var day: Int   { Calendar.current.component(.day,   from: self) }

    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self))!
    }

    var endOfMonth: Date {
        Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
    }

    var startOfWeek: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self))!
    }

    var endOfWeek: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: startOfWeek)!
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    func isSameMonth(as other: Date) -> Bool {
        year == other.year && month == other.month
    }
}
