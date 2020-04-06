//
//  InAppPurchases.swift
//  TimeLineShared
//
//  Created by Mathieu Dutour on 05/04/2020.
//  Copyright © 2020 Mathieu Dutour. All rights reserved.
//

import Foundation
import StoreKit

public let sharedIAPPassword = "4d5125cebaa347a18def405beee4cb0f"
public let unlimitedContactsProductId = "unlimitedcontacts"

public class IAPManager: NSObject {
  public static let shared = IAPManager()

  var onReceiveProductsHandler: ((Result<[SKProduct], IAPManagerError>) -> Void)?
  var onBuyProductHandler: ((Result<Bool, Error>) -> Void)?
  var totalRestoredPurchases = 0

  public enum IAPManagerError: Error {
    case noProductIDsFound
    case noProductsFound
    case paymentWasCancelled
    case productRequestFailed
  }

  private override init() {
     super.init()
  }

  public func startObserving() {
    SKPaymentQueue.default().add(self)
  }


  public func stopObserving() {
    SKPaymentQueue.default().remove(self)
  }

  public func getProducts(withHandler productsReceiveHandler: @escaping (_ result: Result<[SKProduct], IAPManagerError>) -> Void) {
    onReceiveProductsHandler = productsReceiveHandler

    let request = SKProductsRequest(productIdentifiers: [unlimitedContactsProductId])
    request.delegate = self
    request.start()
  }

  public func getPriceFormatted(for product: SKProduct) -> String? {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = product.priceLocale
    return formatter.string(from: product.price)
  }

  public func buy(product: SKProduct, withHandler handler: @escaping ((_ result: Result<Bool, Error>) -> Void)) {
    let payment = SKPayment(product: product)
    SKPaymentQueue.default().add(payment)

    // Keep the completion handler.
    onBuyProductHandler = handler
  }

  public func restorePurchases(withHandler handler: @escaping ((_ result: Result<Bool, Error>) -> Void)) {
    onBuyProductHandler = handler
    totalRestoredPurchases = 0
    SKPaymentQueue.default().restoreCompletedTransactions()
  }
}

extension IAPManager.IAPManagerError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .noProductIDsFound: return "No In-App Purchase product identifiers were found."
    case .noProductsFound: return "No In-App Purchases were found."
    case .productRequestFailed: return "Unable to fetch available In-App Purchase products at the moment."
    case .paymentWasCancelled: return "In-App Purchase process was cancelled."
    }
  }
}

extension IAPManager: SKProductsRequestDelegate {
  public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
    let products = response.products
    if products.count > 0 {
      onReceiveProductsHandler?(.success(products))
    } else {
      onReceiveProductsHandler?(.failure(.noProductsFound))
    }
  }

  public func request(_ request: SKRequest, didFailWithError error: Error) {
    onReceiveProductsHandler?(.failure(.productRequestFailed))
  }

  public func requestDidFinish(_ request: SKRequest) {

  }
}

extension IAPManager: SKPaymentTransactionObserver {
  public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    transactions.forEach { (transaction) in
      switch transaction.transactionState {
      case .purchased:
        onBuyProductHandler?(.success(true))
        SKPaymentQueue.default().finishTransaction(transaction)
      case .restored:
        totalRestoredPurchases += 1
        SKPaymentQueue.default().finishTransaction(transaction)
      case .failed:
        if let error = transaction.error as? SKError {
            if error.code != .paymentCancelled {
                onBuyProductHandler?(.failure(error))
            } else {
                onBuyProductHandler?(.failure(IAPManagerError.paymentWasCancelled))
            }
            print("IAP Error:", error.localizedDescription)
        }
        SKPaymentQueue.default().finishTransaction(transaction)
      case .deferred, .purchasing: break
      @unknown default: break
      }
    }
  }

  public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
    if totalRestoredPurchases != 0 {
      onBuyProductHandler?(.success(true))
    } else {
      print("IAP: No purchases to restore!")
      onBuyProductHandler?(.success(false))
    }
  }

  public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
    if let error = error as? SKError {
      if error.code != .paymentCancelled {
        print("IAP Restore Error:", error.localizedDescription)
        onBuyProductHandler?(.failure(error))
      } else {
        onBuyProductHandler?(.failure(IAPManagerError.paymentWasCancelled))
      }
    }
  }
}
