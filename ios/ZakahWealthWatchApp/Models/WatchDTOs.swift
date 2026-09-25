import Foundation

public struct WatchStateSnapshot: Codable {
  public let v: Int
  public let syncedAt: String
  public let generatedAt: String?
  public let mainCurrency: String
  public let currencies: [String]
  public let paymentSources: [WatchPaymentSource]
  public let expenseCategories: [String]
  public let incomeCategories: [String]
  public let pendingInbox: [WatchPendingItem]
  public let recentActivity: [WatchActivityItem]

  public init(
    v: Int = 1,
    syncedAt: String = "",
    generatedAt: String? = nil,
    mainCurrency: String = "SAR",
    currencies: [String] = ["SAR", "USD", "EUR", "EGP"],
    paymentSources: [WatchPaymentSource] = [],
    expenseCategories: [String] = [],
    incomeCategories: [String] = [],
    pendingInbox: [WatchPendingItem] = [],
    recentActivity: [WatchActivityItem] = []
  ) {
    self.v = v
    self.syncedAt = syncedAt
    self.generatedAt = generatedAt
    self.mainCurrency = mainCurrency
    self.currencies = currencies
    self.paymentSources = paymentSources
    self.expenseCategories = expenseCategories
    self.incomeCategories = incomeCategories
    self.pendingInbox = pendingInbox
    self.recentActivity = recentActivity
  }
}

public struct WatchPaymentSource: Codable, Identifiable {
  public let id: String
  public let name: String
  public let type: String // "cash" | "card"
  public let currency: String
  public let last4: String?

  public init(
    id: String,
    name: String,
    type: String,
    currency: String,
    last4: String? = nil
  ) {
    self.id = id
    self.name = name
    self.type = type
    self.currency = currency
    self.last4 = last4
  }
}

public struct WatchPendingItem: Codable, Identifiable {
  public let id: String
  public let type: String // "expense" | "income" | "transfer"
  public let amount: Double
  public let currency: String
  public let merchant: String
  public let category: String
  public let paymentSourceId: String?
  public let cardLast4: String?
  public let accountLast4: String?
  public let detectedBank: String?
  public let date: String

  public init(
    id: String,
    type: String = "expense",
    amount: Double,
    currency: String,
    merchant: String,
    category: String,
    paymentSourceId: String? = nil,
    cardLast4: String? = nil,
    accountLast4: String? = nil,
    detectedBank: String? = nil,
    date: String
  ) {
    self.id = id
    self.type = type
    self.amount = amount
    self.currency = currency
    self.merchant = merchant
    self.category = category
    self.paymentSourceId = paymentSourceId
    self.cardLast4 = cardLast4
    self.accountLast4 = accountLast4
    self.detectedBank = detectedBank
    self.date = date
  }
}

public struct WatchActivityItem: Codable, Identifiable {
  public let id: String
  public let type: String
  public let amount: Double
  public let currency: String
  public let title: String
  public let category: String
  public let date: String

  public init(
    id: String,
    type: String,
    amount: Double,
    currency: String,
    title: String,
    category: String,
    date: String
  ) {
    self.id = id
    self.type = type
    self.amount = amount
    self.currency = currency
    self.title = title
    self.category = category
    self.date = date
  }
}

public struct WatchCommandResult: Codable {
  public let v: Int
  public let operationId: String
  public let status: String // "success" | "rejected" | "failed"
  public let code: String
  public let message: String?
  public let entityId: String?
  public let targetAmount: Double?
  public let rate: Double?

  public var isSuccess: Bool {
    return status.lowercased() == "success"
  }

  public init(
    v: Int = 1,
    operationId: String,
    status: String,
    code: String,
    message: String? = nil,
    entityId: String? = nil,
    targetAmount: Double? = nil,
    rate: Double? = nil
  ) {
    self.v = v
    self.operationId = operationId
    self.status = status
    self.code = code
    self.message = message
    self.entityId = entityId
    self.targetAmount = targetAmount
    self.rate = rate
  }
}
