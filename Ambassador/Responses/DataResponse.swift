//
//  DataResponse.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//


import Foundation
import Embassy


/// Data response responses data from given handler immediately to the client
public class DataResponse: WebApp {

    /// The status code to response
    public var statusCode: Int

    /// The status message to response
    public var statusMessage: String

    /// Headers to response
    public var headers: [(String, String)]

    /// Function for generating JSON response
    public var handler: (_ environ: [String: Any], _ response: DataResponse?, _ sendData: @escaping (Data) -> Void) -> Void
    
    /// The Content type to response
    public var contentType: String

    public init(
        statusCode: Int = 200,
        statusMessage: String = "OK",
        contentType: String = "application/octet-stream",
        headers: [(String, String)] = [],
        handler: @escaping (_ environ: [String: Any], _ sendData: @escaping (Data) -> Void) -> Void
    ) {
        self.statusCode = statusCode
        self.statusMessage = statusMessage
        self.contentType = contentType
        self.headers = headers
        self.handler = { environ, response, sendData in
            handler(environ, sendData)
        }
    }

    public init(
        statusCode: Int = 200,
        statusMessage: String = "OK",
        contentType: String = "application/octet-stream",
        headers: [(String, String)] = [],
        handler: ((_ environ: [String: Any]) -> Data)? = nil
    ) {
        self.statusCode = statusCode
        self.statusMessage = statusMessage
        self.contentType = contentType
        self.headers = headers
        self.handler = { environ, response, sendData in
            if let handler = handler {
                let data = handler(environ)
                sendData(data)
            } else {
                sendData(Data())
            }
        }
    }

    public static func make(closure: @escaping ([String: Any], DataResponse?, @escaping (Data) -> Void) -> Void) -> DataResponse {
        let response = DataResponse()
        response.handler = { environ, response, sendData in
            closure(environ, response, sendData)
        }
        return response
    }

    public static func make(closure: @escaping ([String: Any], DataResponse?) -> Data) -> DataResponse {
        let response = DataResponse()
        response.handler = { environ, response, sendData in
            sendData(closure(environ, response))
        }
        return response
    }

    public func app(
        _ environ: [String: Any],
        startResponse: @escaping ((String, [(String, String)]) -> Void),
        sendBody: @escaping ((Data) -> Void)
    ) {
        handler(environ, self) { data in
            var headers = self.headers
            let headerDict = MultiDictionary<String, String, LowercaseKeyTransform>(items: headers)
            if headerDict["Content-Type"] == nil {
                headers.append(("Content-Type", self.contentType))
            }
            if headerDict["Content-Length"] == nil {
                headers.append(("Content-Length", String(data.count)))
            }

            startResponse("\(self.statusCode) \(self.statusMessage)", headers)
            if !data.isEmpty {
                sendBody(data)
            }
            sendBody(Data())
        }
    }
}
