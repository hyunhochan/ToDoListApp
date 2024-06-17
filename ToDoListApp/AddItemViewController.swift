//
//  AddItemViewController.swift
//  ToDoListApp
//
//  Created by hyunho on 6/6/24.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import MapKit

protocol AddItemDelegate {
    func didAddItem(title: String, date: Date, imageURL: String?, latitude: Double, longitude: Double)
    func didEditItem(id: String, title: String, date: Date, imageURL: String?, latitude: Double, longitude: Double)
}

class AddItemViewController: UIViewController, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, MKMapViewDelegate {

    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var timePicker: UIDatePicker!
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var mapView: MKMapView!
    
    var delegate: AddItemDelegate?
    var editingItem: (id: String, title: String, date: Date, imageURL: String?, latitude: Double, longitude: Double)?
    var selectedImage: UIImage?
    var selectedLatitude: Double?
    var selectedLongitude: Double?
    var saveButton: UIBarButtonItem?
    
    let maxImageSize: Int = 1 * 1024 * 1024 // 1MB
    let defaultLocation = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780) // 위치 안찍었을 때 자동으로 서울 체크

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = editingItem == nil ? "일정 추가" : "일정 수정"
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save))
        navigationItem.rightBarButtonItem = saveButton
        
        titleTextField.delegate = self
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(selectImage)))
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(mapTapped(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        let viewTapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(viewTapGesture)
        
        mapView.delegate = self
        
        if let item = editingItem {
            titleTextField.text = item.title
            datePicker.date = item.date
            timePicker.date = item.date
            selectedLatitude = item.latitude
            selectedLongitude = item.longitude
            if let imageURL = item.imageURL {
                loadImage(from: imageURL)
            }
            setInitialMapLocation(latitude: item.latitude, longitude: item.longitude)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func cancel() {
        navigationController?.popViewController(animated: true)
    }

    @objc func save() {
        guard let title = titleTextField.text, !title.isEmpty else {
            self.view.showToast(message: "Please fill the blanks.", duration: 2.0)
            self.statusLabel.text = "알람을 구별할 수 있는 '메모'를 기입 후 저장해 주세요."
            self.statusLabel.textColor = .red
            shakeView()
            return
        }

        let date = datePicker.date
        let time = timePicker.date

        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: time)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute

        if let finalDate = Calendar.current.date(from: dateComponents) {
            if finalDate < Date() {
                self.view.showToast(message: "Cannot schedule a notification in the past.", duration: 2.0)
                self.statusLabel.text = "미래의 시간대를 선택 후 알람을 다시 생성해 주세요."
                self.statusLabel.textColor = .red
                shakeView()
            } else {
                let coordinate: CLLocationCoordinate2D
                if let selectedCoordinate = mapView.annotations.first?.coordinate {
                    coordinate = selectedCoordinate
                } else {
                    coordinate = defaultLocation
                }
                
                if let image = selectedImage {
                    let imageData = image.jpegData(compressionQuality: 0.8)
                    if let data = imageData, data.count > maxImageSize {
                        self.view.showToast(message: "이미지 크기는 1MB를 초과할 수 없습니다.", duration: 2.0)
                        self.statusLabel.text = "이미지 크기를 줄여주세요."
                        self.statusLabel.textColor = .red
                        shakeView()
                        saveButton?.isEnabled = true
                    } else {
                        saveButton?.isEnabled = false
                        uploadImage(image) { imageURL in
                            if let item = self.editingItem {
                                self.delegate?.didEditItem(id: item.id, title: title, date: finalDate, imageURL: imageURL, latitude: coordinate.latitude, longitude: coordinate.longitude)
                            } else {
                                self.delegate?.didAddItem(title: title, date: finalDate, imageURL: imageURL, latitude: coordinate.latitude, longitude: coordinate.longitude)
                            }
                            self.view.showToast(message: "알람을 등록하는 중입니다..", duration: 2.0)
                            self.navigationItem.rightBarButtonItem?.isEnabled = false
                            self.navigationController?.popViewController(animated: true)
                        }
                    }
                } else {
                    if let item = editingItem {
                        delegate?.didEditItem(id: item.id, title: title, date: finalDate, imageURL: item.imageURL, latitude: coordinate.latitude, longitude: coordinate.longitude)
                    } else {
                        delegate?.didAddItem(title: title, date: finalDate, imageURL: nil, latitude: coordinate.latitude, longitude: coordinate.longitude)
                    }
                    self.view.showToast(message: "알람을 등록하는 중입니다..", duration: 2.0)
                    self.navigationItem.rightBarButtonItem?.isEnabled = false
                    navigationController?.popViewController(animated: true)
                }
            }
        }
    }


    @objc func selectImage() {
            let imagePickerController = UIImagePickerController()
            imagePickerController.delegate = self
            imagePickerController.sourceType = .photoLibrary
            present(imagePickerController, animated: true, completion: nil)
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let selectedImage = info[.originalImage] as? UIImage {
                imageView.image = selectedImage
                self.selectedImage = selectedImage
            }
            dismiss(animated: true, completion: nil)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss(animated: true, completion: nil)
        }

        func uploadImage(_ image: UIImage, completion: @escaping (String?) -> Void) {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                completion(nil)
                return
            }
            let imageName = UUID().uuidString
            let storageRef = Storage.storage().reference().child("images/\(imageName).jpg")
            
            storageRef.putData(imageData, metadata: nil) { (metadata, error) in
                if let error = error {
                    print("Error uploading image: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                storageRef.downloadURL { (url, error) in
                    if let error = error {
                        print("Error getting download URL: \(error.localizedDescription)")
                        completion(nil)
                        return
                    }
                    completion(url?.absoluteString)
                }
            }
        }

    func loadImage(from url: String) {
            let storageRef = Storage.storage().reference(forURL: url)
            storageRef.getData(maxSize: 1 * 1024 * 1024) { data, error in
                if let error = error {
                    print("Error loading image: \(error.localizedDescription)")
                    return
                }
                if let data = data {
                    self.imageView.image = UIImage(data: data)
                }
            }
        }

    @objc func mapTapped(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: mapView)
        let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
        selectedLatitude = coordinate.latitude
        selectedLongitude = coordinate.longitude
        updateMapLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    func setInitialMapLocation(latitude: Double, longitude: Double) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.removeAnnotations(mapView.annotations)
        mapView.addAnnotation(annotation)
        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        mapView.setRegion(region, animated: true)
    }

    func updateMapLocation(latitude: Double, longitude: Double) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.removeAnnotations(mapView.annotations)
        mapView.addAnnotation(annotation)
        let currentRegion = mapView.region
        let newRegion = MKCoordinateRegion(center: coordinate, span: currentRegion.span)
        mapView.setRegion(newRegion, animated: true)
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

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func shakeView() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.duration = 0.5
        animation.values = [-10, 10, -8, 8, -6, 6, -4, 4, -2, 2, 0]
        view.layer.add(animation, forKey: "shake")
    }
}
