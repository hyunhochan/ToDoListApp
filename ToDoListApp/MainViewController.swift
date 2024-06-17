//
//  ViewController.swift
//  ToDoListApp
//
//  Created by hyunho on 6/6/24.
//

import UIKit
import UserNotifications
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

extension UIView {
    func showToast(message: String, duration: Double) {
        let toastLabel = UILabel()
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = .center
        toastLabel.font = UIFont.systemFont(ofSize: 14)
        toastLabel.text = message
        toastLabel.alpha = 1.0
        toastLabel.layer.cornerRadius = 10
        toastLabel.clipsToBounds = true
        
        let maxWidthPercentage: CGFloat = 0.8
        let maxTitleSize = CGSize(width: self.bounds.size.width * maxWidthPercentage, height: self.bounds.size.height)
        var expectedSize = toastLabel.sizeThatFits(maxTitleSize)
        expectedSize.width = min(maxTitleSize.width, expectedSize.width)
        expectedSize.height = min(maxTitleSize.height, expectedSize.height)
        
        toastLabel.frame = CGRect(x: (self.bounds.size.width - expectedSize.width - 20) / 2,
                                  y: self.bounds.size.height - expectedSize.height - 60,
                                  width: expectedSize.width + 20,
                                  height: expectedSize.height + 10)
        
        self.addSubview(toastLabel)
        
        UIView.animate(withDuration: 0.5, delay: duration, options: .curveEaseOut, animations: {
            toastLabel.alpha = 0.0
        }, completion: { _ in
            toastLabel.removeFromSuperview()
        })
    }
}

class MainViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, AddItemDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var logoutBarButtonItem: UIBarButtonItem!
    
    var items: [(id: String, title: String, date: Date, imageURL: String?, latitude: Double, longitude: Double)] = []
    let db = Firestore.firestore()
    var listener: ListenerRegistration?

    override func viewDidLoad() {
        super.viewDidLoad()

        // 로그인 상태 확인
        if !isLoggedIn() {
            transitionToLoginScreen()
            return
        }

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundView = createEmptyTableViewLabel()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewItem))
        
        logoutBarButtonItem.target = self
        logoutBarButtonItem.action = #selector(logoutButtonTapped)
        
        listenForItemsFromFirestore()
    }

    @objc func logoutButtonTapped() {
        do {
            try Auth.auth().signOut()
            UserDefaults.standard.set(false, forKey: "isLoggedIn")
            UserDefaults.standard.removeObject(forKey: "userEmail")
            transitionToLoginScreen()
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
            self.view.showToast(message: "로그아웃 실패: \(signOutError.localizedDescription)", duration: 2.0)
        }
    }

    func transitionToLoginScreen() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController {
            loginVC.modalPresentationStyle = .fullScreen
            self.present(loginVC, animated: true, completion: nil)
        } else {
            print("LoginViewController를 찾을 수 없습니다.")
        }
    }
    
    func isLoggedIn() -> Bool {
        return Auth.auth().currentUser != nil || UserDefaults.standard.bool(forKey: "isLoggedIn")
    }

    func listenForItemsFromFirestore() {
        guard let user = Auth.auth().currentUser else {
            print("No user is logged in.")
            return
        }
        listener = db.collection("users").document(user.uid).collection("todoItems").order(by: "date").addSnapshotListener { querySnapshot, error in
            guard let documents = querySnapshot?.documents else {
                print("Error fetching documents: \(String(describing: error))")
                return
            }
            
            self.items = documents.compactMap { doc -> (String, String, Date, String?, Double, Double)? in
                let data = doc.data()
                guard let title = data["title"] as? String,
                      let timestamp = data["date"] as? Timestamp,
                      let latitude = data["latitude"] as? Double,
                      let longitude = data["longitude"] as? Double else { return nil }
                let imageURL = data["imageURL"] as? String
                return (doc.documentID, title, timestamp.dateValue(), imageURL, latitude, longitude)
            }
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.scheduleNotificationsForItems()
            }
        }
    }

    func scheduleNotificationsForItems() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for item in items {
            scheduleNotification(for: item)
        }
    }

    func didAddItem(title: String, date: Date, imageURL: String?, latitude: Double, longitude: Double) {
        guard let user = Auth.auth().currentUser else {
            print("No user is logged in.")
            return
        }
        let docRef = db.collection("users").document(user.uid).collection("todoItems").addDocument(data: [
            "title": title,
            "date": date,
            "imageURL": imageURL ?? NSNull(),
            "latitude": latitude,
            "longitude": longitude
        ]) { error in
            if let error = error {
                print("Error adding document: \(error)")
            }
        }
        
        let newItem = (id: docRef.documentID, title: title, date: date, imageURL: imageURL, latitude: latitude, longitude: longitude)
        items.append(newItem)
        items.sort { $0.date < $1.date }
        tableView.reloadData()
        scheduleNotification(for: newItem)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.view.showToast(message: "Notification scheduled: \(title)", duration: 2.0)
        }
    }

    func didEditItem(id: String, title: String, date: Date, imageURL: String?, latitude: Double, longitude: Double) {
        guard let user = Auth.auth().currentUser else {
            print("No user is logged in.")
            return
        }
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index] = (id: id, title: title, date: date, imageURL: imageURL, latitude: latitude, longitude: longitude)
            items.sort { $0.date < $1.date }
            tableView.reloadData()
            saveItemToFirestore(item: items[index])
            scheduleNotification(for: items[index])
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.view.showToast(message: "Notification updated: \(title)", duration: 2.0)
            }
        }
    }

    func saveItemToFirestore(item: (id: String, title: String, date: Date, imageURL: String?, latitude: Double, longitude: Double)) {
        guard let user = Auth.auth().currentUser else {
            print("No user is logged in.")
            return
        }
        let docData: [String: Any] = [
            "title": item.title,
            "date": item.date,
            "imageURL": item.imageURL ?? NSNull(),
            "latitude": item.latitude,
            "longitude": item.longitude
        ]
        db.collection("users").document(user.uid).collection("todoItems").document(item.id).setData(docData) { error in
            if let error = error {
                print("Error adding document: \(error)")
            } else {
                print("Document added with ID: \(item.id)")
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if items.isEmpty {
            tableView.backgroundView?.isHidden = false
        } else {
            tableView.backgroundView?.isHidden = true
        }
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CustomTableViewCell", for: indexPath) as! CustomTableViewCell
        
        cell.customImageView.image = nil
        cell.customImageView.contentMode = .scaleAspectFill
        cell.customImageView.clipsToBounds = true
        
        if indexPath.row < items.count {
            let item = items[indexPath.row]
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy.MM.dd HH시 mm분"
            cell.titleLabel.text = item.title
            cell.dateLabel.text = formatter.string(from: item.date)
            
            if let imageURL = item.imageURL {
                loadImage(from: imageURL) { image in
                    DispatchQueue.main.async {
                        if let currentIndexPath = tableView.indexPath(for: cell), currentIndexPath == indexPath {
                            cell.customImageView.image = image
                        }
                    }
                }
            }
            
            cell.imageTapAction = {
                if let image = cell.customImageView.image {
                    self.showImagePopup(image: image)
                }
            }
        }
        
        return cell
    }

    func loadImage(from url: String, completion: @escaping (UIImage?) -> Void) {
        let storageRef = Storage.storage().reference(forURL: url)
        storageRef.getData(maxSize: 1 * 1024 * 1024) { data, error in
            if let error = error {
                print("Error loading image: \(error.localizedDescription)")
                completion(nil)
                return
            }
            if let data = data {
                completion(UIImage(data: data))
            } else {
                completion(nil)
            }
        }
    }


    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let mapVC = storyboard.instantiateViewController(withIdentifier: "MapViewController") as? MapViewController {
            mapVC.latitude = item.latitude
            mapVC.longitude = item.longitude
            navigationController?.pushViewController(mapVC, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let editAction = UIContextualAction(style: .normal, title: "Edit") { (_, _, completionHandler) in
            let item = self.items[indexPath.row]
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let addItemVC = storyboard.instantiateViewController(withIdentifier: "AddItemViewController") as? AddItemViewController {
                addItemVC.delegate = self
                addItemVC.editingItem = item
                self.navigationController?.pushViewController(addItemVC, animated: true)
            }
            completionHandler(true)
        }
        editAction.backgroundColor = .blue

        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { (_, _, completionHandler) in
            self.deleteItem(self.items[indexPath.row])
            completionHandler(true)
        }
        
        return UISwipeActionsConfiguration(actions: [deleteAction, editAction])
    }

    func showImagePopup(image: UIImage) {
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = UIScreen.main.bounds
        imageView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        imageView.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissImagePopup))
        imageView.addGestureRecognizer(tapGesture)
        if let window = UIApplication.shared.keyWindow {
            window.addSubview(imageView)
        }
    }

    @objc func dismissImagePopup(_ sender: UITapGestureRecognizer) {
        sender.view?.removeFromSuperview()
    }

    func deleteItem(_ item: (id: String, title: String, date: Date, imageURL: String?, latitude: Double, longitude: Double)) {
        guard let user = Auth.auth().currentUser else {
            print("No user is logged in.")
            return
        }
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
            tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .fade)
        }
        removeNotification(for: item)
        deleteItemFromFirestore(itemID: item.id)
        
        if items.isEmpty {
            tableView.backgroundView?.isHidden = false
        }
        self.view.showToast(message: "Notification removed: \(item.title)", duration: 2.0)
    }

    func deleteItemFromFirestore(itemID: String) {
        guard let user = Auth.auth().currentUser else {
            print("No user is logged in.")
            return
        }
        db.collection("users").document(user.uid).collection("todoItems").document(itemID).delete { error in
            if let error = error {
                print("Error deleting document: \(error)")
            }
        }
    }

    func scheduleNotification(for item: (id: String, title: String, date: Date, imageURL: String?, latitude: Double, longitude: Double)) {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.date), repeats: false)
        
        let request = UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { (error) in
            if let error = error {
                print("Error adding notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled: \(item.title) at \(item.date)")
            }
        }
    }

    func removeNotification(for item: (id: String, title: String, date: Date, imageURL: String?, latitude: Double, longitude: Double)) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [item.id])
        print("Notification removed: \(item.title) at \(item.date)")
    }

    func createEmptyTableViewLabel() -> UILabel {
        let message = "새 알림을 추가하려면 우측 상단의 '+'을 누르십시오."
        let label = UILabel()
        label.text = message
        label.textAlignment = .center
        label.textColor = .systemBlue
        label.font = UIFont.systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.sizeToFit()
        return label
    }

    @objc func addNewItem() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let addItemVC = storyboard.instantiateViewController(withIdentifier: "AddItemViewController") as? AddItemViewController {
            addItemVC.delegate = self
            navigationController?.pushViewController(addItemVC, animated: true)
        }
    }
}
