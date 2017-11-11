// The MIT License (MIT)
//
// Copyright (c) 2017 Alexander Grebenyuk (github.com/kean).

import UIKit


public struct LayoutCompatible<Base> {
    internal let base: Base
}

extension UIView {
    @nonobjc public var al: LayoutCompatible<UIView> { return LayoutCompatible(base: self) }
}

extension UILayoutGuide {
    @nonobjc public var al: LayoutCompatible<UILayoutGuide> { return LayoutCompatible(base: self) }
}

extension LayoutCompatible where Base: AnchorCompatible {
    // MARK: Anchors

    public var top: Anchor<AnchorTypeEdge, AnchorAxisVertical> { return Anchor(item: base, attribute: .top) }
    public var bottom: Anchor<AnchorTypeEdge, AnchorAxisVertical> { return Anchor(item: base, attribute: .bottom) }
    public var left: Anchor<AnchorTypeEdge, AnchorAxisHorizontal> { return Anchor(item: base, attribute: .left) }
    public var right: Anchor<AnchorTypeEdge, AnchorAxisHorizontal> { return Anchor(item: base, attribute: .right) }
    public var leading: Anchor<AnchorTypeEdge, AnchorAxisHorizontal> { return Anchor(item: base, attribute: .leading) }
    public var trailing: Anchor<AnchorTypeEdge, AnchorAxisHorizontal> { return Anchor(item: base, attribute: .trailing) }

    public var centerX: Anchor<AnchorTypeCenter, AnchorAxisHorizontal> { return Anchor(item: base, attribute: .centerX) }
    public var centerY: Anchor<AnchorTypeCenter, AnchorAxisVertical> { return Anchor(item: base, attribute: .centerY) }

    public var width: Anchor<AnchorTypeDimension, AnchorAxisHorizontal> { return Anchor(item: base, attribute: .width) }
    public var height: Anchor<AnchorTypeDimension, AnchorAxisVertical> { return Anchor(item: base, attribute: .height) }

    // MARK: Anchors Collections

    public func edges(_ axis: UILayoutConstraintAxis) -> EdgesCollection { return EdgesCollection(item: base, axis: [axis]) }
    public var edges: EdgesCollection { return EdgesCollection(item: base, axis: [.horizontal, .vertical]) }
    public var center: AxisCollection { return AxisCollection(centerX: centerX, centerY: centerY) }
    public var size: DimensionsCollection { return DimensionsCollection(width: width, height: height) }
}

extension LayoutCompatible where Base: UIView {
    public var margins: LayoutCompatible<UILayoutGuide> { return base.layoutMarginsGuide.al }

    @available(iOS 11.0, tvOS 11.0, *)
    public var safeArea: LayoutCompatible<UILayoutGuide> { return base.safeAreaLayoutGuide.al }
}

public protocol AnchorCompatible {
    var superview: UIView? { get }
}

extension UIView: AnchorCompatible {}
extension UILayoutGuide: AnchorCompatible {
    public var superview: UIView? { return self.owningView }
}


// MARK: Anchors

// phantom types
public class AnchorAxisHorizontal {}
public class AnchorAxisVertical {}

public class AnchorTypeDimension {}
public class AnchorTypeCenter: AnchorTypeAlignment {}
public class AnchorTypeEdge: AnchorTypeAlignment {}

public protocol AnchorTypeAlignment {} // center or edge

public struct Anchor<Type, Axis> { // type and axis are phantom types
    internal let item: AnchorCompatible
    internal let attribute: NSLayoutAttribute
    internal let offset: CGFloat

    init(item: AnchorCompatible, attribute: NSLayoutAttribute, offset: CGFloat = 0) {
        self.item = item
        self.attribute = attribute
        self.offset = offset
    }
}

extension Anchor where Type: AnchorTypeAlignment {
    /// Aligns the anchors.
    @discardableResult
    public func align<Type: AnchorTypeAlignment>(with anchor: Anchor<Type, Axis>, offset: CGFloat = 0, multiplier: CGFloat = 1, relation: NSLayoutRelation = .equal) -> NSLayoutConstraint {
        return _constraint(self, anchor, offset: offset, multiplier: multiplier, relation: relation)
    }

    /// Returns the anchor for the same axis, but offset by a given amount.
    @discardableResult
    public func offset(by offset: CGFloat) -> Anchor<Type, Axis> {
        return Anchor<Type, Axis>(item: item, attribute: attribute, offset: offset)
    }
}

extension Anchor where Type: AnchorTypeEdge {
    /// Pins the edge to the same edge of the superview.
    @discardableResult
    public func pinToSuperview(inset: CGFloat = 0, relation: NSLayoutRelation = .equal) -> NSLayoutConstraint {
        return _pin(self, to: item.superview!, inset: inset, relation: relation)
    }

    /// Pins the edge to the respected margin of the superview.
    @discardableResult
    public func pinToSuperviewMargin(inset: CGFloat = 0, relation: NSLayoutRelation = .equal) -> NSLayoutConstraint {
        return _pin(self, to: item.superview!.layoutMarginsGuide, inset: inset, relation: relation)
    }
}

extension Anchor where Type: AnchorTypeCenter {
    /// Aligns the axis with a superview axis.
    @discardableResult
    public func alignWithSuperview(offset: CGFloat = 0, relation: NSLayoutRelation = .equal) -> NSLayoutConstraint {
        return align(with: Anchor<Type, Axis>(item: self.item.superview!, attribute: self.attribute), offset: offset, relation: relation)
    }
}

extension Anchor where Type: AnchorTypeDimension {
    /// Sets the dimension to a specific size.
    @discardableResult
    public func set(_ constant: CGFloat, relation: NSLayoutRelation = .equal) -> NSLayoutConstraint {
        return Layout.constraint(item: item, attribute: attribute, relation: relation, constant: constant)
    }

    /// Make the dimension
    @discardableResult
    public func same<Axis>(as anchor: Anchor<AnchorTypeDimension, Axis>, offset: CGFloat = 0, multiplier: CGFloat = 1, relation: NSLayoutRelation = .equal) -> NSLayoutConstraint {
        return _constraint(self, anchor, offset: offset, multiplier: multiplier, relation: relation)
    }
}

private func _constraint<T1, A1, T2, A2>(_ lhs: Anchor<T1, A1>, _ rhs: Anchor<T2, A2>, offset: CGFloat = 0, multiplier: CGFloat = 1, relation: NSLayoutRelation = .equal) -> NSLayoutConstraint {
    return Layout.constraint(item: lhs.item, attribute: lhs.attribute, toItem: rhs.item, attribute: rhs.attribute, relation: relation, multiplier: multiplier, constant: offset - lhs.offset + rhs.offset)
}

private func _pin<T, A>(_ anchor: Anchor<T, A>, to item2: AnchorCompatible, inset: CGFloat = 0, relation: NSLayoutRelation = .equal) -> NSLayoutConstraint {
    let isInverted = inverted.contains(anchor.attribute)
    let other = Anchor<T, A>(item: item2, attribute: anchor.attribute) // other anchor
    return _constraint(anchor, other, offset: (isInverted ? -inset : inset), relation: (isInverted ? relation.inverted : relation))
}

private let inverted: Set<NSLayoutAttribute> = [.trailing, .right, .bottom, .trailingMargin, .rightMargin, .bottomMargin]


// MARK: Collections

public struct EdgesCollection {
    internal let item: AnchorCompatible
    internal let axis: Set<UILayoutConstraintAxis>
    private var attributes: [NSLayoutAttribute] {
        return axis.flatMap { $0 == .horizontal ? [.left, .right] : [.top, .bottom] }
    }

    /// Pins the edges of the view to the same edges of its superview.
    @discardableResult
    public func fillSuperview(insets: CGFloat, relation: NSLayoutRelation = .equal) -> [NSLayoutConstraint] {
        let insets = UIEdgeInsets(top: insets, left: insets, bottom: insets, right: insets)
        return fill(item.superview!, insets: insets, relation: relation)
    }

    /// Pins the edges of the view to the same edges of its superview.
    @discardableResult
    public func fillSuperview(insets: UIEdgeInsets = .zero, relation: NSLayoutRelation = .equal) -> [NSLayoutConstraint] {
        return fill(item.superview!, insets: insets, relation: relation)
    }

    /// Pins the edges of the view to the corresponding margins of its superview.
    @discardableResult
    public func fillSuperviewMargins(insets: UIEdgeInsets = .zero, relation: NSLayoutRelation = .equal) -> [NSLayoutConstraint] {
        return fill(item.superview!.layoutMarginsGuide, insets: insets, relation: relation)
    }

    /// Pins the edges of the view to the same edges of the given item.
    @discardableResult
    public func fill(_ container: AnchorCompatible, insets: UIEdgeInsets = .zero, relation: NSLayoutRelation = .equal) -> [NSLayoutConstraint] {
        return attributes.map {
            let anchor = Anchor<Any, Any>(item: item, attribute: $0) // anchor for edge
            return _pin(anchor, to: container, inset: insets.inset(for: $0), relation: relation.inverted) // invert because the meaning or relation is diff
        }
    }
}

public struct AxisCollection {
    internal var centerX: Anchor<AnchorTypeCenter, AnchorAxisHorizontal>
    internal var centerY: Anchor<AnchorTypeCenter, AnchorAxisVertical>

    /// Centers the axis in the superview.
    @discardableResult
    public func alignWithSuperview() -> [NSLayoutConstraint] {
        return [centerX.alignWithSuperview(), centerY.alignWithSuperview()]
    }

    /// Makes the axis equal to the other collection of axis.
    @discardableResult
    public func align(with collection: AxisCollection) -> [NSLayoutConstraint] {
        return [centerX.align(with: collection.centerX), centerY.align(with: collection.centerY)]
    }
}

public struct DimensionsCollection {
    internal var width: Anchor<AnchorTypeDimension, AnchorAxisHorizontal>
    internal var height: Anchor<AnchorTypeDimension, AnchorAxisVertical>

    /// Set the size of item.
    @discardableResult
    public func set(_ size: CGSize, relation: NSLayoutRelation = .equal) -> [NSLayoutConstraint] {
        return [width.set(size.width, relation: relation), height.set(size.height, relation: relation)]
    }

    /// Makes the size of the item equal to the size of the other item.
    @discardableResult
    public func same(as collection: DimensionsCollection, insets: CGSize = .zero, multiplier: CGFloat = 1, relation: NSLayoutRelation = .equal) -> [NSLayoutConstraint] {
        return [width.same(as: collection.width, offset: -insets.width, multiplier: multiplier, relation: relation),
                height.same(as: collection.height, offset: -insets.height, multiplier: multiplier, relation: relation)]
    }
}


// MARK: Stack and Spacer

public typealias Stack = UIStackView

public extension Stack {
    @nonobjc public convenience init(_ views: UIView..., with: (UIStackView) -> Void = { _ in }) {
        self.init(arrangedSubviews: views)
        with(self)
    }

    @nonobjc public convenience init(_ views: [UIView], axis: UILayoutConstraintAxis = .horizontal, spacing: CGFloat = 0, alignment: UIStackViewAlignment = .fill, distribution: UIStackViewDistribution = .fill) {
        self.init(arrangedSubviews: views)
        self.axis = axis
        self.spacing = spacing
        self.alignment = alignment
        self.distribution = distribution
    }
}

public final class Spacer: UIView { // using `UIView` and not `UILayoutGuide` to support stack views
    @nonobjc public convenience init(width: CGFloat) {
        self.init(dimension: .width(width))
    }

    @nonobjc public convenience init(minWidth: CGFloat) {
        self.init(dimension: .width(minWidth), isFlexible: true)
    }

    @nonobjc public convenience init(height: CGFloat) {
        self.init(dimension: .height(height))
    }

    @nonobjc public convenience init(minHeight: CGFloat) {
        self.init(dimension: .height(minHeight), isFlexible: true)
    }

    private enum Dimension {
        case width(CGFloat), height(CGFloat)
    }

    private init(dimension: Dimension, isFlexible: Bool = false) {
        super.init(frame: .zero)
        Layout.make(id: "Yalta.Spacer") {
            switch dimension {
            case let .width(constant):
                al.width.set(constant, relation: isFlexible ? .greaterThanOrEqual : .equal)
                if isFlexible { al.width.set(0).priority = UILayoutPriority(42) } // disambiguate
                al.height.set(0).priority = UILayoutPriority(42)  // disambiguate
            case let .height(constant):
                al.height.set(constant, relation: isFlexible ? .greaterThanOrEqual : .equal)
                if isFlexible { al.height.set(0).priority = UILayoutPriority(42) } // disambiguate
                al.width.set(0).priority = UILayoutPriority(42) // disambiguate
            }
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public class var layerClass: Swift.AnyClass {
        return CATransformLayer.self
    }

    override public var backgroundColor: UIColor? {
        get { return nil }
        set { return }
    }
}


// MARK: Layout

public final class Layout { // this is what enabled autoinstalling
    private static let shared = Layout()
    private init() {}

    private final class Context { // context in which constraits get created.
        let priority: UILayoutPriority?
        let id: String?
        var constraints = [NSLayoutConstraint]()

        init(priority: UILayoutPriority?, id: String?) {
            self.priority = priority
            self.id = id
        }
    }

    private var stack = [Context]()

    /// All of the constraints created in the given closure are automatically
    /// activated. This is more efficient then installing them
    /// one-be-one. More importantly, it allows to make changes to the constraints
    /// before they are installed (e.g. change `priority`).
    @discardableResult
    public static func make(priority: UILayoutPriority? = nil, id: String? = nil, _ closure: () -> Void) -> [NSLayoutConstraint] {
        let context = Context(priority: priority, id: id)
        Layout.shared.stack.append(context)
        closure()
        let constraints = Layout.shared.stack.removeLast().constraints

        NSLayoutConstraint.activate(constraints)
        return constraints
    }

    private func install(_ constraint: NSLayoutConstraint) {
        if stack.isEmpty { // no longer batching updates
            NSLayoutConstraint.activate([constraint])
        } else { // remember which constaints to install when batch is completed
            let context = stack.last!
            if let priority = context.priority { constraint.priority = priority }
            constraint.identifier = context.id
            context.constraints.append(constraint)
        }
    }

    internal static func constraint(item item1: Any, attribute attr1: NSLayoutAttribute, toItem item2: Any? = nil, attribute attr2: NSLayoutAttribute? = nil, relation: NSLayoutRelation = .equal, multiplier: CGFloat = 1, constant: CGFloat = 0, priority: UILayoutPriority? = nil, identifier: String? = nil) -> NSLayoutConstraint {
        assert(Thread.isMainThread, "Yalta APIs can only be used from the main thread")
        (item1 as? UIView)?.translatesAutoresizingMaskIntoConstraints = false
        let constraint = NSLayoutConstraint( item: item1, attribute: attr1, relatedBy: relation, toItem: item2, attribute: attr2 ?? .notAnAttribute, multiplier: multiplier, constant: constant)
        if let priority = priority { constraint.priority = priority }
        constraint.identifier = identifier
        Layout.shared.install(constraint)
        return constraint
    }
}

internal extension NSLayoutRelation {
    var inverted: NSLayoutRelation {
        switch self {
        case .greaterThanOrEqual: return .lessThanOrEqual
        case .lessThanOrEqual: return .greaterThanOrEqual
        case .equal: return .equal
        }
    }
}

internal extension UIEdgeInsets {
    func inset(for attribute: NSLayoutAttribute) -> CGFloat {
        switch attribute {
        case .top: return top; case .bottom: return bottom
        case .left, .leading: return left
        case .right, .trailing: return right
        default: return 0
        }
    }
}
