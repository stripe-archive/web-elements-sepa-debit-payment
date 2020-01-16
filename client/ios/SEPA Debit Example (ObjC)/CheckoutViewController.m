//
//  CheckoutViewController.m
//  SEPA Debit Example (ObjC)
//
//  Created by Cameron Sabol on 12/16/19.
//  Copyright © 2019 Stripe. All rights reserved.
//

#import "CheckoutViewController.h"

#import <Stripe/Stripe.h>

/**
* To run this app, you'll need to first run the sample server locally.
* Follow the "How to run locally" instructions in the root directory's README.md to get started.
* Once you've started the server, open http://localhost:4242 in your browser to check that the
* server is running locally.
* After verifying the sample server is running locally, build and run the app using the iOS simulator.
*/
NSString *const BackendUrl = @"http://127.0.0.1:4242/";

@interface CheckoutViewController () <STPAuthenticationContext>

@property (nonatomic, readonly) UITextField *nameField;
@property (nonatomic, readonly) UITextField *emailField;
@property (nonatomic, readonly) UITextField *ibanField;
@property (nonatomic, readonly) UIButton *payButton;

@property (nonatomic, copy) NSString *paymentIntentClientSecret;

@end

@implementation CheckoutViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];

    _nameField = [[UITextField alloc] init];
    self.nameField.borderStyle = UITextBorderStyleRoundedRect;
    self.nameField.textContentType = UITextContentTypeName;
    self.nameField.placeholder = @"Full Name";
    self.nameField.translatesAutoresizingMaskIntoConstraints = NO;

    _emailField = [[UITextField alloc] init];
    self.emailField.borderStyle = UITextBorderStyleRoundedRect;
    self.emailField.textContentType = UITextContentTypeEmailAddress;
    self.emailField.placeholder = @"Email";
    self.emailField.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *billingDetailsView = [[UIView alloc] init];
    [billingDetailsView addSubview:self.nameField];
    [billingDetailsView addSubview:self.emailField];

    UILabel *ibanLabel = [[UILabel alloc] init];
    ibanLabel.font = [UIFont boldSystemFontOfSize:14];
    ibanLabel.textColor = [UIColor grayColor];
    ibanLabel.text = @"IBAN";
    ibanLabel.translatesAutoresizingMaskIntoConstraints = NO;

    _ibanField = [[UITextField alloc] init];
    self.ibanField.borderStyle = UITextBorderStyleRoundedRect;
    self.ibanField.placeholder = @"DE89370400440532013000";
    self.ibanField.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *ibanView = [[UIView alloc] init];
    [ibanView addSubview:ibanLabel];
    [ibanView addSubview:self.ibanField];

    UILabel *mandateLabel = [[UILabel alloc] init];
    mandateLabel.numberOfLines = 0;

    NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.lineSpacing = 1.5;

    NSAttributedString *mandateText = [[NSAttributedString alloc] initWithString:@"By providing your IBAN and confirming this payment, you are"
                                       " authorizing Rocketship Inc. and Stripe, our payment service"
                                       " provider, to send instructions to your bank to debit your account"
                                       " and your bank to debit your account in accordance with those"
                                       " instructions. You are entitled to a refund from your bank under the"
                                       " terms and conditions of your agreement with your bank. A refund must"
                                       " be claimed within 8 weeks starting from the date on which your"
                                       " account was debited."
                                                                      attributes:@{NSParagraphStyleAttributeName: paragraphStyle}];

    mandateLabel.attributedText = mandateText;

    _payButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.payButton.layer.cornerRadius = 5;
    self.payButton.backgroundColor = [UIColor systemBlueColor];
    self.payButton.titleLabel.font = [UIFont systemFontOfSize:18];
    [self.payButton setTitle:@"Accept Mandate and Pay" forState:UIControlStateNormal];
    [self.payButton addTarget:self action:@selector(pay) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *stackView = [[UIStackView alloc] initWithArrangedSubviews:@[billingDetailsView,
                                                                             ibanView,
                                                                             mandateLabel,
                                                                             self.payButton]];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.spacing = 20;
    [self.view addSubview:stackView];

    [NSLayoutConstraint activateConstraints:@[

        // Billing Details
        [self.nameField.leadingAnchor constraintEqualToAnchor:billingDetailsView.leadingAnchor],
        [self.nameField.trailingAnchor constraintEqualToAnchor:billingDetailsView.trailingAnchor],
        [self.nameField.topAnchor constraintEqualToAnchor:billingDetailsView.topAnchor],

        [self.emailField.leadingAnchor constraintEqualToAnchor:billingDetailsView.leadingAnchor],
        [self.emailField.trailingAnchor constraintEqualToAnchor:billingDetailsView.trailingAnchor],
        [self.emailField.topAnchor constraintEqualToSystemSpacingBelowAnchor:self.nameField.bottomAnchor multiplier:1],
        [billingDetailsView.bottomAnchor constraintEqualToAnchor:self.emailField.bottomAnchor],

        // IBAN Collection
        [ibanLabel.leadingAnchor constraintEqualToAnchor:ibanView.leadingAnchor],
        [ibanLabel.trailingAnchor constraintEqualToAnchor:ibanView.trailingAnchor],
        [ibanLabel.topAnchor constraintEqualToAnchor:ibanView.topAnchor],

        [self.ibanField.leadingAnchor constraintEqualToAnchor:ibanView.leadingAnchor],
        [self.ibanField.trailingAnchor constraintEqualToAnchor:ibanView.trailingAnchor],
        [self.ibanField.topAnchor constraintEqualToSystemSpacingBelowAnchor:ibanLabel.bottomAnchor multiplier:0.5],
        [ibanView.bottomAnchor constraintEqualToAnchor:self.ibanField.bottomAnchor],

        // Stack View
        [stackView.leftAnchor constraintEqualToSystemSpacingAfterAnchor:self.view.safeAreaLayoutGuide.leftAnchor multiplier:2],
        [self.view.safeAreaLayoutGuide.rightAnchor constraintEqualToSystemSpacingAfterAnchor:stackView.rightAnchor multiplier:2],
        [stackView.topAnchor constraintEqualToSystemSpacingBelowAnchor:self.view.safeAreaLayoutGuide.topAnchor multiplier:2],
    ]];

    [self startCheckout];

}

- (void)displayAlertWithTitle:(NSString *)title message:(NSString *)message restartDemo:(BOOL)restartDemo {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        if (restartDemo) {
            [alert addAction:[UIAlertAction actionWithTitle:@"Restart demo" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                [self.nameField setText:nil];
                [self.emailField setText:nil];
                [self.ibanField setText:nil];
                [self startCheckout];
            }]];
        } else {
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        }
        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (void)startCheckout {
    // Create a PaymentIntent by calling the sample server's /create-payment-intent endpoint.
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@create-payment-intent", BackendUrl]];
    NSMutableURLRequest *request = [[NSURLRequest requestWithURL:url] mutableCopy];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:@{@"items": @1, @"currency": @"eur"} options:0 error:NULL]];
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *requestError) {
        NSError *error = requestError;
        if (data != nil) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (error != nil || httpResponse.statusCode != 200 || json[@"publicKey"] == nil) {
                [self displayAlertWithTitle:@"Error loading page" message:error.localizedDescription ?: @"" restartDemo:NO];
            } else {
                self.paymentIntentClientSecret = json[@"clientSecret"];
                NSString *stripePublishableKey = json[@"publicKey"];
                // Configure the SDK with your Stripe publishable key so that it can make requests to the Stripe API
                [Stripe setDefaultPublishableKey:stripePublishableKey];
            }
        } else {
            [self displayAlertWithTitle:@"Error loading page" message:error.localizedDescription ?: @"" restartDemo:NO];

        }
    }];
    [task resume];
}

- (void)pay {

    // Collect SEPA Debit details on the client
    STPPaymentMethodSEPADebitParams *sepaDebitParams = [[STPPaymentMethodSEPADebitParams alloc] init];
    sepaDebitParams.iban = self.ibanField.text;

    // Collect customer information
    STPPaymentMethodBillingDetails *billingDetails = [[STPPaymentMethodBillingDetails alloc] init];
    billingDetails.name = self.nameField.text;
    billingDetails.email = self.emailField.text;

    STPPaymentIntentParams *paymentIntentParams = [[STPPaymentIntentParams alloc] initWithClientSecret:self.paymentIntentClientSecret];

    paymentIntentParams.paymentMethodParams = [STPPaymentMethodParams paramsWithSEPADebit:sepaDebitParams
                                                                           billingDetails:billingDetails
                                                                                 metadata:nil];

    paymentIntentParams.returnURL = @"sepa-debit-example://stripe-redirect";
    [[STPPaymentHandler sharedHandler] confirmPayment:paymentIntentParams
                            withAuthenticationContext:self
                                           completion:^(STPPaymentHandlerActionStatus handlerStatus, STPPaymentIntent * handledIntent, NSError * _Nullable handlerError) {
        switch (handlerStatus) {
            case STPPaymentHandlerActionStatusFailed:
                [self displayAlertWithTitle:@"Payment failed" message:handlerError.localizedDescription ?: @"" restartDemo:NO];
                break;
            case STPPaymentHandlerActionStatusCanceled:
                [self displayAlertWithTitle:@"Canceled" message:handlerError.localizedDescription ?: @"" restartDemo:NO];
                break;
            case STPPaymentHandlerActionStatusSucceeded:
                [self displayAlertWithTitle:@"Payment successfully created" message:handlerError.localizedDescription ?: @"" restartDemo:YES];
                break;
        }
    }];
}

#pragma mark - STPAuthenticationContext
- (UIViewController *)authenticationPresentingViewController {
    return self;
}


@end
