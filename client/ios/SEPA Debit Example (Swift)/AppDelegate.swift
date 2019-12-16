//
//  AppDelegate.swift
//  SEPA Debit Example (Swift)
//
//  Created by Cameron Sabol on 12/16/19.
//  Copyright © 2019 Stripe. All rights reserved.
//

import UIKit

import Stripe

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let rootVC = CheckoutViewController()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = rootVC

        window.makeKeyAndVisible()
        self.window = window
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        let stripeHandled = Stripe.handleURLCallback(with: url)
        if stripeHandled {
            return true
        }
        return false
    }
}


