//
//  ViewController.swift
//  ActivityRingsExporter
//
//  Created by Ezekiel Elin on 12/14/17.
//  Copyright © 2017 Ezekiel Elin. All rights reserved.
//

import UIKit
import HealthKit

class ViewController: UIViewController {
    
    @IBOutlet var datePicker: UIDatePicker!
    @IBOutlet var exportButton: UIButton!
    
    @IBOutlet var activitySpinner: UIActivityIndicatorView!
    
    var healthStore: HKHealthStore?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
            
            datePicker.maximumDate = Date()
            datePicker.minimumDate = healthStore?.earliestPermittedSampleDate()
        } else {
            let alert = UIAlertController(title: "HealthKit Unavailable", message: "This device does not support HealthKit", preferredStyle: .alert)
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @IBAction func exportPressed() {
        exportButton.isHidden = true
        activitySpinner.startAnimating()
        
        let endDate = Date()
        let startDate = self.datePicker.date
        
        if let healthStore = self.healthStore {
            let activity = HKObjectType.activitySummaryType()
            
            healthStore.requestAuthorization(toShare: nil, read: [activity], completion: { (success, error) in
                
                let calendar = Calendar(identifier: .gregorian)
                
                var endComponents = calendar.dateComponents([.day, .month, .year, .era], from: endDate)
                var startComponents = calendar.dateComponents([.day, .month, .year, .era], from: startDate)
                
                endComponents.calendar = calendar
                startComponents.calendar = calendar
                
                let summariesWithinRange = HKQuery.predicate(forActivitySummariesBetweenStart: startComponents, end: endComponents)
                
                let query = HKActivitySummaryQuery(predicate: summariesWithinRange, resultsHandler: { (summaryQuery, summaries, error) in
                    
                    guard let summaries = summaries else {
                        DispatchQueue.main.async {
                            let alert = UIAlertController(title: "HealthKit Error", message: error?.localizedDescription, preferredStyle: .alert)
                            self.present(alert, animated: true, completion: nil)
                        }
                        return
                    }
                    
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"

                    let exportArray = summaries.map({ (summary) -> ActivitySummary in
                        let activity = summary.activeEnergyBurned.doubleValue(for: HKUnit.kilocalorie())
                        let activityGoal = summary.activeEnergyBurnedGoal.doubleValue(for: HKUnit.kilocalorie())
                        
                        let exercise = summary.appleExerciseTime.doubleValue(for: HKUnit.minute())
                        let exerciseGoal = summary.appleExerciseTimeGoal.doubleValue(for: HKUnit.minute())
                        
                        let stand = summary.appleStandHours.doubleValue(for: HKUnit.count())
                        let standGoal = summary.appleStandHoursGoal.doubleValue(for: HKUnit.count())
                        
                        var date: Date!
                        if let d = summary.dateComponents(for: calendar).date {
                            date = d
                        } else {
                            date = Date(timeIntervalSince1970: 0)
                            DispatchQueue.main.async {
                                let alert = UIAlertController(title: "HealthKit Error", message: "No date present on record. Will use 0", preferredStyle: .alert)
                                
                                let button = UIAlertAction(title: "OK", style: .default, handler: nil)
                                alert.addAction(button)
                                
                                self.present(alert, animated: true, completion: nil)
                            }
                        }
                        
                        let sum = ActivitySummary(move: activity, moveGoal: activityGoal, exercise: exercise, exerciseGoal: exerciseGoal, stand: stand, standGoal: standGoal, date: formatter.string(from: date))
                        return sum
                    })
                    
                    do {
                        let jsonEncoder = JSONEncoder()
                        let encode = try jsonEncoder.encode(exportArray)
                        guard let jsonString = String(data: encode, encoding: .utf8) else {
                            DispatchQueue.main.async {
                                let alert = UIAlertController(title: "HealthKit Error", message: "An error occurred exporting the results", preferredStyle: .alert)
                                self.present(alert, animated: true, completion: nil)
                            }
                            return
                        }
                        
                        DispatchQueue.main.async {
                            let vc = UIActivityViewController(activityItems: [jsonString], applicationActivities: nil)
                            
                            vc.popoverPresentationController?.sourceView = self.view
                            self.present(vc, animated: true, completion: nil)
                            
                            self.exportButton.isHidden = false
                            self.activitySpinner.stopAnimating()
                        }
                    } catch let error2 {
                        DispatchQueue.main.async {
                            let alert = UIAlertController(title: "HealthKit Error", message: error2.localizedDescription, preferredStyle: .alert)
                            self.present(alert, animated: true, completion: nil)
                        }
                    }
                })
                healthStore.execute(query)
            })
        } else {
            let alert = UIAlertController(title: "HealthKit Unavailable", message: "This device does not support HealthKit", preferredStyle: .alert)
            self.present(alert, animated: true, completion: nil)
        }
    }
}

struct ActivitySummary: Codable {
    let move: Double
    let moveGoal: Double
    
    let exercise: Double
    let exerciseGoal: Double
    
    let stand: Double
    let standGoal: Double
    
    let date: String
}
