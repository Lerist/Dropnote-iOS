//
// Created by Maciej Oczko on 05.03.2016.
// Copyright (c) 2016 Maciej Oczko. All rights reserved.
//

import Foundation
import CoreData
import RxSwift

protocol BrewModelControllerType {
    func createNewBrew(withMethod method: BrewMethod) -> Observable<Brew>
    func createNewBrew(withMethod method: BrewMethod, coffee: Coffee?, coffeeMachine: CoffeeMachine?) -> Observable<Brew>
    
    func createNewBrewAttribute(forType type: BrewAttributeType) -> Observable<BrewAttribute>
    func currentBrew() -> Brew?
    func removeCurrentBrew() -> Observable<Bool>
    func removeUnfinishedBrew() -> Observable<Bool>
    func saveBrew() -> Observable<()>
}

final class BrewModelController: BrewModelControllerType {
    let stack: StackType
    private var brew: Brew?

    init(stack: StackType, brew: Brew? = nil) {
        self.stack = stack
        self.brew = brew
    }

    func createNewBrew(withMethod method: BrewMethod) -> Observable<Brew> {
        return createNewBrew(withMethod: method, coffee: nil, coffeeMachine: nil)
    }
    
    func createNewBrew(withMethod method: BrewMethod, coffee: Coffee?, coffeeMachine: CoffeeMachine?) -> Observable<Brew> {
        let coffeeID = coffee?.objectID
        let coffeeMachineID = coffeeMachine?.objectID
		return Observable.create {
			[weak self] observer in
			self?.stack.asyncOperation {
				context in
				let operations = CoreDataOperations<Brew>(managedObjectContext: context)
				do {
					let predicate = NSPredicate(format: "method == %d AND isFinished == NO", method.intValue)
					let brews = try operations.fetch(withPredicate: predicate)

					if let brew = brews.last {
						observer.onNext(brew)
						observer.onCompleted()
					} else {
						let brew = operations.create()
                        self?.configureBrew(brew, withMethod: method)
						self?.configureBrew(brew, withCoffeeID: coffeeID, inContext: context)
                        self?.configureBrew(brew, withCoffeeMachineID: coffeeMachineID, inContext: context)
                        self?.configureCuppingAttributesForBrew(brew, inContext: context)
						do {
							try operations.save()
							observer.onNext(brew)
							observer.onCompleted()
						} catch {
							observer.onError(error)
						}
					}
				} catch {
					observer.onError(error)
				}
			}
			return NopDisposable.instance
		}
			.doOn(onNext: {
				brew in self.brew = brew
		})
	}
    
    private func configureBrew(brew: Brew, withMethod method: BrewMethod) {
        brew.created = NSDate.timeIntervalSinceReferenceDate()
        brew.method = method.intValue
        brew.isFinished = false
    }
    
    private func configureBrew(brew: Brew, withCoffeeID coffeeID: NSManagedObjectID?, inContext context: NSManagedObjectContext) {
        if let id = coffeeID {
            let safeCoffee = context.objectWithID(id) as! Coffee
            brew.coffee = safeCoffee
        }
    }
    
    private func configureBrew(brew: Brew, withCoffeeMachineID coffeeMachineID: NSManagedObjectID?, inContext context: NSManagedObjectContext) {
        if let id = coffeeMachineID {
            let safeCoffeeMachine = context.objectWithID(id) as! CoffeeMachine
            brew.coffeeMachine = safeCoffeeMachine
        }
    }
    
    private func configureCuppingAttributesForBrew(brew: Brew, inContext context: NSManagedObjectContext) {
        let cuppingOperations = CoreDataOperations<Cupping>(managedObjectContext: context)
        for cuppingAttribute in CuppingAttribute.allValues {
            let cupping = cuppingOperations.create()
            cupping.brew = brew
            cupping.type = cuppingAttribute.rawValue
            cupping.value = 0
        }
    }

    func createNewBrewAttribute(forType type: BrewAttributeType) -> Observable<BrewAttribute> {
        if let attribute = brew?.brewAttributeForType(type) {
            return .just(attribute)
        }
        return Observable.create {
            [weak self] observer in
            self?.stack.asyncOperation {
                context in
                let operations = CoreDataOperations<BrewAttribute>(managedObjectContext: context)
                let attribute = operations.create()
                attribute.type = type.intValue
                observer.onNext(attribute)
                observer.onCompleted()
            }
            return NopDisposable.instance
        }
    }
    
    func saveBrew() -> Observable<()> {
        currentBrew()?.coffee?.updatedAt = NSDate.timeIntervalSinceReferenceDate()
        currentBrew()?.coffeeMachine?.updatedAt = NSDate.timeIntervalSinceReferenceDate()        
        return stack.save().map { _ in }
    }

    func currentBrew() -> Brew? {
        return brew
    }
    
    func removeCurrentBrew() -> Observable<Bool> {
        return removeBrew(currentBrew())
    }

    func removeUnfinishedBrew() -> Observable<Bool> {
        return Observable<Brew?>.create {
            [weak self] observer in
            self?.stack.asyncOperation {
                context in
                do {
                    let operations = CoreDataOperations<Brew>(managedObjectContext: context)
                    let predicate = NSPredicate(format: "isFinished == NO")
                    let brews = try operations.fetch(withPredicate: predicate)
                    observer.onNext(brews.last)
                    observer.onCompleted()
                } catch {
                    observer.onError(error)
                }
            }
            return NopDisposable.instance
        }
        .flatMap(removeBrew)
    }
    
    private func removeBrew(brew: Brew?) -> Observable<Bool> {
        guard let brew = brew else { return .just(false) }
        let brewID = brew.objectID
        return Observable.create {
            [weak self] observer in
            self?.stack.asyncOperation {
                context in
                do {
                    let operations = CoreDataOperations<Brew>(managedObjectContext: context)
                    let brew = operations.objectForID(brewID)
                    
                    if let brew = brew {
                        context.deleteObject(brew)
                        observer.onNext(true)
                    } else {
                        observer.onNext(false)
                    }
                    
                    try operations.save()
                    observer.onCompleted()
                } catch {
                    observer.onError(error)
                }
            }
            return NopDisposable.instance
        }
    }
}
