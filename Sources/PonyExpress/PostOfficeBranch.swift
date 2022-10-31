//
//  PostOfficeBranch.swift
//  
//
//  Created by Adam Wulf on 10/16/22.
//

import Foundation

/// Just like a ``PostOffice`` but also able to limit the types of posts and senders using generic types
/// - note: All notifications sent through this `PostOfficeBranch` must conform to `Notification`,
/// and all senders using this `PostOfficeBranch` must conform to `Sender`.
///
/// Define a `PostOfficeBranch` to more narrowly define what types of notifications can be sent from
/// specific types of senders. While observers are strictly typed in ``PostOffice``, the sent notifications
/// and senders are not type constrained. Using a `PostOfficeBranch` can add constraints to the
/// notifications and senders, which helps prevent sending incorrect notification objects or senders due to
/// typos or other common coding mistakes.
///
/// ```swift
/// let myBranch = PostOfficeBranch<MySpecificEvents, MySender>()
/// ```
public class PostOfficeBranch<Notification, Sender: AnyObject> {
    /// The ``PostOffice`` used to send the posts
    private let mainBranch = PostOffice()

    // MARK: - Runtime Checks

    @discardableResult
    public func register<T: AnyObject, N, S>(queue: DispatchQueue? = nil,
                                       sender: Sender? = nil,
                                       _ recipient: T,
                                       _ method: @escaping (T) -> (N, S?) -> Void) -> RecipientId {
        // The problem is that we allow the registrar to register a recipient+method with a type
        // that doesn't conform to Notification. It correctly won't ever be called, and won't crash,
        // but ideally we'd see a compile error when trying to register a method to an invalid type.
        //
        // something like:
        // guard N is Notification else { fatalError() }
        let block = { (_ arg1: Notification, _ arg2: Sender?) -> Void in
            if let arg2 = arg2 {
                guard let a = arg1 as? N, let b = arg2 as? S else { fatalError("types don't match") }
                method(recipient)(a, b)
            } else {
                guard let a = arg1 as? N else { return }
                method(recipient)(a, nil)
            }
        }
        return register(queue: queue, sender: sender, block)
    }

    // MARK: - Register Method with Sender

    /// Register a recipient and method with the `PostOffice`. This method will be called if the posted notification
    /// matches the method's parameter's type. The sender must also match the method's type or be `nil`.
    ///
    /// - parameter queue: The recipient will always receive posts on this queue. If `nil`, then the post will be made
    /// on the queue of the sender.
    /// - parameter sender: Optional. Ignored if `nil`, otherwise will limit the received notifications to only those sent by the `sender`.
    /// - parameter recipient: The object that will receive the posted notification.
    /// - parameter method: The method of the `recipient` that will be called with the posted notification. Its two arguments
    /// include the notification, and an optional `sender`. The method will only be called if both the notification and `sender`
    /// types match, or if the notification type matches and the `sender` is `nil`. The method arguments must conform to `PostOfficeBranch`
    /// generic constraints `Notification` and `Sender`. Parameter names in the method are ignored.
    /// - returns: A ``RecipientId`` that can be used later to unregister the recipient.
    ///
    /// Example registration code:
    /// ```
    /// PostOffice.default.register(recipient, ExampleRecipient.receiveNotification)
    /// ```
    @discardableResult
    public func register<T: AnyObject>(queue: DispatchQueue? = nil,
                                       sender: Sender? = nil,
                                       _ recipient: T,
                                       _ method: @escaping (T) -> (Notification, Sender?) -> Void) -> RecipientId {
        mainBranch.register(queue: queue, sender: sender, recipient, method)
    }

    /// Register a recipient and method with the `PostOffice`. This method will be called if both the posted notification
    /// and `sender` match the method's parameter's type.
    ///
    /// - parameter queue: The recipient will always receive posts on this queue. If `nil`, then the post will be made
    /// on the queue of the sender.
    /// - parameter sender: Optional. Ignored if `nil`, otherwise will limit the received notifications to only those sent by the `sender`.
    /// - parameter recipient: The object that will receive the posted notification.
    /// - parameter method: The method of the `recipient` that will be called with the posted notification. Its two arguments
    /// include the notification, and a required `sender`. The method will only be called if both the notification and `sender`
    /// types match.  The method arguments must conform to `PostOfficeBranch` generic constraints `Notification`
    /// and `Sender`. Parameter names in the method are ignored.
    /// - returns: A ``RecipientId`` that can be used later to unregister the recipient.
    ///
    /// Example registration code:
    /// ```
    /// PostOffice.default.register(recipient, ExampleRecipient.receiveNotification)
    /// ```
    @discardableResult
    public func register<T: AnyObject>(queue: DispatchQueue? = nil,
                                       sender: Sender? = nil,
                                       _ recipient: T,
                                       _ method: @escaping (T) -> (Notification, Sender) -> Void) -> RecipientId {
        mainBranch.register(queue: queue, sender: sender, recipient, method)
    }

    // MARK: - Register Method without Sender

    /// Register a recipient and method with the `PostOffice`. This method will be called if the posted notification
    /// matches the method's parameter's type.
    ///
    /// - parameter queue: The recipient will always receive posts on this queue. If `nil`, then the post will be made
    /// on the queue of the sender.
    /// - parameter sender: Limits the received notifications to only those sent by the `sender`.
    /// - parameter recipient: The object that will receive the posted notification.
    /// - parameter method: The method of the `recipient` that will be called with the posted notification. Its one argument
    /// is the posted notification. The method will only be called if the notification matches the method's argument type. The method argument
    /// must conform to `PostOfficeBranch` generic constraint `Notification`. The parameter name in the method is ignored.
    /// - returns: A ``RecipientId`` that can be used later to unregister the recipient.
    ///
    /// Example registration code:
    /// ```
    /// PostOffice.default.register(recipient, ExampleRecipient.receiveNotification)
    /// ```
    @discardableResult
    public func register<T: AnyObject>(queue: DispatchQueue? = nil,
                                       sender: Sender?,
                                       _ recipient: T,
                                       _ method: @escaping (T) -> (Notification) -> Void) -> RecipientId {
        mainBranch.register(queue: queue, sender: sender, recipient, method)
    }

    /// Register a recipient and method with the `PostOffice`. This method will be called if the posted notification
    /// matches the method's parameter's type.
    ///
    /// - parameter queue: The recipient will always receive posts on this queue. If `nil`, then the post will be made
    /// on the queue of the sender.
    /// - parameter recipient: The object that will receive the posted notification.
    /// - parameter method: The method of the `recipient` that will be called with the posted notification. Its one argument
    /// is the posted notification. The method will only be called if the notification matches the method's argument type. The method argument
    /// must conform to `PostOfficeBranch` generic constraint `Notification`. The parameter name in the method is ignored.
    /// - returns: A ``RecipientId`` that can be used later to unregister the recipient.
    ///
    /// Example registration code:
    /// ```
    /// PostOffice.default.register(recipient, ExampleRecipient.receiveNotification)
    /// ```
    @discardableResult
    public func register<T: AnyObject>(queue: DispatchQueue? = nil,
                                       _ recipient: T,
                                       _ method: @escaping (T) -> (Notification) -> Void) -> RecipientId {
        mainBranch.register(queue: queue, recipient, method)
    }

    // MARK: - Register Block with Sender

    /// Register a block for the object and sender as parameters. This block will be called if the sender matches
    /// the `sender` parameter, or if the sender is `nil`.
    ///
    /// - parameter queue: The recipient will always receive posts on this queue. If `nil`, then the post will be made
    /// on the queue of the sender.
    /// - parameter sender: Optional. Ignored if `nil`, otherwise will limit the received notifications to only those sent by the `sender`.
    /// - parameter block: The block that will receive the posted notification and sender, if any. Posted notifications
    /// that are sent with a `nil` sender will be passed to this block as well. The block arguments must conform to `PostOfficeBranch`
    /// generic constraints `Notification` and `Sender`. The parameter names in the block are ignored.
    /// - returns: A ``RecipientId`` that can be used later to unregister the recipient.
    ///
    /// Example registration code:
    /// ```
    /// PostOffice.default.register { (notification: MyNotification, sender: MySender?) in ... }
    /// ```
    @discardableResult
    public func register(queue: DispatchQueue? = nil,
                         sender: Sender? = nil,
                         _ block: @escaping (Notification, Sender?) -> Void) -> RecipientId {
        mainBranch.register(queue: queue, sender: sender, block)
    }

    /// Register a block for the object and sender as parameters. The block will be called if the sender matches
    /// the `sender` param, if any. If the `sender` parameter is nil, then all senders will be sent to this block.
    /// If the notification is posted without a sender, this block will not be called.
    ///
    /// - parameter queue: The recipient will always receive posts on this queue. If `nil`, then the post will be made
    /// on the queue of the sender.
    /// - parameter sender: Optional. Ignored if `nil`, otherwise will limit the received notifications to only those sent by the `sender`.
    /// - parameter block: The block that will receive the posted notification and sender. The block arguments must conform to
    /// `PostOfficeBranch` generic constraints `Notification` and `Sender`. The parameter names in the block are ignored.
    /// - returns: A ``RecipientId`` that can be used later to unregister the recipient.
    ///
    /// ```
    /// PostOffice.default.register { (notification: MyNotification, sender: MySender) in ... }
    /// ```
    @discardableResult
    public func register(queue: DispatchQueue? = nil,
                         sender: Sender? = nil,
                         _ block: @escaping (Notification, Sender) -> Void) -> RecipientId {
        mainBranch.register(queue: queue, sender: sender, block)
    }

    // MARK: - Register Block without Sender

    /// Register a block with the object as the single parameter:
    ///
    /// - parameter queue: The recipient will always receive posts on this queue. If `nil`, then the post will be made
    /// on the queue of the sender.
    /// - parameter sender: Optional. Ignored if `nil`, otherwise will limit the received notifications to only those sent by the `sender`.
    /// - parameter block: The block that will receive the posted notification. The block argument must conform to
    /// `PostOfficeBranch` generic constraint `Notification`. The parameter name in the block is ignored.
    /// - returns: A ``RecipientId`` that can be used later to unregister the recipient.
    ///
    /// ```
    /// PostOffice.default.register { (notification: MyNotification) in ... }
    /// ```
    @discardableResult
    public func register(queue: DispatchQueue? = nil,
                         sender: Sender?,
                         _ block: @escaping (Notification) -> Void) -> RecipientId {
        mainBranch.register(queue: queue, sender: sender, block)
    }

    /// Register a block with the object as the single parameter:
    ///
    /// - returns: A ``RecipientId`` that can be used later to unregister the recipient.
    ///
    /// - parameter queue: The recipient will always receive posts on this queue. If `nil`, then the post will be made
    /// on the queue of the sender.
    /// - parameter block: The block that will receive the posted notification. The block argument must conform to
    /// `PostOfficeBranch` generic constraint `Notification`. The parameter name in the block is ignored.
    /// ```
    /// PostOffice.default.register { (notification: ExampleNotification) in ... }
    /// ```
    @discardableResult
    public func register(queue: DispatchQueue? = nil,
                         _ block: @escaping (Notification) -> Void) -> RecipientId {
        mainBranch.register(queue: queue, block)
    }

    // MARK: - Unregister

    /// Stops any future notifications from being sent to the recipient method or block that was registered with this ``RecipientId``.
    /// - parameter recipient: The ``RecipientId`` that was returned from a registration method.
    /// - note: Calling this method with an already unregistered `RecipientId` does nothing.
    public func unregister(_ recipient: RecipientId) {
        mainBranch.unregister(recipient)
    }

    // MARK: - Post

    /// Sends the notification to all recipients that match the notification's type.
    /// - parameter notification: The notification object to send. Must conform to `PostOfficeBranch` generic `Notification` parameter.
    /// - parameter sender: Optional. Ignored if `nil`. The object that represents the sender of the notification. Must conform
    /// to `PostOfficeBranch` generic `Sender` parameter.
    public func post(_ notification: Notification, sender: Sender? = nil) {
        mainBranch.post(notification, sender: sender)
    }

    /// Sends the notification to all recipients that match the notification's type.
    /// - parameter notification: The notification object to send.
    public func post(_ notification: Notification) {
        mainBranch.post(notification)
    }
}
