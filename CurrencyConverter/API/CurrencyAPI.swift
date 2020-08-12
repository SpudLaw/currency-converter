//
//  CurrencyAPI.swift
//  CurrencyConverter
//
//  Created by Caroline Law on 8/8/20.
//  Copyright © 2020 CAL. All rights reserved.
//

import Foundation
import Combine

class CurrencyAPI {

    enum CurrencyError: LocalizedError {
        case apiError(message: String)

        var errorDescription: String? {
            switch self {
            case let .apiError(message):
                return message
            }
        }
    }

    private let session = URLSession.shared
    private let baseURL = "api.currencylayer.com"
    private let accessKey = "bd3ad620cc343a1289b2ac25e6ac0eca"

    private var currenciesAbrv = [String]()

    // [Source: [Dest: Amount]
    private var allExchangeRates = [String: [String: Double]]()

    let userDefaults = UserDefaults.standard
    let exchangeRatesKey = "exchangeRatesKey"

    private func url(with queryItems: [URLQueryItem]?, path: String) -> URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = baseURL
        components.path = "/" + path

        components.queryItems = [URLQueryItem(name: "access_key", value: accessKey)]

        if let queryItems = queryItems {
            components.queryItems?.append(contentsOf: queryItems)
        }

         guard let url = components.url else {
            preconditionFailure("Failure to construct URL")
        }

        return url
    }

    private func load(url: URL, completionHandler: @escaping (Result<Data, Error>) -> Void) {
        let task = self.session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
            if let error = error {
                    completionHandler(.failure(error))
                } else if let data = data {
                    completionHandler(.success(data))

                } else {
                    let error = NSError(domain: "other error", code: 0, userInfo: nil)
                    completionHandler(.failure(error))
                }
            }
        }

        task.resume()
    }

    func loadListOfCurrencies(completionHandler: @escaping ([String: String]) -> Void) {
        load(url: url(with: nil, path: "list")) { result in
            switch result {
            case .success(let data):
                let currenciesData = try? JSONDecoder().decode(CurrenciesResponse.self, from: data)
                if let theData = currenciesData?.currencies {
                    completionHandler(theData)
                } else {
                    print("Currencies couldn't be fetched")
                }
            case.failure(let error):
                print(error.localizedDescription)
            }
        }
    }

    private func loadExchangeRates(source: String?, completionHandler: @escaping([String: Double]?, CurrencyError?) -> Void) {
        let query = URLQueryItem(name: "currencies", value: currenciesAbrv.joined(separator: ", "))
        var queries = [URLQueryItem]()
        if source == nil {
            queries = [query, URLQueryItem(name: "format", value: "1")]
        } else {
            queries = [query, URLQueryItem(name: "source", value: source), URLQueryItem(name: "format", value: "1")]
        }

        load(url: url(with: queries, path: "live")) { result in
            switch result {
            case .success(let data):
                let exchangeRatesData = try? JSONDecoder().decode(ExchangesResponse.self , from: data)
                if let theData = exchangeRatesData?.quotes {
                    completionHandler(theData, nil)
                } else {
                    if let error = exchangeRatesData?.error?.info {
                        completionHandler(nil, CurrencyError.apiError(message: error))
                    }
                }

            case .failure(let error):
                completionHandler(nil, CurrencyError.apiError(message: error.localizedDescription))
            }
        }
    }

    func getListOfExchangeRates(for amount: Double, from source: String? = nil, completionHandler: @escaping([String: Double]?, CurrencyError?) -> Void) {
        var amounts = [String: Double]()

//        if let savedExchangeRates = self.userDefaults.object(forKey: exchangeRatesKey) as! [String: Double]? {
//            for rate in savedExchangeRates {
//                amounts[rate.key] = rate.value * amount
//            }

        // TODO: FIGURE OUT WHICH SOURCE IT IS, GET THE EXCHANGE RATES FOR IT
//
//            completionHandler(amounts, nil)
//        } else {
            loadExchangeRates(source: source) { exchangeRates, error  in
                guard let exchangeRates = exchangeRates else {
                    completionHandler(nil, error)
                    return
                }

                for rate in exchangeRates {
                    amounts[rate.key] = rate.value * amount
                }

                // TODO: FIGURE OUT WHICH SOURCE IT IS, GET THE EXCHANGE RATES FOR IT, STORE IT
                self.userDefaults.setValue(exchangeRates, forKey: self.exchangeRatesKey)

                completionHandler(amounts, nil)

            }
//        }

    }

}
