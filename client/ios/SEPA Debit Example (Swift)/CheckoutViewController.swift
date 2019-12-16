//
//  CheckoutViewController.swift
//  SEPA Debit Example (Swift)
//
//  Created by Cameron Sabol on 12/16/19.
//  Copyright © 2019 Stripe. All rights reserved.
//

import UIKit

import Stripe

/**
 * To run this app, you'll need to first run the sample server locally.
 * Follow the "How to run locally" instructions in the root directory's README.md to get started.
 * Once you've started the server, open http://localhost:4242 in your browser to check that the
 * server is running locally.
 * After verifying the sample server is running locally, build and run the app using the iOS simulator.
 */
let BackendUrl = "http://127.0.0.1:4242/"

class CheckoutViewController: UIViewController {

    private let nameField = UITextField()
    private let emailField = UITextField()
    private let ibanField = UITextField()
    private let payButton = UIButton()

    private var paymentIntentClientSecret: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white

        nameField.borderStyle = .roundedRect
        nameField.textContentType = .name
        nameField.placeholder = "Full Name"
        nameField.translatesAutoresizingMaskIntoConstraints = false

        emailField.borderStyle = .roundedRect
        emailField.textContentType = .emailAddress
        emailField.placeholder = "Email"
        emailField.translatesAutoresizingMaskIntoConstraints = false

        let billingDetailsView = UIView()
        billingDetailsView.addSubview(nameField)
        billingDetailsView.addSubview(emailField)

        let ibanLabel = UILabel()
        ibanLabel.font = UIFont.boldSystemFont(ofSize: 14)
        ibanLabel.textColor = .gray
        ibanLabel.text = "IBAN"
        ibanLabel.translatesAutoresizingMaskIntoConstraints = false

        ibanField.borderStyle = .roundedRect
        ibanField.placeholder = "DE89370400440532013000"
        ibanField.translatesAutoresizingMaskIntoConstraints = false

        let ibanView = UIView()
        ibanView.addSubview(ibanLabel)
        ibanView.addSubview(ibanField)

        let mandateLabel = UILabel()
        mandateLabel.numberOfLines = 0
        let paragraphStyle =  NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 1.5

        mandateLabel.attributedText = NSAttributedString(string: "By providing your IBAN and confirming this payment, you are authorizing Rocketship Inc. and Stripe, our payment service provider, to send instructions to your bank to debit your account and your bank to debit your account in accordance with those instructions. You are entitled to a refund from your bank under the terms and conditions of your agreement with your bank. A refund must be claimed within 8 weeks starting from the date on which your account was debited.", attributes: [NSAttributedString.Key.paragraphStyle : paragraphStyle])

        payButton.layer.cornerRadius = 5
        payButton.backgroundColor = .systemBlue
        payButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        payButton.setTitle("Accept Mandate and Pay", for: .normal)
        payButton.addTarget(self, action: #selector(pay), for: .touchUpInside)

        let stackView = UIStackView(arrangedSubviews: [billingDetailsView, ibanView, mandateLabel, payButton])
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        NSLayoutConstraint.activate([

            // Billing Details View
            nameField.leadingAnchor.constraint(equalTo: billingDetailsView.leadingAnchor),
            nameField.trailingAnchor.constraint(equalTo: billingDetailsView.trailingAnchor),
            nameField.topAnchor.constraint(equalTo: billingDetailsView.topAnchor),

            emailField.leadingAnchor.constraint(equalTo: billingDetailsView.leadingAnchor),
            emailField.trailingAnchor.constraint(equalTo: billingDetailsView.trailingAnchor),
            emailField.topAnchor.constraint(equalToSystemSpacingBelow: nameField.bottomAnchor, multiplier: 1),
            billingDetailsView.bottomAnchor.constraint(equalTo: emailField.bottomAnchor),

            // IBAN View
            ibanLabel.leadingAnchor.constraint(equalTo: ibanView.leadingAnchor),
            ibanLabel.trailingAnchor.constraint(equalTo: ibanView.trailingAnchor),
            ibanLabel.topAnchor.constraint(equalTo: ibanView.topAnchor),

            ibanField.leadingAnchor.constraint(equalTo: ibanView.leadingAnchor),
            ibanField.trailingAnchor.constraint(equalTo: ibanView.trailingAnchor),
            ibanField.topAnchor.constraint(equalToSystemSpacingBelow: ibanLabel.bottomAnchor, multiplier: 0.5),
            ibanView.bottomAnchor.constraint(equalTo: ibanField.bottomAnchor),

            // Stack View
            stackView.leftAnchor.constraint(equalToSystemSpacingAfter: view.safeAreaLayoutGuide.leftAnchor, multiplier: 2),
            view.safeAreaLayoutGuide.rightAnchor.constraint(equalToSystemSpacingAfter: stackView.rightAnchor, multiplier: 2),
            stackView.topAnchor.constraint(equalToSystemSpacingBelow: view.safeAreaLayoutGuide.topAnchor, multiplier: 2),
        ])
        startCheckout()

    }

    func displayAlert(title: String, message: String, restartDemo: Bool = false) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            if restartDemo {
                alert.addAction(UIAlertAction(title: "Restart demo", style: .cancel) { _ in
                    self.nameField.text = nil
                    self.emailField.text = nil
                    self.ibanField.text = nil
                    self.startCheckout()
                })
            }
            else {
                alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            }
            self.present(alert, animated: true, completion: nil)
        }
    }

    func startCheckout() {
        // Create a PaymentIntent by calling the sample server's /create-payment-intent endpoint.
        let url = URL(string: BackendUrl + "create-payment-intent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = try? JSONSerialization.data(withJSONObject: ["items": 1, "currency": "eur"], options: [])

        let task = URLSession.shared.dataTask(with: request, completionHandler: { [weak self] (data, response, error) in
            guard let response = response as? HTTPURLResponse,
                response.statusCode == 200,
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String : Any],
                let clientSecret = json["clientSecret"] as? String,
                let stripePublishableKey = json["publicKey"] as? String else {
                    let message = error?.localizedDescription ?? "Failed to decode response from server."
                    self?.displayAlert(title: "Error loading page", message: message)
                    return
            }
            self?.paymentIntentClientSecret = clientSecret
            // Configure the SDK with your Stripe publishable key so that it can make requests to the Stripe API
            Stripe.setDefaultPublishableKey(stripePublishableKey)
        })
        task.resume()
    }

    @objc
    func pay() {
        guard let paymentIntentClientSecret = paymentIntentClientSecret else {
            return;
        }

        // Collect SEPA Debit details on the client
        let sepaDebitParams = STPPaymentMethodSEPADebitParams()
        sepaDebitParams.iban = ibanField.text

        // Collect customer information
        let billingDetails = STPPaymentMethodBillingDetails()
        billingDetails.name = nameField.text
        billingDetails.email = emailField.text

        let paymentIntentParams = STPPaymentIntentParams(clientSecret: paymentIntentClientSecret)

        paymentIntentParams.paymentMethodParams = STPPaymentMethodParams(sepaDebit: sepaDebitParams,
                                                                         billingDetails: billingDetails,
                                                                         metadata: nil)
        paymentIntentParams.returnURL = "sepa-debit-example://stripe-redirect"

        STPPaymentHandler.shared().confirmPayment(withParams: paymentIntentParams,
                                                  authenticationContext: self)
        { (handlerStatus, paymentIntent, error) in
            switch handlerStatus {
            case .succeeded:
                self.displayAlert(title: "Payment successfully created",
                                  message: error?.localizedDescription ?? "",
                                  restartDemo: true)

            case .canceled:
                self.displayAlert(title: "Canceled",
                                  message: error?.localizedDescription ?? "",
                                  restartDemo: false)

            case .failed:
                self.displayAlert(title: "Payment failed",
                                  message: error?.localizedDescription ?? "",
                                  restartDemo: false)

            @unknown default:
                fatalError()
            }
        }



    }

}

extension CheckoutViewController: STPAuthenticationContext {
    func authenticationPresentingViewController() -> UIViewController {
        return self
    }
}

