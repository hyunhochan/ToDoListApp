//
//  LoginViewController.swift
//  ToDoListApp
//
//  Created by hyunho on 6/6/24.
//

import UIKit
import FirebaseAuth

class LoginViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("LoginViewController loaded")
        
        emailTextField.delegate = self
        passwordTextField.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @IBAction func loginButtonTapped(_ sender: UIButton) {
        print("Login button tapped")
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            self.view.showToast(message: "Please enter email and password", duration: 2.0)
            shakeView()
            return
        }
        
        print("Attempting to sign in with email: \(email)")
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            if let error = error {
                print("Login failed with error: \(error.localizedDescription)")
                self.view.showToast(message: "Login failed: \(error.localizedDescription)", duration: 2.0)
                self.shakeView()
                return
            }
            print("Login successful, transitioning to main screen")
            UserDefaults.standard.set(true, forKey: "isLoggedIn")
            UserDefaults.standard.set(email, forKey: "userEmail")
            self.transitionToMainScreen()
        }
    }

    func transitionToMainScreen() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let mainNavController = storyboard.instantiateViewController(withIdentifier: "MainNavigationController") as? UINavigationController {
            mainNavController.modalPresentationStyle = .fullScreen
            self.present(mainNavController, animated: true, completion: nil)
        } else {
            print("MainNavigationController를 찾을 수 없습니다.")
        }
    }

    @IBAction func signUpButtonTapped(_ sender: UIButton) {
        print("Sign Up button tapped")
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let signUpVC = storyboard.instantiateViewController(withIdentifier: "SignUpViewController") as? SignUpViewController {
            print("SignUpViewController found, presenting...")
            self.present(signUpVC, animated: true, completion: nil)
        } else {
            print("SignUpViewController를 찾을 수 없습니다.")
        }
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else {
            return
        }

        let keyboardHeight = keyboardFrame.height

        UIView.animate(withDuration: duration,
                       delay: 0,
                       options: UIView.AnimationOptions(rawValue: curve),
                       animations: {
                        self.view.frame.origin.y = -keyboardHeight / 2
                       },
                       completion: nil)
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else {
            return
        }

        UIView.animate(withDuration: duration,
                       delay: 0,
                       options: UIView.AnimationOptions(rawValue: curve),
                       animations: {
                        self.view.frame.origin.y = 0
                       },
                       completion: nil)
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
        UIView.animate(withDuration: 0.3) {
            self.view.frame.origin.y = 0
        }
    }

    func shakeView() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.duration = 0.5
        animation.values = [-10, 10, -8, 8, -6, 6, -4, 4, -2, 2, 0]
        view.layer.add(animation, forKey: "shake")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
