//
//  LoginViewController.swift
//  ToDoListApp
//
//  Created by hyunho on 6/6/24.
//

import UIKit
import FirebaseAuth

class SignUpViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Delegate 설정
        emailTextField.delegate = self
        passwordTextField.delegate = self
        
        // 키보드 노티피케이션 등록
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    deinit {
        // 키보드 노티피케이션 제거
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBAction func signUpButtonTapped(_ sender: UIButton) {
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            self.view.showToast(message: "Please enter email and password", duration: 2.0)
            shakeView()
            return
        }
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            if let error = error {
                self.view.showToast(message: "Sign up failed: \(error.localizedDescription)", duration: 2.0)
                self.shakeView()
                return
            }
            // 회원가입 성공 시 메인 화면으로 이동
            self.dismiss(animated: true, completion: nil)
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
        // 화면을 원래 위치로 되돌림
        UIView.animate(withDuration: 0.3) {
            self.view.frame.origin.y = 0
        }
    }
    
    // 흔들림 애니메이션 추가
    func shakeView() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.duration = 0.5
        animation.values = [-10, 10, -8, 8, -6, 6, -4, 4, -2, 2, 0]
        view.layer.add(animation, forKey: "shake")
    }
}
