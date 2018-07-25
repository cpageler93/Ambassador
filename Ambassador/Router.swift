//
//  Router.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation

/// Router WebApp for routing requests to different WebApp
open class Router: WebApp {

    public struct Route: Hashable {
        let path: String
        let method: String
    }

    var routes: [Route: WebApp] = [:]
    open var notFoundResponse: WebApp = DataResponse(
        statusCode: 404,
        statusMessage: "Not found"
    )
    private let semaphore = DispatchSemaphore(value: 1)

    public init() {
    }

    open subscript(path: String) -> WebApp? {
        get {
            return self[path, "*"]
        }

        set {
            self[path, "*"] = newValue!
        }
    }

    open subscript(path: String, method: String) -> WebApp? {
        get {
            // enter critical section
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)
            defer {
                semaphore.signal()
            }
            return routes[Route(path: path, method: method)]
        }

        set {
            // enter critical section
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)
            defer {
                semaphore.signal()
            }
            routes[Route(path: path, method: method)] = newValue!
        }
    }

    open func get(path: String, _ webApp: WebApp) {
        self[path, "GET"] = webApp
    }

    open func head(path: String, _ webApp: WebApp) {
        self[path, "HEAD"] = webApp
    }

    open func post(path: String, _ webApp: WebApp) {
        self[path, "POST"] = webApp
    }

    open func put(path: String, _ webApp: WebApp) {
        self[path, "PUT"] = webApp
    }

    open func delete(path: String, _ webApp: WebApp) {
        self[path, "DELETE"] = webApp
    }

    open func connect(path: String, _ webApp: WebApp) {
        self[path, "CONNECT"] = webApp
    }

    open func options(path: String, _ webApp: WebApp) {
        self[path, "OPTIONS"] = webApp
    }

    open func trace(path: String, _ webApp: WebApp) {
        self[path, "TRACE"] = webApp
    }

    open func patch(path: String, _ webApp: WebApp) {
        self[path, "PATCH"] = webApp
    }

    open func app(
        _ environ: [String: Any],
        startResponse: @escaping ((String, [(String, String)]) -> Void),
        sendBody: @escaping ((Data) -> Void)
    ) {
        let path = environ["PATH_INFO"] as! String
        let requestMethod = environ["REQUEST_METHOD"] as! String

        if let (webApp, captures) = matchRoute(to: path, httpMethod: requestMethod) {
            var environ = environ
            environ["ambassador.router_captures"] = captures
            webApp.app(environ, startResponse: startResponse, sendBody: sendBody)
            return
        }
        return notFoundResponse.app(environ, startResponse: startResponse, sendBody: sendBody)
    }

    private func matchRoute(to searchPath: String, httpMethod: String) -> (WebApp, [String])? {
        typealias ReturnValue = (WebApp, [String])
        var routeMatches: [(NSTextCheckingResult, ReturnValue)] = []
        for (route, webApp) in routes {
            guard route.method == "*" || route.method == httpMethod else { continue }
            let regex = try! NSRegularExpression(pattern: route.path, options: [])
            let matches = regex.matches(
                in: searchPath,
                options: [],
                range: NSRange(location: 0, length: searchPath.count)
            )
            if !matches.isEmpty {
                let match = matches[0]
                guard match.range.length == searchPath.count else { continue }
                let searchPath = NSString(string: searchPath)
                var captures = [String]()
                for rangeIdx in 1 ..< match.numberOfRanges {
                    captures.append(searchPath.substring(with: match.range(at: rangeIdx)))
                }
                let possibleReturnValue = (webApp, captures)
                routeMatches.append((match, possibleReturnValue))
            }
        }
        
        // sort the most specific route to top and return the result
        return routeMatches.sorted(by: { (routeMatch1, routeMatch2) -> Bool in
            guard let regex1 = routeMatch1.0.regularExpression,
                let regex2 = routeMatch2.0.regularExpression
            else {
                return false
            }

            // prefer regex without capture groups
            // skip this decision when number of capture groups are equal
            if regex1.numberOfCaptureGroups < regex2.numberOfCaptureGroups {
                return true
            } else if regex1.numberOfCaptureGroups > regex2.numberOfCaptureGroups {
                return false
            }

            // prefer the shorter regex pattern
            return regex1.pattern.count < regex2.pattern.count
        }).first?.1
    }
}
