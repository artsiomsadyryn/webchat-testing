//
//  Coordinator.swift
//  Model
//
//  Created by SOL on 28.04.17.
//  Copyright © 2017 SOL. All rights reserved.
//

import UIKit

/**
 The base class of the single module. Basically one coordinator is connected with one container controller like NavigationCoordinator, TabCoordinator and e.t.c.
 All navigation logic as well as screen transition control should be kept it this 'Coordinator' layer.
 Custom coordinator can interact with 'Views' and 'Presentation' layers to setup screens in proper way.
 
 Custom coordinator may contain:
 - In most cases, strong references to base container controllr
 - Strong references to it's child coordinators ('children' property)
 - Weak reference to its parent coordinator
 */
open class Coordinator: NSObject, Continer {
    /// All child coordinators references to keep tree-like application navigation structure.
    /// Use *add(child:)* and *removeFromParent()* to modify this array.
    open private(set) lazy var children = [Coordinator]()
    
    /// The coordinator's parent, or nil if it has none
    open private(set) weak var parent: Coordinator?
    
    open private(set) var modallyShownCoordinator: Coordinator?
    open private(set) var modallyShownController: UIViewController?
    
    public var parentResolver: Resolver? {
        return parent
    }
    
    public var containers: [ContainerItem] = []
    
    public init(parent: Coordinator? = nil) {
        super.init()
        
        parent?.add(child: self)
        registerContent()
    }
    
    /// Override this func to register content into container
    /// This method will be called immediately after init
    open func registerContent() {
        // Do nothing
    }
    
    /// The base container controller associated with this coordinator. Each custom coordinator must return the ViewController's object
    open var baseViewController: UIViewController {
        fatalError("Model.Coordinator.baseViewController\n" +
            "Abstract getter. Please override 'baseViewController' getter in child class")
    }
    
    /// The currently active (top, selected, etc.) view controller inside the container controller
    open var activeViewController: UIViewController? {
        fatalError("Model.Coordinator.activeViewController\n" +
            "Abstract getter. Please override 'activeController' getter in child class")
    }
    
    /// Adds a coordinator to the end of the list of child coordinators. Use this method to build navigation tree-like structure inside you application.
    /// - parameter coordinator: coordinator object that should be added as child. This coordinator should not have parent before the method call.
    open func add(child: Coordinator) {
        if child.parent === self, children.contains(where: { $0 === child }) {
            return
        }
        
        if child.parent != nil {
            assertionFailure("Model.Coordinator.add(child:)\n" +
                "Attempt to add child coordinator which already has parent")
        }
        
        if children.contains(where: { $0 === child }) {
            assertionFailure("Model.Coordinator.add(child:)\n" +
                "Child coordinator already contains in children coordinators list")
        }
        
        children.append(child)
        child.parent = self
    }
    
    /// Removes the the coordinator from its parent's children coordinators array. If this method is overridden then
    /// the super implementation must be called.
    open func removeFromParent() {
        guard let parentCoordinator = parent else {
            return
        }
        
        guard let index = parentCoordinator.children.firstIndex(where: { $0 === self }) else {
            assertionFailure("Model.Coordinator.removeFromParent()\n" +
                "Parent coordinator does not contain current coordinator in children list")
            self.parent = nil
            return
        }
        
        parentCoordinator.children.remove(at: index)
        self.parent = nil
    }
    
    /// Present coordinator modally coordinator and add it to child coordinators list
    /// - parameter coordinator: coordinator object that should be added as child. This coordinator should not have parent before the method call.
    /// - parameter presentationStyle: style to present coordinator base controller, default is `.currentContext`.
    /// - parameter animated: if presenting will be animated or not
    /// - parameter completion: the closure to execute after the presentation finishes
    open func presentModal(coordinator: Coordinator,
                           presentationStyle: UIModalPresentationStyle = .currentContext,
                           animated: Bool = true,
                           completion: (() -> ())? = nil) {
        guard modallyShownCoordinator == nil && modallyShownController == nil else {
            assertionFailure("Model.Coordinator.presentModal(coordinator:presentationStyle:animated:completion:)\n" +
                "Unable to present modal coordinator. modallyShownCoordinator and modallyShownController should be nil")
            completion?()
            return
        }
        if coordinator.modallyShownCoordinator != nil {
            assertionFailure("Model.Coordinator.presentModal(coordinator:presentationStyle:animated:completion:)\n" +
                "Attempt to add modally shown coordinator with has own modal coordinator")
        }
        add(child: coordinator)
        modallyShownCoordinator = coordinator
        presentModal(controller: coordinator.baseViewController,
                     presentationStyle: presentationStyle,
                     animated: animated,
                     completion: completion)
    }
    
    /// Present controller modally
    /// - parameter controller: controller object that should be presented.
    /// - parameter presentationStyle: style to present coordinator base controller, default is `.currentContext`.
    /// - parameter animated: if presenting will be animated or not
    /// - parameter completion: the closure to execute after the presentation finishes
    open func presentModal(controller: UIViewController,
                           presentationStyle: UIModalPresentationStyle = .currentContext,
                           animated: Bool = true,
                           completion: (() -> Void)? = nil) {
        guard modallyShownController == nil && (modallyShownCoordinator == nil || modallyShownCoordinator?.baseViewController == controller) else {
            assertionFailure("Model.Coordinator.presentModal(coordinator:presentationStyle:animated:completion:)\n" +
                "Unable to present modal coordinator. modallyShownController should be nil " +
                "or presented coordinator should contains current controller")
            completion?()
            return
        }
        if controller.presentedViewController != nil || controller.presentingViewController != nil {
            assertionFailure("Model.Coordinator.presentModal(coordinator:presentationStyle:animated:completion:)\n" +
                "Attempt to present modal controller witch alredy beeng presented")
        }
        
        modallyShownController = controller
        controller.modalPresentationStyle = presentationStyle

        var presenterViewController = baseViewController
        switch presentationStyle {
        case .currentContext, .overCurrentContext:
            presenterViewController = activeViewController ?? presenterViewController
        case .pageSheet, .automatic:
            controller.presentationController?.delegate = self
        default:
            break
        }
        presenterViewController.present(controller, animated: animated, completion: completion)
        clearUnusedChildCoordinators()
    }
    
    /// Dismiss modally presented coordinator also remove this coordinator from child list
    /// - parameter animated: if dismissing will be animated or not
    /// - parameter completion: the closure to execute after the dismissing finishes
    open func dismissModalCoordinator(animated: Bool = true, completion: (() -> Void)? = nil) {
        if modallyShownCoordinator == nil {
            assertionFailure("Model.Coordinator.dismissModalCoordinator(animated:completion:)\n" +
                "Unable to dismiss modal coordinator: modallyShownCoordinator is nil")
        }
        guard modallyShownCoordinator?.modallyShownCoordinator == nil else {
            assertionFailure("Model.Coordinator.dismissModalCoordinator(animated:completion:)\n" +
                "Attempt to dismiss coordinator witch already has own modal coordinator. Dismiss it first")
            modallyShownCoordinator?.dismissModalController(animated: animated, completion: { [weak self] in
                self?.dismissModalCoordinator(animated: true, completion: completion)
            })
            return
        }
        
        modallyShownCoordinator?.removeFromParent()
        modallyShownCoordinator = nil
        dismissModalController(animated: animated, completion: completion)
    }
    
    /// Dismiss modally presented controller
    /// - parameter animated: if dismissing will be animated or not
    /// - parameter completion: the closure to execute after the dismissing finishes
    open func dismissModalController(animated: Bool = true, completion: (() -> Void)? = nil) {
        if modallyShownCoordinator != nil {
            assertionFailure("Model.Coordinator.dismissModalController(animated:completion:)\n" +
                "You should dismiss modal coordinator first.")
        }
        if modallyShownController == nil {
            assertionFailure("Model.Coordinator.dismissModalController(animated:completion:)\n" +
                "Unable to dismiss modal coordinator: modallyShownController is nil")
            return
        }
        modallyShownController?.dismiss(animated: animated, completion: completion)
        modallyShownController = nil
    }
    
    /// Dismiss modally presented coordinator if it's type is equal to passed
    /// - parameter type: coordinator's type to be found
    /// - parameter animated: if dismissing will be animated or not
    /// - parameter completion: the closure to execute after the dismissing finishes
    open func dismissModalCoordinator<CoordinatorType: Coordinator>(type: CoordinatorType.Type, animated: Bool = true, completion: (() -> Void)? = nil) {
        guard modallyShownCoordinator is CoordinatorType else { return }
        dismissModalCoordinator(animated: animated, completion: completion)
    }
    
    /// Returns closure that dismiss modally presented coordinator if it's type is equal to passed
    /// - parameter type: coordinator's type to be found
    /// - parameter animated: if dismissing will be animated or not
    /// - parameter completion: the closure to execute after the dismissing finishes
    open func dismissModalCoordinatorClosure<CoordinatorType: Coordinator>(type: CoordinatorType.Type) -> () -> () {
        return { [weak self] in
            self?.dismissModalCoordinator(type: CoordinatorType.self, animated: true)
        }
    }
    
    /// Returns first coordinator in child list with required type or nil if not found
    /// - parameter type: coordinator's type to be found
    open func childCoordinator<CoordinatorType: Coordinator>(withType type: CoordinatorType.Type) -> CoordinatorType? {
        let coordinator = (children.first { $0 is CoordinatorType } as? CoordinatorType)
        return coordinator
    }

    /// Clear unused children coordinators
    open func clearUnusedChildCoordinators() {
        children
            .filter({ baseViewController.children.contains($0.baseViewController) && $0 != modallyShownCoordinator })
            .forEach({ $0.removeFromParent() })
    }
}

// MARK: - Coordinator+UIAdaptivePresentationControllerDelegate
extension Coordinator: UIAdaptivePresentationControllerDelegate {
    public func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        guard modallyShownCoordinator?.modallyShownCoordinator == nil else {
            assertionFailure("Model.Coordinator.presentationControllerShouldDismiss(_:)\n" +
                "Attempt to dismiss coordinator witch already has own modal coordinator. Dismiss it first")
            modallyShownCoordinator?.dismissModalController(animated: true, completion: { [weak self] in
                self?.dismissModalCoordinator(animated: true, completion: nil)
            })
            return false
        }

        guard modallyShownController != nil
            && presentationController.presentedViewController === modallyShownController else {
            assertionFailure("Model.Coordinator.Coordinator.presentationControllerShouldDismiss(_:)\n" +
                "Unable to adaptive dismiss modal controller: modallyShownController is nil or not contains at presentationController")
            return false
        }

        guard let interactiveDismissalHandler = (modallyShownController ?? presentationController.presentedViewController) as? InteractiveDismissalHandler else { return true }

        var isGestureAllowed = false
        var isDismissUncompleted = false
        interactiveDismissalHandler.handleInteractiveDismissal(.modalInteractiveGesture, allow: { [weak self] in
            if isDismissUncompleted {
                self?.dismissModalController()
            }
            isGestureAllowed = true
        }, deny: {})
        isDismissUncompleted = true
        return isGestureAllowed
    }

    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        guard presentationController.presentedViewController === modallyShownController else {
            assertionFailure("Model.Coordinator.Coordinator.presentationControllerDidDismiss(_:)\n" +
                "Unable to adaptive dismiss modal controller: modallyShownController is not contains at presentationController")
            return
        }

        modallyShownCoordinator?.removeFromParent()
        modallyShownCoordinator = nil
        modallyShownController = nil
    }
}
