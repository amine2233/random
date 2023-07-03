//
//  File.swift
//  
//
//  Created by Amine Bensalah on 03/07/2023.
//

import Foundation
#if canImport(UIKit)
import UIKit

extension Randoms {
    public enum GravatarStyle: String {
        case Standard
        case MM
        case Identicon
        case MonsterID
        case Wavatar
        case Retro

        static let allValues = [Standard, MM, Identicon, MonsterID, Wavatar, Retro]
    }

    public static func createGravatar(_ style: Randoms.GravatarStyle = .Standard, size: Int = 80, completion: ((_ image: UIImage?, _ error: Error?) -> Void)?) {
        var url = "https://secure.gravatar.com/avatar/thisimagewillnotbefound?s=\(size)"
        if style != .Standard {
            url += "&d=\(style.rawValue.lowercased())"
        }

        let request = URLRequest(url: URL(string: url)! as URL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 5.0)
        let session = URLSession.shared

        session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) in
            DispatchQueue.main.async {
                if error == nil {
                    completion?(UIImage(data: data!), nil)
                } else {
                    completion?(nil, error)
                }
            }
        }).resume()
    }

    public static func randomGravatar(_ size: Int = 80, completion: ((_ image: UIImage?, _ error: Error?) -> Void)?) {
        let options = Randoms.GravatarStyle.allValues
        Randoms.createGravatar(options.randomElement()!, size: size, completion: completion)
    }
}

public extension UIColor {
    /// SwiftRandom extension
    static func random(_ randomAlpha: Bool = false) -> UIColor {
        let randomRed = CGFloat.random()
        let randomGreen = CGFloat.random()
        let randomBlue = CGFloat.random()
        let alpha = randomAlpha ? CGFloat.random() : 1.0
        return UIColor(red: randomRed, green: randomGreen, blue: randomBlue, alpha: alpha)
    }
}
#endif
