//
//  PostOffice.swift
//
//
//  Created by Adam Wulf on 08.27.22.
//

import Foundation
import Locks

/// A `PostOffice` is able to send strongly-typed notifications from any strongly-typed sender, and will
/// relay them to all registered recipients appropriately.
///
/// A ``default`` `PostOffice` is provided. To send a notification:
///
/// ```swift
/// PostOffice.default.post(yourNotification, sender: yourSender)
/// ```
public class PostOffice {

    // MARK: - Public

    /// A default `PostOffice`, akin to `NotificationCenter.default`.
    public static let `default` = PostOffice()

    // MARK: - Private

    /// A key to help cache recipients into `listeners`. This provides a hashable value for an arbitrary swift type
    /// and also provides an easy method to test if any object matches a type. This helps all recipients for a specific
    /// type to be grouped together in `listeners`, and for any notification object to be quickly tested to see which
    /// groups of recipients should be notified.
    private struct Key: Hashable {
        let name: String
        let test: (Any) -> Bool

        static func == (lhs: PostOffice.Key, rhs: PostOffice.Key) -> Bool {
            return lhs.name == rhs.name
        }
        func hash(into hasher: inout Hasher) {
            hasher.combine(name)
        }

        static func key<T>(for type: T.Type) -> Key {
            return Key(name: String(describing: type),
                       test: { obj in
                        return obj is T
                       })
        }
    }

    /// Storage to keep the recipient and all of its metadata conveniently linked
    private struct RecipientContext {
        let recipient: AnyRecipient
        let queue: DispatchQueue?
        let sender: AnyObject?
        let id: RecipientId

        init(recipient: AnyRecipient, queue: DispatchQueue?, sender: AnyObject?) {
            self.recipient = recipient
            self.queue = queue
            self.sender = sender
            self.id = RecipientId()
        }
    }

    private let lock = Mutex()
    private var listeners: [Key: [RecipientContext]] = [:]
    private var recipientToKey: [RecipientId: Key] = [:]

    // MARK: - Internal

    /// The number of listeners for all registered types. Used for testing only.
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return listeners.reduce(0, { $0 + $1.value.count })
    }

    // MARK: - Initializer

    /// A default `PostOffice` is already provided at `PostOffice.default`. If more than one `PostOffice` is required,
    /// one can be built with `PostOffice()`.
    public init() {
        // noop
    }

    // MARK: - Register Method with Sender

    /// Register a recipient and method with the `PostOffice`. This method will be called if the posted notification
    /// matches the method's parameter's type. The sender must also match the method's type or be `nil`.
    ///
    /// - parameter queue: The recipient will always receive posts on this queue. If `nil`, then the post will be made
    /// on the queue of the sender.
    /// - parameter sender: Optional. Ignored if `nil`, otherwise will limit the received notifications to only those sent by the `sender`.
    /// - parameter recipient: The object that will receive the posted ``Mail``.
    /// - parameter method: The method of the `recipient` that will be called with the posted ``Mail``. Its two arguments
    /// include the notification, and an optional `sender`. The method will only be called if both the notification and `sender`
    /// types match, or if the notification type matches and the `sender` is `nil`.
    /// - returns: A ``RecipientId`` that can be used later to unregister the recipient.
    ///
    /// Example registration code:
    /// ```
    /// PostOffice.default.register(recipient, ExampleRecipient.receiveNotification)
    /// ```
    @discardableResult
    public func register<T: AnyObject, Notification: Mail, Sender: AnyObject>(queue: DispatchQueue? = nil,
                                                                              sender: Sender? = nil,
                                                                              _ recipient: T,
                                                                              _ method: @escaping (T) -> (Notification, Sender?) -> Void)
    -> RecipientId {
        lock.lock()
        defer { lock.unlock() }
        let name = Key.key(for: Notification.self)
        let context = RecipientContext(recipient: AnyRecipient(recipient, method), queue: queue, sender: sender)
        listeners[name, default: []].append(context)
        recipientToKey[context.id] = name
        return context.id
    }

    /// Register a recipient and method with the `PostOffice`. This method will be called if both the posted notification
    /// and `sender` match the method's parameter's type.
    ///
    /// - parameter queue: The recipient will always receive posts on this queue. If `nil`, then the post will be made
    /// on the queue of the sender.
    /// - parameter sender: Optional. Ignored if `nil`, otherwise will limit the received notifications to only those sent by the `sender`.
    /// - parameter recipient: The object that will receive the posted ``Mail``.
    /// - parameter method: The method of the `recipient` that will be called with the posted notification. Its two arguments
    /// include the notification, and a required `sender`. The method will only be called if both the notification and `sender`
    /// types match.
    /// - returns: A ``RecipientId`` that can be used later to unregister the recipient.
    ///
    /// Example registration code:
    /// ```
    /// PostOffice.default.register(recipient, ExampleRecipient.receiveNotification)
    /// ```
    @discardableResult
    public func register<T: AnyObject, Notification: Mail, Sender: AnyObject>(queue: DispatchQueue? = nil,
                                                                              sender: Sender? = nil,
                                                                              _ recipient: T,
                                                                              _ method: @escaping (T) -> (Notification, Sender) -> Void)
    -> RecipientId {
        lock.lock()
        defer { lock.unlock() }
        let name = Key.key(for: Notification.self)
        let context = RecipientContext(recipient: AnyRecipient(recipient, method), queue: queue, sender: sender)
        listeners[name, default: []].append(context)
        recipientToKey[context.id] = name
        return context.id
    }

    // MARK: - Register Method without Sender

    /// Register a recipient and method with the `PostOffice`. This method will be called if the posted notification
    /// matches the method's parameter's type.
    ///
    /// - parameter queue: The recipient will always receive posts on this queue. If `nil`, then the post will be made
    /// on the queue of the sender.
    /// - parameter sender: Optional. Limits the received notifications to only those sent by the `sender`.
    /// - parameter recipient: The object that will receive the posted ``Mail``.
    /// - parameter method: The method of the `recipient` that will be called with the posted notification. Its one argument
    /// is the posted notification. The method will only be called if the notification matches the method's argument type.
    /// - returns: A ``RecipientId`` that can be used later to unregister the recipient.
    ///
    /// Example registration code:
    /// ```
    /// PostOffice.default.register(recipient, ExampleRecipient.receiveNotification)
    /// ```
    @discardableResult
    public func register<T: AnyObject, Notification: Mail, Sender: AnyObject>(
        queue: DispatchQueue? = nil,
        sender: Sender?,
        _ recipient: T,
        _ method: @escaping (T) -> (Notification) -> Void) -> RecipientId {
        lock.lock()
        defer { lock.unlock() }
        let name = Key.key(for: Notification.self)
        let context = RecipientContext(recipient: AnyRecipient(recipient, method), queue: queue, sender: sender)
        listeners[name, default: []].append(context)
        recipientToKey[context.id] = name
        return context.id
    }

    /// Register a recipient and method with the `PostOffice`. This method will be called if the posted notification
    /// matches the method's parameter's type.
    ///
    /// - parameter queue: The recipient will always receive posts on this queue. If `nil`, then the post will be made
    /// on the queue of the sender.
    /// - parameter recipient: The object that will receive the posted notification.
    /// - parameter method: The method of the `recipient` that will be called with the posted ``Mail``. Its one argument
    /// is the posted notification. The method will only be called if the notification matches the method's argument type.
    /// - returns: A ``RecipientId`` that can be used later to unregister the recipient.
    ///
    /// Example registration code:
    /// ```
    /// PostOffice.default.register(recipient, ExampleRecipient.receiveNotification)
    /// ```
    @discardableResult
    public func register<T: AnyObject, Notification: Mail>(queue: DispatchQueue? = nil,
                                                           _ recipient: T,
                                                           _ method: @escaping (T) -> (Notification) -> Void) -> RecipientId {
        lock.lock()
        defer { lock.unlock() }
        let sender: AnyObject? = nil
        let name = Key.key(for: Notification.self)
        let context = RecipientContext(recipient: AnyRecipient(recipient, method), queue: queue, sender: sender)
        listeners[name, default: []].append(context)
        recipientToKey[context.id] = name
        return context.id
    }

    // MARK: - Register Block with Sender

    /// Register a block for the object and sender as parameters. This block will be called if the sender matches
    /// the `sender` parameter, or if the sender is `nil`.
    ///
    /// - parameter queue: The recipient will always receive posts on this queue. If `nil`, then the post will be made
    /// on the queue of the sender.
    /// - parameter sender: Optional. Ignored if `nil`, otherwise will limit the received notifications to only those sent by the `sender`.
    /// - parameter block: The block that will receive the posted ``Mail`` and sender, if any. Posted notifications
    /// that are sent with a `nil` sender will be passed to this block as well
    /// - returns: A ``RecipientId`` that can be used later to unregister the recipient.
    ///
    /// Example registration code:
    /// ```
    /// PostOffice.default.register { (notification: MyNotification, sender: MySender?) in ... }
    /// ```
    @discardableResult
    public func register<Notification: Mail, Sender: AnyObject>(queue: DispatchQueue? = nil,
                                                                sender: Sender? = nil,
                                                                _ block: @escaping (Notification, Sender?) -> Void) -> RecipientId {
        lock.lock()
        defer { lock.unlock() }
        let name = Key.key(for: Notification.self)
        let context = RecipientContext(recipient: AnyRecipient(block), queue: queue, sender: sender)
        listeners[name, default: []].append(context)
        recipientToKey[context.id] = name
        return context.id
    }

    /// Register a block for the object and sender as parameters. The block will be called if the sender matches
    /// the `sender` param, if any. If the `sender` parameter is nil, then all senders will be sent to this block.
    /// If the notification is posted without a sender, this block will not be called.
    ///
    /// - parameter queue: The recipient will always receive posts on this queue. If `nil`, then the post will be made
    /// on the queue of the sender.
    /// - parameter sender: Optional. Ignored if `nil`, otherwise will limit the received notifications to only those sent by the `sender`.
    /// - parameter block: The block that will receive the posted ``Mail`` and sender.
    /// - returns: A ``RecipientId`` that can be used later to unregister the recipient.
    ///
    /// ```
    /// PostOffice.default.register { (notification: MyNotification, sender: MySender) in ... }
    /// ```
    @discardableResult
    public func register<Notification: Mail, Sender: AnyObject>(queue: DispatchQueue? = nil,
                                                                sender: Sender? = nil,
                                                                _ block: @escaping (Notification, Sender) -> Void) -> RecipientId {
        lock.lock()
        defer { lock.unlock() }
        let name = Key.key(for: Notification.self)
        let optBlock = { (note: Notification, sender: Sender?) in
            guard let sender = sender else { return }
            block(note, sender)
        }
        let context = RecipientContext(recipient: AnyRecipient(optBlock), queue: queue, sender: sender)
        listeners[name, default: []].append(context)
        recipientToKey[context.id] = name
        return context.id
    }

    // MARK: - Register Block without Sender

    /// Register a block from an optional `sender` with the notification as the single parameter.
    ///
    /// - parameter queue: The recipient will always receive posts on this queue. If `nil`, then the post will be made
    /// on the queue of the sender.
    /// - parameter sender: Optional. Ignored if `nil`, otherwise will limit the received notifications to only those sent by the `sender`.
    /// - parameter block: The block that will receive the posted ``Mail``.
    /// - returns: A ``RecipientId`` that can be used later to unregister the recipient.
    ///
    /// ```
    /// PostOffice.default.register { (notification: MyNotification) in ... }
    /// ```
    @discardableResult
    public func register<Notification: Mail, Sender: AnyObject>(queue: DispatchQueue? = nil,
                                                                sender: Sender?,
                                                                _ block: @escaping (Notification) -> Void) -> RecipientId {
        return register(queue: queue, sender: sender, { (notification: Notification, _: Sender?) in
            block(notification)
        })
    }

    /// Register a block with the notification as the single parameter:
    ///
    /// - returns: A ``RecipientId`` that can be used later to unregister the recipient.
    ///
    /// - parameter queue: The recipient will always receive posts on this queue. If `nil`, then the post will be made
    /// on the queue of the sender.
    /// - parameter block: The block that will receive the posted ``Mail``.
    /// ```
    /// PostOffice.default.register { (notification: ExampleNotification) in ... }
    /// ```
    @discardableResult
    public func register<Notification: Mail>(queue: DispatchQueue? = nil,
                                             _ block: @escaping (Notification) -> Void) -> RecipientId {
        let anySender: AnyObject? = nil
        return register(queue: queue, sender: anySender, { notification in
            block(notification)
        })
    }

    // MARK: - Unregister

    /// Stops any future notifications from being sent to the recipient method or block that was registered with this ``RecipientId``.
    /// - parameter recipient: The ``RecipientId`` that was returned from a registration method.
    public func unregister(_ recipient: RecipientId) {
        lock.lock()
        defer { lock.unlock() }
        guard let name = recipientToKey.removeValue(forKey: recipient) else { return }
        listeners[name]?.removeAll(where: { $0.id == recipient })
    }

    // MARK: - Post

    /// Sends the notification to all recipients that match the notification's type.
    /// - parameter notification: The notification object to send, must conform to ``Mail``.
    /// - parameter sender: Optional. Ignored if `nil`. The object that represents the sender of the notification.
    public func post<S: AnyObject>(_ notification: Mail, sender: S? = nil) {
        lock.lock()
        var allListeners: [RecipientContext] = []
        for key in listeners.keys {
            if key.test(notification),
               let typeListeners = listeners[key] {
                allListeners.append(contentsOf: typeListeners)
                listeners[key] = typeListeners.filter({ !$0.recipient.canCollect })
            }
        }
        guard !allListeners.isEmpty else {
            lock.unlock()
            return
        }
        lock.unlock()

        for listener in allListeners {
            guard listener.sender == nil || listener.sender === sender else { continue }
            if let queue = listener.queue {
                queue.async {
                    listener.recipient.block?(notification, sender)
                }
            } else {
                listener.recipient.block?(notification, sender)
            }
        }
    }

    /// Sends the notification to all recipients that match the notification's type.
    /// - parameter notification: The notification object to send, must conform to ``Mail``.
    public func post(_ notification: Mail) {
        let anySender: AnyObject? = nil
        post(notification, sender: anySender)
    }
}
