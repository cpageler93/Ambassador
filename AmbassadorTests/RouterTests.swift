//
//  RouterTests.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

import Ambassador

class RouterTests: XCTestCase {
    func testRouter() {
        let router = Router()
        router["/path/to/1"] = DataResponse() { environ -> Data in
            return Data("hello".utf8)
        }

        var receivedStatus: [String] = []
        let startResponse = { (status: String, headers: [(String, String)]) in
            receivedStatus.append(status)
        }

        var receivedData: [Data] = []
        let sendBody = { (data: Data) in
            receivedData.append(data)
        }
        let environ: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "404 Not found")
        XCTAssertEqual(receivedData.count, 1)
        XCTAssertEqual(receivedData.last?.count, 0)

        let environ2: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/path/to/1",
        ]
        router.app(
            environ2,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 2)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 3)
        XCTAssertEqual(String(bytes: receivedData[1], encoding: String.Encoding.utf8), "hello")
        XCTAssertEqual(receivedData.last?.count, 0)
    }

    func testRegularExpressionRouting() {
        let router = Router()
        var receivedCaptures: [String]?
        let emailRoute = "/activate/email/([a-zA-Z0-9]+@[a-zA-Z0-9]+\\.[a-zA-Z0-9]+)" +
            "/code/([a-zA-Z0-9]+)"
        router[emailRoute] = DataResponse() { environ -> Data in
            receivedCaptures = environ["ambassador.router_captures"] as? [String]
            return Data("email".utf8)
        }
        router["/foo"] = DataResponse() { environ -> Data in
            return Data("foo".utf8)
        }

        var receivedStatus: [String] = []
        let startResponse = { (status: String, headers: [(String, String)]) in
            receivedStatus.append(status)
        }

        var receivedData: [Data] = []
        let sendBody = { (data: Data) in
            receivedData.append(data)
        }
        let environ: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/egg",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "404 Not found")
        XCTAssertEqual(receivedData.count, 1)
        XCTAssertEqual(receivedData.last?.count, 0)

        let environ2: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/activate/email/fang@envoy.com/code/ABCD1234",
        ]
        router.app(
            environ2,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 2)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 3)
        XCTAssertEqual(String(bytes: receivedData[1], encoding: String.Encoding.utf8), "email")
        XCTAssertEqual(receivedData.last?.count, 0)
        XCTAssertEqual(receivedCaptures ?? [], ["fang@envoy.com", "ABCD1234"])
    }

    func testRoutingOnSimilarRoutes() {
        let router = Router()
        router["/resource"] = DataResponse() { environ -> Data in
            return Data("index".utf8)
        }
        router["/resource/([0-9])"] = DataResponse() { environ -> Data in
            return Data("show".utf8)
        }
        router["/resource/([a-zA-Z0-9-]+)"] = DataResponse() { environ -> Data in
            return Data("show uuid".utf8)
        }
        router["/resource/([0-9])/action"] = DataResponse() { environ -> Data in
            return Data("action on single resource".utf8)
        }
        router["/resource/([a-zA-Z0-9-]+)/action"] = DataResponse() { environ -> Data in
            return Data("action on single resource with uuid".utf8)
        }
        router["/resource/types"] = DataResponse() { environ -> Data in
            return Data("static".utf8)
        }
        router["/resource/verylongandexplicitstaticmethod"] = DataResponse() { environ -> Data in
            return Data("verylongandexplicitstaticmethod".utf8)
        }

        var receivedStatus: [String] = []
        let startResponse = { (status: String, headers: [(String, String)]) in
            receivedStatus.append(status)
        }

        var receivedData: [Data] = []
        let sendBody = { (data: Data) in
            receivedData.append(data)
        }

        // test /resource
        var environ: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "index")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()


        // test /resource/([0-9])
        environ = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource/1",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "show")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()

        // test /resource/([a-zA-Z0-9-]+)
        environ = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource/\(UUID().uuidString)",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "show uuid")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()

        // test /resource/([0-9])/action
        environ = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource/1/action",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "action on single resource")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()

        // test /resource/types
        environ = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource/types",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "static")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()

        // test /resource/verylongandexplicitstaticmethod
        environ = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource/verylongandexplicitstaticmethod",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "verylongandexplicitstaticmethod")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()
    }

    func testRoutingForMultipleHTTPMethods() {
        let router = Router()
        router.get(path: "/resource", DataResponse() { environ -> Data in
            return Data("GET".utf8)
        })
        router.head(path: "/resource", DataResponse() { environ -> Data in
            return Data("HEAD".utf8)
        })
        router.post(path: "/resource", DataResponse() { environ -> Data in
            return Data("POST".utf8)
        })
        router.put(path: "/resource", DataResponse() { environ -> Data in
            return Data("PUT".utf8)
        })
        router.delete(path: "/resource", DataResponse() { environ -> Data in
            return Data("DELETE".utf8)
        })
        router.connect(path: "/resource", DataResponse() { environ -> Data in
            return Data("CONNECT".utf8)
        })
        router.options(path: "/resource", DataResponse() { environ -> Data in
            return Data("OPTIONS".utf8)
        })
        router.trace(path: "/resource", DataResponse() { environ -> Data in
            return Data("TRACE".utf8)
        })
        router.patch(path: "/resource", DataResponse() { environ -> Data in
            return Data("PATCH".utf8)
        })

        router["/fallback"] = DataResponse() { environ -> Data in
            return Data("*".utf8)
        }

        var receivedStatus: [String] = []
        let startResponse = { (status: String, headers: [(String, String)]) in
            receivedStatus.append(status)
        }

        var receivedData: [Data] = []
        let sendBody = { (data: Data) in
            receivedData.append(data)
        }

        // test GET /resource
        var environ: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "GET")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()

        // test HEAD /resource
        environ = [
            "REQUEST_METHOD": "HEAD",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "HEAD")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()

        // test POST /resource
        environ = [
            "REQUEST_METHOD": "POST",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "POST")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()

        // test PUT /resource
        environ = [
            "REQUEST_METHOD": "PUT",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "PUT")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()

        // test DELETE /resource
        environ = [
            "REQUEST_METHOD": "DELETE",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "DELETE")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()

        // test CONNECT /resource
        environ = [
            "REQUEST_METHOD": "CONNECT",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "CONNECT")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()

        // test OPTIONS /resource
        environ = [
            "REQUEST_METHOD": "OPTIONS",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "OPTIONS")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()

        // test TRACE /resource
        environ = [
            "REQUEST_METHOD": "TRACE",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "TRACE")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()

        // test PATCH /resource
        environ = [
            "REQUEST_METHOD": "PATCH",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "PATCH")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()

        // test GET /fallback
        environ = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/fallback",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "*")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()

        // test POST /fallback
        environ = [
            "REQUEST_METHOD": "POST",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/fallback",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "*")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()

        // test CONNECT /fallback
        environ = [
        "REQUEST_METHOD": "CONNECT",
        "SCRIPT_NAME": "",
        "PATH_INFO": "/fallback",
        ]
        router.app(
        environ,
        startResponse: startResponse,
        sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "*")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()

    }

    func testDynamicStatusCode() {
        let router = Router()

        router.get(path: "/resource", DataResponse.make { (environ, response) in
            return Data("GET".utf8)
        })

        router.get(path: "/failure", DataResponse.make { (environ, response) in
            response?.statusCode = 500
            response?.statusMessage =  "Internal Server Error"
            return Data("GET".utf8)
        })

        var receivedStatus: [String] = []
        let startResponse = { (status: String, headers: [(String, String)]) in
            receivedStatus.append(status)
        }

        var receivedData: [Data] = []
        let sendBody = { (data: Data) in
            receivedData.append(data)
        }


        // test GET /resource
        var environ = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/resource",
        ]

        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "GET")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()


        // test GET /failure
        environ = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/failure",
        ]

        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "500 Internal Server Error")
        XCTAssertEqual(receivedData.count, 2)
        XCTAssertEqual(String(data: receivedData[0], encoding: .utf8), "GET")
        XCTAssertEqual(receivedData.last?.count, 0)
        receivedStatus.removeAll()
        receivedData.removeAll()
    }

}
