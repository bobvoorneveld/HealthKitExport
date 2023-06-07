//
//  WorkoutView.swift
//  HealthKitExport
//
//  Created by Bob Voorneveld on 07/06/2023.
//

import SwiftUI
import HealthKit

struct WorkoutView: View {
    let workout: HKWorkout

    let store = HKHealthStore()

    var distance: Double {
        (workout.statistics(for: HKQuantityType.quantityType(forIdentifier: .distanceCycling)!)?.sumQuantity()?.doubleValue(for: HKUnit.meter()) ?? 0) / 1000
    }

    var duration: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: workout.endDate.timeIntervalSince(workout.startDate) as NSNumber) ?? "0"
    }

    var sourceName: String {
        workout.sourceRevision.source.name
    }

    @State private var samples: [Sample]?
    @State private var loadingSamples = false


    var body: some View {
        VStack {

            VStack {
                Text("Source: " + sourceName)
                Text("Date: " + workout.startDate.formatted(date: .numeric, time: .omitted))

                Text(String(format: "%.1f", distance) + "km")

            }
            .padding(.bottom, 16)

            if loadingSamples {
                Text("loading heartrate samples")
            } else if let samples {
                VStack(spacing: 0) {
                    Text("Heartrate samples")

                    Text("\(samples.count) samples for \(duration) seconds")
                    
                    List(samples) { sample in
                        HStack{
                            Text(sample.timestamp)
                            Spacer()
                            Text("\(sample.rate)")
                        }
                    }
                }
            } else {
                Text("No samples heartrate samples")
            }
        }
        .task {
            await getHeartRate()
        }
    }

    func getHeartRate() async {
        loadingSamples = true
        let quantityType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: [.strictStartDate])
        let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
        var newSamples = [Sample]()
        let query = HKQuantitySeriesSampleQuery(quantityType: quantityType, predicate: predicate) { query, quantity, dateInterval, sample, done, error in
            guard let rate = quantity?.doubleValue(for: heartRateUnit), let date = dateInterval?.start else {
                return
            }
            newSamples.append(Sample(date: date, rate: Int(round(rate)), workoutStartDate: workout.startDate))

            if done {
                loadingSamples = false
                samples = newSamples
            }
        }

        store.execute(query)
    }
}

struct Sample: Identifiable {
    let id = UUID()
    let date: Date
    let rate: Int
    let workoutStartDate: Date

    var timestamp: String {
        date.timeIntervalSince(workoutStartDate).stringValue
    }
}

extension TimeInterval{

    var stringValue: String {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        return formatter.string(from: self)!
    }
}
