//
//  AmbTests.swift
//  CombineExtTests
//
//  Created by Shai Mishali on 29/03/2020.
//  Copyright © 2020 Combine Community. All rights reserved.
//

import XCTest
import Combine
import CombineExt

class AmbTests: XCTestCase {
    var subscription: AnyCancellable!

    override func tearDown() {
        subscription = nil
    }

    func testAmbValues() {
        let subject1 = PassthroughSubject<Int, Never>()
        let subject2 = PassthroughSubject<Int, Never>()
        var completion: Subscribers.Completion<Never>?
        var values = [Int]()

        subscription = subject1
            .amb(subject2)
            .sink(receiveCompletion: { completion = $0 },
                  receiveValue: { values.append($0) })

        subject2.send(1) //
        subject2.send(2) //
        subject1.send(6)
        subject1.send(6)
        subject1.send(6)
        subject2.send(8) //

        XCTAssertEqual(values, [1, 2, 8])

        XCTAssertNil(completion)
        subject1.send(completion: .finished)
        XCTAssertNil(completion)
        subject2.send(completion: .finished)
        XCTAssertEqual(completion, .finished)
    }

    func testAmbEmptyAndNever() {
        let subject1 = Empty<Int, Never>(completeImmediately: false).append(0)
        let subject2 = Empty<Int, Never>(completeImmediately: true).append(1)
        var completion: Subscribers.Completion<Never>?
        var values = [Int]()

        subscription = subject1
            .amb(subject2)
            .sink(receiveCompletion: { completion = $0 },
                  receiveValue: { values.append($0) })

        XCTAssertEqual(values, [1])
        XCTAssertEqual(completion, .finished)
    }
}
