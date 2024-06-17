//
//  AppDelegate.swift
//  ToDoListApp
//
//  Created by hyunho on 6/6/24.
//

import UIKit
import Firebase
import UserNotifications
import FirebaseFirestore
import FirebaseAuth

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    lazy var db = Firestore.firestore()
    
    var items: [(id: String, title: String, date: Date)] = []

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        self.window = UIWindow(frame: UIScreen.main.bounds)
        showInitialViewController()
        return true
    }

    func showInitialViewController() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let mainNavController = storyboard.instantiateViewController(withIdentifier: "MainNavigationController") as? UINavigationController {
            window?.rootViewController = mainNavController
            window?.makeKeyAndVisible()
        }
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        fetchItemsFromFirestore { newData in
            completionHandler(newData ? .newData : .noData)
        }
    }

    func fetchItemsFromFirestore(completion: @escaping (Bool) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(false)
            return
        }
        
        db.collection("users").document(user.uid).collection("todoItems").order(by: "date").getDocuments { querySnapshot, error in
            guard let documents = querySnapshot?.documents else {
                completion(false)
                return
            }
            
            var newItems: [(id: String, title: String, date: Date)] = []
            
            newItems = documents.compactMap { doc -> (String, String, Date)? in
                let data = doc.data()
                guard let title = data["title"] as? String,
                      let timestamp = data["date"] as? Timestamp else { return nil }
                return (doc.documentID, title, timestamp.dateValue())
            }
            
            if !self.areItemsEqual(newItems, self.items) {
                self.items = newItems
                self.scheduleNotificationsForItems()
                completion(true)
            } else {
                completion(false)
            }
        }
    }

    func scheduleNotificationsForItems() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for item in items {
            scheduleNotification(for: item)
        }
    }

    func scheduleNotification(for item: (id: String, title: String, date: Date)) {
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

    // Foreground 알림 처리
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound])
    }

    // Background 및 종료된 상태에서 알림 처리
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    func areItemsEqual(_ lhs: [(id: String, title: String, date: Date)], _ rhs: [(id: String, title: String, date: Date)]) -> Bool {
        guard lhs.count == rhs.count else {
            return false
        }
        for (index, item) in lhs.enumerated() {
            if item.id != rhs[index].id || item.title != rhs[index].title || item.date != rhs[index].date {
                return false
            }
        }
        return true
    }
}
