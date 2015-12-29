//
//  WebClient.swift
//  VirtualTourist
//
//  Created by eiji on 2015/11/29.
//  Copyright © 2015 Udacity. All rights reserved.

import Foundation

public class CustomError {
	static let ErrorDomain = "com.udacity.virtualtourist.error"
	
	/// custom error codes
	public enum Code: Int{
		case NetworkError = 0
		case ServerError
		case InvalidAccountError
		case JSONIFYError
		case JSONParseError
		case EmptyDataError
		case UnknownError
	}
	
	/// error descriptions for development
	static let Description = [
		Code.NetworkError: "unreachable network connection",
		Code.ServerError: "server error occurred",
		Code.InvalidAccountError: "wrong account or invalid credentials",
		Code.JSONIFYError: "object serialization with JSON failed",
		Code.JSONParseError: "parsing JSON object failed",
		Code.EmptyDataError: "obtained data is empty",
		Code.UnknownError: "unknown error has been occurred"
	]
	
	/// get NSError object from specified custom error code
	class func getError(code: Code, description: String? = nil) -> NSError {
		return NSError(domain: ErrorDomain, code: code.rawValue, userInfo: [ NSLocalizedDescriptionKey: (description == nil ? getDescription(code) : description!) ])
	}
	
	class func getDescription(code: Code) -> String {
		if let description = CustomError.Description[code] {
			return description
		}
		return CustomError.Description[CustomError.Code.UnknownError]!
	}
}

/**
WebClient class that manages sending HTTP requests and parsing JSON data stored in the responses.
*/
final class WebClient : NSObject{
	
	/*
	redefines dictionary for JSON format
	sample:
	{
	"Id": "xxxxxxx",
	"Key": 0000000
	}
	*/
	typealias JSONBody = [String: AnyObject]
	typealias UniqueKey = String
	typealias CompletionHandler = (success: Bool, error: NSError?) -> ()
	typealias CompletionHandlerWithResultData = (result: AnyObject!, success: Bool, error: NSError?) -> Void
	typealias CompletionHandlerWithResultString = (resultString: String?, success: Bool, error: NSError?) -> Void
	
	private let session : NSURLSession // session class for downloading data
	private let HttpRequestTimeoutInterval = Const.HttpRequest.TimeoutIntervalInSec
	
	var startParsePos = 0 // how many letters should be skipped to start parsing JSON
	
	struct Method {
		static let POST = "POST"
		static let GET = "GET"
		static let DELETE = "DELETE"
		static let PUT = "PUT"
	}
	
	private static var serverErrorForDebug = false
	
	override init() {
		session = NSURLSession.sharedSession()
		super.init()
	}
	
	// convert a dictionary of parameters to a url string
	private class func escapedParameters(parameters: [String : AnyObject]?) -> String {
		if let parameters = parameters {
			var urlVars = [String]()
			
			for (key, value) in parameters {
				// make sure that it is a string value
				let stringValue = "\(value)"
				
				// Escaped characters
				// URLQueryAllowedCharacterSet doesn't contain ":"
				// URLPasswordAllowedCharacterSet includes ":" "{", and "}" for json format strings
				let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLPasswordAllowedCharacterSet())
				
				urlVars += [key + "=" + "\(escapedValue!)"]
			}
			
			return (!urlVars.isEmpty ? "?" : "") + urlVars.joinWithSeparator("&")
		} else {
			return ""
		}
	}
	
	/**
	Create a URL object from base URL string and specified method and GET parameters
	
	:param: baseURL Common URL string for the target web service: (example) http://www.udacity.com/api
	:param: method Kind of operation indicating in the HTTP request: (example) loginFrom
	:param: parameters A dictionary in which GET parameters are stored: (example) ["lon": 100, "lat":30], converted to the string "lon=100&lat=30"
	:returns: Created URL object: (example) http://www.udacity.com/api/loginFrom?lon=100&lat=30
	*/
	func createURL(baseURL: String, method: String?, parameters: [String : AnyObject]? = [String : AnyObject]()) -> NSURL {
		let urlMethod = method == nil ? "" : "/" + method!
		let urlString = baseURL + urlMethod + WebClient.escapedParameters(parameters)
		let url = NSURL(string: urlString)!
		print(urlString)
		return url
	}
	
	/**
	Create a HTTP request for the specified URL, HTTP method and hTTP header fields
	
	:param: url Target URL: (ex) http://www.udacity.com/api
	:param: method HTTP method: (ex) POST
	:param: parameters A dictionary of HTTP header fields: (ex) ["Content-Type": "application/json", ...]
	:returns: A created request object
	*/
	func createRequest(url: NSURL, method: String, parameters: [String : AnyObject]? = [String : AnyObject]()) -> NSMutableURLRequest {
		let request = NSMutableURLRequest(URL: url)
		request.HTTPMethod = method
		request.addValue("application/json", forHTTPHeaderField: "Content-Type")
		if let httpHeaderFields = parameters {
			for (key, value) in httpHeaderFields {
				print(key)
				print(value)
				request.addValue(value as! String, forHTTPHeaderField: key)
			}
		}
		// set timeout interval
		request.timeoutInterval = HttpRequestTimeoutInterval
		
		return request
	}
	
	/**
	Send HTTP request with JSON type additional data and call specified handler on completion.
	
	:param: request HTTP request
	:param: jsonBody A dictionary which correspondes to the HTTP body string on the request
	:param: completionHandler callback on completed the request
	:returns: none
	*/
	func sendRequest(request: NSMutableURLRequest, jsonBody: [String:AnyObject]?, completionHandler: CompletionHandlerWithResultData) -> NSURLSessionDataTask? {
		
		if let body = jsonBody {
			do {
				request.HTTPBody = try NSJSONSerialization.dataWithJSONObject(body, options: [])
			} catch {
				// jsonfy error
				completionHandler(result: nil, success: false, error: CustomError.getError(CustomError.Code.JSONIFYError))
				return nil
			}
		}
		
		// define a task for the request and on the completion
		let task = session.dataTaskWithRequest(request) { data, response, downloadError in
			if WebClient.serverErrorForDebug {
				completionHandler(result: nil, success: false, error: CustomError.getError(CustomError.Code.ServerError))
				return
			}
			if let error = downloadError {
				if WebClient.isTimeout(error) { // if the process is timeout, return a network connection error
					completionHandler(result: nil, success: false, error: CustomError.getError(CustomError.Code.NetworkError))
				} else { // in other cases, app can recognizes server error
					completionHandler(result: nil, success: false, error: downloadError)
				}
			} else {
				self.parseJSONObject(data!, completionHandler: completionHandler)
			}
		}
		// do the task
		task.resume()
		
		return task
	}
	
	/**
	Check a returned error is timeout (or network unreachable) error or not.
	
	:param: error returned error after the HTTP session
	:returns: result
	*/
	class func isTimeout(error: NSError) -> Bool {
		// check native class
		if error.domain == NSURLErrorDomain && error.code == NSURLErrorTimedOut {
			return true
		}
		// check custom class
		if error.code == CustomError.Code.NetworkError.rawValue {
			return true
		}
		return false
	}
	
	// parse JSON string and obtain the Foundation objects
	private func parseJSONObject(data: NSData, completionHandler: CompletionHandlerWithResultData) {
		// subset response data
		let offset = self.startParsePos
		let subSetData = data.subdataWithRange(NSMakeRange(offset, data.length - offset))
		// parse objects to json format
		do {
			let parsedResult: AnyObject? = try NSJSONSerialization.JSONObjectWithData(subSetData, options: [NSJSONReadingOptions.AllowFragments])
			completionHandler(result: parsedResult, success: true, error: nil)
		} catch {
			completionHandler(result: nil, success: false,
				error: CustomError.getError(CustomError.Code.JSONParseError))
		}
	}
	
	
}