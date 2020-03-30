//
//  Amb.swift
//  CombineExt
//
//  Created by Shai Mishali on 29/03/2020.
//

import Combine

public extension Publisher {
    func amb<Other: Publisher>(_ other: Other) -> Publishers.Amb<Self, Other> where Other.Output == Output, Other.Failure == Failure {
        Publishers.Amb(first: self, second: other)
    }

    func amb<Other: Publisher>(_ others: Other...) -> Publishers.Amb<AnyPublisher<Output, Failure>, AnyPublisher<Output, Failure>> where Other.Output == Output, Other.Failure == Failure {
        switch others.count {
        case 0:
            assertionFailure("You need at least two publishers to use `amb`")
        case 1:
            return self.eraseToAnyPublisher().amb(others[0].eraseToAnyPublisher())
        default:
            let seed = nil as Publishers.Amb<AnyPublisher<Output, Failure>, AnyPublisher<Output, Failure>>?
            let result = others.reduce(seed) { publishers, publisher in
                publishers?.amb(publisher)
            }

            guard let ambed = result else {
                return Publishers.Amb(first: Empty(completeImmediately: true).eraseToAnyPublisher(),
                                      second: Empty(completeImmediately: true).eraseToAnyPublisher())
            }

            return ambed
        }
    }
}

public extension Publishers {
    class Amb<First: Publisher, Second: Publisher>: Publisher where First.Output == Second.Output, First.Failure == Second.Failure {
        public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
            subscriber.receive(subscription: Subscription(first: first,
                                                          second: second,
                                                          downstream: subscriber))
        }

        public typealias Output = First.Output
        public typealias Failure = First.Failure

        private let first: First
        private let second: Second

        public init(first: First,
                    second: Second) {
            self.first = first
            self.second = second
        }
    }
}

private extension Publishers.Amb {
    class Subscription<Downstream: Subscriber>: Combine.Subscription where Output == Downstream.Input, Failure == Downstream.Failure {
        private var firstSink: Sink<First, Downstream>?
        private var secondSink: Sink<Second, Downstream>?
        private var preDecisionDemand = Subscribers.Demand.none
        private var decision: Decision? {
            didSet {
                guard let decision = decision else { return }
                switch decision {
                case .first:
                    secondSink = nil
                case .second:
                    firstSink = nil
                }

                request(preDecisionDemand)
            }
        }

        init(first: First,
             second: Second,
             downstream: Downstream) {
            self.firstSink = Sink(upstream: first,
                                  downstream: downstream) { [weak self] in
                                guard let self = self,
                                      self.decision == nil else { return }

                                self.decision = .first
                             }

            self.secondSink = Sink(upstream: second,
                                   downstream: downstream) { [weak self] in
                                guard let self = self,
                                      self.decision == nil else { return }

                                self.decision = .second
                              }
        }

        func request(_ demand: Subscribers.Demand) {
            guard decision != nil else {
                preDecisionDemand += demand
                return
            }

            let neededDemand = demand + preDecisionDemand
            if preDecisionDemand != .none {
                preDecisionDemand = .none
            }

            firstSink?.demand(neededDemand)
            secondSink?.demand(neededDemand)
        }

        func cancel() {
            firstSink = nil
            secondSink = nil
        }
    }
}

private enum Decision {
    case first
    case second
}

private extension Publishers.Amb {
    class Sink<Upstream: Publisher, Downstream: Subscriber>: CombineExt.Sink<Upstream, Downstream> where Upstream.Output == Downstream.Input, Upstream.Failure == Downstream.Failure {
        private let emitted: () -> Void

        init(upstream: Upstream,
             downstream: Downstream,
             emitted: @escaping () -> Void) {
            self.emitted = emitted
            super.init(upstream: upstream,
                       downstream: downstream,
                       transformOutput: { $0 },
                       transformFailure: { $0 })
        }

        override func receive(subscription: Combine.Subscription) {
            super.receive(subscription: subscription)

            subscription.request(.max(1))
        }

        override func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            emitted()
            return buffer.buffer(value: input)
        }

        override func receive(completion: Subscribers.Completion<Downstream.Failure>) {
            emitted()
            buffer.complete(completion: completion)
        }
    }
}
