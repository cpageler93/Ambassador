//
//  JSONResponse.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//


import Foundation
import Embassy


/// A response app for responding JSON data
public class JSONResponse: WebApp {

    /// Underlying data response
    var dataResponse: DataResponse

    public init(
        statusCode: Int = 200,
        statusMessage: String = "OK",
        contentType: String = "application/json",
        jsonWritingOptions: JSONSerialization.WritingOptions = .prettyPrinted,
        headers: [(String, String)] = [],
        handler: @escaping (_ environ: [String: Any], _ response: DataResponse?, _ sendJSON: @escaping (Any) -> Void) -> Void
    ) {
        dataResponse = DataResponse(
            statusCode: statusCode,
            statusMessage: statusMessage,
            contentType: contentType,
            headers: headers
        ) { environ, sendData in
            handler(environ, nil) { json in
                let data = try! JSONSerialization.data(withJSONObject: json, options: jsonWritingOptions)
                sendData(data)
            }
        }
    }

    public init(
        statusCode: Int = 200,
        statusMessage: String = "OK",
        contentType: String = "application/json",
        jsonWritingOptions: JSONSerialization.WritingOptions = .prettyPrinted,
        headers: [(String, String)] = [],
        handler: ((_ environ: [String: Any]) -> Any)? = nil
    ) {
        dataResponse = DataResponse(
            statusCode: statusCode,
            statusMessage: statusMessage,
            contentType: contentType,
            headers: headers
        ) { environ, sendData in
            let data: Data
            if let handler = handler {
                let json = handler(environ)
                data = try! JSONSerialization.data(withJSONObject: json, options: jsonWritingOptions)
            } else {
                data = Data()
            }
            sendData(data)
        }
    }

    public static func make(closure: @escaping ([String: Any], DataResponse?, @escaping (Data) -> Void) -> Void) -> JSONResponse {
        let response = JSONResponse()
        response.dataResponse.handler = { environ, response, sendData in
            closure(environ, response, sendData)
        }
        return response
    }

    public static func make(closure: @escaping ([String: Any], DataResponse?) -> Data) -> JSONResponse {
        let response = JSONResponse()
        response.dataResponse.handler = { environ, response, sendData in
            sendData(closure(environ, response))
        }
        return response
    }

    public func app(
        _ environ: [String: Any],
        startResponse: @escaping ((String, [(String, String)]) -> Void),
        sendBody: @escaping ((Data) -> Void)
    ) {
        return dataResponse.app(environ, startResponse: startResponse, sendBody: sendBody)
    }

}
