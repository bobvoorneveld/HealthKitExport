//
//  ContentView.swift
//  HealthKitExport
//
//  Created by Bob Voorneveld on 07/06/2023.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @State var isReady = false
    @State var workouts: [HKWorkout] = []

    let store = HKHealthStore()

    var body: some View {
        NavigationStack {
            VStack {
                if isReady {

                    List(workouts, id: \.uuid) { workout in
                        NavigationLink {
                            WorkoutView(workout: workout)
                        } label: {
                            HStack {
                                Text(workout.startDate, style: .date)
                                Spacer()
                                Text("\(workout.workoutActivityType.name)")
                            }
                        }
                    }
                } else {
                    Text("please authorize the app")
                }
            }
            .padding()
            .task {
                if !HKHealthStore.isHealthDataAvailable() {
                    return
                }

                guard await requestPermission() else {
                    return
                }

                isReady = true

                workouts = await readWorkouts() ?? []
            }
        }
    }

    func requestPermission() async -> Bool {
    //    let write: Set<HKSampleType> = [.workoutType()]
        let read: Set = [
            .workoutType(),
            HKSeriesType.activitySummaryType(),
            HKSeriesType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
        ]

        let res: ()? = try? await store.requestAuthorization(toShare: [], read: read)

        return res != nil
    }

    func readWorkouts() async -> [HKWorkout]? {
        // Could filter on workout type here by creating a predicate
//        let predicate = HKQuery.predicateForWorkouts(with: .cycling)

        let samples: [HKSample]? = try! await withCheckedThrowingContinuation { continuation in
            store.execute(
                HKSampleQuery(
                    sampleType: .workoutType(),
                    predicate: nil,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [.init(keyPath: \HKSample.startDate, ascending: false)]
                ) { query, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let samples else {
                        fatalError("should have samples")
                    }
                    continuation.resume(returning: samples)
                }
            )
        }
        guard let workouts = samples as? [HKWorkout] else {
            return nil
        }
        return workouts
    }
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
