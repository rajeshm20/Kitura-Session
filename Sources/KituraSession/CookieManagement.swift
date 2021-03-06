/**
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import Kitura
import LoggerAPI

import Foundation

internal class CookieManagement {
    
    //
    // Cookie name
    private let name: String
    
    //
    // Cookie path
    private let path: String
    
    //
    // Cookie is secure
    private let secure: Bool
    
    //
    // Max age of Cookie
    #if os(Linux)
    private let maxAge: NSTimeInterval
    #else
    private let maxAge: TimeInterval
    #endif
    //
    // Cookie encoder/decoder
    private let crypto: CookieCryptography
    
    internal init(cookieCrypto: CookieCryptography, cookieParms: [CookieParameter]?) {
        var name = "kitura-session-id"
        var path = "/"
        var secure = false
        var maxAge = -1.0
        if  let cookieParms = cookieParms  {
            for  parm in cookieParms  {
                switch(parm) {
                case .name(let pName):
                    name = pName
                case .path(let pPath):
                    path = pPath
                case .secure(let pSecure):
                    secure = pSecure
                case .maxAge(let pMaxAge):
                    maxAge = pMaxAge
                }
            }
        }
        
        self.name = name
        self.path = path
        self.secure = secure
        self.maxAge = maxAge
        
        crypto = cookieCrypto
    }
    
    
    internal func getSessionId(request: RouterRequest, response: RouterResponse) -> (String?, Bool) {
        var sessionId: String? = nil
        var newSession = false
        
        if  let cookie = request.cookies[name],
            let decodedCookieValue = crypto.decode(cookie.value) {
            sessionId = decodedCookieValue
            newSession = false
        }
        else {
            // No Cookie
            #if os(Linux)
                sessionId = NSUUID().UUIDString
            #else
                sessionId = NSUUID().uuidString
            #endif
            newSession = true
        }
        return (sessionId, newSession)
    }
    
    #if os(Linux)
    internal func addCookie(sessionId: String, domain: String, response: RouterResponse) -> Bool {
        typealias PropValue = Any
    
        guard let encodedSessionId = crypto.encode(sessionId) else {
            return false
        }
        var properties: [String: PropValue] = [NSHTTPCookieName: name as PropValue,
                                               NSHTTPCookieValue: encodedSessionId as PropValue,
                                               NSHTTPCookieDomain: domain as PropValue,
                                               NSHTTPCookiePath: path as PropValue]
        if  secure  {
            properties[NSHTTPCookieSecure] = "Yes"
        }
        if  maxAge > 0.0  {
            properties[NSHTTPCookieMaximumAge] = String(Int(maxAge)) as PropValue
            properties[NSHTTPCookieVersion] = "1"
        }
        let cookie = NSHTTPCookie(properties: properties)
        response.cookies[name] = cookie
        return true
    }
    #else
    internal func addCookie(sessionId: String, domain: String, response: RouterResponse) -> Bool {
        guard let encodedSessionId = crypto.encode(sessionId) else {
            return false
        }
        var properties: [HTTPCookiePropertyKey: AnyObject] = [HTTPCookiePropertyKey.name: name,
                                                              HTTPCookiePropertyKey.value: encodedSessionId,
                                                              HTTPCookiePropertyKey.domain: domain,
                                                              HTTPCookiePropertyKey.path: path]
        if  secure  {
            properties[HTTPCookiePropertyKey.secure] = "Yes"
        }
        if  maxAge > 0.0  {
            properties[HTTPCookiePropertyKey.maximumAge] = String(Int(maxAge))
            properties[HTTPCookiePropertyKey.version] = "1"
        }
        let cookie = HTTPCookie(properties: properties)
        response.cookies[name] = cookie
        return true
    }
    #endif
}
